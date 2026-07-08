import 'package:flutter/material.dart';
import '../api.dart';
import '../auth.dart';
import '../theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  String _step = 'email'; // email | register | otp
  String _mode = 'login'; // login | register
  String? _hint;
  String? _error;
  bool _busy = false;

  bool get _emailValid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text);
  bool get _phoneValid => _phone.text.replaceAll(RegExp(r'\D'), '').length == 10;
  String get _phoneDigits => _phone.text.replaceAll(RegExp(r'\D'), '');

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
      await Api.requestLoginOtp(_email.text.trim());
      _set(() {
        _busy = false;
        _step = 'otp';
        _mode = 'login';
        _hint = 'OTP sent to your email';
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
    if (!_phoneValid) {
      _set(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.register(fullName: _name.text.trim(), phone: _phoneDigits, email: _email.text.trim());
      _set(() {
        _busy = false;
        _step = 'otp';
        _mode = 'register';
        _hint = 'OTP sent to ${_email.text.trim()}';
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
          ? await Api.verifyRegisterOtp(_email.text.trim(), _code.text.trim())
          : await Api.loginVerify(_email.text.trim(), _code.text.trim());
      if (data['requiresAccountSelection'] == true) {
        final accounts = (data['accounts'] as List?) ?? [];
        if (accounts.isNotEmpty) {
          final picked = await Api.selectAccount(
            (data['phone'] ?? '').toString(),
            accounts.first['userId'].toString(),
          );
          await _finish(picked);
          return;
        }
        _set(() {
          _busy = false;
          _error = 'Multiple accounts found for this number. Please use the web app.';
        });
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

  Future<void> _finish(Map<String, dynamic> data) async {
    final token = data['token']?.toString();
    if (token == null || token.isEmpty) {
      _set(() {
        _busy = false;
        _error = 'Login failed. Please try again.';
      });
      return;
    }
    await AuthState.instance.login(AppUser(
      email: _email.text.trim(),
      name: (data['fullName'] ?? _email.text.split('@').first).toString(),
      phone: _phoneDigits.isEmpty ? null : _phoneDigits,
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
        await Api.register(fullName: _name.text.trim(), phone: _phoneDigits, email: _email.text.trim());
      } else {
        await Api.resendLoginOtp(_email.text.trim());
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
    final res = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _GuestDialog(),
    );
    if (res == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await Api.guestSession(fullName: res['name']!, phone: res['phone']!);
      await AuthState.instance.login(AppUser(
        isGuest: true,
        name: res['name'],
        phone: res['phone'],
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

          if (_step == 'email') ...[
            const Text('EMAIL ADDRESS', style: T.label),
            const SizedBox(height: AppSpacing.sm),
            AppField(icon: Icons.mail_outline, hint: 'you@email.com', controller: _email, autofocus: true, keyboardType: TextInputType.emailAddress, onChanged: (_) => setState(() {})),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ErrorText(_error!),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton('Continue', loading: _busy, onPressed: _emailValid ? _startLogin : null),
          ] else if (_step == 'register') ...[
            const Text('CREATE YOUR ACCOUNT', style: T.label),
            const SizedBox(height: 4),
            Text('No account yet for ${_email.text.trim()} — just a couple of details to get started.', style: T.caption),
            const SizedBox(height: AppSpacing.md),
            AppField(icon: Icons.person_outline, hint: 'Full name', controller: _name, onChanged: (_) => setState(() {})),
            const SizedBox(height: AppSpacing.md),
            AppField(icon: Icons.call_outlined, hint: 'Mobile number (10 digits)', controller: _phone, keyboardType: TextInputType.phone, onChanged: (_) => setState(() {})),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              _ErrorText(_error!),
            ],
            const SizedBox(height: AppSpacing.xl),
            AppButton('Create account & send OTP', loading: _busy, onPressed: (_name.text.trim().isNotEmpty && _phoneValid) ? _startRegister : null),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: TextButton(
                onPressed: () => setState(() { _step = 'email'; _error = null; }),
                child: const Text('Use a different email', style: T.caption),
              ),
            ),
          ] else ...[
            const Center(child: Text('ENTER THE 6-DIGIT CODE', style: T.label)),
            const SizedBox(height: 4),
            Center(child: Text('Sent to ${_email.text.trim()}', style: T.caption)),
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
                onPressed: () => setState(() { _step = 'email'; _hint = null; _error = null; }),
                child: const Text('Change email', style: T.caption),
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
          const Text(
            'By continuing you agree to our Terms & Conditions and Privacy Policy. A mobile number is required to complete a booking.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textFaint, fontSize: 12),
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
  bool get _valid => _name.text.trim().isNotEmpty && _phone.text.replaceAll(RegExp(r'\D'), '').length == 10;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceAlt,
      title: const Text('Continue as guest', style: T.h3),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('A name and mobile number are needed to make a booking.', style: T.caption),
          const SizedBox(height: AppSpacing.md),
          AppField(icon: Icons.person_outline, hint: 'Full name', controller: _name, onChanged: (_) => setState(() {})),
          const SizedBox(height: AppSpacing.md),
          AppField(icon: Icons.call_outlined, hint: 'Mobile number (10 digits)', controller: _phone, keyboardType: TextInputType.phone, onChanged: (_) => setState(() {})),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: T.caption)),
        TextButton(
          onPressed: _valid
              ? () => Navigator.pop(context, {'name': _name.text.trim(), 'phone': _phone.text.replaceAll(RegExp(r'\D'), '')})
              : null,
          child: Text('Continue', style: TextStyle(color: _valid ? AppColors.primary : AppColors.textFaint)),
        ),
      ],
    );
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
