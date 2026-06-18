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
  final _code = TextEditingController();
  String _step = 'email';
  String? _hint;
  bool _busy = false;

  bool get _emailValid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text);

  Future<void> _sendOtp() async {
    setState(() => _busy = true);
    final res = await Api.requestOtp(_email.text.trim());
    setState(() {
      _busy = false;
      _step = 'otp';
      _hint = res['debug_code'] != null ? 'Dev OTP: ${res['debug_code']}' : 'OTP sent to your email & phone';
    });
  }

  Future<void> _verify() async {
    setState(() => _busy = true);
    final ok = await Api.verifyOtp(_email.text.trim(), _code.text.trim());
    setState(() => _busy = false);
    if (!ok) {
      setState(() => _hint = 'Invalid code — please try again');
      return;
    }
    await AuthState.instance.login(AppUser(email: _email.text.trim(), name: _email.text.split('@').first));
  }

  Future<void> _guest() => AuthState.instance.login(AppUser(isGuest: true, name: 'Guest'));

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
            const SizedBox(height: AppSpacing.xl),
            AppButton('Send OTP', loading: _busy, onPressed: _emailValid ? _sendOtp : null),
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
            const SizedBox(height: AppSpacing.xl),
            AppButton('Verify & continue', loading: _busy, onPressed: _code.text.length == 6 ? _verify : null),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: TextButton(
                onPressed: () => setState(() { _step = 'email'; _hint = null; }),
                child: const Text('Change email / resend', style: T.caption),
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
