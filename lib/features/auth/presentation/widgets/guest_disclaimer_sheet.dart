import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class GuestDisclaimerSheet extends StatelessWidget {
  final VoidCallback onContinueAsGuest;
  final VoidCallback onSignIn;
  final VoidCallback onCreateAccount;

  const GuestDisclaimerSheet({
    super.key,
    required this.onContinueAsGuest,
    required this.onSignIn,
    required this.onCreateAccount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.textSecondaryDark.withAlpha(77),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Icon(
            Icons.person_outline_rounded,
            color: AppColors.primary,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            'Using Mispoti as Guest',
            style: TextStyle(
              color: AppColors.textPrimaryDark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create an account to unlock the full experience.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          _BenefitRow(
            icon: Icons.cloud_done_rounded,
            text: 'Save your preferences and playlists in the cloud',
          ),
          const SizedBox(height: 12),
          _BenefitRow(
            icon: Icons.sync_rounded,
            text: 'Sync your library across all your devices',
          ),
          const SizedBox(height: 12),
          _BenefitRow(
            icon: Icons.history_rounded,
            text: 'Access your listening history anywhere',
          ),
          const SizedBox(height: 12),
          _BenefitRow(
            icon: Icons.rocket_launch_rounded,
            text: 'Get early access to new personalized features',
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: onCreateAccount,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Create Account',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: TextButton(
              onPressed: onSignIn,
              child: Text(
                'I already have an account — Sign In',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onContinueAsGuest,
            child: Text(
              'Continue as Guest',
              style: TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 22),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: AppColors.textSecondaryDark,
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
