import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class AuthBanner extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onDismiss;

  const AuthBanner({
    super.key,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withAlpha(51),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 12),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(
                Icons.close_rounded,
                color: AppColors.textSecondaryDark,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
