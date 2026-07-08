import 'package:flutter/material.dart';
import '../api.dart';
import '../auth.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import 'corporate_cx.dart';
import 'notifications.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    if (AuthState.instance.user?.isGuest == true) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceAlt,
          title: const Text('Log out as guest?', style: TextStyle(color: AppColors.text)),
          content: const Text(
            "You booked as a guest. If you log out you'll lose access to your bookings & QR here in the app. Create an account first to keep them.",
            style: TextStyle(color: AppColors.textMuted),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out anyway', style: TextStyle(color: AppColors.danger))),
          ],
        ),
      );
      if (ok != true) return;
    }
    AuthState.instance.logout();
  }

  Future<void> _openEdit(BuildContext context, AppUser user) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => _EditProfileSheet(user: user),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String?, Widget?)>[
      (Icons.business_outlined, 'Corporate / Bulk booking', 'Register or manage your company', const CxLandingScreen()),
      (Icons.notifications_none, 'Notifications', 'Booking & payment updates', const NotificationsScreen()),
      (Icons.credit_card, 'Payment methods', 'Cards & UPI are entered at checkout', null),
      (Icons.verified_user_outlined, 'Security', 'You sign in with a one-time code (OTP)', null),
      (Icons.help_outline, 'Help & support', null, null),
    ];

    return ListenableBuilder(
      listenable: AuthState.instance,
      builder: (context, _) {
        final user = AuthState.instance.user;
        final isGuest = user?.isGuest == true;
        final name = isGuest ? 'Guest player' : (user?.name ?? 'Strikin player');
        final email = user?.email ?? (isGuest ? 'Signed in as guest' : '');
        final pts = user?.loyaltyPoints ?? 0;
        return AppScaffold(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              const Text('Profile', style: T.h1),
              const SizedBox(height: AppSpacing.lg),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                onTap: (user == null || isGuest) ? null : () => _openEdit(context, user),
                child: AppCard(
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
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
                            if (!isGuest) ...[
                              const SizedBox(height: 6),
                              Row(children: [
                                Icon(Icons.diamond_outlined, size: 14, color: AppColors.primary),
                                const SizedBox(width: 4),
                                Text('$pts loyalty pts', style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                              ]),
                            ],
                          ],
                        ),
                      ),
                      if (!isGuest) const Icon(Icons.edit_outlined, size: 20, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (int i = 0; i < rows.length; i++) ...[
                      InkWell(
                        onTap: rows[i].$4 == null
                            ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon')))
                            : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => rows[i].$4!)),
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
              AppButton('Log out', variant: 'secondary', onPressed: () => _logout(context)),
              const SizedBox(height: AppSpacing.lg),
              Center(child: Text('Strikin v1.0.0 · API ${Api.baseUrl}', style: const TextStyle(color: AppColors.textFaint, fontSize: 12))),
            ],
          ),
        );
      },
    );
  }
}

