import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../core/theme/app_theme.dart';

/// Floating AI Assistant button that sits in the bottom-right corner of any dashboard.
/// Adheres to 56x56 px circular shape, elevation/shadow, LifeLink branding,
/// and navigates to the dedicated AI Chat screen on tap.
class FloatingAiAssistantButton extends StatelessWidget {
  final Object? heroTag;

  const FloatingAiAssistantButton({
    super.key,
    this.heroTag = 'lifelink_ai_floating_button',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56.w,
      height: 56.w,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.40),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          splashColor: Colors.white24,
          highlightColor: Colors.white10,
          onTap: () {
            Navigator.of(context).pushNamed('/ai-chat');
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Main AI / Robot Icon
              Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 28.w,
              ),
              // Subtle pulse spark dot in the upper corner
              Positioned(
                top: 10.w,
                right: 11.w,
                child: Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
