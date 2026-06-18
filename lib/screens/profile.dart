import 'package:flutter/material.dart';
import '../api.dart';
import '../auth.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import 'corporate.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String?, Widget?)>[
      (Icons.business_outlined, 'Corporate / Bulk booking', 'Register or manage your company', const CorporateScreen()),
      (Icons.credit_card, 'Payment methods', null, null),
      (Icons.verified_user_outlined, 'Security & MFA', 'OTP, biometric login', null),
      (Icons.notifications_none, 'Notifications', 'Email · SMS · WhatsApp', null),
      (Icons.receipt_long_outlined, 'Invoices & GST', null, null),
      (Icons.help_outline, 'Help & support', null, null),
    ];

    return ListenableBuilder(
      listenable: AuthState.instance,
      builder: (context, _) {
        final user = AuthState.instance.user;
        final name = user?.isGuest == true ? 'Guest player' : (user?.name ?? 'Strikin player');
        final email = user?.email ?? (user?.isGuest == true ? 'Signed in as guest' : '');
        return AppScaffold(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              const Text('Profile', style: T.h1),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                child: Row(
                  children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                      child: const Icon(Icons.person, color: AppColors.textOnAccent, size: 28),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: T.h3),
                          if (email.isNotEmpty) Text(email, style: T.caption),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_outlined, size: 20, color: AppColors.textMuted),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (int i = 0; i < rows.length; i++) ...[
                      InkWell(
                        onTap: rows[i].$4 == null ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => rows[i].$4!)),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          child: Row(
                            children: [
                              Icon(rows[i].$1, size: 20, color: AppColors.textMuted),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(rows[i].$2, style: T.body),
                                    if (rows[i].$3 != null) Text(rows[i].$3!, style: const TextStyle(color: AppColors.textFaint, fontSize: 13)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right, size: 18, color: AppColors.textFaint),
                            ],
                          ),
                        ),
                      ),
                      if (i < rows.length - 1) const Divider(color: AppColors.border, height: 1),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton('Log out', variant: 'secondary', onPressed: () => AuthState.instance.logout()),
              const SizedBox(height: AppSpacing.lg),
              Center(child: Text('Strikin v1.0.0 · API ${Api.baseUrl}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12))),
            ],
          ),
        );
      },
    );
  }
}
