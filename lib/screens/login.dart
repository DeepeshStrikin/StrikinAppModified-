import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api.dart';
import '../auth.dart';
import '../theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/profile_capture.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import 'terms.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _id = TextEditingController();    // email OR 10-digit mobile number
  final _name = TextEditingController();
  final _extra = TextEditingController(); // mobile number, asked only when signing up with an email
  final _code = TextEditingController();
  DateTime? _dob;
  String? _gender;
  String _step = 'id'; // id | register | otp
  String _mode = 'login'; // login | register
  String? _hint;
  String? _error;
  bool _busy = false;

  String get _idText => _id.text.trim();
  bool get _idIsEmail => _idText.contains('@');
  /// Digits of the typed number, with a leading +91 / 91 / 0 stripped so a user
  /// who types their country code or a trunk zero still resolves to 10 digits.
  String get _idDigits {
    var d = _idText.replaceAll(RegExp(r'\D'), '');
    if (d.length == 12 && d.startsWith('91')) {
      d = d.substring(2);
    } else if (d.length == 11 && d.startsWith('0')) {
      d = d.substring(1);
    }
    return d;
  }
  bool get _idIsPhone => !_idIsEmail && _idDigits.length == 10;
  bool get _idValid => _idIsEmail
      ? RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_idText)
      : _idIsPhone;

  /// Value sent to the API: normalised (lowercased) email or 10-digit phone.
  String get _identifier => _idIsEmail ? _idText.toLowerCase() : _idDigits;

  String get _extraDigits => _extra.text.replaceAll(RegExp(r'\D'), '');

  /// Registration needs a phone: the typed one (mobile signup) or the extra field (email signup).
  String get _regPhone => _idIsEmail ? _extraDigits : _idDigits;
  bool get _registerValid => _name.text.trim().isNotEmpty && _regPhone.length == 10 && _dob != null && _gender != null;

  void _set(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  /// Step 1: request a login OTP. If no account exists, switch to the register step.
  Future<void> _startLogin() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.requestLoginOtp(_identifier);
      _set(() {
        _busy = false;
        _step = 'otp';
        _mode = 'login';
        _hint = _idIsEmail ? 'OTP sent to your email' : 'OTP sent to your mobile number';
        _code.clear();
      });
    } on ApiException catch (e) {
      if (e.code == 'NOT_FOUND') {
        _set(() {
          _busy = false;
          _step = 'register';
          _error = null;
        });
      } else {
        _set(() {
          _busy = false;
          _error = e.message;
        });
      }
    } catch (_) {
      _set(() {
        _busy = false;
        _error = 'Network error. Please try again.';
      });
    }
  }

  /// Step 1b (new users): register, which sends a verification OTP.
  Future<void> _startRegister() async {
    if (_name.text.trim().isEmpty) {
      _set(() => _error = 'Enter your name');
      return;
    }
    if (_regPhone.length != 10) {
      _set(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    if (_dob == null) {
      _set(() => _error = 'Select your date of birth');
      return;
    }
    if (_gender == null) {
      _set(() => _error = 'Select your gender');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.register(
        fullName: _name.text.trim(),
        phone: _regPhone,
        email: _idIsEmail ? _idText.toLowerCase() : null,
        dateOfBirth: _dob,
        gender: _gender,
      );
      _set(() {
        _busy = false;
        _step = 'otp';
        _mode = 'register';
        _hint = _idIsEmail ? 'OTP sent to $_idText' : 'OTP sent to your mobile number';
        _code.clear();
      });
    } on ApiException catch (e) {
      _set(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      _set(() {
        _busy = false;
        _error = 'Network error. Please try again.';
      });
    }
  }

  /// Step 2: verify the OTP (login or register) and store the session token.
  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = _mode == 'register'
          ? await Api.verifyRegisterOtp(_identifier, _code.text.trim())
          : await Api.loginVerify(_identifier, _code.text.trim());
      if (data['requiresAccountSelection'] == true) {
        final accounts = (data['accounts'] as List?) ?? [];
        if (accounts.isEmpty) {
          _set(() {
            _busy = false;
            _error = 'No account found for this number.';
          });
          return;
        }
        // Let the user choose which account (never auto-pick the first one).
        final userId = accounts.length == 1
            ? accounts.first['userId'].toString()
            : await _pickAccount(accounts);
        if (userId == null) {
          _set(() => _busy = false); // user dismissed the picker
          return;
        }
        final picked = await Api.selectAccount(
          (data['phone'] ?? _identifier).toString(),
          userId,
        );
        await _finish(picked);
        return;
      }
      await _finish(data);
    } on ApiException catch (e) {
      _set(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      _set(() {
        _busy = false;
        _error = 'Network error. Please try again.';
      });
    }
  }

  /// When a phone number is linked to more than one account, ask which to use.
  /// Returns the chosen userId, or null if the user dismisses the sheet.
  Future<String?> _pickAccount(List<dynamic> accounts) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: Text('Choose an account', style: T.h2)),
              const SizedBox(height: 6),
              const Center(
                child: Text('This number is linked to more than one account.',
                    textAlign: TextAlign.center, style: T.caption),
              ),
              const SizedBox(height: AppSpacing.lg),
              ...accounts.map((a) {
                final m = Map<String, dynamic>.from(a as Map);
                final name = (m['fullName'] ?? 'Account').toString();
                final sub = [m['companyName'], m['role']]
                    .where((x) => x != null && '$x'.isNotEmpty)
                    .join(' · ');
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: InkWell(
                    onTap: () => Navigator.pop(context, m['userId'].toString()),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w600)),
                              if (sub.isNotEmpty) Text(sub, style: T.caption),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: AppColors.textFaint),
                      ]),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finish(Map<String, dynamic> data) async {
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      _set(() {
        _busy = false;
        _error = 'Login failed. Please try again.';
      });
      return;
    }
    final phone = _regPhone.isNotEmpty ? _regPhone : (data['phone']?.toString() ?? '');
    await AuthState.instance.login(AppUser(
      email: _idIsEmail ? _idText.toLowerCase() : data['email']?.toString(),
      name: (data['fullName'] ?? (_idIsEmail ? _idText.split('@').first : 'Player')).toString(),
      phone: phone.isEmpty ? null : phone,
      gender: _gender,
      dob: _dob?.toIso8601String(),
      token: token,
      role: data['role']?.toString(),
      companyName: data['companyName']?.toString(),
    ));
  }

  Future<void> _resend() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_mode == 'register') {
        await Api.register(
          fullName: _name.text.trim(),
          phone: _regPhone,
          email: _idIsEmail ? _idText.toLowerCase() : null,
          dateOfBirth: _dob,
          gender: _gender,
        );
      } else {
        await Api.resendLoginOtp(_identifier);
      }
      _set(() {
        _busy = false;
        _hint = 'A new OTP has been sent';
      });
    } catch (_) {
      _set(() {
        _busy = false;
        _error = 'Could not resend. Try again.';
      });
    }
  }

  Future<void> _guest() async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => const _GuestDialog(),
    );
    if (res == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final dob = res['dob'] as DateTime?;
      final data = await Api.guestSession(
        fullName: res['name'] as String,
        phone: res['phone'] as String,
        dateOfBirth: dob,
        gender: res['gender'] as String?,
      );
      await AuthState.instance.login(AppUser(
        isGuest: true,
        name: res['name'] as String?,
        phone: res['phone'] as String?,
        gender: res['gender'] as String?,
        dob: dob?.toIso8601String(),
        token: data['token']?.toString(),
        guestSessionId: data['guestSessionId']?.toString(),
      ));
    } on ApiException catch (e) {
      _set(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      _set(() {
        _busy = false;
        _error = 'Could not start guest session.';
      });
    }
  }

  /// Opens a dark-themed date picker for the registration date of birth.
  Future<void> _pickDob() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'SELECT YOUR DATE OF BIRTH',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.primary,
            onPrimary: AppColors.textOnAccent,
            surface: AppColors.surface,
            onSurface: AppColors.text,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) _set(() { _dob = picked; _error = null; });
  }

  /// Tappable date-of-birth field, styled to match [AppField].
  Widget _dobField() {
    final d = _dob;
    final label = d == null
        ? 'Date of birth'
        : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    return GestureDetector(
      onTap: _busy ? null : _pickDob,
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
          Text(label, style: TextStyle(color: d == null ? AppColors.textFaint : AppColors.text, fontSize: 15)),
          const Spacer(),
          const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textFaint),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxxl),
          const Center(child: BrandMark(size: 120)),
          const SizedBox(height: AppSpacing.lg),
          const Center(
            child: Text('STRIKIN',
                style: TextStyle(color: AppColors.text, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 6)),
          ),
          const SizedBox(height: 6),
          const Center(child: Text('Book activities. Earn rewards. Play more.', style: T.caption)),
          const SizedBox(height: AppSpacing.xxxl),

          if (_step == 'id') ...[
            const Text('EMAIL OR MOBILE NUMBER', style: T.label),
            const SizedBox(height: AppSpacing.sm),
            AppField(icon: Icons.person_outline, hint: 'you@email.com or 10-digit mobile', controller: _id, autofocus: true, keyboardType: TextInputType.emailAddress, inputFormatters: [_PhoneOrEmailFormatter()], onChanged: (_) => setState(() {})),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ErrorText(_error!),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton('Continue', loading: _busy, onPressed: _idValid ? _startLogin : null),
          ] else if (_step == 'register') ...[
            const Text('CREATE YOUR ACCOUNT', style: T.label),
            const SizedBox(height: 4),
            Text('No account yet for $_idText — just a couple of details to get started.', style: T.caption),
            const SizedBox(height: AppSpacing.md),
            AppField(icon: Icons.person_outline, hint: 'Full name', controller: _name, onChanged: (_) => setState(() {})),
            const SizedBox(height: AppSpacing.md),
            if (_idIsEmail) ...[
              AppField(icon: Icons.call_outlined, hint: 'Mobile number (10 digits)', controller: _extra, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)], onChanged: (_) => setState(() {})),
              const SizedBox(height: AppSpacing.md),
            ],
            _dobField(),
            const SizedBox(height: AppSpacing.md),
            const Text('GENDER', style: T.label),
            const SizedBox(height: AppSpacing.sm),
            GenderSelector(value: _gender, onChanged: (v) => setState(() => _gender = v)),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ErrorText(_error!),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton('Create account & send OTP', loading: _busy, onPressed: _registerValid ? _startRegister : null),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: () => setState(() { _step = 'id'; _error = null; }),
                child: const Text('Use a different email or number', style: T.caption),
              ),
            ),
          ] else ...[
            const Center(child: Text('ENTER THE 6-DIGIT CODE', style: T.label)),
            const SizedBox(height: 4),
            Center(child: Text('Sent to $_identifier', style: T.caption)),
            const SizedBox(height: AppSpacing.lg),
            OtpInput(controller: _code, onChanged: (_) => setState(() {})),
            if (_hint != null) ...[
              const SizedBox(height: AppSpacing.md),
              Center(child: Text(_hint!, style: TextStyle(color: AppColors.primary, fontSize: 13))),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ErrorText(_error!),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton('Verify & continue', loading: _busy, onPressed: _code.text.length == 6 ? _verify : null),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: _busy ? null : _resend,
                child: const Text('Resend code', style: T.caption),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => setState(() { _step = 'id'; _hint = null; _error = null; }),
                child: const Text('Change email or number', style: T.caption),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xxl),
          Row(children: const [
            Expanded(child: Divider(color: AppColors.border)),
            Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.md), child: Text('or', style: T.caption)),
            Expanded(child: Divider(color: AppColors.border)),
          ]),
          const SizedBox(height: AppSpacing.xl),
          AppButton('Continue as guest', variant: 'secondary', onPressed: _guest),
          const SizedBox(height: AppSpacing.xxl),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen())),
            child: const Text.rich(
              TextSpan(children: [
                TextSpan(text: 'By continuing you agree to our '),
                TextSpan(text: 'Terms & Conditions', style: TextStyle(color: AppColors.textMuted, decoration: TextDecoration.underline)),
                TextSpan(text: ' and Privacy Policy. A mobile number is required to complete a booking.'),
              ]),
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textFaint, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Inline error message shown under a form field.
class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText(this.message);
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: Color(0xFFE5484D)),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFE5484D), fontSize: 13))),
        ],
      );
}

