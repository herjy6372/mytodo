import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/private_config.dart';
import '../models/user_profile.dart';
import 'auth_repository.dart';

/// 프로필 저장소. Firestore users/{uid} 문서를 관리합니다.
/// 인증 상태가 바뀌면 자동으로 프로필을 로드/생성합니다.
class ProfileRepository extends ChangeNotifier {
  ProfileRepository._();
  static final ProfileRepository instance = ProfileRepository._();

  /// 항상 ADMIN 으로 부여되는 운영자 이메일.
  static const adminEmail = PrivateConfig.adminEmail;

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserProfile? _profile;
  StreamSubscription? _authSub;
  StreamSubscription? _profileSub;
  bool _initialized = false;
  String? _handlingUid;
  String? _localPhotoPath; // 기기 로컬에 저장된 프로필 사진 경로

  UserProfile? get profile => _profile;
  bool get hasProfile => _profile != null;
  UserRole get role => _profile?.role ?? UserRole.normal;

  /// 로컬 저장 사진 경로 (SharedPreferences 키).
  static String _localPhotoKey(String uid) => 'local_photo_$uid';

  /// 로컬 사진 경로. 없으면 null.
  String? get localPhotoPath => _localPhotoPath;

  /// 표시할 사진: 로컬 > Firestore photoUrl 순서.
  /// 로컬 경로면 'file:' 접두사를 붙여 반환 → UserAvatar 가 FileImage 로 처리.
  String? get displayPhotoUrl {
    final lp = _localPhotoPath;
    if (lp != null) return 'file:$lp';
    return _profile?.photoUrl;
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    if (_auth.currentUser != null) {
      await _onAuthChange(_auth.currentUser);
    }
    _authSub = _auth.authStateChanges().listen(_onAuthChange);
  }

