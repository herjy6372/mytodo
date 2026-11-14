import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// FirebaseAuth 기반 인증 저장소.
/// 외부에서는 [email] / [isLoggedIn] / [signOut] 등 단순 API 만 사용합니다.
class AuthRepository extends ChangeNotifier {
  AuthRepository._();
  static final AuthRepository instance = AuthRepository._();

  static const _explicitLogoutKey = 'auth_explicit_logout';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _initialized = false;

  /// 앱 시작 시 한 번 호출.
  /// 1) FirebaseAuth 의 초기 세션 복원 이벤트를 기다리고,
  /// 2) 사용자가 직접 로그아웃한 적이 없는데 세션이 비어 있으면
  ///    GoogleSignIn silent 로그인으로 세션을 복구합니다.
  Future<void> load() async {
    if (_initialized) return;
    _initialized = true;

    // 1. FirebaseAuth 가 로컬 키체인/스토리지에서 세션을 복원할 때까지 대기
    try {
      await _auth
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // 타임아웃 또는 스트림 오류 시 현재 상태 유지
    }

    // 2. 명시적으로 로그아웃하지 않았는데 currentUser 가 null 이면 조용히 복원 시도
    if (_auth.currentUser == null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final explicitLogout = prefs.getBool(_explicitLogoutKey) ?? false;
        if (!explicitLogout) {
          final googleUser = await _googleSignIn
              .signInSilently()
              .timeout(const Duration(seconds: 4), onTimeout: () => null);
          if (googleUser != null) {
            final googleAuth = await googleUser.authentication;
            if (googleAuth.accessToken != null || googleAuth.idToken != null) {
              final credential = GoogleAuthProvider.credential(
                accessToken: googleAuth.accessToken,
                idToken: googleAuth.idToken,
              );
              await _auth.signInWithCredential(credential);
            }
          }
        }
      } catch (e) {
        debugPrint('자동 로그인 세션 복원 실패: $e');
      }
    }

    // 3. 이후 인증/토큰 상태 변화 구독
    _auth.userChanges().listen((_) {
      notifyListeners();
    });
    notifyListeners();
  }

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  String? get email => currentUser?.email ?? currentUser?.displayName;
  String? get uid => currentUser?.uid;

  /// 구글 로그인 (iOS/Android).
  /// iOS 의 경우 Info.plist 에 REVERSED_CLIENT_ID URL Scheme 이 등록돼 있어야 합니다.
  Future<void> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) {
      // 사용자가 취소
      throw FirebaseAuthException(
        code: 'cancelled',
        message: '로그인이 취소되었습니다.',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _auth.signInWithCredential(credential);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_explicitLogoutKey, false);
    } catch (_) {}
  }

  /// 로그아웃 — Firebase + Google 양쪽 모두 정리.
  Future<void> signOut() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_explicitLogoutKey, true);
    } catch (_) {}
    try {
      await _googleSignIn.signOut();
    } catch (_) {/* 구글 로그인 사용 안 했을 수 있음 */}
    await _auth.signOut();
  }

  /// 기존 호출 호환을 위한 별칭.
  Future<void> logout() => signOut();
}
