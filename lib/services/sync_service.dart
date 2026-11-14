import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth_repository.dart';
import '../data/ledger_repository.dart';
import '../data/mood_repository.dart';
import '../data/todo_repository.dart';
import '../models/ledger.dart';
import '../models/mood.dart';
import '../models/todo.dart';

// ─── 백엔드 추상 인터페이스 ───────────────────────────────────────────────────

abstract class SyncBackend {
  // ── 할 일 ──────────────────────────────────────────────────────────────
  Future<void> uploadTodos(String userId, List<Todo> todos);
  Future<List<Todo>> downloadTodos(String userId);

  // ── 기분 ──────────────────────────────────────────────────────────────
  Future<void> uploadMoods(String userId, List<MoodEntry> moods);
  Future<List<MoodEntry>> downloadMoods(String userId);

  // ── 가계부 ────────────────────────────────────────────────────────────
  Future<void> uploadLedger(String userId, List<LedgerEntry> entries);
  Future<List<LedgerEntry>> downloadLedger(String userId);

  // ── 클라우드 전체 삭제 (복원 후 호출) ────────────────────────────────
  Future<void> deleteAll(String userId);
}

// ─── 더미 백엔드 (개발/테스트용) ─────────────────────────────────────────────

class NoopSyncBackend implements SyncBackend {
  @override Future<void> uploadTodos(String u, List<Todo> t) async {}
  @override Future<List<Todo>> downloadTodos(String u) async => [];
  @override Future<void> uploadMoods(String u, List<MoodEntry> m) async {}
  @override Future<List<MoodEntry>> downloadMoods(String u) async => [];
  @override Future<void> uploadLedger(String u, List<LedgerEntry> e) async {}
  @override Future<List<LedgerEntry>> downloadLedger(String u) async => [];
  @override Future<void> deleteAll(String u) async {}
}

// ─── Firestore 백엔드 ─────────────────────────────────────────────────────────

class FirebaseSyncBackend implements SyncBackend {
  FirebaseSyncBackend(this._db);
  final FirebaseFirestore _db;

  // 컬렉션 경로 헬퍼
  CollectionReference<Map<String, dynamic>> _todos(String uid) =>
      _db.collection('todos').doc(uid).collection('items');
  CollectionReference<Map<String, dynamic>> _moods(String uid) =>
      _db.collection('moods').doc(uid).collection('items');
  CollectionReference<Map<String, dynamic>> _ledger(String uid) =>
      _db.collection('ledger').doc(uid).collection('items');

  // ── 할 일 ──────────────────────────────────────────────────────────────
  @override
  Future<void> uploadTodos(String userId, List<Todo> todos) async {
    await _batchSet(
      _todos(userId),
      {for (final t in todos) t.id: {...t.toJson(), 'updatedAt': FieldValue.serverTimestamp()}},
    );
  }

  @override
  Future<List<Todo>> downloadTodos(String userId) async {
    final snap = await _todos(userId).get();
    return snap.docs.map((d) {
      try { return Todo.fromJson(d.data()); } catch (_) { return null; }
    }).whereType<Todo>().toList();
  }

  // ── 기분 ──────────────────────────────────────────────────────────────
  @override
  Future<void> uploadMoods(String userId, List<MoodEntry> moods) async {
    await _batchSet(
      _moods(userId),
      {for (final m in moods) m.id: {...m.toJson(), 'updatedAt': FieldValue.serverTimestamp()}},
    );
  }

  @override
  Future<List<MoodEntry>> downloadMoods(String userId) async {
    final snap = await _moods(userId).get();
    return snap.docs.map((d) {
      try { return MoodEntry.fromJson(d.data()); } catch (_) { return null; }
    }).whereType<MoodEntry>().toList();
  }

  // ── 가계부 ────────────────────────────────────────────────────────────
  @override
  Future<void> uploadLedger(String userId, List<LedgerEntry> entries) async {
    await _batchSet(
      _ledger(userId),
      {for (final e in entries) e.id: {...e.toJson(), 'updatedAt': FieldValue.serverTimestamp()}},
    );
  }