  /// 프로필이 실제로 로드될 때까지(혹은 timeout) 대기.
  /// 가입 직후 즉시 프로필을 갱신해야 할 때 사용합니다.
  Future<UserProfile?> waitForProfile({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (_profile != null) return _profile;
    final completer = Completer<UserProfile?>();
    void listener() {
      if (_profile != null && !completer.isCompleted) {
        completer.complete(_profile);
      }
    }

    addListener(listener);
    try {
      return await completer.future.timeout(timeout, onTimeout: () => null);
    } finally {
      removeListener(listener);
    }
  }

  /// SharedPreferences 에서 로컬 사진 경로를 읽어 캐싱.
  Future<void> _loadLocalPhotoPath(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_localPhotoKey(uid));
      if (path != null && await File(path).exists()) {
        _localPhotoPath = path;
      } else {
        _localPhotoPath = null;
      }
    } catch (_) {
      _localPhotoPath = null;
    }
  }

  Future<void> _onAuthChange(User? user) async {
    final newUid = user?.uid;
    // 이미 동일한 uid 에 대해 구독이 활성화된 상태면 중복 실행 방지
    if (newUid != null && newUid == _handlingUid && _profileSub != null) {
      return;
    }
    _handlingUid = newUid;

    await _profileSub?.cancel();
    _profileSub = null;
    if (user == null) {
      _profile = null;
      _localPhotoPath = null;
      notifyListeners();
      return;
    }

    // 로컬 사진 경로 먼저 로드
    await _loadLocalPhotoPath(user.uid);
    if (_handlingUid != user.uid) return;

    // 문서 실시간 구독을 먼저 연결 (오프라인 캐시 즉시 반영).
    _profileSub = _db.collection('users').doc(user.uid).snapshots().listen(
      (snap) async {
        if (!snap.exists) {
          await _createInitial(user);
          return;
        }
        final data = snap.data() ?? {};

        // 관리자에 의해 비활성화된 계정: 자동 로그아웃
        if (data['disabled'] == true) {
          await AuthRepository.instance.signOut();
          return;
        }

        _profile = UserProfile.fromFirestore(snap.id, data);
        // STUDENT 등급 유저가 만 14세 이상이면 자동으로 NORMAL로 강등
        if (_profile!.role == UserRole.student) {
          final age = _profile!.age;
          if (age != null && age >= 14) {
            _db.collection('users').doc(user.uid).update({
              'role': 'NORMAL',
              'updatedAt': FieldValue.serverTimestamp(),
            }).ignore();
          }
        }
        notifyListeners();
      },
      onError: (e) {
        debugPrint('프로필 구독 실패: $e');
      },
    );

    // 기존 doc 확인: admin 강제 승급 + GUEST → NORMAL 자동 전환 (타임아웃 적용하여 앱 시작 지연 방지).
    try {
      final docRef = _db.collection('users').doc(user.uid);
      final snap = await docRef.get().timeout(const Duration(seconds: 4));
      if (_handlingUid != user.uid) return;
      if (!snap.exists) {
        await _createInitial(user);
      } else {
        final data = snap.data() ?? {};
        // 비활성화(탈퇴처리) 계정은 자동 역할 조정 등 모든 쓰기 건너뜀 → 생년월일 등 보호
        if (data['disabled'] == true) {
          await AuthRepository.instance.signOut();
        } else {
          final isAdminEmail =
              (user.email ?? '').toLowerCase() == adminEmail.toLowerCase();
          final roleCode = data['role'] as String? ?? 'NORMAL';
          final Map<String, dynamic> updates = {};

          if (isAdminEmail && roleCode != 'ADMIN') {
            updates['role'] = 'ADMIN';
          } else if (roleCode == 'GUEST') {
            updates['role'] = 'NORMAL';
          }

          if (updates.isNotEmpty) {
            updates['email'] = user.email;
            updates['updatedAt'] = FieldValue.serverTimestamp();
            await docRef.set(updates, SetOptions(merge: true));
          }
        }
      }
    } catch (e) {
      debugPrint('프로필 초기 검사 실패: $e');
    }
  }

  Future<void> _createInitial(User user) async {
    final isAdmin = (user.email ?? '').toLowerCase() == adminEmail.toLowerCase();
    final fresh = UserProfile(
      uid: user.uid,
      email: user.email ?? '',
      nickname: user.displayName,
      photoUrl: user.photoURL,
      role: isAdmin ? UserRole.admin : UserRole.normal,
      ageVerified: false,
      privacyAgreed: false,
    );
    await _db.collection('users').doc(user.uid).set(fresh.toFirestore());
  }

  /// 프로필 갱신. 조건이 충족되면 GUEST → NORMAL 자동 승급.
  /// (단, ADMIN/PRO 등급은 유지됩니다.)
  ///
  /// [photoUrl] 에 빈 문자열을 넘기면 사진을 제거합니다 (null 은 변경 없음).
  Future<void> updateProfile({
    String? nickname,
    DateTime? birthDate,
    String? photoUrl,
    bool? ageVerified,
    bool? privacyAgreed,
    bool clearBirthDate = false,
  }) async {
    if (_profile == null) {
      await waitForProfile(timeout: const Duration(seconds: 3));
    }
    final current = _profile;
    if (current == null) {
      throw StateError('프로필이 아직 준비되지 않았습니다. 잠시 후 다시 시도해 주세요.');
    }
    // photoUrl 빈 문자열은 제거 의도.
    final effectivePhoto =
        (photoUrl != null && photoUrl.isEmpty) ? null : photoUrl;
    final clearPhoto = photoUrl != null && photoUrl.isEmpty;

    var next = current.copyWith(
      nickname: nickname,
      birthDate: birthDate,
      clearBirthDate: clearBirthDate,
      photoUrl: effectivePhoto,
      ageVerified: ageVerified,
      privacyAgreed: privacyAgreed,
    );
    if (clearPhoto) {
      next = UserProfile(
        uid: next.uid,
        email: next.email,
        nickname: next.nickname,
        birthDate: next.birthDate,
        photoUrl: null,
        role: next.role,
        ageVerified: next.ageVerified,
        privacyAgreed: next.privacyAgreed,
        phoneCountryCode: next.phoneCountryCode,
        phoneNumber: next.phoneNumber,
        countryCode: next.countryCode,
        createdAt: next.createdAt,
        updatedAt: next.updatedAt,
      );
    }
    // guest 등급이 남아 있는 기존 계정은 normal로 자동 승급
    if (next.role == UserRole.normal) {
      // 이미 normal 이상 — 변경 없음
    }
    await _db.collection('users').doc(current.uid).set(
          next.toFirestore(),
          SetOptions(merge: true),
        );
  }

  // ── 휴대폰 번호 ──────────────────────────────────────────────────────

  /// phone_registry 문서 키: 국가코드 숫자 + 전화번호 숫자만 남김.
  static String _phoneKey(String countryCode, String phone) {
    final cc = countryCode.replaceAll(RegExp(r'[^0-9]'), '');
    final pn = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return '$cc$pn';
  }

  /// 휴대폰 번호 등록 / 변경.
  /// 다른 사용자가 이미 동일 번호를 등록했으면 [Exception('phone_duplicate')] 를 던집니다.
  Future<void> updatePhone({
    required String countryCode,
    required String phoneNumber,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('로그인이 필요합니다.');
    if (phoneNumber.replaceAll(RegExp(r'[^0-9]'), '').isEmpty) {
      throw ArgumentError('전화번호를 입력해 주세요.');
    }

    final newKey = _phoneKey(countryCode, phoneNumber);
    final registry = _db.collection('phone_registry');

    // 중복 확인
    final existing = await registry.doc(newKey).get();
    if (existing.exists && existing.data()?['uid'] != user.uid) {
      throw Exception('phone_duplicate');
    }

    // 기존 번호 registry 에서 제거
    final oldCode = _profile?.phoneCountryCode ?? '';
    final oldNum = _profile?.phoneNumber ?? '';
    if (oldNum.isNotEmpty) {
      final oldKey = _phoneKey(oldCode, oldNum);
      if (oldKey != newKey) {
        await registry.doc(oldKey).delete().catchError((_) {});
      }
    }

    // 새 번호 registry 등록
    await registry.doc(newKey).set({'uid': user.uid});

    // users/{uid} 업데이트
    await _db.collection('users').doc(user.uid).set({
      'phoneCountryCode': countryCode.trim(),
      'phoneNumber': phoneNumber.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 휴대폰 번호 삭제.
  Future<void> removePhone() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final oldCode = _profile?.phoneCountryCode ?? '';
    final oldNum = _profile?.phoneNumber ?? '';
    if (oldNum.isNotEmpty) {
      final oldKey = _phoneKey(oldCode, oldNum);
      await _db
          .collection('phone_registry')
          .doc(oldKey)
          .delete()
          .catchError((_) {});
    }
    await _db.collection('users').doc(user.uid).set({
      'phoneCountryCode': null,
      'phoneNumber': null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 거주 국가 코드 저장 ('KR' 또는 'US').
  Future<void> updateCountryCode(String code) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).set({
      'countryCode': code,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 다른 사용자의 등급을 변경 (ADMIN 전용).
  Future<void> setRole(String targetUid, UserRole role) async {
    if (_profile?.role != UserRole.admin) {
      throw StateError('ADMIN 만 등급을 변경할 수 있습니다.');
    }
    await _db.collection('users').doc(targetUid).set(
      {'role': role.code, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// 프로필 사진을 기기 로컬에 저장 (Firebase Storage 미사용).
  Future<void> uploadPhoto(File file) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final dest = File('${dir.path}/profile_${user.uid}.jpg');
    await file.copy(dest.path);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localPhotoKey(user.uid), dest.path);
    _localPhotoPath = dest.path;
    notifyListeners();
  }

  /// 로컬 사진 제거.
  Future<void> removeLocalPhoto() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_localPhotoKey(user.uid));
    if (path != null) {
      try { await File(path).delete(); } catch (_) {}
      await prefs.remove(_localPhotoKey(user.uid));
    }
    _localPhotoPath = null;
    notifyListeners();
  }

  /// 회원 탈퇴 — Firebase Auth + users/{uid} + 모든 사용자 데이터 삭제.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final uid = user.uid;

    // 1. Google 재인증 시도 (오래된 세션으로 인해 user.delete() 가 실패하는 현상 방지)
    try {
      final googleUser = await GoogleSignIn().signInSilently();
      if (googleUser != null) {
        final googleAuth = await googleUser.authentication;
        if (googleAuth.accessToken != null || googleAuth.idToken != null) {
          final cred = GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          );
          await user.reauthenticateWithCredential(cred);
        }
      }
    } catch (_) {
      // 재인증 실패 시 기존 세션으로 진행
    }

    // 2. 등록된 휴대폰 번호 레지스트리 삭제 (탈퇴 후 재가입 시 중복 오류 방지)
    try {
      final oldCode = _profile?.phoneCountryCode ?? '';
      final oldNum = _profile?.phoneNumber ?? '';
      if (oldNum.isNotEmpty) {
        final oldKey = _phoneKey(oldCode, oldNum);
        await _db.collection('phone_registry').doc(oldKey).delete();
      }
    } catch (e) {
      debugPrint('phone_registry 삭제 실패: $e');
    }

    // 3. 클라우드 동기화 데이터 삭제 (todos / moods / ledger)
    for (final colName in const ['todos', 'moods', 'ledger']) {
      try {
        final items = await _db
            .collection(colName)
            .doc(uid)
            .collection('items')
            .get();
        for (final d in items.docs) {
          await d.reference.delete();
        }
        await _db.collection(colName).doc(uid).delete();
      } catch (e) {
        debugPrint('$colName 삭제 실패: $e');
      }
    }

    // 4. 보호자 동의 문서 삭제 (있는 경우)
    try {
      await _db.collection('parent_consents').doc(uid).delete();
    } catch (_) {}

    // 5. 로컬 프로필 사진 삭제
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString(_localPhotoKey(uid));
      if (path != null) {
        await File(path).delete();
        await prefs.remove(_localPhotoKey(uid));
      }
    } catch (_) {/* 사진 없을 수도 있음 */}

    // 6. users/{uid} 프로필 문서 삭제
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('users 문서 삭제 실패: $e');
    }

    // 7. Firebase Auth 계정 삭제 및 Google 세션 정리
    await user.delete();
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
