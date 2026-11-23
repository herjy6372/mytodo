import 'package:flutter/material.dart';

/// 앱 전체에서 사용하는 다국어 문자열.
/// [AppLocalizations.of(context)] 로 접근합니다.
class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('ko', 'KR'));
  }

  static const delegate = _AppLocalizationsDelegate();

  bool get isKorean => locale.languageCode == 'ko';

  // ── 내부 헬퍼 ────────────────────────────────────────────────────────────
  /// ko / en / ja / fil(Filipino) / vi 순서로 넘기면 현재 로케일에 맞는 값 반환.
  String _t(String ko, String en, String ja, String fil, String vi) {
    switch (locale.languageCode) {
      case 'ko':  return ko;
      case 'ja':  return ja;
      case 'fil': return fil;
      case 'vi':  return vi;
      default:    return en;
    }
  }

  // ── 공통 ────────────────────────────────────────────────────────────────

  String get appTitle    => _t('나의 할 일', 'My To-Do',    'マイToDo',         'Aking Gawain',    'Công Việc Của Tôi');
  String get cancel      => _t('취소',             'Cancel',             'キャンセル',              'Kanselahin',            'Hủy');
  String get confirm     => _t('확인',             'Confirm',            '確認',                   'Kumpirmahin',           'Xác nhận');
  String get save        => _t('저장',             'Save',               '保存',                   'I-save',                'Lưu');
  String get close       => _t('닫기',             'Close',              '閉じる',                  'Isara',                 'Đóng');
  String get delete      => _t('삭제',             'Delete',             '削除',                   'Burahin',               'Xóa');
  String get ok          => _t('확인',             'OK',                 'OK',                    'OK',                    'OK');
  String get retry       => _t('다시 시도',         'Retry',              '再試行',                  'Subukan Muli',          'Thử lại');
  String get loading     => _t('불러오는 중...',    'Loading...',         '読み込み中...',            'Nag-lo-load...',        'Đang tải...');

  // ── 홈 화면 ─────────────────────────────────────────────────────────────

  String get homeTitle   => _t('나의 할 일', 'My To-Do', 'マイToDo', 'Aking Gawain', 'Công Việc Của Tôi');

  /// intl DateFormat 포맷 문자열
  String get homeGreetingFormat => _t(
    'y년 M월 d일 (E)',
    'EEEE, MMMM d, y',
    'y年M月d日 (E)',
    'EEEE, MMMM d, y',
    'EEEE, d MMMM, y',
  );
  /// intl DateFormat 에 넘길 로케일
  String get homeGreetingLocale => _t('ko_KR', 'en_US', 'ja_JP', 'en_US', 'vi_VN');

  String get summaryToday => _t('오늘',     'Today',       '今日',        'Ngayon',          'Hôm nay');
  String get summaryWeek  => _t('이번주',   'This Week',   '今週',        'Linggong Ito',    'Tuần này');
  String get summaryMonth => _t('이번달',   'This Month',  '今月',        'Buwang Ito',      'Tháng này');
  String get summaryUnit  => _t('개',       '',            '件',          '',                '');

  String get weekScheduleTitle  => _t('이번주 일정',              'This Week',      '今週の予定',               'Iskedyul Ngayong Linggo',  'Lịch tuần này');
  String get weekScheduleSeeAll => _t('전체보기',                 'See All',        '全て見る',                 'Tingnan Lahat',            'Xem tất cả');
  String get weekScheduleEmpty  => _t('이번 주에 등록된 할 일이 없습니다.', 'No tasks this week.', '今週のタスクはありません。', 'Walang gawain ngayong linggo.', 'Không có công việc trong tuần này.');

  String get menuTodos      => _t('할 일 목록',  'Tasks',        'タスク',     'Mga Gawain',   'Công việc');
  String get menuCalendar   => _t('날짜형 목록', 'Calendar',     'カレンダー',  'Kalendaryo',   'Lịch');
  String get menuGraph      => _t('그래프형 목록','Statistics',  '統計',       'Estadistika',  'Thống kê');
  String get menuSettings   => _t('설정',        'Settings',    '設定',       'Mga Setting',  'Cài đặt');
  String get menuMood       => _t('기분한줄',     'Mood',        '気分メモ',   'Mood',         'Tâm trạng');
  String get menuLedger     => _t('가계부',       'Budget',      '家計簿',     'Budget',       'Sổ chi tiêu');
  String get menuTimer      => _t('타이머',       'Timer',       'タイマー',   'Timer',        'Hẹn giờ');
  String get menuWorldClock => _t('세계시각',     'World Clock', '世界時計',   'World Clock',  'Giờ thế giới');

  String get bannerBetaSync => _t(
    '동기화 기능이 베타(테스트) 기능으로 사용되며 백업 및 복원이 원활히 진행되지 않을 수 있습니다.',
    'Sync is a beta feature. Backup and restore may not work perfectly.',
    '同期機能はベータ版です。バックアップと復元が正常に動作しない場合があります。',
    'Ang sync ay isang beta feature. Maaaring hindi gumana nang maayos ang backup at restore.',
    'Tính năng đồng bộ đang ở giai đoạn beta. Sao lưu và khôi phục có thể không hoạt động hoàn hảo.',
  );
  String get bannerNoSync => _t(
    '동기화 기능이 없으므로 기록이 삭제되지 않도록 주의하시길 바랍니다.',
    'No sync available. Be careful not to lose your records.',
    '同期機能がありません。記録が消えないよう注意してください。',
    'Walang sync. Mag-ingat na huwag mawala ang iyong mga tala.',
    'Không có đồng bộ. Hãy cẩn thận để không mất dữ liệu.',
  );
  String get bannerLoginRequired => _t(
    '로그인 후 앱 기능을 사용하실 수 있습니다.',
    'Sign in to use app features.',
    'ログイン後にアプリ機能を使用できます。',
    'Mag-sign in para gamitin ang app.',
    'Đăng nhập để sử dụng các tính năng ứng dụng.',
  );

  // ── 설정 화면 ────────────────────────────────────────────────────────────

  String get settingsTitle => _t('설정', 'Settings', '設定', 'Mga Setting', 'Cài đặt');

  String get settingsAccountLoginRequired => _t('로그인이 필요합니다', 'Sign in required', 'ログインが必要です', 'Kailangan mag-sign in', 'Yêu cầu đăng nhập');
  String get settingsAccountLoginHint     => _t(
    '로그인하면 클라우드 동기화를 사용할 수 있어요.',
    'Sign in to enable cloud sync.',
    'ログインするとクラウド同期が利用できます。',
    'Mag-sign in para ma-enable ang cloud sync.',
    'Đăng nhập để bật đồng bộ đám mây.',
  );
  String get settingsSignIn  => _t('로그인',   'Sign In',   'ログイン',   'Mag-sign In',   'Đăng nhập');
  String get settingsSignOut => _t('로그아웃', 'Sign Out',  'ログアウト', 'Mag-sign Out',  'Đăng xuất');

  String get settingsSignOutTitle   => _t('로그아웃', 'Sign Out', 'ログアウト', 'Mag-sign Out', 'Đăng xuất');
  String get settingsSignOutConfirm => _t(
    '로그아웃 하시겠습니까?',
    'Are you sure you want to sign out?',
    'ログアウトしますか？',
    'Sigurado ka bang mag-sign out?',
    'Bạn có chắc muốn đăng xuất không?',
  );

  String get settingsSectionSync  => _t('클라우드 동기화', 'Cloud Sync',    'クラウド同期',  'Cloud Sync',   'Đồng bộ đám mây');
  String get settingsSyncAuto     => _t('자동 동기화',    'Auto Sync',     '自動同期',      'Auto Sync',    'Tự động đồng bộ');
  String get settingsSyncOff      => _t(
    '꺼짐 · 켜면 자동으로 백업됩니다.',
    'Off · Enable to auto-backup.',
    'オフ · オンにすると自動バックアップされます。',
    'Off · I-on para mag-auto-backup.',
    'Tắt · Bật để tự động sao lưu.',
  );
  String get settingsSyncBusy     => _t('동기화 중...',  'Syncing...',    '同期中...',     'Nag-sisync...','Đang đồng bộ...');
  String get settingsSyncNever    => _t(
    '켜짐 · 아직 동기화한 적이 없습니다.',
    'On · Never synced yet.',
    'オン · まだ同期していません。',
    'On · Hindi pa na-sync.',
    'Bật · Chưa từng đồng bộ.',
  );

  String get settingsSyncLastFormat  => _t('y.M.d HH:mm', 'M/d/y HH:mm', 'y/M/d HH:mm', 'M/d/y HH:mm', 'd/M/y HH:mm');
  String get settingsSyncLastLocale  => _t('ko_KR', 'en_US', 'ja_JP', 'en_US', 'vi_VN');
  String settingsSyncLast(String d)  => _t('마지막 동기화: $d', 'Last sync: $d', '最終同期: $d', 'Huling sync: $d', 'Đồng bộ lần cuối: $d');

  String get settingsSyncBackup        => _t('백업',   'Backup',  'バックアップ', 'I-backup',  'Sao lưu');
  String get settingsSyncRestore       => _t('복원',   'Restore', '復元',        'I-restore', 'Khôi phục');
  String get settingsSyncRestoreTitle  => _t('클라우드에서 복원', 'Restore from Cloud', 'クラウドから復元', 'I-restore mula sa Cloud', 'Khôi phục từ đám mây');
  String get settingsSyncRestoreConfirm => _t(
    '현재 기기의 모든 할 일이 클라우드 저장본으로 덮어써집니다. 진행할까요?',
    'All tasks on this device will be overwritten with the cloud data. Continue?',
    'このデバイスのすべてのタスクがクラウドデータで上書きされます。続けますか？',
    'Lahat ng tasks sa device na ito ay papalitan ng cloud data. Ituloy?',
    'Tất cả công việc trên thiết bị này sẽ bị ghi đè bằng dữ liệu đám mây. Tiếp tục?',
  );
  String get settingsSyncRestoreSuccess => _t('클라우드에서 복원 완료.', 'Restored from cloud.', 'クラウドから復元完了。', 'Na-restore mula sa cloud.', 'Đã khôi phục từ đám mây.');
  String settingsSyncRestoreFail(String e) => _t('복원 실패: $e', 'Restore failed: $e', '復元失敗: $e', 'Nabigo ang restore: $e', 'Khôi phục thất bại: $e');

  // 백업 통계 카드
  String get syncBackupMetaTitle   => _t('마지막 백업 내역', 'Last Backup Summary', '最終バックアップ内容', 'Huling Backup', 'Tóm tắt sao lưu cuối');
  String get syncBackupTodos       => _t('할 일', 'To-Do', 'タスク', 'Gawain', 'Công việc');
  String get syncBackupMoods       => _t('기분 한줄', 'Mood', '気分メモ', 'Mood', 'Tâm trạng');
  String get syncBackupLedger      => _t('가계부', 'Budget', '家計簿', 'Budget', 'Chi tiêu');
  String syncBackupCount(int n)    => _t('$n개', '$n items', '$n件', '$n', '$n mục');
  String get syncBackupDateFormat  => _t('y년 M월 d일 HH:mm', 'MMM d, y · HH:mm', 'y年M月d日 HH:mm', 'MMM d, y · HH:mm', 'd/M/y HH:mm');
  String get syncBackupDateLocale  => _t('ko_KR', 'en_US', 'ja_JP', 'en_US', 'vi_VN');

  // 복원 경고
  String get syncRestoreWarning    => _t(
    '⚠️ 복원 기능을 사용할 시 기기의 기존 파일들이 모두 삭제됩니다.\n복원 완료 후 클라우드 백업도 삭제됩니다.',
    '⚠️ Restoring will delete all existing local data.\nThe cloud backup will also be removed after restore.',
    '⚠️ 復元すると既存のローカルデータがすべて削除されます。\n復元完了後、クラウドバックアップも削除されます。',
    '⚠️ Ang pagpapanumbalik ay magtatanggal ng lahat ng lokal na data.\nAng cloud backup ay matatanggal din pagkatapos ng restore.',
    '⚠️ Khôi phục sẽ xóa toàn bộ dữ liệu cục bộ.\nSao lưu đám mây cũng sẽ bị xóa sau khi khôi phục.',
  );
  String get syncRestoreOk         => _t('OK, 진행', 'OK, Proceed', 'OK、進める', 'OK, Ituloy', 'OK, Tiếp tục');
  String get syncRestoreNo         => _t('NO, 취소', 'NO, Cancel', 'NO、キャンセル', 'NO, Kanselahin', 'NO, Hủy');

  // 테스트 진행 중 안내
  String get syncTestingNotice     => _t(
    '백업·복원 기능은 현재 베타 테스트 단계입니다.\n중요한 데이터는 별도로 보관해 주세요.',
    'Backup & restore is currently in beta testing.\nPlease keep separate copies of important data.',
    'バックアップ・復元機能は現在ベータテスト段階です。\n重要なデータは別途保管してください。',
    'Ang backup at restore ay nasa beta testing pa.\nMangyaring mag-ingat ng hiwalay na kopya ng data.',
    'Sao lưu và khôi phục đang trong giai đoạn beta.\nVui lòng giữ bản sao riêng của dữ liệu quan trọng.',
  );

  String get settingsSectionNotifThemeLang => _t(
    '알림 / 테마 / 언어', 'Notifications / Theme / Language', '通知 / テーマ / 言語', 'Notipikasyon / Tema / Wika', 'Thông báo / Giao diện / Ngôn ngữ',
  );
  String get settingsNotifTitle    => _t('푸시 알림',  'Push Notifications', 'プッシュ通知',  'Push Notifications', 'Thông báo đẩy');
  String get settingsNotifSubtitle => _t(
    '설정한 시간이 되면 알림으로 알려드립니다.',
    'Get notified at the time you set.',
    '設定した時間になるとお知らせします。',
    'Maabisuhan sa oras na itinakda mo.',
    'Nhận thông báo vào thời gian bạn đặt.',
  );
  String get settingsNotifGranted => _t('알림 권한이 허용되었습니다.', 'Notification permission granted.', '通知権限が許可されています。', 'Naibigay na ang pahintulot sa notipikasyon.', 'Đã cấp quyền thông báo.');
  String get settingsNotifDenied  => _t(
    '알림 권한이 거부되었습니다. 시스템 설정에서 변경해 주세요.',
    'Notification permission denied. Please change in system settings.',
    '通知権限が拒否されています。システム設定で変更してください。',
    'Tinanggihan ang pahintulot sa notipikasyon. Baguhin sa system settings.',
    'Quyền thông báo bị từ chối. Vui lòng thay đổi trong cài đặt hệ thống.',
  );

  String get settingsThemeTitle    => _t('테마', 'Theme', 'テーマ', 'Tema', 'Giao diện');
  String get settingsThemeSubtitle => _t('시스템 / 고양이 / 강아지 / 기린 / 커피', 'System / Cat / Dog / Giraffe / Coffee', 'システム / 猫 / 犬 / キリン / コーヒー', 'System / Pusa / Aso / Giraffe / Kape', 'Hệ thống / Mèo / Chó / Hươu cao cổ / Cà phê');

  String get settingsLanguageTitle    => _t('언어 / Language', 'Language / 언어', '言語 / Language', 'Wika / Language', 'Ngôn ngữ / Language');
  String get settingsLanguageSubtitle => _t(
    '한국어 / English / 日本語 / Filipino / Tiếng Việt',
    '한국어 / English / 日本語 / Filipino / Tiếng Việt',
    '한국어 / English / 日本語 / Filipino / Tiếng Việt',
    '한국어 / English / 日本語 / Filipino / Tiếng Việt',
    '한국어 / English / 日本語 / Filipino / Tiếng Việt',
  );

  String get settingsSectionAppInfo    => _t('앱 정보',    'App Info',         'アプリ情報',     'Info ng App',      'Thông tin ứng dụng');
  String get settingsNoticesTitle      => _t('공지사항',   'Announcements',    'お知らせ',       'Mga Anunsyo',      'Thông báo');
  String get settingsNoticesSubtitle   => _t('서비스 관련 안내사항', 'Service notices', 'サービス案内', 'Mga abiso sa serbisyo', 'Thông báo dịch vụ');
  String get settingsUpdatesTitle      => _t('업데이트 내역', 'Update History',  'アップデート履歴', 'Kasaysayan ng Update', 'Lịch sử cập nhật');
  String get settingsUpdatesSubtitle   => _t('버전별 변경사항 확인', 'View version change history', 'バージョンごとの変更内容', 'Tingnan ang kasaysayan ng bersyon', 'Xem lịch sử thay đổi');
  String get settingsSupportTitle      => _t('고객지원',   'Support',          'サポート',       'Suporta',          'Hỗ trợ');
  String get settingsSupportSubtitle   => _t(
    '오류 신고 · 신기능 제안 · 개인정보 처리방침',
    'Bug report · Feature request · Privacy',
    'バグ報告 · 機能提案 · プライバシー',
    'Bug report · Feature request · Privacy',
    'Báo lỗi · Đề xuất tính năng · Quyền riêng tư',
  );
  String get settingsManualTitle       => _t('사용설명서',  'User Guide',      '使い方ガイド',   'Gabay ng Gumagamit', 'Hướng dẫn sử dụng');
  String get settingsManualSubtitle    => _t('주요 기능 설명', 'Feature guide', '機能説明', 'Gabay sa mga feature', 'Mô tả tính năng');

  String get settingsPrivacyTitle      => _t('개인정보 처리방침', 'Privacy Policy', 'プライバシーポリシー', 'Patakaran sa Privacy', 'Chính sách Quyền riêng tư');
  String get settingsPrivacySubtitle   => _t('수집 항목, 보관 기간, 이용 목적 안내', 'Data collection, retention & purposes', '収集項目・保存期間・利用目的の案内', 'Mga detalye ng koleksyon ng data', 'Thông tin thu thập, lưu giữ và mục đích sử dụng');
  String get settingsTermsTitle        => _t('이용약관', 'Terms of Service', '利用規約', 'Mga Tuntunin ng Serbisyo', 'Điều khoản Dịch vụ');
  String get settingsTermsSubtitle     => _t('서비스 이용 규칙 및 책임 한계', 'Service rules & limitation of liability', 'ご利用ルールと責任の制限', 'Mga panuntunan sa paggamit ng serbisyo', 'Quy tắc sử dụng dịch vụ và giới hạn trách nhiệm');
  String get settingsPolicyKo          => _t('🇰🇷 한국어', '🇰🇷 한국어', '🇰🇷 한국어', '🇰🇷 한국어', '🇰🇷 한국어');
  String get settingsPolicyEn          => _t('🇺🇸 English', '🇺🇸 English', '🇺🇸 English', '🇺🇸 English', '🇺🇸 English');
  String get settingsVersionTitle      => _t('앱 버전',    'App Version',     'アプリバージョン', 'Bersyon ng App',   'Phiên bản ứng dụng');
  String get settingsVersionOld        => _t('구버전',     'Old',             '旧バージョン',    'Lumang bersyon',   'Phiên bản cũ');
  String get settingsVersionLatest     => _t('최신',       'Latest',          '最新',            'Pinakabago',       'Mới nhất');

  String get settingsProApply  => _t('Pro 등급 신청', 'Apply for Pro', 'Proランク申請', 'Mag-apply para sa Pro', 'Đăng ký Pro');
  String get settingsProManage => _t('Pro / 학생 승인 관리 (관리자)', 'Pro / Student Approval (Admin)', 'Pro / 学生承認管理 (管理者)', 'Pro / Student Approval (Admin)', 'Quản lý duyệt Pro / Học sinh (Admin)');

  String get settingsFooter => _t('나의 할 일 · made with Flutter', 'My To-Do · made with Flutter', 'マイToDo · made with Flutter', 'Aking Gawain · made with Flutter', 'Công Việc Của Tôi · made with Flutter');

  // ── 로그인 화면 ──────────────────────────────────────────────────────────

  String get loginTitle => _t('나의 할 일', 'My To-Do', 'マイToDo', 'Aking Gawain', 'Công Việc Của Tôi');
  String get loginSubtitle => _t(
    '할 일을 기록하고 관리해보세요.',
    'Record and manage your tasks.',
    'タスクを記録・管理しましょう。',
    'I-record at pamahalaan ang iyong mga gawain.',
    'Ghi lại và quản lý công việc của bạn.',
  );
  String get loginWithGoogle    => _t('구글로 로그인', 'Sign in with Google', 'Googleでログイン', 'Mag-sign in gamit ang Google', 'Đăng nhập bằng Google');
  String get loginWithoutLogin  => _t('로그인 없이 사용', 'Use without signing in', 'ログインなしで使用', 'Gumamit nang walang pag-sign in', 'Sử dụng không cần đăng nhập');
  String get loginNoSyncWarning => _t(
    '로그인 없이 사용하면 데이터가 기기에만 저장됩니다.\n앱 삭제 시 모든 기록이 사라집니다.',
    'Without signing in, data is stored locally only.\nAll records will be lost if you uninstall the app.',
    'ログインなしで使用すると、データはデバイスにのみ保存されます。\nアンインストール時にすべての記録が失われます。',
    'Kung wala kang pag-sign in, ang data ay lokal lang naka-save.\nMawawala ang lahat ng tala kapag na-uninstall ang app.',
    'Không đăng nhập, dữ liệu chỉ lưu trên thiết bị.\nTất cả dữ liệu sẽ mất khi gỡ cài đặt ứng dụng.',
  );

  // ── 할 일 목록 화면 ──────────────────────────────────────────────────────

  String get todoListTitle => _t('할 일 목록', 'Tasks', 'タスク', 'Mga Gawain', 'Công việc');
  String get todoListEmpty => _t('등록된 할 일이 없습니다.', 'No tasks yet.', 'タスクがありません。', 'Walang mga gawain pa.', 'Chưa có công việc nào.');
  String get todoListAdd   => _t('할 일 추가', 'Add Task', 'タスクを追加', 'Magdagdag ng Gawain', 'Thêm công việc');

  // ── 알림 화면 ────────────────────────────────────────────────────────────

  String get notifScreenTitle   => _t('알림', 'Notifications', '通知', 'Mga Notipikasyon', 'Thông báo');
  String get notifMarkAllRead   => _t('모두 읽음', 'Mark all read', '全て既読', 'Markahan Lahat', 'Đánh dấu đã đọc');
  String get notifEmpty         => _t('모든 알림을 읽었습니다.', 'All notifications read.', 'すべての通知を既読にしました。', 'Nabasa na ang lahat ng notipikasyon.', 'Đã đọc tất cả thông báo.');
  String notifBtn(int n)        => n > 0
      ? _t('알림 ($n)', 'Notifications ($n)', '通知 ($n)', 'Mga Notipikasyon ($n)', 'Thông báo ($n)')
      : _t('알림', 'Notifications', '通知', 'Mga Notipikasyon', 'Thông báo');
  String get dailyNotifOn       => _t('🔔 일일 비서 알림이 활성화되어 있어요!', '🔔 Daily assistant notifications are on!', '🔔 毎日のアシスタント通知がオンです！', '🔔 Naka-on ang daily assistant notifications!', '🔔 Thông báo trợ lý hàng ngày đang bật!');
  String get dailyNotifOff      => _t('🔕 일일 비서 알림이 비활성화 되어 있어요!', '🔕 Daily assistant notifications are off!', '🔕 毎日のアシスタント通知がオフです！', '🔕 Naka-off ang daily assistant notifications!', '🔕 Thông báo trợ lý hàng ngày đang tắt!');
  String get dailyNotifSlotSectionTitle => _t('시간대별로 선택하기', 'Choose by time slot', '時間帯ごとに選択', 'Piliin ayon sa oras', 'Chọn theo khung giờ');
  String get dailyNotifSlotMorning      => _t('🌅 아침 알림', '🌅 Morning', '🌅 朝の通知', '🌅 Umaga', '🌅 Buổi sáng');
  String get dailyNotifSlotLunch        => _t('🍱 점심 알림', '🍱 Lunch', '🍱 昼の通知', '🍱 Tanghali', '🍱 Buổi trưa');
  String get dailyNotifSlotEvening      => _t('🌆 저녁 알림', '🌆 Evening', '🌆 夕方の通知', '🌆 Gabi', '🌆 Buổi tối');
  String get dailyNotifSlotBedtime      => _t('🌙 잠자리 알림', '🌙 Bedtime', '🌙 就寝前の通知', '🌙 Oras ng Tulog', '🌙 Trước khi ngủ');
  String get dailyNotifSlotWeekly       => _t('📊 주간 요약 알림', '📊 Weekly Summary', '📊 週間サマリー', '📊 Lingguhang Buod', '📊 Tóm tắt hàng tuần');
  String dailyNotifSlotDailyTime(String time)  => _t('매일 $time', 'Daily at $time', '毎日 $time', 'Araw-araw sa $time', 'Hàng ngày lúc $time');
  String dailyNotifSlotWeeklyTime(String time) => _t('매주 일요일 $time', 'Every Sunday at $time', '毎週日曜日 $time', 'Tuwing Linggo sa $time', 'Mỗi Chủ Nhật lúc $time');

  // ── 캘린더 화면 ──────────────────────────────────────────────────────────

  String get calendarTitle          => _t('날짜형 목록', 'Calendar', 'カレンダー', 'Kalendaryo', 'Lịch');
  String get calendarFormatMonth    => _t('월간', 'Month', '月表示', 'Buwanan', 'Tháng');
  String get calendarFormatTwoWeeks => _t('2주', '2 Weeks', '2週間', '2 Linggo', '2 Tuần');
  String get calendarFormatWeek     => _t('주간', 'Week', '週表示', 'Linggo', 'Tuần');
  String get calendarDateFormat     => _t('M월 d일 (E)', 'EEE, MMM d', 'M月d日(E)', 'EEE, MMM d', 'EEE, d MMM');
  String get calendarDateLocale     => _t('ko_KR', 'en_US', 'ja_JP', 'en_US', 'vi_VN');
  String calendarTaskCount(int n)   => _t('$n건', '$n tasks', '$n件', '$n gawain', '$n việc');
  String get calendarEmpty          => _t('이 날에는 할 일이 없습니다.', 'No tasks for this day.', 'この日のタスクはありません。', 'Walang gawain para sa araw na ito.', 'Không có công việc cho ngày này.');
  String get calendarAddFab         => _t('이 날에 추가', 'Add to This Day', 'この日に追加', 'Idagdag sa Araw na Ito', 'Thêm vào ngày này');

  // ── 그래프 화면 ──────────────────────────────────────────────────────────

  String get graphTitle => _t('그래프형 목록', 'Statistics', '統計', 'Estadistika', 'Thống kê');

  // ── 기분한줄 화면 ────────────────────────────────────────────────────────

  String get moodTitle => _t('기분한줄', 'Mood Journal', '気分メモ', 'Mood Journal', 'Nhật ký tâm trạng');

  // ── 가계부 화면 ──────────────────────────────────────────────────────────

  String get ledgerTitle => _t('가계부', 'Budget', '家計簿', 'Budget', 'Sổ chi tiêu');

  // ── 타이머 화면 ──────────────────────────────────────────────────────────

  String get timerTitle => _t('타이머', 'Timer', 'タイマー', 'Timer', 'Hẹn giờ');

  // ── 세계시각 화면 ────────────────────────────────────────────────────────

  String get worldClockTitle => _t('세계시각', 'World Clock', '世界時計', 'World Clock', 'Giờ thế giới');

  // ── 공지사항 화면 ────────────────────────────────────────────────────────

  String get noticesTitle        => _t('공지사항', 'Announcements', 'お知らせ', 'Mga Anunsyo', 'Thông báo');
  String get noticesEmpty        => _t('공지사항이 없습니다.', 'No announcements.', 'お知らせはありません。', 'Walang mga anunsyo.', 'Không có thông báo.');
  String get noticesLoginRequired=> _t('로그인 후 이용할 수 있습니다.', 'Please sign in to view.', 'ログイン後にご利用いただけます。', 'Mag-sign in para makita.', 'Vui lòng đăng nhập để xem.');

  // ── 업데이트 내역 화면 ───────────────────────────────────────────────────

  String get updatesTitle => _t('업데이트 내역', 'Update History', 'アップデート履歴', 'Kasaysayan ng Update', 'Lịch sử cập nhật');

  // ── 고객지원 화면 ────────────────────────────────────────────────────────

  String get supportTitle => _t('고객지원', 'Support', 'サポート', 'Suporta', 'Hỗ trợ');

  // ── 테마 설정 화면 ───────────────────────────────────────────────────────

  String get themeSettingsTitle => _t('테마 설정', 'Theme Settings', 'テーマ設定', 'Mga Setting ng Tema', 'Cài đặt giao diện');

  // ── 프로필 편집 화면 ─────────────────────────────────────────────────────

  String get profileTitle => _t('프로필 / 계정', 'Profile / Account', 'プロフィール / アカウント', 'Profile / Account', 'Hồ sơ / Tài khoản');
  String get profileNickname  => _t('닉네임', 'Nickname', 'ニックネーム', 'Palayaw', 'Biệt danh');
  String get profileBirthday  => _t('생일', 'Birthday', '生年月日', 'Kaarawan', 'Ngày sinh');
  String get profileAgeVerified => _t('만 14세 이상입니다.', 'I am 14 years of age or older.', '満14歳以上です。', 'Ako ay 14 taong gulang o mas matanda.', 'Tôi từ 14 tuổi trở lên.');
  String get profileAgeVerifiedSub => _t(
    '14세 미만은 법정대리인의 동의가 필요합니다.',
    'Those under 14 require parental consent.',
    '14歳未満は保護者の同意が必要です。',
    'Ang mga wala pang 14 taon ay nangangailangan ng pahintulot ng magulang.',
    'Dưới 14 tuổi cần có sự đồng ý của phụ huynh.',
  );
  String get profilePrivacyAgreed  => _t('개인정보 처리방침에 동의합니다. ', 'I agree to the Privacy Policy. ', 'プライバシーポリシーに同意します。', 'Sumasang-ayon ako sa Privacy Policy. ', 'Tôi đồng ý với Chính sách Quyền riêng tư. ');
  String get profilePrivacyView    => _t('(보기)', '(View)', '(表示)', '(Tingnan)', '(Xem)');
  String get profilePrivacyAgreedSub => _t(
    '동의 시 닉네임/나이가 저장되며 등급이 "일반(NORMAL)" 으로 변경됩니다.',
    'By agreeing, your nickname/age will be saved and your grade will be set to "Normal".',
    '同意すると、ニックネーム/年齢が保存され、等級が「一般(NORMAL)」に変更されます。',
    'Sa pagsang-ayon, ang iyong palayaw/edad ay mase-save at ang grade ay magiging "Normal".',
    'Khi đồng ý, biệt danh/tuổi sẽ được lưu và cấp độ sẽ là "Bình thường (NORMAL)".',
  );
  String get profileSaved     => _t('프로필이 저장되었습니다.', 'Profile saved.', 'プロフィールが保存されました。', 'Na-save ang profile.', 'Đã lưu hồ sơ.');
  String profileSaveFail(String e) => _t('저장 실패: $e', 'Save failed: $e', '保存失敗: $e', 'Nabigo ang pag-save: $e', 'Lưu thất bại: $e');

  String get profileDeleteTitle   => _t('회원 탈퇴', 'Delete Account', 'アカウント削除', 'Burahin ang Account', 'Xóa tài khoản');
  String get profileDeleteConfirm => _t(
    '계정과 모든 클라우드 데이터(할 일, 프로필)가 영구적으로 삭제됩니다.\n이 작업은 되돌릴 수 없습니다. 계속하시겠어요?',
    'Your account and all cloud data (tasks, profile) will be permanently deleted.\nThis action cannot be undone. Continue?',
    'アカウントとすべてのクラウドデータ(タスク、プロフィール)が永久に削除されます。\nこの操作は元に戻せません。続けますか？',
    'Ang iyong account at lahat ng cloud data ay permanenteng mabubura.\nHindi ito maaaring ibalik. Ituloy?',
    'Tài khoản và toàn bộ dữ liệu đám mây sẽ bị xóa vĩnh viễn.\nHành động này không thể hoàn tác. Tiếp tục?',
  );
  String get profileDeleteBtn     => _t('탈퇴', 'Delete', '退会', 'Burahin', 'Xóa');
  String get profileDeleteWarning => _t(
    '※ 탈퇴 시 클라우드의 모든 데이터(할 일·프로필)가 즉시 삭제됩니다.',
    '※ All cloud data (tasks · profile) will be deleted immediately upon withdrawal.',
    '※ 退会するとクラウドの全データ(タスク・プロフィール)が即時削除されます。',
    '※ Lahat ng cloud data ay agad na mabubura kapag nag-withdraw.',
    '※ Tất cả dữ liệu đám mây sẽ bị xóa ngay lập tức khi rút lui.',
  );

  String get profilePhone            => _t('휴대폰 번호', 'Phone Number', '電話番号', 'Numero ng Telepono', 'Số điện thoại');
  String get profilePhoneNote        => _t(
    '※ 동일 번호로 중복 등록 불가. 보호자 번호는 별도 입력란을 이용하세요.',
    '※ Cannot register the same number twice. Use a separate field for guardian numbers.',
    '※ 同じ番号の重複登録は不可。保護者の番号は別の入力欄をご利用ください。',
    '※ Hindi maaaring mag-register ng parehong numero nang dalawang beses.',
    '※ Không thể đăng ký cùng một số hai lần. Dùng ô riêng cho số người giám hộ.',
  );
  String get profilePhoneDuplicate   => _t('이미 등록된 휴대폰 번호입니다.', 'This phone number is already registered.', 'この電話番号はすでに登録されています。', 'Ang numerong ito ay nairehistro na.', 'Số điện thoại này đã được đăng ký.');
  String get profilePhotoTitle       => _t('프로필 사진', 'Profile Photo', 'プロフィール写真', 'Profile Photo', 'Ảnh đại diện');
  String get profilePhotoGallery     => _t('갤러리에서 선택', 'Choose from Gallery', 'ギャラリーから選択', 'Pumili mula sa Gallery', 'Chọn từ Thư viện');
  String get profilePhotoRemove      => _t('프로필 사진 제거', 'Remove Profile Photo', 'プロフィール写真を削除', 'Alisin ang Profile Photo', 'Xóa ảnh đại diện');
  String get profilePhotoChanged     => _t('프로필 사진을 변경했어요.', 'Profile photo changed.', 'プロフィール写真を変更しました。', 'Nabago ang profile photo.', 'Đã thay đổi ảnh đại diện.');
  String get profileAvatarApplied    => _t('기본 아바타가 적용됐어요.', 'Default avatar applied.', 'デフォルトアバターが適用されました。', 'Nailapat ang default avatar.', 'Đã áp dụng avatar mặc định.');
  String get profilePhotoRemoved     => _t('프로필 사진을 제거했어요.', 'Profile photo removed.', 'プロフィール写真を削除しました。', 'Naalis ang profile photo.', 'Đã xóa ảnh đại diện.');
  String profilePhotoChangeFail(String e) => _t('변경 실패: $e', 'Change failed: $e', '変更失敗: $e', 'Nabigo ang pagbabago: $e', 'Thay đổi thất bại: $e');
  String get profileReLoginRequired  => _t('보안을 위해 다시 로그인 후 시도해 주세요.', 'Please sign in again for security reasons.', 'セキュリティのため、再ログインしてお試しください。', 'Mangyaring mag-sign in muli para sa seguridad.', 'Vui lòng đăng nhập lại vì lý do bảo mật.');
  String profileDeleteFail(String e) => _t('탈퇴 실패: $e', 'Delete failed: $e', '退会失敗: $e', 'Nabigo ang pag-withdraw: $e', 'Xóa tài khoản thất bại: $e');
  String get profileBrowserFail      => _t('브라우저를 열 수 없습니다.', 'Cannot open browser.', 'ブラウザを開けません。', 'Hindi mabuksan ang browser.', 'Không thể mở trình duyệt.');
  String get profileGradePrefix      => _t('등급: ', 'Grade: ', '等級: ', 'Grade: ', 'Cấp độ: ');
  String get profileNicknameHint     => _t('예) 홍길동', 'e.g. John', '例) 山田太郎', 'hal. Juan', 'vd. Nguyễn');
  String get profileBirthdayHint     => _t('예) 1990-01-01', 'e.g. 1990-01-01', '例) 1990-01-01', 'hal. 1990-01-01', 'vd. 1990-01-01');
  String get profileBirthdayPick     => _t('생일 선택', 'Select Birthday', '誕生日を選択', 'Pumili ng Kaarawan', 'Chọn ngày sinh');
  String get profilePhoneHint        => _t('01012345678 (숫자만)', '01012345678 (numbers only)', '01012345678（数字のみ）', '01012345678 (numero lang)', '01012345678 (chỉ số)');
  String get profileLocale           => _t('ko', 'en', 'ja', 'en', 'vi');

  // ── Pro 등급 신청 화면 ───────────────────────────────────────────────────

  String get proRequestTitle => _t('Pro 등급 신청', 'Apply for Pro', 'Proランク申請', 'Mag-apply para sa Pro', 'Đăng ký Pro');

  // ── 사용설명서 화면 ──────────────────────────────────────────────────────

  String get manualTitle => _t('사용설명서', 'User Guide', '使い方ガイド', 'Gabay ng Gumagamit', 'Hướng dẫn sử dụng');

  // ── 온보딩 화면 ──────────────────────────────────────────────────────────

  String get onboardingTitle => _t('시작하기', 'Get Started', 'はじめる', 'Magsimula', 'Bắt đầu');

  // ── 언어 설정 화면 ───────────────────────────────────────────────────────

  String get languageTitle => _t('언어 / Language', 'Language / 언어', '言語 / Language', 'Wika / Language', 'Ngôn ngữ / Language');
  String get languageSelectHint => _t(
    '앱에서 사용할 언어를 선택하세요.',
    'Select the language to use in the app.',
    'アプリで使用する言語を選択してください。',
    'Piliin ang wikang gagamitin sa app.',
    'Chọn ngôn ngữ sử dụng trong ứng dụng.',
  );
  String get languageApplyNote => _t(
    '※ 언어 변경은 즉시 적용됩니다.',
    '※ Language change applies immediately.',
    '※ 言語変更はすぐに反映されます。',
    '※ Ang pagbabago ng wika ay agad na mailalapat.',
    '※ Thay đổi ngôn ngữ được áp dụng ngay lập tức.',
  );

  // ── AI 인사이트 (Gemini) ─────────────────────────────────────────────────

  String get geminiNoKeyTitle => _t('AI 데일리 인사이트', 'AI Daily Insight', 'AIデイリーインサイト', 'AI Daily Insight', 'AI Nhận xét Hằng ngày');
  String get geminiNoKeyDesc  => _t(
    '설정에서 Gemini API 키를 입력하면\n할 일·기분·가계부를 AI가 분석해 드려요.',
    'Enter a Gemini API key in Settings to get\nAI analysis of your tasks, mood & budget.',
    '設定でGemini APIキーを入力すると\nタスク・気分・家計簿をAIが分析します。',
    'Ilagay ang Gemini API key sa Settings para\nmakuha ang AI analysis ng iyong mga gawain.',
    'Nhập Gemini API key trong Cài đặt để\nAI phân tích công việc, tâm trạng và chi tiêu.',
  );
  String get geminiGoSettings  => _t('설정', 'Settings', '設定', 'Mga Setting', 'Cài đặt');
  String get geminiAnalyzing   => _t('Gemini 분석 중...', 'Gemini analyzing...', 'Gemini 分析中...', 'Nag-aanalisa si Gemini...', 'Gemini đang phân tích...');
  String get geminiIdleHint    => _t('AI가 오늘 하루를 분석해 드릴게요.', 'AI will analyze your day for you.', 'AIが今日を分析します。', 'Susuriin ng AI ang iyong araw.', 'AI sẽ phân tích ngày hôm nay của bạn.');
  String get geminiIdleDesc    => _t(
    '할 일·기분·가계부 데이터를 종합해\n시간대별 맞춤 인사이트를 생성합니다.',
    'Combines your tasks, mood & budget data\nto generate time-based personalized insights.',
    'タスク・気分・家計簿を統合して\n時間帯別のインサイトを生成します。',
    'Pinagsasama ang tasks, mood at budget\npara gumawa ng personalized na insights.',
    'Tổng hợp công việc, tâm trạng và chi tiêu\nđể tạo nhận xét cá nhân hóa theo giờ.',
  );
  String get geminiGenerateBtn => _t('✨ 인사이트 생성하기', '✨ Generate Insight', '✨ インサイト生成', '✨ Gumawa ng Insight', '✨ Tạo nhận xét');
  String get geminiLoadFailed  => _t('AI 인사이트를 불러오지 못했어요.', 'Failed to load AI insight.', 'AIインサイトを読み込めませんでした。', 'Hindi na-load ang AI insight.', 'Không thể tải AI nhận xét.');
  String get geminiRetry       => _t('다시 시도 →', 'Retry →', '再試行 →', 'Subukan Muli →', 'Thử lại →');

  String get geminiErrBadRequest    => _t('요청 형식이 올바르지 않습니다. 데이터 구성을 확인해 주세요.', 'Request format is invalid. Please check your data.', 'リクエスト形式が正しくありません。', 'Ang format ng request ay invalid.', 'Định dạng yêu cầu không hợp lệ.');
  String get geminiErrKeyMissing    => _t('Gemini API 키가 설정되지 않았습니다. 설정 화면에서 키를 입력해 주세요.', 'Gemini API key is not set. Please enter your key in Settings.', 'Gemini APIキーが設定されていません。', 'Hindi nakatakda ang Gemini API key.', 'Chưa cài đặt Gemini API key.');
  String get geminiErrKeyInvalid    => _t('API 키가 유효하지 않습니다. 키를 확인하고 다시 입력해 주세요.', 'API key is invalid or expired. Please check your key and re-enter it.', 'APIキーが無効です。確認して再入力してください。', 'Invalid ang API key.', 'API key không hợp lệ.');
  String get geminiErrQuotaExhausted=> _t(
    '무료 할당량이 완전히 소진되었습니다.\nGoogle AI Studio에서 새 프로젝트의 API 키를 발급받아 설정에서 교체해 주세요.',
    'Free quota exhausted.\nPlease create a new project in Google AI Studio and enter a new API key in Settings.',
    '無料クォータが枯渇しました。\nGoogle AI Studioで新しいAPIキーを発行してください。',
    'Naubusan na ng free quota.\nGumawa ng bagong project sa Google AI Studio.',
    'Đã hết hạn mức miễn phí.\nHãy tạo dự án mới trong Google AI Studio.',
  );
  String get geminiErrRateLimit  => _t('요청이 너무 잦습니다. 약 1분 뒤에 다시 시도해 주세요!', 'Too many requests. Please try again in about a minute!', 'リクエストが多すぎます。約1分後に再試行してください！', 'Masyadong maraming request. Subukan muli pagkatapos ng isang minuto!', 'Quá nhiều yêu cầu. Vui lòng thử lại sau khoảng 1 phút!');
  String get geminiErrNetwork    => _t('네트워크 오류가 발생했습니다. 연결 상태를 확인해 주세요.', 'A network error occurred. Please check your connection.', 'ネットワークエラーが発生しました。接続状態を確認してください。', 'May network error. Suriin ang iyong koneksyon.', 'Lỗi mạng. Vui lòng kiểm tra kết nối của bạn.');
  String get geminiErrParse      => _t('AI 응답을 처리하지 못했습니다. 잠시 후 다시 시도해 주세요.', 'Failed to process the AI response. Please try again later.', 'AI応答の処理に失敗しました。後でもう一度お試しください。', 'Hindi naproseso ang AI response. Subukan muli mamaya.', 'Không thể xử lý phản hồi AI. Vui lòng thử lại sau.');
  String get geminiErrGeneral    => _t('AI 서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.', 'An AI server error occurred. Please try again later.', 'AIサーバーエラーが発生しました。後でもう一度お試しください。', 'May AI server error. Subukan muli mamaya.', 'Lỗi máy chủ AI. Vui lòng thử lại sau.');
}

// ─── 델리게이트 ─────────────────────────────────────────────────────────────

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ko', 'en', 'ja', 'fil', 'vi'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