  @override
  Future<List<LedgerEntry>> downloadLedger(String userId) async {
    final snap = await _ledger(userId).get();
    return snap.docs.map((d) {
      try { return LedgerEntry.fromJson(d.data()); } catch (_) { return null; }
    }).whereType<LedgerEntry>().toList();
  }

  // ── 클라우드 전체 삭제 ────────────────────────────────────────────────
  @override
  Future<void> deleteAll(String userId) async {
    await Future.wait([
      _deleteCollection(_todos(userId)),
      _deleteCollection(_moods(userId)),
      _deleteCollection(_ledger(userId)),
    ]);
  }

  // ── 내부 유틸 ─────────────────────────────────────────────────────────

  /// Firestore 500개 제한을 넘지 않도록 청크 단위 batch set + 로컬에서 삭제된 문서 정리.
  Future<void> _batchSet(
    CollectionReference<Map<String, dynamic>> col,
    Map<String, Map<String, dynamic>> docs,
  ) async {
    const chunk = 400;
    // 원격에만 남아 있는(로컬에서 삭제된) 도큐먼트 제거
    final existingSnap = await col.get();
    final obsoleteRefs = existingSnap.docs
        .where((d) => !docs.containsKey(d.id))
        .map((d) => d.reference)
        .toList();
    for (var i = 0; i < obsoleteRefs.length; i += chunk) {
      final batch = _db.batch();
      for (final ref in obsoleteRefs.skip(i).take(chunk)) {
        batch.delete(ref);
      }
      await batch.commit();
    }

    final entries = docs.entries.toList();
    for (var i = 0; i < entries.length; i += chunk) {
      final batch = _db.batch();
      for (final e in entries.skip(i).take(chunk)) {
        batch.set(col.doc(e.key), e.value, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  /// 컬렉션 내 모든 도큐먼트 삭제 (청크 단위).
  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> col,
  ) async {
    const chunk = 400;
    QuerySnapshot snap;
    do {
      snap = await col.limit(chunk).get();
      if (snap.docs.isEmpty) break;
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snap.docs.length == chunk);
  }
}

// ─── 백업 메타데이터 ──────────────────────────────────────────────────────────

class BackupMeta {
  const BackupMeta({
    required this.date,
    required this.todosCount,
    required this.moodsCount,
    required this.ledgerCount,
  });

  final DateTime date;
  final int todosCount;
  final int moodsCount;
  final int ledgerCount;
}

// ─── SyncService ──────────────────────────────────────────────────────────────

class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _enabledKey    = 'sync_enabled';
  static const _lastSyncKey   = 'sync_last';
  static const _bmDateKey     = 'bm_date';
  static const _bmTodosKey    = 'bm_todos';
  static const _bmMoodsKey    = 'bm_moods';
  static const _bmLedgerKey   = 'bm_ledger';

  SyncBackend backend = NoopSyncBackend();

  bool _enabled    = false;
  DateTime? _lastSyncedAt;
  bool _busy       = false;
  bool _loaded     = false;
  bool _applyingRemote = false;
  Timer? _autoSyncTimer;
  String? _lastError;

  // 백업 메타데이터
  BackupMeta? _backupMeta;

  bool get enabled         => _enabled && AuthRepository.instance.isLoggedIn;
  bool get busy            => _busy;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError    => _lastError;
  BackupMeta? get backupMeta => _backupMeta;

  // ── 초기화 ────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool(_enabledKey) ?? false;
    final ms = prefs.getInt(_lastSyncKey);
    _lastSyncedAt = ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    _backupMeta = _loadMeta(prefs);
    _loaded = true;

    // 로컬 데이터 변경 시 자동 동기화 예약 (디바운스 2초)
    TodoRepository.instance.addListener(_onLocalDataChanged);
    MoodRepository.instance.addListener(_onLocalDataChanged);
    LedgerRepository.instance.addListener(_onLocalDataChanged);

    notifyListeners();
  }

  void _onLocalDataChanged() {
    if (_applyingRemote || !enabled) return;
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer(const Duration(seconds: 2), () {
      if (enabled && !_busy) {
        syncNow(TodoRepository.instance.todos);
      }
    });
  }

  BackupMeta? _loadMeta(SharedPreferences prefs) {
    final ms = prefs.getInt(_bmDateKey);
    if (ms == null) return null;
    return BackupMeta(
      date: DateTime.fromMillisecondsSinceEpoch(ms),
      todosCount:  prefs.getInt(_bmTodosKey)  ?? 0,
      moodsCount:  prefs.getInt(_bmMoodsKey)  ?? 0,
      ledgerCount: prefs.getInt(_bmLedgerKey) ?? 0,
    );
  }

  Future<void> _saveMeta(SharedPreferences prefs, BackupMeta meta) async {
    await prefs.setInt(_bmDateKey,   meta.date.millisecondsSinceEpoch);
    await prefs.setInt(_bmTodosKey,  meta.todosCount);
    await prefs.setInt(_bmMoodsKey,  meta.moodsCount);
    await prefs.setInt(_bmLedgerKey, meta.ledgerCount);
  }

  Future<void> _clearMeta(SharedPreferences prefs) async {
    await prefs.remove(_bmDateKey);
    await prefs.remove(_bmTodosKey);
    await prefs.remove(_bmMoodsKey);
    await prefs.remove(_bmLedgerKey);
  }

  // ── 설정 ──────────────────────────────────────────────────────────────

  Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _enabled = value;
    await prefs.setBool(_enabledKey, value);
    notifyListeners();
  }