/// Edit profile bottom sheet — name, phone, date of birth → PATCH /auth/me.
class _EditProfileSheet extends StatefulWidget {
  final AppUser user;
  const _EditProfileSheet({required this.user});
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  DateTime? _dob;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.user.name ?? '');
    _phone = TextEditingController(text: widget.user.phone ?? '');
    _email = TextEditingController(text: widget.user.email ?? '');
    _dob = (widget.user.dob != null) ? DateTime.tryParse(widget.user.dob!) : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  String _dobText() {
    final d = _dob;
    if (d == null) return 'Select date of birth';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(primary: AppColors.primary, onPrimary: AppColors.textOnAccent, surface: AppColors.surface),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  String? _dobIso() => _dob == null
      ? null
      : '${_dob!.year.toString().padLeft(4, '0')}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}';

  bool get _dobChanged => (widget.user.dob ?? '') != (_dobIso() ?? '');

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Please enter your full name.');
      return;
    }
    final newPhone = _phone.text.trim();
    final newEmail = _email.text.trim();
    final phoneChanged = newPhone != (widget.user.phone ?? '').trim();
    final emailChanged = newEmail.toLowerCase() != (widget.user.email ?? '').trim().toLowerCase();

    // Validate any changed contact before touching the server.
    if (phoneChanged && newPhone.replaceAll(RegExp(r'\D'), '').length != 10) {
      setState(() => _error = 'Please enter a valid 10-digit mobile number.');
      return;
    }
    if (emailChanged && newEmail.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(newEmail)) {
      setState(() => _error = 'Please enter a valid email address.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // 1. Name / date of birth — no OTP. (Phone is verified separately below.)
      if (name != (widget.user.name ?? '') || _dobChanged) {
        final updated = await Api.updateProfile(fullName: name, dateOfBirth: _dobIso(), clearDob: _dob == null);
        await AuthState.instance.applyProfileUpdate(updated);
      }

      // 2. Phone change → OTP to the new number.
      if (phoneChanged && !await _verifyContact('phone', newPhone)) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      // 3. Email change → OTP to the new email.
      if (emailChanged && newEmail.isNotEmpty && !await _verifyContact('email', newEmail)) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save. Please try again.';
        });
      }
    }
  }

  /// Send an OTP to [value] and open the verify sheet. Returns true once the
  /// change is applied to the profile, false if the user cancels.
  Future<bool> _verifyContact(String field, String value) async {
    await Api.requestContactChangeOtp(field, value); // throws → surfaced by _save
    if (!mounted) return false;
    final applied = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
      builder: (_) => _ContactOtpSheet(field: field, value: value),
    );
    if (applied == null) return false;
    await AuthState.instance.applyProfileUpdate(applied);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.lg, bottom: AppSpacing.lg + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Edit profile', style: T.h2),
          const SizedBox(height: AppSpacing.lg),
          const Text('Full name', style: T.label),
          const SizedBox(height: AppSpacing.sm),
          AppField(icon: Icons.person_outline, hint: 'Your name', controller: _name),
          const SizedBox(height: AppSpacing.md),
          const Text('Phone', style: T.label),
          const SizedBox(height: AppSpacing.sm),
          AppField(icon: Icons.phone_outlined, hint: 'Phone number', controller: _phone, keyboardType: TextInputType.phone),
          const SizedBox(height: AppSpacing.md),
          const Text('Email', style: T.label),
          const SizedBox(height: AppSpacing.sm),
          AppField(icon: Icons.mail_outline, hint: 'Email address', controller: _email, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 6),
          const Text("We'll send a code to confirm a new phone or email.", style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
          const SizedBox(height: AppSpacing.md),
          const Text('Date of birth', style: T.label),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            onTap: _pickDob,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(children: [
                const Icon(Icons.cake_outlined, size: 18, color: AppColors.textFaint),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: Text(_dobText(), style: TextStyle(color: _dob == null ? AppColors.textFaint : AppColors.text, fontSize: 15))),
                if (_dob != null)
                  GestureDetector(
                    onTap: () => setState(() => _dob = null),
                    child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                  ),
              ]),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton('Save changes', loading: _busy, onPressed: _busy ? null : _save),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// OTP confirmation for a phone/email change. Returns the updated profile map
/// via Navigator.pop on success, or null if the user dismisses it.
class _ContactOtpSheet extends StatefulWidget {
  final String field; // 'phone' | 'email'
  final String value;
  const _ContactOtpSheet({required this.field, required this.value});
  @override
  State<_ContactOtpSheet> createState() => _ContactOtpSheetState();
}

class _ContactOtpSheetState extends State<_ContactOtpSheet> {
  final _otp = TextEditingController();
  bool _busy = false;
  bool _resending = false;
  String? _error;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _otp.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code we sent you.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final profile = await Api.verifyContactChangeOtp(widget.field, widget.value, code);
      if (mounted) Navigator.of(context).pop(profile);
    } on ApiException catch (e) {
      if (mounted) setState(() { _busy = false; _error = e.message; });
    } catch (_) {
      if (mounted) setState(() { _busy = false; _error = 'Could not verify. Please try again.'; });
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await Api.requestContactChangeOtp(widget.field, widget.value);
      if (mounted) {
        setState(() => _resending = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code resent.')));
      }
    } catch (e) {
      if (mounted) setState(() { _resending = false; _error = e is ApiException ? e.message : 'Could not resend. Try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final label = widget.field == 'email' ? 'email' : 'mobile number';
    return Padding(
      padding: EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.lg, bottom: AppSpacing.lg + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Verify your new $label', style: T.h2),
          const SizedBox(height: 6),
          Text('Enter the 6-digit code we sent to ${widget.value} to confirm the change.', style: T.caption),
          const SizedBox(height: AppSpacing.lg),
          AppField(icon: Icons.lock_outline, hint: '6-digit code', controller: _otp, keyboardType: TextInputType.number),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton('Verify & save', loading: _busy, onPressed: _busy ? null : _verify),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: _resending ? null : _resend,
              child: Text(_resending ? 'Resending…' : "Didn't get it? Resend code", style: TextStyle(color: AppColors.primary)),
            ),
          ),
        ],
      ),
    );
  }
}
