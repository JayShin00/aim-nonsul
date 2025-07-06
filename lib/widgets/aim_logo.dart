import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AimLogo extends StatelessWidget {
  final double? size;
  final bool showText;

  const AimLogo({Key? key, this.size, this.showText = true}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final logoSize = size ?? 32.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // AIM 로고 아이콘
        Container(
          width: logoSize,
          height: logoSize,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(8),
            boxShadow: AppTheme.lightShadow,
          ),
          child: Center(
            child: Text(
              'A',
              style: TextStyle(
                fontSize: logoSize * 0.6,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        if (showText) ...[
          const SizedBox(width: 8),
          // AIM 텍스트
          ShaderMask(
            shaderCallback:
                (bounds) => AppTheme.primaryGradient.createShader(bounds),
            child: Text(
              'AIM',
              style: TextStyle(
                fontSize: logoSize * 0.75,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class AimHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool showBackButton;
  final VoidCallback? onBackPressed;

  const AimHeader({
    Key? key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.showBackButton = false,
    this.onBackPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: const BoxDecoration(color: AppTheme.backgroundColor),
      child: SafeArea(
        child: Column(
          children: [
            // 상단 네비게이션 바
            if (showBackButton || trailing != null)
              Container(
                height: 56,
                child: Row(
                  children: [
                    if (showBackButton)
                      GestureDetector(
                        onTap:
                            onBackPressed ?? () => Navigator.of(context).pop(),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.close,
                            color: AppTheme.textPrimary,
                            size: 20,
                          ),
                        ),
                      ),
                    const Spacer(),
                    if (trailing != null) trailing!,
                  ],
                ),
              ),
            // 헤더 콘텐츠
            Row(
              children: [
                const AimLogo(size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTheme.headingLarge.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