  // ── 백업 (로컬 → 클라우드) ────────────────────────────────────────────

  Future<void> syncNow(List<Todo> localTodos) async {
    if (!enabled || _busy) return;
    final user = AuthRepository.instance.uid;
    if (user == null) return;

    _busy = true;
    _lastError = null;
    notifyListeners();
    try {
      // ── 할 일 (현재 로컬 상태를 클라우드에 정확히 백업) ────────────
      final todosSnapshot = List<Todo>.from(localTodos);
      await backend.uploadTodos(user, todosSnapshot);

      // ── 기분 ──────────────────────────────────────────────────────
      final moods = MoodRepository.instance.entries;
      await backend.uploadMoods(user, moods);

      // ── 가계부 ────────────────────────────────────────────────────
      final ledger = LedgerRepository.instance.entries;
      await backend.uploadLedger(user, ledger);

      // ── 메타데이터 저장 ───────────────────────────────────────────
      _lastSyncedAt = DateTime.now();
      _backupMeta = BackupMeta(
        date: _lastSyncedAt!,
        todosCount:  todosSnapshot.length,
        moodsCount:  moods.length,
        ledgerCount: ledger.length,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, _lastSyncedAt!.millisecondsSinceEpoch);
      await _saveMeta(prefs, _backupMeta!);
    } catch (e) {
      _lastError = e.toString();
      debugPrint('백업 실패: $e');
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  // ── 복원 (클라우드 → 로컬) + 복원 후 클라우드 삭제 ──────────────────

  Future<void> restoreFromCloud() async {
    if (!enabled || _busy) return;
    final user = AuthRepository.instance.uid;
    if (user == null) return;

    _busy = true;
    _applyingRemote = true;
    _autoSyncTimer?.cancel();
    _lastError = null;
    notifyListeners();
    try {
      // ── 다운로드 ──────────────────────────────────────────────────
      final remoteTodos  = await backend.downloadTodos(user);
      final remoteMoods  = await backend.downloadMoods(user);
      final remoteLedger = await backend.downloadLedger(user);

      // ── 로컬 교체 ─────────────────────────────────────────────────
      await TodoRepository.instance.replaceAll(remoteTodos);
      await MoodRepository.instance.replaceAll(remoteMoods);
      await LedgerRepository.instance.replaceAll(remoteLedger);

      // ── 복원 완료 후 클라우드 백업 삭제 ──────────────────────────
      await backend.deleteAll(user);

      // ── 메타데이터 초기화 ─────────────────────────────────────────
      _lastSyncedAt = DateTime.now();
      _backupMeta = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, _lastSyncedAt!.millisecondsSinceEpoch);
      await _clearMeta(prefs);
    } catch (e) {
      _lastError = e.toString();
      debugPrint('복원 실패: $e');
      rethrow;
    } finally {
      _applyingRemote = false;
      _busy = false;
      notifyListeners();
    }
  }
}
