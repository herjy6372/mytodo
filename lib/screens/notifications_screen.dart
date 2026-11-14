import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/auth_repository.dart';
import '../data/language_repository.dart';
import '../data/notification_repository.dart';
import '../data/profile_repository.dart';
import '../l10n/app_localizations.dart';
import '../models/user_profile.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Stream<List<AppNotification>> _stream;
  late final String _targetId;

  @override
  void initState() {
    super.initState();
    final role = ProfileRepository.instance.role;
    final uid = AuthRepository.instance.uid ?? '';
    _targetId = (role == UserRole.admin)
        ? NotificationRepository.adminTargetId
        : uid;
    _stream = NotificationRepository.watchFor(_targetId);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dateLocale = LanguageRepository.instance.language.calendarLocale;
    final dateFormat = AppLocalizations.of(context).settingsSyncLastFormat;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifScreenTitle),
        actions: [
          TextButton(
            onPressed: () => NotificationRepository.markAllRead(_targetId),
            child: Text(l.notifMarkAllRead),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _stream,
        builder: (context, snap) {
          if (snap.hasError) {
            final errStr = snap.error.toString();
            final isPermDenied = errStr.contains('permission-denied') ||
                errStr.contains('PERMISSION_DENIED');
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPermDenied
                          ? Icons.lock_outline_rounded
                          : Icons.cloud_off_rounded,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPermDenied
                          ? 'Firestore 규칙이 아직 배포되지 않았습니다.\n\n터미널에서 실행하세요:\nfirebase deploy --only firestore:rules'
                          : '오류: $errStr',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13, height: 1.6),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_none_rounded,
                      size: 52, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(l.notifEmpty,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            itemCount: list.length,
            separatorBuilder: (context2, index2) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final n = list[i];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => NotificationRepository.markRead(n.id),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: n.read
                        ? scheme.surface
                        : scheme.primary.withValues(alpha:0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: n.read
                          ? scheme.outlineVariant
                          : scheme.primary.withValues(alpha:0.3),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 4, right: 10),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: n.read
                              ? Colors.transparent
                              : scheme.primary,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n.title,
                              style: TextStyle(
                                fontWeight: n.read
                                    ? FontWeight.normal
                                    : FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              n.body,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat(dateFormat, dateLocale)
                                  .format(n.createdAt),
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha:0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
