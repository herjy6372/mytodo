import 'dart:io';

import 'package:flutter/material.dart';

/// 사용자 프로필 사진을 표시하는 공통 위젯.
/// - `asset:cats/orange` → 번들 에셋 이미지
/// - `file:/path/to/img` → 기기 로컬 파일 이미지
/// - 그 외 → 네트워크 URL
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.photoUrl,
    this.radius = 24,
    this.fallbackIcon = Icons.person_rounded,
  });

  final String? photoUrl;
  final double radius;
  final IconData fallbackIcon;

  static const _assetPrefix = 'asset:';
  static const _filePrefix = 'file:';

  /// 'asset:cats/orange' 같은 식별자를 만든다.
  static String assetIdOf(String folder, String name) =>
      '$_assetPrefix$folder/$name';

  /// [photoUrl] 에 맞는 ImageProvider 를 반환. 없으면 null.
  static ImageProvider? providerFor(String? photoUrl) {
    if (photoUrl == null || photoUrl.isEmpty) return null;
    if (photoUrl.startsWith(_assetPrefix)) {
      return AssetImage(
          'assets/avatars/${photoUrl.substring(_assetPrefix.length)}.png');
    }
    if (photoUrl.startsWith(_filePrefix)) {
      final path = photoUrl.substring(_filePrefix.length);
      final file = File(path);
      if (file.existsSync()) return FileImage(file);
      return null; // 파일 없으면 기본 아이콘
    }
    return NetworkImage(photoUrl);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = providerFor(photoUrl);
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primary.withValues(alpha: 0.12),
      backgroundImage: provider,
      child: provider == null
          ? Icon(fallbackIcon,
              color: scheme.primary, size: radius)
          : null,
    );
  }
}