/// Collects a name + phone to start a guest session (the backend requires both).
class _GuestDialog extends StatefulWidget {
  const _GuestDialog();
  @override
  State<_GuestDialog> createState() => _GuestDialogState();
}

class _GuestDialogState extends State<_GuestDialog> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  String? _gender;
  DateTime? _dob;
  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _phone.text.replaceAll(RegExp(r'\D'), '').length == 10 &&
      _gender != null &&
      _dob != null;

  @override
  Widget build(BuildContext context) {
    final bottomInset = bottomSafePad(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
        bottom: AppSpacing.lg + bottomInset,
      ),
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
          const Center(child: Text('Continue as guest', style: T.h2)),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'Enter your details to continue booking as a guest.',
              textAlign: TextAlign.center,
              style: T.caption,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppField(icon: Icons.person_outline, hint: 'Full name', controller: _name, onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpacing.md),
          AppField(icon: Icons.call_outlined, hint: 'Mobile number (10 digits)', controller: _phone, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)], onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpacing.md),
          DobField(value: _dob, onTap: () async {
            final picked = await pickDob(context, _dob);
            if (picked != null) setState(() => _dob = picked);
          }),
          const SizedBox(height: AppSpacing.md),
          const Text('GENDER', style: T.label),
          const SizedBox(height: AppSpacing.sm),
          GenderSelector(value: _gender, onChanged: (v) => setState(() => _gender = v)),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            'Continue',
            onPressed: _valid
                ? () => Navigator.pop(context, {
                      'name': _name.text.trim(),
                      'phone': _phone.text.replaceAll(RegExp(r'\D'), ''),
                      'gender': _gender,
                      'dob': _dob,
                    })
                : null,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

