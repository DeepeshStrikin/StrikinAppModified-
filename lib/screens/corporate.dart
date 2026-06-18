import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

const _steps = [
  ('Company details', 'Name, Business License No., Tax/GST No., address, official email & phone, logo.'),
  ('Multi-factor verification', 'OTP sent to your official phone & email to confirm identity.'),
  ('Offline verification', 'A Strikin sales manager visits to confirm details. Mandatory for all corporates.'),
  ('Superadmin account', 'Once verified, you become the Superadmin — invite your team & allocate budgets.'),
];

const _fields = [
  ('company', 'Company name', Icons.business_outlined),
  ('license', 'Business license no.', Icons.description_outlined),
  ('gst', 'GST / Tax no.', Icons.receipt_outlined),
  ('email', 'Official email', Icons.mail_outline),
  ('phone', 'Official phone', Icons.call_outlined),
];

const _perks = [
  (Icons.account_balance_wallet_outlined, 'Corporate wallet & credit line', 'Prepaid tokens or postpaid with cheque deposit.'),
  (Icons.people_outline, 'Roles & permissions', 'Superadmin, Team Lead, and Employee roles.'),
  (Icons.pie_chart_outline, 'Budget allocation', 'Distribute tokens equally, tiered, or custom.'),
  (Icons.receipt_long_outlined, 'GST-compliant invoices', 'CGST/SGST/IGST with HSN/SAC codes.'),
];

class CorporateScreen extends StatefulWidget {
  const CorporateScreen({super.key});
  @override
  State<CorporateScreen> createState() => _CorporateScreenState();
}

class _CorporateScreenState extends State<CorporateScreen> {
  final _ctrls = {for (final f in _fields) f.$1: TextEditingController()};
  bool _submitted = false;

  bool _submitting = false;

  bool get _complete => _fields.every((f) => (_ctrls[f.$1]!.text).trim().length > 1);

  Future<void> _submit() async {
    setState(() => _submitting = true);
    await Api.submitInquiry(
      companyName: _ctrls['company']!.text.trim(),
      email: _ctrls['email']!.text.trim(),
      phone: _ctrls['phone']!.text.trim(),
      licenseNo: _ctrls['license']!.text.trim(),
      gstNo: _ctrls['gst']!.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _submitted = true;
    });
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg), child: AppHeader(title: 'Corporate')),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxxl),
                    children: [
                      const Tag('B2B · BULK BOOKING', tone: 'accent'),
                      const SizedBox(height: AppSpacing.sm),
                      const Text('Bring your team\nto Strikin', style: T.display),
                      const SizedBox(height: AppSpacing.sm),
                      const Text('Allocate budgets to employees, run group bookings, and get corporate rates (20–25% on golf). No bar facility on corporate bookings.', style: T.body),
                      const SizedBox(height: AppSpacing.xl),

                      if (_submitted)
                        AppCard(
                          child: Column(
                            children: [
                              Container(
                                width: 64, height: 64,
                                decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                child: const Icon(Icons.schedule, color: AppColors.textOnAccent, size: 32),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              const Text('Application received', style: T.h2, textAlign: TextAlign.center),
                              const SizedBox(height: AppSpacing.sm),
                              Text('We\'ve sent an OTP to ${_ctrls['email']!.text}. Our sales manager will reach out to schedule offline verification. You can resume anytime via the re-login link in your email.',
                                  style: T.caption, textAlign: TextAlign.center),
                              const SizedBox(height: AppSpacing.lg),
                              AppButton('Done', variant: 'secondary', onPressed: () => setState(() => _submitted = false)),
                            ],
                          ),
                        )
                      else ...[
                        AppCard(
                          child: Column(
                            children: [
                              for (int i = 0; i < _steps.length; i++) ...[
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 26, height: 26,
                                      decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                                      alignment: Alignment.center,
                                      child: Text('${i + 1}', style: const TextStyle(color: AppColors.textOnAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(_steps[i].$1, style: T.bodyStrong),
                                          const SizedBox(height: 2),
                                          Text(_steps[i].$2, style: T.caption),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (i < _steps.length - 1) const Divider(color: AppColors.border, height: AppSpacing.xl),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        const Text('Get started', style: T.h3),
                        const SizedBox(height: AppSpacing.md),
                        ..._fields.map((f) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: AppField(
                                icon: f.$3,
                                hint: f.$2,
                                controller: _ctrls[f.$1],
                                keyboardType: f.$1 == 'phone' ? TextInputType.phone : f.$1 == 'email' ? TextInputType.emailAddress : TextInputType.text,
                                onChanged: (_) => setState(() {}),
                              ),
                            )),
                        const SizedBox(height: AppSpacing.lg),
                        AppButton('Submit & send OTP', loading: _submitting, onPressed: _complete ? _submit : null),
                        const SizedBox(height: AppSpacing.md),
                        const Center(child: Text('Corporate accounts go live only after offline verification is completed.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint, fontSize: 12))),
                      ],

                      const SizedBox(height: AppSpacing.xxl),
                      const Text('What you get', style: T.h3),
                      const SizedBox(height: AppSpacing.md),
                      ..._perks.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: AppCard(
                              child: Row(
                                children: [
                                  Icon(p.$1, size: 22, color: AppColors.primary),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.$2, style: T.bodyStrong),
                                        Text(p.$3, style: T.caption),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