/// For the dual email-or-mobile field: while the user is typing a phone number
/// (no '@' and no letters), strip everything except digits — so "7075-098792"
/// or "70750 98792" becomes "7075098792". Emails are left untouched (dashes and
/// dots are valid there).
class _PhoneOrEmailFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    if (text.contains('@') || RegExp(r'[a-zA-Z]').hasMatch(text)) return newValue;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits == text) return newValue;
    return TextEditingValue(text: digits, selection: TextSelection.collapsed(offset: digits.length));
  }
}

/// Six separate OTP boxes that fill as the user types. A transparent text field
/// overlays the boxes to capture input.
class OtpInput extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int length;
  const OtpInput({super.key, required this.controller, required this.onChanged, this.length = 6});

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centered group of fixed-size boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(widget.length, (i) {
              final filled = i < code.length;
              final isCurrent = i == code.length && _focus.hasFocus;
              return Container(
                width: 46,
                height: 56,
                margin: EdgeInsets.only(right: i == widget.length - 1 ? 0 : AppSpacing.sm),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: isCurrent ? AppColors.primary : (filled ? AppColors.textMuted : AppColors.border),
                    width: isCurrent ? 2 : 1,
                  ),
                ),
                child: Text(filled ? code[i] : '',
                    style: const TextStyle(color: AppColors.text, fontSize: 22, fontWeight: FontWeight.w700)),
              );
            }),
          ),
          // Transparent input on top to capture typing
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: widget.length,
                showCursor: false,
                onChanged: (v) {
                  widget.onChanged(v);
                  setState(() {});
                },
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
