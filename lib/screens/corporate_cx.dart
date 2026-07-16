import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../api.dart';
import '../app_image.dart';
import '../app_nav.dart';
import '../auth.dart';
import '../models.dart';
import '../razorpay_checkout.dart';
import '../store.dart';
import 'terms.dart';
import 'activity_booking.dart';
import 'bookings.dart';
import 'shows.dart';

// ── 0. Corporate landing (entry) — hero + Sign Up / Get in touch + How it works + FAQ ──

class CxLandingScreen extends StatefulWidget {
  const CxLandingScreen({super.key});
  @override
  State<CxLandingScreen> createState() => _CxLandingScreenState();
}

class _CxLandingScreenState extends State<CxLandingScreen> {
  int _faqOpen = -1;

  @override
  void initState() {
    super.initState();
    // A returning corporate user goes straight to their role dashboard (the
    // Home/Team/Bookings/Settings shell), not the signup page or setup wizard.
    if (AuthState.instance.user?.isCorporate ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          settings: const RouteSettings(name: 'cx_shell'),
          builder: (_) => const CxCorporateShell(),
        ));
      });
    }
  }

  final _faqs = const [
    ['What types of corporate events can Strikin host?',
     'Strikin is equipped to host a variety of corporate events, including team-building activities, company outings, tournaments, and corporate parties. Our flexible spaces can be customized to suit different event formats and sizes.'],
    ['What is the maximum capacity for corporate events?',
     'Capacity depends on the activity and space. Contact us with your group size and we will recommend the best option.'],
    ['How far in advance should I book my corporate event?',
     'We recommend booking at least 1–2 weeks ahead for large groups, though we can often accommodate shorter notice.'],
  ];

  Widget _howCard(IconData icon, String label) => Expanded(
        child: Container(
          height: 98,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: const Color(0xFF262626), borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 26),
              const SizedBox(height: 12),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      );

  // A "Corporate Benefits" row: lime icon in a rounded square + title + description.
  Widget _benefit(IconData icon, String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: 22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: const Color(0xFF262626), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: _lime, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(body, style: const TextStyle(color: _muted, fontSize: 14, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Hero — the clean design photo + real (tappable) heading & buttons on top.
          Container(color: _bg, height: MediaQuery.of(context).padding.top),
          AspectRatio(
            aspectRatio: 390 / 511,
            child: LayoutBuilder(
              builder: (context, cons) {
                final w = cons.maxWidth, h = cons.maxHeight;
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/corporate_hero.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF2C4522), Color(0xFF141B10), Color(0xFF1A1A1A)]),
                        ),
                      ),
                    ),
                    // top fade (under the status bar / back arrow) + bottom fade into the page
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: h * 0.16,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xCC1A1A1A), Colors.transparent]),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: h * 0.22,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xFF1A1A1A)]),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 4,
                      top: 2,
                      child: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.of(context).maybePop()),
                    ),
                    Positioned(
                      left: w * 0.041,
                      top: h * 0.231,
                      width: w * 0.66,
                      child: const Text(
                        'Take Your\nTeam Out to\nPlay',
                        style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, height: 1.18,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 12)]),
                      ),
                    ),
                    Positioned(
                      left: w * 0.041,
                      top: h * 0.579,
                      width: w * 0.42,
                      height: h * 0.094,
                      child: _pill('Sign Up', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxCompanyDetailsScreen()))),
                    ),
                    Positioned(
                      left: w * 0.041,
                      top: h * 0.705,
                      width: w * 0.42,
                      height: h * 0.094,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxGetInTouchScreen())),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xCC212222),
                          side: const BorderSide(color: _lime, width: 2),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: const Text('Get in touch', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Corporate Benefits', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 18),
                _benefit(Icons.percent, 'Corporate Discounts', 'Enjoy special discounts on our curated food and beverage menus for corporate groups.'),
                _benefit(Icons.inventory_2_outlined, 'Custom Packages', 'Tailor your event with custom packages that include gameplay, food, and beverages.'),
                _benefit(Icons.attach_money, 'Team Budget', "Set a budget for your team's event and track expenses in real-time."),
                const SizedBox(height: 6),
                const Text('How it works', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                // Informational only — these do not navigate.
                Row(children: [
                  _howCard(Icons.groups_outlined, 'Add team'),
                  _howCard(Icons.account_balance_wallet_outlined, 'Set budget'),
                  _howCard(Icons.calendar_month_outlined, 'Start booking'),
                ]),
                const SizedBox(height: 30),
                const Text('Frequently asked questions', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                ...List.generate(_faqs.length, (i) {
                  final open = _faqOpen == i;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: const Color(0xFF262626), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFF484848))),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _faqOpen = open ? -1 : i),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(children: [
                              Expanded(child: Text(_faqs[i][0], style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3))),
                              const SizedBox(width: 10),
                              Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white),
                            ]),
                          ),
                        ),
                        if (open) Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Text(_faqs[i][1], style: const TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Get in touch (enquiry / request form) ────────────────────────────────────

class CxGetInTouchScreen extends StatefulWidget {
  const CxGetInTouchScreen({super.key});
  @override
  State<CxGetInTouchScreen> createState() => _CxGetInTouchScreenState();
}

class _CxGetInTouchScreenState extends State<CxGetInTouchScreen> {
  final _company = TextEditingController(), _name = TextEditingController(), _job = TextEditingController();
  final _email = TextEditingController(), _phone = TextEditingController(), _notes = TextEditingController();
  int _size = 1; // 0:1-10, 1:11-50, 2:51-200
  final _sizes = const ['1–10 employees', '11–50 employees', '51–200 employees'];

  Widget _sizeChip(int i) {
    final sel = _size == i;
    return GestureDetector(
      onTap: () => setState(() => _size = i),
      child: Container(
        margin: const EdgeInsets.only(right: 10, bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? Colors.transparent : _field,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: sel ? _lime : Colors.transparent, width: 1.5),
        ),
        child: Text(_sizes[i], style: TextStyle(color: sel ? _lime : Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(title: 'Get in touch'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                children: [
                  const Text('Enter your details', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  _field2('Company name', 'Enter company name', _company),
                  const SizedBox(height: 20),
                  const Text('Company size', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Wrap(children: [for (int i = 0; i < 3; i++) _sizeChip(i)]),
                  const SizedBox(height: 14),
                  _field2('Contact person name', 'Enter your name', _name),
                  const SizedBox(height: 20),
                  _field2('Job title', 'Enter your job title', _job),
                  const SizedBox(height: 20),
                  _field2('Email', 'Enter your email', _email, kb: TextInputType.emailAddress),
                  const SizedBox(height: 20),
                  _field2('Phone', 'Enter your phone number', _phone, kb: TextInputType.phone),
                  const SizedBox(height: 20),
                  const Text('Additional notes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notes,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Enter your message',
                      hintStyle: const TextStyle(color: _placeholder, fontSize: 15),
                      filled: true,
                      fillColor: _field,
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
              child: Column(
                children: [
                  const Text('By sending this request, I agree to be contacted by Strikin regarding my enquiry',
                      style: TextStyle(color: _muted, fontSize: 13, height: 1.35)),
                  const SizedBox(height: 12),
                  _pill('Send request', () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const CxAckScreen(message: "Thanks for reaching out!\nOur team will contact you shortly\nwith the next steps.")))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Acknowledgement (reusable: account created / request sent) ───────────────

class CxAckScreen extends StatelessWidget {
  final String message;
  final String? nextLabel;
  final WidgetBuilder? next;
  final String? nextRouteName;
  const CxAckScreen({super.key, required this.message, this.nextLabel, this.next, this.nextRouteName});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 44),
            decoration: BoxDecoration(color: const Color(0xFF262626), borderRadius: BorderRadius.circular(16)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(color: Color(0xFF6FCF63), shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Color(0xFF12330C), size: 26),
                ),
                const SizedBox(height: 22),
                Text(message, textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700, height: 1.35)),
                const SizedBox(height: 22),
                if (next != null) ...[
                  _pill(nextLabel ?? 'Continue',
                      () => Navigator.of(context).push(MaterialPageRoute(
                            settings: nextRouteName == null ? null : RouteSettings(name: nextRouteName),
                            builder: next!,
                          ))),
                  const SizedBox(height: 16),
                ],
                GestureDetector(
                  onTap: () => Navigator.of(context).popUntil((r) => r.settings.name == 'cx_dashboard' || r.isFirst),
                  child: const Text('Back to home',
                      style: TextStyle(color: _muted, fontSize: 15, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Corporate CX — screens rebuilt exactly from the Figma (dark + lime). ──────
// UI-first (no backend wired yet). Colours/spacing match the design tokens.

const _bg = Color(0xFF141414);
const _field = Color(0xFF2C2C2C);
const _card = Color(0xFF1F1F1F);
const _cardBorder = Color(0xFF2E2E2E);
const _lime = Color(0xFFD7FD32);
const _muted = Color(0xFF9A9A9A);
const _placeholder = Color(0xFF6E6E6E);
const _secondary = Color(0xFFD9D9D9);

// ── shared bits ──────────────────────────────────────────────────────────────

PreferredSizeWidget _appBar({String title = 'Strikin', bool profile = false}) => AppBar(
      backgroundColor: _bg,
      elevation: 0,
      centerTitle: true,
      leading: const BackButton(color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
      actions: profile
          ? const [Padding(padding: EdgeInsets.only(right: 16), child: Icon(Icons.person_outline, color: Colors.white))]
          : null,
    );

Widget _stepBar(int step, int total) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Step $step of $total', style: const TextStyle(color: _muted, fontSize: 14)),
        const SizedBox(height: 10),
        Row(
          children: [
            for (int i = 0; i < total; i++) ...[
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: i < step ? _lime : const Color(0xFF333333),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              if (i < total - 1) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );

Widget _field2(String label, String hint, TextEditingController c, {TextInputType? kb}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextField(
          controller: c,
          keyboardType: kb,
          style: const TextStyle(color: Colors.white, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _placeholder, fontSize: 15),
            filled: true,
            fillColor: _field,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );

Widget _pill(String text, VoidCallback? onTap) => SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _lime,
          disabledBackgroundColor: const Color(0xFF3A3A2A),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        child: Text(text, style: const TextStyle(color: Color(0xFF141414), fontSize: 16, fontWeight: FontWeight.w800)),
      ),
    );

Widget _greyPill(String text, VoidCallback? onTap) => SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _secondary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
        ),
        child: Text(text, style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 15, fontWeight: FontWeight.w700)),
      ),
    );

// ── 1. Company details (Step 1 of 2) ─────────────────────────────────────────

class CxCompanyDetailsScreen extends StatefulWidget {
  const CxCompanyDetailsScreen({super.key});
  @override
  State<CxCompanyDetailsScreen> createState() => _CxCompanyDetailsScreenState();
}

class _CxCompanyDetailsScreenState extends State<CxCompanyDetailsScreen> {
  final _name = TextEditingController(), _pan = TextEditingController(), _gst = TextEditingController();
  bool _busy = false;

  void _snack(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  // Validate the company name + PAN format, and check the PAN isn't already registered.
  Future<void> _next() async {
    final name = _name.text.trim();
    final pan = _pan.text.trim().toUpperCase();
    if (name.isEmpty) {
      _snack('Enter your company name.');
      return;
    }
    if (!RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
      _snack('Enter a valid PAN number (e.g. ABCDE1234F).');
      return;
    }
    setState(() => _busy = true);
    try {
      final res = await Api.corporateCheckPan(pan);
      if (res['exists'] == true) {
        _snack((res['message'] ?? 'A company with this PAN is already registered.').toString());
        return;
      }
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CxSuperAdminScreen(company: {
                'name': name,
                'panNumber': pan,
                if (_gst.text.trim().isNotEmpty) 'gstNumber': _gst.text.trim().toUpperCase(),
                'size': 'SIZE_11_50',
              })));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepBar(1, 2),
              const SizedBox(height: 26),
              const Text('Company details', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 26),
              Expanded(
                child: ListView(
                  children: [
                    _field2('Company Name', 'Enter company name', _name),
                    const SizedBox(height: 22),
                    _field2('Company PAN number', 'Enter PAN number', _pan),
                    const SizedBox(height: 22),
                    _field2('GST (optional)', 'Enter GST number', _gst),
                  ],
                ),
              ),
              _pill(_busy ? 'Checking…' : 'Continue', _busy ? null : _next),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 2. Super admin (Step 2 of 2) + verification sheet ────────────────────────

class CxSuperAdminScreen extends StatefulWidget {
  final Map<String, dynamic> company;
  const CxSuperAdminScreen({super.key, required this.company});
  @override
  State<CxSuperAdminScreen> createState() => _CxSuperAdminScreenState();
}

class _CxSuperAdminScreenState extends State<CxSuperAdminScreen> {
  final _name = TextEditingController(), _job = TextEditingController(), _email = TextEditingController(), _phone = TextEditingController();
  bool _busy = false;

  Map<String, dynamic> get _admin => {
        'fullName': _name.text.trim(),
        if (_job.text.trim().isNotEmpty) 'jobTitle': _job.text.trim(),
        'workEmail': _email.text.trim(),
        'phone': _phone.text.trim(),
      };

  // Step 1: validate + send the OTP to the work email, then open the code sheet.
  Future<void> _sendOtp() async {
    final email = _email.text.trim();
    final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter your full name.')));
      return;
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid work email (e.g. name@company.com).')));
      return;
    }
    if (digits.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid 10-digit phone number.')));
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.corporateSignupSendOtp(company: widget.company, admin: _admin);
      if (mounted) _verify();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send the code. Please try again.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _verify() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        final code = TextEditingController();
        var busy = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 14, bottom: MediaQuery.of(ctx).viewInsets.bottom + 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 18),
                const Center(child: Text('Enter verification code', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
                const SizedBox(height: 16),
                const Text("We've sent a verification code to your work email. Please check your inbox (and spam/junk folder if you don't see it right away), then enter the code below to verify",
                    style: TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                const SizedBox(height: 18),
                _field2('Verification code', 'Enter code', code),
                const SizedBox(height: 16),
                _pill(busy ? 'Verifying…' : 'Submit', busy
                    ? null
                    : () async {
                        if (code.text.trim().isEmpty) return;
                        setSheet(() => busy = true);
                        try {
                          final res = await Api.corporateSignupVerify(otp: code.text.trim(), company: widget.company, admin: _admin);
                          final token = res['token']?.toString();
                          if (token != null && token.isNotEmpty) {
                            await AuthState.instance.login(AppUser(
                              email: _email.text.trim(),
                              name: (res['fullName'] ?? _name.text.trim()).toString(),
                              phone: _phone.text.trim(),
                              token: token,
                              role: (res['role'] ?? 'super_admin').toString(),
                              companyName: (res['companyName'] ?? widget.company['name'])?.toString(),
                            ));
                          }
                          if (!ctx.mounted || !mounted) return;
                          Navigator.pop(ctx);
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => CxAckScreen(
                                    message: 'Your corporate account has been\ncreated.',
                                    nextLabel: 'Get started',
                                    nextRouteName: 'cx_dashboard',
                                    next: (_) => const CxDashboardScreen(),
                                  )));
                        } on ApiException catch (e) {
                          setSheet(() => busy = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                        } catch (_) {
                          setSheet(() => busy = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Could not verify. Please try again.')));
                        }
                      }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stepBar(2, 2),
              const SizedBox(height: 26),
              const Text('Super admin', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 26),
              Expanded(
                child: ListView(
                  children: [
                    _field2('Full Name', 'Enter full name', _name),
                    const SizedBox(height: 22),
                    _field2('Job title', 'Enter job title', _job),
                    const SizedBox(height: 22),
                    _field2('Work Email', 'Enter email id', _email, kb: TextInputType.emailAddress),
                    const SizedBox(height: 22),
                    _field2('Phone number', 'Enter phone number', _phone, kb: TextInputType.phone),
                  ],
                ),
              ),
              _pill(_busy ? 'Sending…' : 'Continue', _busy ? null : _sendOtp),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 3. Team setup (CSV / Invite link accordion) ──────────────────────────────

class CxTeamSetupScreen extends StatefulWidget {
  const CxTeamSetupScreen({super.key});
  @override
  State<CxTeamSetupScreen> createState() => _CxTeamSetupScreenState();
}

class _CxTeamSetupScreenState extends State<CxTeamSetupScreen> {
  int _open = -1; // -1 none, 0 csv, 1 invite
  String? _csvName;
  List<Map<String, dynamic>> _parsed = [];
  bool _busy = false;

  String? _inviteLink;

  void _snack(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  // Generate a REAL company invite code and share the join link.
  Future<void> _shareInvite() async {
    setState(() => _busy = true);
    try {
      final res = await Api.corporateGenerateInvite();
      final web = (res['webLink'] ?? '').toString();
      final deep = (res['deepLink'] ?? res['inviteLink'] ?? '').toString();
      final code = (res['inviteCode'] ?? '').toString();
      // Prefer the web link — it opens in any browser (laptop or phone). The
      // strikin:// deep link only works on a phone that has the app installed.
      final link = web.isNotEmpty ? web : (deep.isNotEmpty ? deep : 'https://strikin.app/join?code=$code');
      if (mounted) setState(() => _inviteLink = link);
      await Share.share('Join our Strikin corporate team: $link');
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not create an invite link. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Pick a CSV, parse each row to {fullName, email, phone?, isTeamLead?}.
  Future<void> _pickCsv() async {
    final picked = await FilePicker.platform.pickFiles(withData: true, type: FileType.custom, allowedExtensions: ['csv']);
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    final lines = String.fromCharCodes(bytes).split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    final rows = <Map<String, dynamic>>[];
    for (var i = 0; i < lines.length; i++) {
      if (i == 0 && lines[i].toLowerCase().contains('email')) continue; // header row
      final cols = lines[i].split(',').map((c) => c.trim()).toList();
      final email = cols.firstWhere((c) => c.contains('@'), orElse: () => '');
      if (email.isEmpty) continue;
      final lead = cols.any((c) {
        final v = c.toLowerCase();
        return v == 'yes' || v == 'true' || v == 'lead' || v == 'team lead';
      });
      rows.add({
        'fullName': cols.isNotEmpty ? cols[0] : '',
        'email': email,
        if (cols.length > 2 && cols[2].isNotEmpty && !cols[2].contains('@')) 'phone': cols[2],
        if (lead) 'isTeamLead': true,
      });
    }
    if (rows.isEmpty) {
      _snack('No valid rows found — each row needs a name and email.');
      return;
    }
    setState(() {
      _csvName = f.name;
      _parsed = rows;
    });
  }

  Future<void> _submitCsv() async {
    if (_parsed.isEmpty) return;
    setState(() => _busy = true);
    try {
      final res = await Api.corporateAddMembers(_parsed);
      if (!mounted) return;
      _snack('${res['created'] ?? _parsed.length} member(s) added.');
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxTeamMembersScreen()));
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not add members. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _accordion(int i, String title, String subtitle, Widget? expanded) {
    final open = _open == i;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = open ? -1 : i),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(subtitle, style: const TextStyle(color: _muted, fontSize: 13, height: 1.35)),
                      ],
                    ),
                  ),
                  Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white),
                ],
              ),
            ),
          ),
          if (open && expanded != null) Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: expanded),
        ],
      ),
    );
  }

  // Generates the CSV template (Name · Position · Email) and opens the share
  // sheet so the user can save / send it, then fill it in and upload it back.
  Future<void> _downloadTemplate() async {
    const csv = 'Name,Position,Email\n'
        'Aarav Sharma,Manager,aarav@company.com\n'
        'Diya Patel,Executive,diya@company.com\n';
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(csv)),
      name: 'strikin-team-template.csv',
      mimeType: 'text/csv',
    );
    await Share.shareXFiles([file], text: 'Strikin — team members template. Columns: Name, Position, Email.');
  }

  Widget _csvBox() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _downloadTemplate,
              icon: const Icon(Icons.file_download_outlined, color: Colors.white, size: 20),
              label: const Text('Team members template',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _lime, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
            ),
          ),
          const SizedBox(height: 18),
          CustomPaint(
            painter: _DashedRRect(color: _placeholder),
            child: SizedBox(
              height: 96,
              width: double.infinity,
              child: Center(
                child: _csvName != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.insert_drive_file_outlined, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Flexible(child: Text(_csvName!, style: const TextStyle(color: Colors.white, fontSize: 15), overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      )
                    : GestureDetector(
                        onTap: _pickCsv,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          decoration: BoxDecoration(color: _secondary, borderRadius: BorderRadius.circular(24)),
                          child: const Text('+ Upload',
                              style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
              ),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(title: 'Team setup', profile: true),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Text("Choose how you'd like to add team members", style: TextStyle(color: _muted, fontSize: 14)),
                  const SizedBox(height: 18),
                  _accordion(0, 'CSV Upload', 'Download the template, fill in your team members, and upload it to add them all at once.', _csvBox()),
                  _accordion(1, 'Invite via link', 'Share this link to invite team members', Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(10)),
                        child: Text(_inviteLink ?? 'Tap "Share link" to generate an invite', style: const TextStyle(color: _placeholder, fontSize: 14), overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(height: 14),
                      _greyPill(_busy ? 'Generating…' : 'Share link', _busy ? null : _shareInvite),
                      const SizedBox(height: 10),
                      _greyPill('View team members', () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxTeamMembersScreen()))),
                    ],
                  )),
                ],
              ),
            ),
            if (_csvName != null && _open == 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: _pill(_busy ? 'Adding…' : 'Continue', _busy ? null : _submitCsv),
              ),
          ],
        ),
      ),
    );
  }
}

// Dashed rounded-rectangle border (CSV drop-zone) — no extra package needed.
class _DashedRRect extends CustomPainter {
  final Color color;
  _DashedRRect({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)));
    const dash = 6.0, gap = 5.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRect old) => old.color != color;
}

// ── 4. Team members (list + star team-lead + edit + delete) ──────────────────

class _Member {
  String id, name, email;
  bool lead;
  _Member(this.name, this.email, {this.lead = false, this.id = ''});
}

class CxTeamMembersScreen extends StatefulWidget {
  const CxTeamMembersScreen({super.key});
  @override
  State<CxTeamMembersScreen> createState() => _CxTeamMembersScreenState();
}

class _CxTeamMembersScreenState extends State<CxTeamMembersScreen> {
  final _members = <_Member>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.corporateMembers();
      final list = ((d['members'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _members
          ..clear()
          ..addAll(list.map((m) => _Member(
                (m['fullName'] ?? '').toString(),
                (m['email'] ?? '').toString(),
                lead: m['isTeamLead'] == true || (m['role'] ?? '').toString() == 'team_lead',
                id: (m['id'] ?? '').toString(),
              )));
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  // Star toggles Team Lead — optimistic, reverts if the backend rejects.
  Future<void> _toggleLead(_Member m) async {
    final next = !m.lead;
    setState(() => m.lead = next);
    final ok = await Api.corporateSetMemberRole(m.id, next ? 'team_lead' : 'member');
    if (!ok && mounted) {
      setState(() => m.lead = !next);
      _snack('Could not update role.');
    }
  }

  Future<void> _remove(_Member m) async {
    final idx = _members.indexOf(m);
    setState(() => _members.remove(m));
    final ok = await Api.corporateRemoveMember(m.id);
    if (!ok && mounted) {
      setState(() => _members.insert(idx < 0 ? 0 : idx, m));
      _snack('Could not remove member.');
    }
  }

  Future<void> _edit(_Member m) async {
    final name = TextEditingController(text: m.name);
    final email = TextEditingController(text: m.email);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 14, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Center(child: Text('Edit member', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
            const SizedBox(height: 18),
            _field2('Name', 'Name', name),
            const SizedBox(height: 18),
            _field2('Email', 'Email', email),
            const SizedBox(height: 16),
            _pill('Save', () { setState(() { m.name = name.text; m.email = email.text; }); Navigator.pop(ctx); }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(title: 'Team setup'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _lime))
                  : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                children: [
                  const Text('Team members', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text('Tap the star to mark a member as Team Lead. The Team Lead can be assigned a budget and is allowed to book any activity.',
                      style: TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 18),
                  if (_members.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text('No members yet — add them from Team setup (CSV or invite link).',
                          style: TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                    ),
                  ..._members.map((m) => Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => _toggleLead(m),
                              child: Icon(m.lead ? Icons.star : Icons.star_border, color: m.lead ? _lime : _muted, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text(m.email, style: const TextStyle(color: _muted, fontSize: 13)),
                                ],
                              ),
                            ),
                            IconButton(onPressed: () => _edit(m), icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20)),
                            IconButton(onPressed: () => _remove(m), icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: _pill('Done', () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const CxAckScreen(message: 'Team members added\nsuccessful')))),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 5. Payment plan ──────────────────────────────────────────────────────────

class CxPaymentPlanScreen extends StatefulWidget {
  const CxPaymentPlanScreen({super.key});
  @override
  State<CxPaymentPlanScreen> createState() => _CxPaymentPlanScreenState();
}

class _CxPaymentPlanScreenState extends State<CxPaymentPlanScreen> {
  int _sel = -1;
  final _custom = TextEditingController();
  final _plans = const [
    ['Starter', 'For small teams', '₹25,000'],
    ['Growth', 'For growing businesses', '₹1,00,000'],
    ['Enterprise', 'For large organisations', '₹5,00,000'],
    ['Custom amount', 'Add your own amount', ''],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(profile: true),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Payment plan', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 22),
              Expanded(
                child: ListView.builder(
                  itemCount: _plans.length,
                  itemBuilder: (c, i) {
                    final p = _plans[i];
                    final sel = _sel == i;
                    final isCustom = i == 3;
                    return GestureDetector(
                      onTap: () => setState(() => _sel = i),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sel ? _lime : _cardBorder, width: sel ? 1.5 : 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(sel ? Icons.check_circle : Icons.radio_button_off, color: sel ? _lime : _muted, size: 22),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p[0], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 4),
                                      Text(p[1], style: const TextStyle(color: _muted, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                if (p[2].isNotEmpty)
                                  Text(p[2], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800))
                                else if (isCustom && sel && _custom.text.trim().isNotEmpty)
                                  Text('₹${_custom.text.trim()}', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                              ],
                            ),
                            if (isCustom && sel) ...[
                              const SizedBox(height: 14),
                              TextField(
                                controller: _custom,
                                keyboardType: TextInputType.number,
                                onChanged: (_) => setState(() {}),
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                                decoration: InputDecoration(
                                  prefixText: '₹ ',
                                  prefixStyle: const TextStyle(color: _placeholder, fontSize: 15),
                                  hintText: 'Enter amount',
                                  hintStyle: const TextStyle(color: _placeholder, fontSize: 15),
                                  filled: true,
                                  fillColor: _field,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              _pill('Continue', _sel < 0
                  ? null
                  : () {
                      const planAmounts = [25000.0, 100000.0, 500000.0];
                      final amount = _sel < 3
                          ? planAmounts[_sel]
                          : (double.tryParse(_custom.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0);
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount.')));
                        return;
                      }
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CxFundPaymentScreen(amount: amount)));
                    }),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 6. Payment (activities + methods) ────────────────────────────────────────

class CxPaymentScreen extends StatefulWidget {
  const CxPaymentScreen({super.key});
  @override
  State<CxPaymentScreen> createState() => _CxPaymentScreenState();
}

class _CxPaymentScreenState extends State<CxPaymentScreen> {
  int _method = 0;

  Widget _activity(String name, String sub) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(sub, style: const TextStyle(color: _muted, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          ],
        ),
      );

  Widget _methodRow(int i, IconData icon, String title, {String? sub}) {
    final sel = _method == i;
    return GestureDetector(
      onTap: () => setState(() => _method = i),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sel ? _lime : _cardBorder, width: sel ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  if (sub != null) ...[const SizedBox(height: 3), Text(sub, style: const TextStyle(color: _muted, fontSize: 13))],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(title: 'Complete Your Payment'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _activity('Golf bay', 'Fri, 18 Jul | 11:30 AM | VVIP bay | 4 players'),
            _activity('Cricket bay', 'Fri, 18 Jul | 11:30 AM | Standard | 10 players'),
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Text('Add another activity', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
              ]),
            ),
            const Text('Select Payment Method', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _methodRow(0, Icons.account_balance, 'Corporate wallet', sub: 'Balance: ₹2,50,000'),
            _methodRow(1, Icons.account_balance_outlined, 'Bank transfer'),
            _methodRow(2, Icons.credit_card, 'Corporate credit/debit card'),
            _methodRow(3, Icons.receipt_long_outlined, 'Cheque'),
            _methodRow(4, Icons.account_balance_wallet_outlined, 'Google pay'),
          ],
        ),
      ),
    );
  }
}

// ── 7. Complete Your Payment (fund via method / credit line) ─────────────────

class CxFundPaymentScreen extends StatefulWidget {
  final double amount;
  const CxFundPaymentScreen({super.key, this.amount = 250000});
  @override
  State<CxFundPaymentScreen> createState() => _CxFundPaymentScreenState();
}

class _CxFundPaymentScreenState extends State<CxFundPaymentScreen> {
  bool _companyOpen = false;
  bool _busy = false;
  int _sel = -1; // 0 bank, 1 cheque, 2 card, 3 gpay, 4 credit line
  late final _creditAmount = TextEditingController(text: widget.amount.toStringAsFixed(0));
  int _billing = 0;
  static const _cycles = ['30 days', '45 days', '60 days'];
  static const _cycleDays = [30, 45, 60];
  double _wallet = 0;

  @override
  void initState() {
    super.initState();
    Api.corporateWallet().then((w) {
      if (mounted) setState(() => _wallet = ((w['totalBalance'] ?? 0) as num).toDouble());
    }).catchError((_) {});
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _result({required String banner, required String header, required String cardTitle, required List<String> details, required String note}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CxPaymentResultScreen(banner: banner, header: header, cardTitle: cardTitle, details: details, note: note),
    ));
  }

  // Fund the wallet. Offline (bank/cheque) records the top-up; card/upi go through
  // Razorpay checkout, then verify the signature.
  Future<void> _fund(String method, String title) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await Api.corporateFundWallet(amount: widget.amount, method: method);
      final orderId = (res['razorpayOrderId'] ?? '').toString();
      if (orderId.isNotEmpty) {
        if (!Api.razorpayConfigured || !razorpayClientSupported) {
          _snack("Online payment isn't available here — use bank transfer or cheque.");
          return;
        }
        final u = AuthState.instance.user;
        final rp = await openRazorpayCheckout(
          keyId: Api.razorpayKeyId,
          orderId: orderId,
          amountPaise: (widget.amount * 100).toInt(),
          name: 'Strikin',
          email: u?.email ?? '',
          contact: u?.phone ?? '',
          description: 'Wallet top-up',
          method: method == 'upi' ? 'upi' : 'card',
        );
        if (rp == null) return; // user dismissed
        final ok = await Api.corporateFundVerify(paymentId: rp.paymentId, orderId: rp.orderId, signature: rp.signature);
        if (!ok) {
          _snack('Payment could not be verified.');
          return;
        }
      }
      if (!mounted) return;
      _result(
        banner: 'Payment initiated successfully',
        header: 'Payment details',
        cardTitle: 'Your $title has been received. It may take up to 2-3 business days to reflect',
        details: ['Amount: ₹${widget.amount.toStringAsFixed(0)}', 'Method: $title'],
        note: "You'll receive an email once the payment is confirmed.",
      );
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not start the payment. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _requestCredit() async {
    final amt = double.tryParse(_creditAmount.text.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
    if (amt <= 0) {
      _snack('Enter a credit amount.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.corporateRequestCreditLine(amount: amt, billingCycleDays: _cycleDays[_billing]);
      if (!mounted) return;
      _result(
        banner: 'Credit Line Request Sent',
        header: 'Credit line request:',
        cardTitle: 'Our team will review your application and get back to you within 2–3 business days.',
        details: ['Amount: ₹${amt.toStringAsFixed(0)}', 'Billing cycle: ${_cycles[_billing]}'],
        note: "You'll receive an email once your credit line is approved.",
      );
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not send the request. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _companyCard() {
    final u = AuthState.instance.user;
    final company = (u?.companyName?.trim().isNotEmpty ?? false) ? u!.companyName!.trim() : 'Your company';
    final adminLine = [u?.name, u?.email, u?.phone].where((s) => (s ?? '').trim().isNotEmpty).join(', ');
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _companyOpen = !_companyOpen),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(company, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('Wallet balance: ₹${_wallet.toStringAsFixed(0)}', style: const TextStyle(color: _lime, fontSize: 13, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(_companyOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white),
            ]),
          ),
          if (_companyOpen) ...[
            const SizedBox(height: 16),
            const Text('Super admin', style: TextStyle(color: _muted, fontSize: 13)),
            const SizedBox(height: 4),
            Text(adminLine.isEmpty ? '—' : adminLine, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
            const SizedBox(height: 14),
            const Text('Amount to add', style: TextStyle(color: _muted, fontSize: 13)),
            const SizedBox(height: 4),
            Text('₹${widget.amount.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 14)),
          ],
        ],
      ),
    );
  }

  Widget _method(int i, IconData icon, String title, String method) {
    final sel = _sel == i;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sel ? _lime : _cardBorder, width: sel ? 1.5 : 1),
      ),
      child: Column(children: [
        InkWell(
          onTap: () => setState(() => _sel = i),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
              if (sel) const Icon(Icons.check_circle, color: _lime, size: 20),
            ]),
          ),
        ),
        if (sel)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _pill(_busy ? 'Processing…' : 'Pay via $title', _busy ? null : () => _fund(method, title)),
          ),
      ]),
    );
  }

  Widget _cycleChip(int b) {
    final sel = _billing == b;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => setState(() => _billing = b),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: sel ? Colors.transparent : _field,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: sel ? _lime : Colors.transparent, width: 1.5),
          ),
          child: Text(_cycles[b], style: TextStyle(color: sel ? _lime : Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _creditLine() {
    final sel = _sel == 4;
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sel ? _lime : _cardBorder, width: sel ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _sel = 4),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.account_balance, color: Colors.white, size: 22),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Credit line', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        SizedBox(height: 6),
                        Text('Book now and pay later through your approved credit limit.', style: TextStyle(color: _muted, fontSize: 13, height: 1.35)),
                      ],
                    ),
                  ),
                  if (sel) const Icon(Icons.check_circle, color: _lime, size: 20),
                ],
              ),
            ),
          ),
          if (sel)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Amount', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _creditAmount,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: InputDecoration(
                      prefixText: '₹ ',
                      prefixStyle: const TextStyle(color: _placeholder),
                      filled: true,
                      fillColor: _field,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Billing cycle', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Row(children: [for (int b = 0; b < 3; b++) _cycleChip(b)]),
                  const SizedBox(height: 18),
                  _pill(_busy ? 'Sending…' : 'Send for approval', _busy ? null : _requestCredit),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(title: 'Complete Your Payment'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            _companyCard(),
            const Text('Select Payment Method', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _method(0, Icons.account_balance, 'Bank transfer', 'bank_transfer'),
            _method(1, Icons.receipt_long_outlined, 'Cheque', 'cheque'),
            _method(2, Icons.credit_card, 'Corporate credit/debit card', 'corporate_card'),
            _method(3, Icons.qr_code, 'UPI', 'upi'),
            const SizedBox(height: 12),
            Text(_sel == 4 ? 'Book Now, Pay Later (Corporate Credit)' : 'Book Now, Pay Later',
                style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            _creditLine(),
          ],
        ),
      ),
    );
  }
}

// ── 8. Result (green banner: payment initiated / credit line request sent) ───

class CxPaymentResultScreen extends StatelessWidget {
  final String banner, header, cardTitle, note;
  final List<String> details;
  const CxPaymentResultScreen({super.key, required this.banner, required this.header, required this.cardTitle, required this.details, required this.note});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFF3E9B5F),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 18, bottom: 18, left: 16, right: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Color(0xFF3E9B5F), size: 15),
                ),
                const SizedBox(width: 10),
                Flexible(child: Text(banner, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cardTitle, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700, height: 1.35)),
                  const SizedBox(height: 16),
                  Text(header, style: const TextStyle(color: _muted, fontSize: 14)),
                  const SizedBox(height: 8),
                  ...details.map((d) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(d, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4)),
                      )),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF3A3A3A), height: 1),
                  const SizedBox(height: 14),
                  Text(note, style: const TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 16),
                  _greyPill('Go to home', () => Navigator.of(context).popUntil((r) => r.settings.name == 'cx_dashboard' || r.isFirst)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 9. Get Ready to Book — corporate home / setup dashboard ───────────────────

class CxDashboardScreen extends StatefulWidget {
  const CxDashboardScreen({super.key});
  @override
  State<CxDashboardScreen> createState() => _CxDashboardScreenState();
}

class _CxDashboardScreenState extends State<CxDashboardScreen> {
  final Set<int> _done = {};
  int _kyc = 0; // 0 = not submitted, 1 = pending admin review, 2 = verified
  double _wallet = 0;
  bool _walletPending = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _carousel = [
    'assets/images/97f99fc5e998d044.png',
    'assets/images/734475baf61e4b38.png',
    'assets/images/86da785fdc68fd9c.png',
    'assets/images/450543d2af53dc91.png',
    'assets/images/88b9aae11e5d43ae.png',
  ];

  @override
  void initState() {
    super.initState();
    _loadKyc();
    _loadWallet();
  }

  Future<void> _loadWallet() async {
    try {
      final w = await Api.corporateWallet();
      if (mounted) {
        setState(() {
          _wallet = ((w['totalBalance'] ?? 0) as num).toDouble();
          _walletPending = w['hasPendingFunding'] == true;
        });
      }
    } catch (_) {}
  }

  // Pull-to-refresh: re-read the live wallet balance + KYC status.
  Future<void> _refresh() async {
    await _loadWallet();
    await _loadKyc();
  }

  // Simple corporate menu (no images) opened from the ☰ in the header.
  Widget _drawer() {
    final u = AuthState.instance.user;
    final company = (u?.companyName?.trim().isNotEmpty ?? false) ? u!.companyName!.trim() : 'Your company';
    Widget item(IconData icon, String label, VoidCallback onTap) => ListTile(
          leading: Icon(icon, color: Colors.white),
          title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          onTap: () {
            Navigator.of(context).pop();
            onTap();
          },
        );
    void go(Widget s) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => s));
    return Drawer(
      backgroundColor: const Color(0xFF1A1A1A),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('STRIKIN', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 3)),
                  const SizedBox(height: 4),
                  Text(company, style: const TextStyle(color: _lime, fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Divider(color: Color(0xFF2E2E2E), height: 1),
            item(Icons.account_balance_wallet_outlined, 'Add money', () async {
              if (!_requireVerified()) return;
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxPaymentPlanScreen()));
              _loadWallet();
            }),
            item(Icons.groups_outlined, 'Team members', () => go(const CxTeamDepartmentsScreen())),
            item(Icons.pie_chart_outline, 'Budget allocation', () => go(const CxBudgetScreen())),
            item(Icons.sports_esports_outlined, 'Book activity', () { if (_requireVerified()) go(const CxSelectActivityScreen()); }),
            item(Icons.refresh, 'Refresh balance', _refresh),
            const Spacer(),
            const Divider(color: Color(0xFF2E2E2E), height: 1),
            item(Icons.logout, 'Log out', () => AuthState.instance.logout()),
          ],
        ),
      ),
    );
  }

  // Wallet balance + "Add money" (always available so a company can top up again).
  Widget _walletCard() => Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Corporate wallet', style: TextStyle(color: _muted, fontSize: 14)),
                      const SizedBox(height: 6),
                      Text('₹${_wallet.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    if (!_requireVerified()) return;
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxPaymentPlanScreen()));
                    _loadWallet();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    decoration: BoxDecoration(color: _lime, borderRadius: BorderRadius.circular(22)),
                    child: const Text('+ Add money',
                        style: TextStyle(color: Color(0xFF141414), fontSize: 14, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
            if (_walletPending) ...[
              const SizedBox(height: 12),
              const Text('A top-up is pending confirmation — the balance updates once the admin confirms it.',
                  style: TextStyle(color: Color(0xFFE8B64C), fontSize: 12.5, height: 1.4)),
            ],
          ],
        ),
      );

  // Read the real KYC status from the backend and map it to the banner state.
  Future<void> _loadKyc() async {
    try {
      final s = await Api.corporateKycStatus();
      final ks = (s['kycStatus'] ?? 'not_started').toString();
      if (mounted) setState(() => _kyc = ks == 'verified' ? 2 : (ks == 'submitted' ? 1 : 0));
    } catch (_) {/* keep current state on network error */}
  }

  Future<void> _begin(int i, Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() => _done.add(i));
  }

  Future<void> _openKyc() async {
    final submitted = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const CxKycScreen()));
    if (submitted == true) await _loadKyc();
  }

  // Booking + wallet top-ups are locked until the company's KYC is verified.
  bool _requireVerified() {
    if (_kyc == 2) return true;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Verify your company first to unlock booking and payments.'),
      behavior: SnackBarBehavior.floating,
    ));
    return false;
  }

  // KYC status banner — shown on the dashboard until the company is approved.
  Widget _kycBanner() {
    if (_kyc == 2) {
      return Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
        child: const Row(children: [
          Icon(Icons.verified, color: _lime, size: 20),
          SizedBox(width: 10),
          Text('Company verified', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
        ]),
      );
    }
    final pending = _kyc == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pending ? _cardBorder : _lime.withValues(alpha: .55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(pending ? Icons.hourglass_top : Icons.shield_outlined, color: pending ? const Color(0xFFE8B64C) : _lime, size: 20),
            const SizedBox(width: 10),
            Text(pending ? 'Verification pending' : 'Verify your company',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text(
            pending
                ? "Our team is reviewing your documents. You'll get an email once your company is approved."
                : 'Upload your PAN & GST so we can verify your company and unlock booking.',
            style: const TextStyle(color: _muted, fontSize: 13.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (pending)
            GestureDetector(
              onTap: _loadKyc,
              child: const Text('Refresh status',
                  style: TextStyle(color: _muted, fontSize: 13, decoration: TextDecoration.underline)),
            )
          else
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _openKyc,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _lime,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Upload documents',
                    style: TextStyle(color: Color(0xFF141414), fontSize: 15, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _setupCard(int i, String label, Widget target, {Widget? manage}) {
    final done = _done.contains(i);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: done ? _lime : Colors.transparent,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: done ? _lime : _muted, width: 1.6),
            ),
            child: done ? const Icon(Icons.check, color: Color(0xFF141414), size: 18) : null,
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700))),
          if (done)
            GestureDetector(
              onTap: manage != null ? () => _begin(i, manage) : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Completed', style: TextStyle(color: _lime, fontSize: 14, fontWeight: FontWeight.w700)),
                  if (manage != null) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.edit_outlined, color: _lime, size: 15),
                  ],
                ],
              ),
            )
          else
            GestureDetector(
              onTap: () => _begin(i, target),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                decoration: BoxDecoration(color: const Color(0xFF2A2A2A), borderRadius: BorderRadius.circular(22)),
                child: const Text('Begin', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Once the company is verified and all three setup steps are done, drop the
    // "Get Ready to Book" checklist and show the main dashboard (wallet + booking).
    final setupComplete = _kyc == 2 && _done.length >= 3;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _bg,
      drawer: _drawer(),
      body: RefreshIndicator(
        color: _lime,
        backgroundColor: _card,
        onRefresh: _refresh,
        child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 22, left: 20, right: 12, bottom: 26),
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2A2A), Color(0xFF141414)]),
            ),
            child: Row(
              children: [
                const Text('STRIKIN', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3)),
                const Spacer(),
                IconButton(
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kycBanner(),
                _walletCard(),
                if (!setupComplete) ...[
                  const Text('Get Ready to Book', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text('Just a few steps away! Complete your setup to unlock bookings.',
                      style: TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 22),
                  _setupCard(0, 'Payment set up', const CxPaymentPlanScreen(), manage: const CxPaymentPlanScreen()),
                  _setupCard(1, 'Team set up', const CxTeamSetupScreen(), manage: const CxTeamDepartmentsScreen()),
                  _setupCard(2, 'Budget allocation', const CxBudgetScreen(), manage: const CxBudgetScreen()),
                  const SizedBox(height: 24),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _lime.withValues(alpha: .55)),
                    ),
                    child: const Row(children: [
                      Icon(Icons.check_circle, color: _lime, size: 22),
                      SizedBox(width: 10),
                      Expanded(child: Text("You're all set — book your next activity below.",
                          style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700))),
                    ]),
                  ),
                  const SizedBox(height: 20),
                ],
                _pill('Book activity', () { if (_requireVerified()) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxSelectActivityScreen())); }),
                const SizedBox(height: 32),
                const Text('THE ADVENTURE MENU',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(height: 8),
                const Text('STRIKIN is your multi-sensory map to limitless fun.',
                    style: TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                const SizedBox(height: 18),
              ],
            ),
          ),
          SizedBox(
            height: 240,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _carousel.length,
              itemBuilder: (c, i) => GestureDetector(
                onTap: () { if (_requireVerified()) Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxSelectActivityScreen())); },
                child: Container(
                  width: 250,
                  margin: const EdgeInsets.only(right: 14),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                  child: Image.asset(
                    _carousel[i],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),
        ],
        ),
      ),
    );
  }
}

// ── 10. Budget allocation ─────────────────────────────────────────────────────

class CxBudgetScreen extends StatefulWidget {
  const CxBudgetScreen({super.key});
  @override
  State<CxBudgetScreen> createState() => _CxBudgetScreenState();
}

class _CxBudgetScreenState extends State<CxBudgetScreen> {
  bool _loading = true;
  bool _busy = false;
  double _wallet = 0;
  List<Map<String, dynamic>> _leads = []; // {teamLeadId, teamLeadName, allocatedAmount, remaining}
  final Map<String, TextEditingController> _amts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.corporateBudgetAllocations();
      final allocs = ((d['allocations'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _wallet = ((d['walletBalance'] ?? 0) as num).toDouble();
        _leads = allocs;
        for (final l in allocs) {
          _amts[(l['teamLeadId'] ?? '').toString()] = TextEditingController();
        }
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _allocate() async {
    setState(() => _busy = true);
    try {
      var any = false;
      for (final l in _leads) {
        final id = (l['teamLeadId'] ?? '').toString();
        final amt = double.tryParse(_amts[id]?.text.replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? 0;
        if (amt > 0) {
          await Api.corporateAllocateBudget(id, amt);
          any = true;
        }
      }
      if (!any) {
        _snack('Enter an amount for at least one team lead.');
        setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxAckScreen(message: 'Budget allotment successful')));
    } on ApiException catch (e) {
      _snack(e.message);
      if (mounted) setState(() => _busy = false);
    } catch (_) {
      _snack('Could not allocate. Please try again.');
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(backgroundColor: _bg, appBar: _appBar(), body: const Center(child: CircularProgressIndicator(color: _lime)));
    }
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  // Corporate wallet card (real balance)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Corporate wallet', style: TextStyle(color: _muted, fontSize: 14)),
                              const SizedBox(height: 6),
                              Text('₹${_wallet.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxPaymentPlanScreen())),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                            decoration: BoxDecoration(color: _secondary, borderRadius: BorderRadius.circular(22)),
                            child: const Text('+Add money', style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Set the amount to be allocated to each Team Lead from the corporate wallet',
                      style: TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 18),
                  if (_leads.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: Text('No team leads yet. Star a member as Team Lead in Team setup first.',
                          style: TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                    ),
                  for (final l in _leads)
                    Container(
                      margin: const EdgeInsets.only(bottom: 14),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((l['teamLeadName'] ?? 'Team lead').toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 3),
                          Text('Allocated: ₹${((l['allocatedAmount'] ?? 0) as num).toStringAsFixed(0)}  ·  Remaining: ₹${((l['remaining'] ?? 0) as num).toStringAsFixed(0)}',
                              style: const TextStyle(color: _muted, fontSize: 13)),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _amts[(l['teamLeadId'] ?? '').toString()],
                            keyboardType: TextInputType.number,
                            style: const TextStyle(color: Colors.white, fontSize: 15),
                            decoration: InputDecoration(
                              prefixText: '₹ ',
                              prefixStyle: const TextStyle(color: _placeholder, fontSize: 15),
                              hintText: 'Amount to allocate',
                              hintStyle: const TextStyle(color: _placeholder, fontSize: 15),
                              filled: true,
                              fillColor: _field,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: _pill(_busy ? 'Allocating…' : 'Allocate budget', (_busy || _leads.isEmpty) ? null : _allocate),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 11. Team members by department (Tech / Marketing / Sales tabs) ────────────

class CxTeamDepartmentsScreen extends StatefulWidget {
  const CxTeamDepartmentsScreen({super.key});
  @override
  State<CxTeamDepartmentsScreen> createState() => _CxTeamDepartmentsScreenState();
}

class _CxTeamDepartmentsScreenState extends State<CxTeamDepartmentsScreen> {
  final _members = <_Member>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.corporateMembers();
      final list = ((d['members'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _members
          ..clear()
          ..addAll(list.map((m) => _Member(
                (m['fullName'] ?? '').toString(),
                (m['email'] ?? '').toString(),
                lead: m['isTeamLead'] == true || (m['role'] ?? '').toString() == 'team_lead',
                id: (m['id'] ?? '').toString(),
              )));
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _toggleLead(_Member m) async {
    final next = !m.lead;
    setState(() => m.lead = next);
    final ok = await Api.corporateSetMemberRole(m.id, next ? 'team_lead' : 'member');
    if (!ok && mounted) {
      setState(() => m.lead = !next);
      _snack('Could not update role.');
    }
  }

  Future<void> _remove(_Member m) async {
    final idx = _members.indexOf(m);
    setState(() => _members.remove(m));
    final ok = await Api.corporateRemoveMember(m.id);
    if (!ok && mounted) {
      setState(() => _members.insert(idx < 0 ? 0 : idx, m));
      _snack('Could not remove member.');
    }
  }

  Future<void> _edit(_Member m) async {
    final name = TextEditingController(text: m.name);
    final email = TextEditingController(text: m.email);
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 14, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Center(child: Text('Edit member', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
            const SizedBox(height: 18),
            _field2('Name', 'Name', name),
            const SizedBox(height: 18),
            _field2('Email', 'Email', email),
            const SizedBox(height: 16),
            _pill('Save', () { setState(() { m.name = name.text; m.email = email.text; }); Navigator.pop(ctx); }),
          ],
        ),
      ),
    );
  }

  // Add a team member (super admin): name + email + phone + a Team Lead checkbox.
  Future<void> _addMember() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    var isLead = false;
    var busy = false;
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 14, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Center(child: Text('Add team member', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
              const SizedBox(height: 18),
              _field2('Full name', 'Enter name', name),
              const SizedBox(height: 16),
              _field2('Email', 'Enter work email', email, kb: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _field2('Phone (optional)', 'Enter phone', phone, kb: TextInputType.phone),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setSheet(() => isLead = !isLead),
                child: Row(children: [
                  Icon(isLead ? Icons.check_box : Icons.check_box_outline_blank, color: isLead ? _lime : _muted, size: 24),
                  const SizedBox(width: 10),
                  const Text('Make this person a Team Lead', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 18),
              _pill(busy ? 'Adding…' : 'Add member', busy
                  ? null
                  : () async {
                      final em = email.text.trim();
                      if (name.text.trim().isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(em)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter a name and a valid email.')));
                        return;
                      }
                      setSheet(() => busy = true);
                      try {
                        await Api.corporateAddMembers([
                          {
                            'fullName': name.text.trim(),
                            'email': em,
                            if (phone.text.trim().isNotEmpty) 'phone': phone.text.trim(),
                            if (isLead) 'isTeamLead': true,
                          }
                        ]);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } on ApiException catch (e) {
                        if (!ctx.mounted) return;
                        setSheet(() => busy = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                      } catch (_) {
                        if (!ctx.mounted) return;
                        setSheet(() => busy = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Could not add member. Please try again.')));
                      }
                    }),
            ],
          ),
        ),
      ),
    );
    if (added == true) _load();
  }

  Widget _memberCard(_Member m) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggleLead(m),
              child: Icon(m.lead ? Icons.star : Icons.star_border, color: m.lead ? _lime : _muted, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(m.name,
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (m.lead) ...[
                        const SizedBox(width: 10),
                        const Text('Team lead', style: TextStyle(color: _lime, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(m.email, style: const TextStyle(color: _muted, fontSize: 13)),
                ],
              ),
            ),
            IconButton(onPressed: () => _edit(m), icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20)),
            IconButton(onPressed: () => _remove(m), icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(title: 'Team members', profile: true),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _lime))
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      children: [
                        const Text('Team members', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        const Text('Tap the star to mark someone as Team Lead.', style: TextStyle(color: _muted, fontSize: 13, height: 1.4)),
                        const SizedBox(height: 16),
                        if (_members.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 30),
                            child: Text('No members yet — add one below, or import a CSV in Team setup.',
                                style: TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                          )
                        else
                          ..._members.map(_memberCard),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: _pill('+ Add member', _addMember),
                  ),
                ],
              ),
      ),
    );
  }
}

// ── 12. Company verification (KYC document upload) ────────────────────────────
// No Figma yet — built on-brand; swap when a design lands. Docs are reviewed by
// the Strikin team in the admin portal; the dashboard shows "pending" meanwhile.

class CxKycScreen extends StatefulWidget {
  const CxKycScreen({super.key});
  @override
  State<CxKycScreen> createState() => _CxKycScreenState();
}

class _CxKycScreenState extends State<CxKycScreen> {
  String? _pan; // uploaded file name
  String? _gst;
  String? _uploading; // documentType currently uploading
  bool _submitting = false;

  // Pick a file → get a presigned URL → PUT the bytes to S3/MinIO → confirm.
  Future<void> _upload(String documentType) async {
    if (_uploading != null) return;
    final picked = await FilePicker.platform.pickFiles(
        withData: true, type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png']);
    if (picked == null || picked.files.isEmpty) return;
    final f = picked.files.first;
    final bytes = f.bytes;
    if (bytes == null) return;
    final ext = (f.extension ?? '').toLowerCase();
    final mime = ext == 'pdf' ? 'application/pdf' : (ext == 'png' ? 'image/png' : 'image/jpeg');
    setState(() => _uploading = documentType);
    try {
      final up = await Api.corporateKycUploadUrl(
          documentType: documentType, fileName: f.name, mimeType: mime, fileSizeBytes: f.size);
      final url = (up['uploadUrl'] ?? '').toString();
      final uploadId = (up['uploadId'] ?? '').toString();
      final ok = url.isNotEmpty && await Api.uploadToPresignedUrl(url, bytes, mime);
      if (!ok) throw Exception('upload failed');
      await Api.corporateKycConfirmUpload(uploadId);
      if (!mounted) return;
      setState(() => documentType == 'pan_card' ? _pan = f.name : _gst = f.name);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed. Please try again.')));
    } finally {
      if (mounted) setState(() => _uploading = null);
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await Api.corporateKycSubmit();
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not submit. Please try again.')));
      }
    }
  }

  Widget _dropZone(String label, String hint, String? file, String documentType) {
    final busy = _uploading == documentType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(hint, style: const TextStyle(color: _muted, fontSize: 13)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: busy ? null : () => _upload(documentType),
          child: CustomPaint(
            painter: _DashedRRect(color: file == null ? _placeholder : _lime),
            child: SizedBox(
              height: 96,
              width: double.infinity,
              child: Center(
                child: busy
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: _lime))
                    : file == null
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                            decoration: BoxDecoration(color: _secondary, borderRadius: BorderRadius.circular(24)),
                            child: const Text('+ Upload',
                                style: TextStyle(color: Color(0xFF1A1A1A), fontSize: 14, fontWeight: FontWeight.w700)),
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.check_circle, color: _lime, size: 20),
                                const SizedBox(width: 8),
                                Flexible(child: Text(file, style: const TextStyle(color: Colors.white, fontSize: 15), overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ready = _pan != null && _gst != null;
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(title: 'Company verification'),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  const Text('Upload your documents so we can verify your company. This usually takes 1–2 business days.',
                      style: TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 22),
                  _dropZone('PAN card', 'Company PAN document', _pan, 'pan_card'),
                  const SizedBox(height: 24),
                  _dropZone('GST certificate', 'GST registration certificate', _gst, 'gst_certificate'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: _pill(_submitting ? 'Submitting…' : 'Submit for verification', (ready && !_submitting) ? _submit : null),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 13. Corporate booking payment ("Complete Your Payment" — pay from wallet) ─
// Same booking pipeline as the normal customer flow; only the payment step adds
// "Corporate wallet" (deducts from the funded budget) alongside the usual methods.

const _cxActivities = [
  ['Golf bay', 'Fri, 18 Jul | 11:30 AM | VVIP bay | 4 players', '₹1,20,000'],
  ['Cricket bay', 'Fri, 18 Jul | 11:30 AM | Standard | 10 players', '₹80,000'],
];

const _cxCarousel = [
  'assets/images/97f99fc5e998d044.png',
  'assets/images/734475baf61e4b38.png',
  'assets/images/86da785fdc68fd9c.png',
  'assets/images/450543d2af53dc91.png',
  'assets/images/88b9aae11e5d43ae.png',
];

class CxBookingPaymentScreen extends StatefulWidget {
  const CxBookingPaymentScreen({super.key});
  @override
  State<CxBookingPaymentScreen> createState() => _CxBookingPaymentScreenState();
}

class _CxBookingPaymentScreenState extends State<CxBookingPaymentScreen> {
  int _sel = -1;
  final Set<int> _openActs = {};

  static const _methods = [
    [Icons.account_balance, 'Corporate wallet', 'Balance: ₹2,50,000'],
    [Icons.account_balance, 'Bank transfer', ''],
    [Icons.credit_card, 'Corporate credit/debit card', ''],
    [Icons.receipt_long_outlined, 'Cheque', ''],
    [Icons.account_balance_wallet_outlined, 'Google pay', ''],
  ];

  Widget _activity(int i) {
    final a = _cxActivities[i];
    final open = _openActs.contains(i);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => open ? _openActs.remove(i) : _openActs.add(i)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a[0], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Text(a[1], style: const TextStyle(color: _muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white),
                ],
              ),
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal', style: TextStyle(color: _muted, fontSize: 14)),
                  Text(a[2], style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _method(int i) {
    final m = _methods[i];
    final icon = m[0] as IconData;
    final label = m[1] as String;
    final sub = m[2] as String;
    final sel = _sel == i;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sel ? _lime : _cardBorder, width: sel ? 1.5 : 1),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _sel = i),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                        if (sub.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(sub, style: const TextStyle(color: _muted, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                  if (sel) const Icon(Icons.check_circle, color: _lime, size: 20),
                ],
              ),
            ),
          ),
          if (sel)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _pill(i == 0 ? 'Pay from wallet' : 'Pay via $label',
                  () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxBookingConfirmedScreen()))),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(title: 'Complete Your Payment'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            for (int i = 0; i < _cxActivities.length; i++) _activity(i),
            // Add another activity
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxSelectActivityScreen())),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(children: [
                    Icon(Icons.add_circle_outline, color: Colors.white, size: 22),
                    SizedBox(width: 14),
                    Text('Add another activity', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text('Select Payment Method', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            for (int i = 0; i < _methods.length; i++) _method(i),
          ],
        ),
      ),
    );
  }
}

// ── 14. Corporate booking confirmation (QR + food per activity) ───────────────

class CxBookingConfirmedScreen extends StatefulWidget {
  const CxBookingConfirmedScreen({super.key});
  @override
  State<CxBookingConfirmedScreen> createState() => _CxBookingConfirmedScreenState();
}

class _CxBookingConfirmedScreenState extends State<CxBookingConfirmedScreen> {
  final Set<int> _open = {0};

  Widget _activity(int i) {
    final a = _cxActivities[i];
    final open = _open.contains(i);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => open ? _open.remove(i) : _open.add(i)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(a[0], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 5),
                        Text(a[1], style: const TextStyle(color: _muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.white),
                ],
              ),
            ),
          ),
          if (open) ...[
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.qr_code_2, color: Colors.black, size: 150),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Show your QR code at the bay entrance to start your game.',
                  textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 13, height: 1.4)),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('Available under My Profile > Order History',
                  style: TextStyle(color: _muted, fontSize: 12)),
            ),
            const SizedBox(height: 14),
            const Divider(color: Color(0xFF3A3A3A), height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Food ordered', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  SizedBox(height: 6),
                  Text('4 Burger, 2 Mountain dews, 1 guinness draught',
                      style: TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFF3E9B5F),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 18, bottom: 18, left: 16, right: 16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text('Booking confirmed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              children: [
                for (int i = 0; i < _cxActivities.length; i++) _activity(i),
                const SizedBox(height: 8),
                const Text('Explore other experiences', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _cxCarousel.length,
                    itemBuilder: (c, i) => Container(
                      width: 220,
                      margin: const EdgeInsets.only(right: 14),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                      child: Image.asset(
                        _cxCarousel[i],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)]),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _greyPill('Go to home', () => Navigator.of(context).popUntil((r) => r.settings.name == 'cx_dashboard' || r.isFirst)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 15. Book a bay (corporate) — activity / date / players / bay / time ───────
// Same selection pipeline as the normal customer flow. "Add to booking" leads to
// the cart (Complete Your Payment); "Add another activity" there loops back here.

const _cxBookDates = [
  ['Tue', '15'], ['Wed', '16'], ['Thu', '17'], ['Fri', '18'], ['Sat', '19'], ['Sun', '20'],
];
const _cxBookTimes = ['11:00 AM', '11:30 AM', '12:00 PM', '12:30 PM', '1:00 PM'];
const _cxSoldOutTimes = {2, 3};
const _cxActivityList = ['Golf bay', 'Cricket bay', 'Pickleball bay', 'Padel bay'];
const _cxVvipRooms = [
  ['assets/images/5d20042ee63c20ce.jpg', 'Four Seasons Room', 'All four seasons, one sensory bay', '10', false],
  ['assets/images/19650d79d03ff25f.jpg', 'Space Room', 'Interstellar luxury bay', '15', true],
  ['assets/images/2501ef2a7dc42b96.jpg', 'Cave room', 'Nature inspired cave room', '10', false],
  ['assets/images/a5f426b2a5253d81.jpg', 'Azulik Tulum', 'Soulful tulum inspired bay', '10', false],
];

class CxBookABayScreen extends StatefulWidget {
  final String? initialActivity;
  const CxBookABayScreen({super.key, this.initialActivity});
  @override
  State<CxBookABayScreen> createState() => _CxBookABayScreenState();
}

class _CxBookABayScreenState extends State<CxBookABayScreen> {
  late String _activity = widget.initialActivity ?? 'Golf bay';
  int _date = 3;
  int? _players;
  int _bayType = -1; // 0 VVIP, 1 Standard
  int _bays = 0;
  int _time = -1;

  Widget _grab() => Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2)));

  Future<void> _pickActivity() async {
    final a = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            _grab(),
            const SizedBox(height: 8),
            for (final a in _cxActivityList)
              ListTile(
                title: Text(a, style: const TextStyle(color: Colors.white, fontSize: 16)),
                trailing: _activity == a ? const Icon(Icons.check, color: _lime) : null,
                onTap: () => Navigator.pop(ctx, a),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (a != null) setState(() => _activity = a);
  }

  Future<void> _pickPlayers() async {
    final n = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              _grab(),
              const SizedBox(height: 14),
              const Text('Number of players', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (int n = 1; n <= 12; n++)
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx, n),
                      child: Container(
                        width: 52,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(10)),
                        child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
    if (n != null) setState(() => _players = n);
  }

  Future<void> _pickBays() async {
    final selected = <int>{};
    final count = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              _grab(),
              const SizedBox(height: 14),
              const Text('Select a VVIP bay', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('You can select multiple bays', style: TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _cxVvipRooms.length,
                  itemBuilder: (c, i) {
                    final r = _cxVvipRooms[i];
                    final soldOut = r[4] as bool;
                    final sel = selected.contains(i);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(r[0] as String, width: 92, height: 74, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(width: 92, height: 74, color: _field)),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r[1] as String, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 3),
                                Text(r[2] as String, style: const TextStyle(color: _muted, fontSize: 13)),
                                const SizedBox(height: 3),
                                soldOut
                                    ? const Text('Sold out', style: TextStyle(color: Color(0xFFE05B5B), fontSize: 13, fontWeight: FontWeight.w600))
                                    : Text('Max players: ${r[3]}', style: const TextStyle(color: _muted, fontSize: 13)),
                              ],
                            ),
                          ),
                          if (!soldOut)
                            GestureDetector(
                              onTap: () => setSheet(() => sel ? selected.remove(i) : selected.add(i)),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: sel ? _lime : Colors.transparent,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: sel ? _lime : _muted, width: 1.6),
                                ),
                                child: sel ? const Icon(Icons.check, color: Color(0xFF141414), size: 16) : null,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: _pill('Confirm', () => Navigator.pop(ctx, selected.length)),
              ),
            ],
          ),
        ),
      ),
    );
    if (count != null) setState(() => _bays = count);
  }

  Widget _dateChip(int i) {
    final d = _cxBookDates[i];
    final sel = _date == i;
    return GestureDetector(
      onTap: () => setState(() => _date = i),
      child: Container(
        width: 72,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(color: sel ? _lime : _card, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(d[0], style: TextStyle(color: sel ? const Color(0xFF141414) : _muted, fontSize: 12)),
            const SizedBox(height: 6),
            Text(d[1], style: TextStyle(color: sel ? const Color(0xFF141414) : Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Jul', style: TextStyle(color: sel ? const Color(0xFF141414) : _muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _timeChip(int i) {
    final soldOut = _cxSoldOutTimes.contains(i);
    final sel = _time == i;
    return GestureDetector(
      onTap: soldOut ? null : () => setState(() => _time = i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: sel ? _lime : Colors.transparent, width: 1.5),
        ),
        child: Text(_cxBookTimes[i],
            style: TextStyle(color: soldOut ? _placeholder : (sel ? _lime : Colors.white), fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _bayCard(int i, String name, String desc, String price, {bool vvip = false}) {
    final sel = _bayType == i;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: sel ? _lime : _cardBorder, width: sel ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _bayType = i),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(sel ? Icons.check_circle : Icons.radio_button_off, color: sel ? _lime : _muted, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 5),
                      Text(desc, style: const TextStyle(color: _muted, fontSize: 13, height: 1.35)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(price, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (sel && vvip) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: _pickBays,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    Expanded(child: Text(_bays > 0 ? '$_bays bay selected' : 'Select bays',
                        style: TextStyle(color: _bays > 0 ? Colors.white : _placeholder, fontSize: 14))),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                  ],
                ),
              ),
            ),
          ],
          if (vvip) ...[
            const SizedBox(height: 12),
            const Text('Filling fast', style: TextStyle(color: Color(0xFFE8A33C), fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _bayType >= 0 && _time >= 0 && _players != null;
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  GestureDetector(
                    onTap: _pickActivity,
                    child: Row(
                      children: [
                        const Text('Book a ', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                        Text(_activity.toLowerCase(), style: const TextStyle(color: _lime, fontSize: 24, fontWeight: FontWeight.w800)),
                        const SizedBox(width: 6),
                        const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 84,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _cxBookDates.length,
                      itemBuilder: (c, i) => _dateChip(i),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Players', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickPlayers,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                      decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(_players?.toString() ?? 'Select number of players',
                                style: TextStyle(color: _players == null ? _placeholder : Colors.white, fontSize: 15)),
                          ),
                          const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Bay type', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  _bayCard(0, 'VVIP bay', 'Experience the best with our VIP bays.', '₹5,000', vvip: true),
                  _bayCard(1, 'Standard bay', 'Level up your game, perfect for groups of 6 per bay', '₹2,500'),
                  const SizedBox(height: 20),
                  const Text('Select time', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (int i = 0; i < _cxBookTimes.length; i++) _timeChip(i),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(22)),
                          child: const Text('View all', style: TextStyle(color: _lime, fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: _pill('Add to booking',
                  canContinue ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxBookingPaymentScreen())) : null),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 16. Select an activity to book — corporate booking entry (like normal flow)
// Mirrors the normal customer's activity picker. Activities are sample data now;
// they'll come from the admin portal / backend once wired.

class CxSelectActivityScreen extends StatefulWidget {
  const CxSelectActivityScreen({super.key});
  @override
  State<CxSelectActivityScreen> createState() => _CxSelectActivityScreenState();
}

class _CxSelectActivityScreenState extends State<CxSelectActivityScreen> {
  List<ActivityType> _acts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Api.getActivities().then((a) {
      if (mounted) setState(() { _acts = a; _loading = false; });
    }).catchError((_) {
      if (mounted) setState(() => _loading = false);
    });
  }

  // Same entry as the normal customer flow: set the activity, then open the real
  // booking screen. The corporate session pays from the wallet at checkout.
  void _open(ActivityType a) {
    BookingStore.instance.setActivity(a);
    final s = '${a.slug} ${a.name}'.toLowerCase();
    final isScreen = s.contains('screen');
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => isScreen ? const ShowsScreen() : const ActivityBookingScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(profile: true),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _lime))
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  const Text('Select an activity to book',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 18),
                  if (_acts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Text('No activities available right now.', style: TextStyle(color: _muted, fontSize: 14)),
                    ),
                  for (final a in _acts)
                    GestureDetector(
                      onTap: () => _open(a),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 6),
                                  Text(a.tagline, style: const TextStyle(color: _muted, fontSize: 13, height: 1.35)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image(image: appImg(a.image), width: 110, height: 84, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(width: 110, height: 84, color: _field)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// ── 17. Team Lead dashboard — scoped: my budget + my team + book ──────────────
// A team lead sees only their own team + allocated budget. No KYC, no wallet
// funding, no company setup (those are super-admin only).

class CxTeamLeadDashboard extends StatefulWidget {
  const CxTeamLeadDashboard({super.key});
  @override
  State<CxTeamLeadDashboard> createState() => _CxTeamLeadDashboardState();
}

class _CxTeamLeadDashboardState extends State<CxTeamLeadDashboard> {
  bool _loading = true;
  double _allocated = 0, _used = 0, _available = 0;
  String _teamName = 'My team';
  final _members = <_Member>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final budget = await Api.corporateMyBudget();
      final team = await Api.corporateMyTeam();
      final list = ((team['members'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _allocated = ((budget['totalAllocated'] ?? 0) as num).toDouble();
        _used = ((budget['totalUsed'] ?? 0) as num).toDouble();
        _available = ((budget['available'] ?? 0) as num).toDouble();
        _teamName = (team['teamName'] ?? 'My team').toString();
        _members
          ..clear()
          ..addAll(list.map((m) => _Member(
                (m['fullName'] ?? '').toString(),
                (m['email'] ?? '').toString(),
                id: (m['id'] ?? m['userId'] ?? '').toString(),
              )));
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _remove(_Member m) async {
    final idx = _members.indexOf(m);
    setState(() => _members.remove(m));
    final ok = await Api.corporateRemoveTeamMember(m.id);
    if (!ok && mounted) {
      setState(() => _members.insert(idx < 0 ? 0 : idx, m));
      _snack('Could not remove member.');
    }
  }

  Future<void> _addMember() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    var busy = false;
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 14, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Center(child: Text('Add member to my team', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
              const SizedBox(height: 18),
              _field2('Full name', 'Enter name', name),
              const SizedBox(height: 16),
              _field2('Email', 'Enter work email', email, kb: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _field2('Phone (optional)', 'Enter phone', phone, kb: TextInputType.phone),
              const SizedBox(height: 18),
              _pill(busy ? 'Adding…' : 'Add member', busy
                  ? null
                  : () async {
                      final em = email.text.trim();
                      if (name.text.trim().isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(em)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter a name and a valid email.')));
                        return;
                      }
                      setSheet(() => busy = true);
                      try {
                        await Api.corporateAddTeamMember(fullName: name.text.trim(), email: em, phone: phone.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } on ApiException catch (e) {
                        if (!ctx.mounted) return;
                        setSheet(() => busy = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                      } catch (_) {
                        if (!ctx.mounted) return;
                        setSheet(() => busy = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Could not add member. Please try again.')));
                      }
                    }),
            ],
          ),
        ),
      ),
    );
    if (added == true) _load();
  }

  Widget _budgetCard() => Container(
        margin: const EdgeInsets.only(bottom: 22),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Budget available', style: TextStyle(color: _muted, fontSize: 14)),
            const SizedBox(height: 6),
            Text('₹${_available.toStringAsFixed(0)}', style: const TextStyle(color: _lime, fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text('Allocated ₹${_allocated.toStringAsFixed(0)}   ·   Used ₹${_used.toStringAsFixed(0)}',
                style: const TextStyle(color: _muted, fontSize: 13)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _lime))
          : SafeArea(
              child: RefreshIndicator(
                color: _lime,
                backgroundColor: _card,
                onRefresh: _load,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        children: [
                          Row(
                            children: [
                              const Text('STRIKIN', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 3)),
                              const Spacer(),
                              Text(_teamName, style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 22),
                          _budgetCard(),
                          Row(
                            children: [
                              const Text('My team', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(20)),
                                child: Text('${_members.length} ${_members.length == 1 ? 'member' : 'members'}',
                                    style: const TextStyle(color: _lime, fontSize: 12, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          if (_members.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 8, bottom: 8),
                              child: Text('No members yet — add someone below.', style: TextStyle(color: _muted, fontSize: 14)),
                            )
                          else
                            ..._members.map((m) => Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(m.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 3),
                                            Text(m.email, style: const TextStyle(color: _muted, fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      IconButton(onPressed: () => _remove(m), icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20)),
                                    ],
                                  ),
                                )),
                          const SizedBox(height: 4),
                          _greyPill('+ Add member', _addMember),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: _pill('Book activity',
                          () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxSelectActivityScreen()))),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── 17b. Team lead's "My Team" — the Team tab for team leads ──────────────────
// Shows ONLY the team lead's own team (never the whole company). They can add a
// member manually or share an invite link, and remove their own members. A team
// lead cannot create other team leads (no star toggle) — that's super-admin-only.
class CxMyTeamScreen extends StatefulWidget {
  const CxMyTeamScreen({super.key});
  @override
  State<CxMyTeamScreen> createState() => _CxMyTeamScreenState();
}

class _CxMyTeamScreenState extends State<CxMyTeamScreen> {
  bool _loading = true;
  bool _inviting = false;
  String _teamName = 'My team';
  final _members = <_Member>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final team = await Api.corporateMyTeam();
      final list = ((team['members'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
      if (!mounted) return;
      setState(() {
        _teamName = (team['teamName'] ?? 'My team').toString();
        _members
          ..clear()
          ..addAll(list.map((m) => _Member(
                (m['fullName'] ?? '').toString(),
                (m['email'] ?? '').toString(),
                id: (m['id'] ?? m['userId'] ?? '').toString(),
              )));
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String s) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  }

  Future<void> _remove(_Member m) async {
    final idx = _members.indexOf(m);
    setState(() => _members.remove(m));
    final ok = await Api.corporateRemoveTeamMember(m.id);
    if (!ok && mounted) {
      setState(() => _members.insert(idx < 0 ? 0 : idx, m));
      _snack('Could not remove member.');
    }
  }

  // Generate a domain-locked invite link for THIS team lead's team and share it.
  Future<void> _inviteByLink() async {
    setState(() => _inviting = true);
    try {
      final res = await Api.corporateTeamInvite();
      final web = (res['webLink'] ?? '').toString();
      final link = web.isNotEmpty ? web : (res['deepLink'] ?? res['inviteLink'] ?? '').toString();
      final code = (res['inviteCode'] ?? '').toString();
      final shareLink = link.isNotEmpty ? link : 'code: $code';
      if (mounted) await Share.share('Join my Strikin team: $shareLink');
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not create an invite link. Try again.');
    } finally {
      if (mounted) setState(() => _inviting = false);
    }
  }

  Future<void> _addMember() async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    var busy = false;
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 14, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 44, height: 4, decoration: BoxDecoration(color: const Color(0xFF3A3A3A), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Center(child: Text('Add member to my team', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700))),
              const SizedBox(height: 18),
              _field2('Full name', 'Enter name', name),
              const SizedBox(height: 16),
              _field2('Email', 'Enter work email', email, kb: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _field2('Phone (optional)', 'Enter phone', phone, kb: TextInputType.phone),
              const SizedBox(height: 18),
              _pill(busy ? 'Adding…' : 'Add member', busy
                  ? null
                  : () async {
                      final em = email.text.trim();
                      if (name.text.trim().isEmpty || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(em)) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter a name and a valid email.')));
                        return;
                      }
                      setSheet(() => busy = true);
                      try {
                        await Api.corporateAddTeamMember(fullName: name.text.trim(), email: em, phone: phone.text.trim());
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } on ApiException catch (e) {
                        if (!ctx.mounted) return;
                        setSheet(() => busy = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.message)));
                      } catch (_) {
                        if (!ctx.mounted) return;
                        setSheet(() => busy = false);
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Could not add member. Please try again.')));
                      }
                    }),
            ],
          ),
        ),
      ),
    );
    if (added == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(title: 'Team members', profile: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _lime))
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      children: [
                        Row(
                          children: [
                            const Text('Team members', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                              decoration: BoxDecoration(color: _field, borderRadius: BorderRadius.circular(20)),
                              child: Text('${_members.length}', style: const TextStyle(color: _lime, fontSize: 12, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('Your team ($_teamName). Add members or share an invite link.', style: const TextStyle(color: _muted, fontSize: 14)),
                        const SizedBox(height: 18),
                        if (_members.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8, bottom: 8),
                            child: Text('No members yet — add someone or share the invite link.', style: TextStyle(color: _muted, fontSize: 14)),
                          )
                        else
                          ..._members.map((m) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(m.name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                          const SizedBox(height: 3),
                                          Text(m.email, style: const TextStyle(color: _muted, fontSize: 13)),
                                        ],
                                      ),
                                    ),
                                    IconButton(onPressed: () => _remove(m), icon: const Icon(Icons.delete_outline, color: Colors.white, size: 20)),
                                  ],
                                ),
                              )),
                        const SizedBox(height: 4),
                        _greyPill(_inviting ? 'Creating link…' : 'Invite by link', _inviting ? null : _inviteByLink),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: _pill('+ Add member', _addMember),
                  ),
                ],
              ),
            ),
    );
  }
}

// ── 18. Corporate app shell — Home / Team / Bookings / Settings bottom nav ────

class CxCorporateShell extends StatefulWidget {
  const CxCorporateShell({super.key});
  @override
  State<CxCorporateShell> createState() => _CxCorporateShellState();
}

class _CxCorporateShellState extends State<CxCorporateShell> {
  int _index = 0;
  final _homeKey = GlobalKey<_CxCorporateHomeState>();

  @override
  Widget build(BuildContext context) {
    // The Team tab is role-scoped: a super admin manages the WHOLE company (all
    // members, can promote team leads); a team lead sees ONLY their own team.
    final isSuperAdmin = AuthState.instance.user?.isSuperAdmin ?? false;
    final screens = [
      CxCorporateHome(key: _homeKey),
      isSuperAdmin ? const CxTeamDepartmentsScreen() : const CxMyTeamScreen(),
      const BookingsScreen(),
      const CxCorporateSettings(),
    ];
    return Scaffold(
      backgroundColor: _bg,
      body: IndexedStack(index: _index, children: screens),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xFF1A1A1A),
          indicatorColor: const Color(0x26D6FD31),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: states.contains(WidgetState.selected) ? _lime : _muted,
              )),
        ),
        child: NavigationBar(
          height: 64,
          selectedIndex: _index,
          onDestinationSelected: (i) {
            setState(() => _index = i);
            // Returning to Home re-checks KYC/wallet/team so admin-side changes appear.
            if (i == 0) _homeKey.currentState?.reload();
          },
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined, color: _muted), selectedIcon: Icon(Icons.home, color: _lime), label: 'Home'),
            NavigationDestination(icon: Icon(Icons.groups_outlined, color: _muted), selectedIcon: Icon(Icons.groups, color: _lime), label: 'Team'),
            NavigationDestination(icon: Icon(Icons.calendar_today_outlined, color: _muted), selectedIcon: Icon(Icons.calendar_today, color: _lime), label: 'Bookings'),
            NavigationDestination(icon: Icon(Icons.settings_outlined, color: _muted), selectedIcon: Icon(Icons.settings, color: _lime), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

// ── 19. Corporate Home — wallet + credit + team/invoice + upcoming + menu ─────

class CxCorporateHome extends StatefulWidget {
  const CxCorporateHome({super.key});
  @override
  State<CxCorporateHome> createState() => _CxCorporateHomeState();
}

class _CxCorporateHomeState extends State<CxCorporateHome> with WidgetsBindingObserver, RouteAware {
  bool _loading = true;
  double _available = 0, _creditUsed = 0;
  double? _creditLimit;
  int _teamCount = 0, _invoiceCount = 0;
  List<Map<String, dynamic>> _upcoming = [];
  int _kyc = 2; // 0 not-started / 1 submitted / 2 verified — super admin only
  double _allocated = 0; // total budget handed to team leads (super admin)
  List<Map<String, dynamic>> _allocations = []; // per-lead allocation rows
  bool get _isSuperAdmin => AuthState.instance.user?.isSuperAdmin ?? false;
  // Wallet money still free to hand out to team leads.
  double get _unallocated => (_available - _allocated).clamp(0, double.infinity).toDouble();

  static const _carousel = [
    'assets/images/97f99fc5e998d044.png',
    'assets/images/734475baf61e4b38.png',
    'assets/images/86da785fdc68fd9c.png',
    'assets/images/450543d2af53dc91.png',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check company/KYC/wallet when the user returns to the app — admin-side
    // changes (e.g. KYC just approved) then show up without a manual pull.
    if (state == AppLifecycleState.resumed) _load();
  }

  // Fired when a pushed flow (e.g. a booking) is popped and the dashboard is
  // visible again → re-fetch so the wallet / budget shows the new balance.
  @override
  void didPopNext() => _load();

  /// Re-fetch from the shell when the Home tab is (re)selected.
  void reload() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final u = AuthState.instance.user;
    try {
      if (u?.isSuperAdmin ?? false) {
        final w = await Api.corporateWallet();
        final d = await Api.corporateDashboard();
        final ks = ((await Api.corporateKycStatus())['kycStatus'] ?? 'verified').toString();
        final alloc = await Api.corporateBudgetAllocations();
        if (!mounted) return;
        setState(() {
          _available = ((w['totalBalance'] ?? 0) as num).toDouble();
          _creditUsed = ((w['creditUsed'] ?? 0) as num).toDouble();
          _creditLimit = (w['creditLimit'] as num?)?.toDouble();
          _teamCount = ((d['teamCount'] ?? 0) as num).toInt();
          _invoiceCount = ((d['invoiceCount'] ?? 0) as num).toInt();
          _upcoming = ((d['upcoming'] ?? []) as List).map((e) => Map<String, dynamic>.from(e)).toList();
          _kyc = ks == 'verified' ? 2 : (ks == 'submitted' ? 1 : 0);
          _allocated = ((alloc['totalAllocated'] ?? 0) as num).toDouble();
          _allocations = ((alloc['allocations'] ?? []) as List)
              .map((e) => Map<String, dynamic>.from(e))
              .where((a) => ((a['allocatedAmount'] ?? 0) as num) > 0)
              .toList();
          _loading = false;
        });
      } else {
        // Team lead: their allocated budget + their own team.
        final b = await Api.corporateMyBudget();
        final t = await Api.corporateMyTeam();
        final bookings = await Api.corporateBookings(); // already scoped to their team
        if (!mounted) return;
        setState(() {
          _available = ((b['available'] ?? 0) as num).toDouble();
          _creditUsed = ((b['totalUsed'] ?? 0) as num).toDouble();
          _creditLimit = (b['totalAllocated'] as num?)?.toDouble();
          _teamCount = ((t['members'] ?? []) as List).length;
          _upcoming = bookings.where((x) => (x['status'] ?? '').toString() == 'upcoming').toList();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _tile(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );

  static String _fmtDate(String raw) {
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  Widget _bookingCard(Map<String, dynamic> b) {
    final activity = (b['activityName'] ?? b['activity'] ?? b['bayName'] ?? 'Booking').toString();
    final date = _fmtDate((b['bookingDate'] ?? b['date'] ?? b['slotDate'] ?? '').toString());
    final who = (b['bookedBy'] ?? b['userName'] ?? b['fullName'] ?? '').toString();
    final players = ((b['numPlayers'] ?? 0) as num).toInt();
    final bays = ((b['numBays'] ?? 0) as num).toInt();
    final bay = (b['bayName'] ?? '').toString();
    final details = [
      if (bay.isNotEmpty) bay,
      if (bays > 0) '$bays ${bays == 1 ? 'bay' : 'bays'}',
      if (players > 0) '$players ${players == 1 ? 'player' : 'players'}',
    ].join(' · ');
    return Container(
      width: 250,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _cardBorder)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(activity, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(date, style: const TextStyle(color: _muted, fontSize: 13)),
          if (details.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(details, style: const TextStyle(color: _muted, fontSize: 12)),
          ],
          if (who.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.person_outline, color: _lime, size: 15),
              const SizedBox(width: 5),
              Expanded(child: Text('Booked by $who', style: const TextStyle(color: _lime, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
            ]),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: _bg, body: Center(child: CircularProgressIndicator(color: _lime)));
    }
    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        color: _lime,
        backgroundColor: _card,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, left: 20, right: 20, bottom: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF2A2A2A), Color(0xFF141414)]),
              ),
              child: const Text('STRIKIN', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 3)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KYC banner — super admin only (a team lead can't verify KYC).
                  if (_isSuperAdmin && _kyc != 2)
                    GestureDetector(
                      onTap: () async {
                        if (_kyc == 1) {
                          _load();
                          return;
                        }
                        final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const CxKycScreen()));
                        if (ok == true) _load();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14), border: Border.all(color: _lime.withValues(alpha: .55))),
                        child: Row(children: [
                          Icon(_kyc == 1 ? Icons.hourglass_top : Icons.shield_outlined, color: _kyc == 1 ? const Color(0xFFE8B64C) : _lime, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_kyc == 1 ? 'Verification pending — tap to refresh' : 'Verify your company to unlock booking',
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                          ),
                          const Icon(Icons.chevron_right, color: _muted),
                        ]),
                      ),
                    ),
                  // Wallet + credit
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(child: Text(_isSuperAdmin ? 'Corporate wallet' : 'My budget', style: const TextStyle(color: _muted, fontSize: 14))),
                          if (_isSuperAdmin)
                            GestureDetector(
                              onTap: () async {
                                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxPaymentPlanScreen()));
                                _load();
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(color: _lime, borderRadius: BorderRadius.circular(20)),
                                child: const Text('+ Add money', style: TextStyle(color: Color(0xFF141414), fontSize: 13, fontWeight: FontWeight.w800)),
                              ),
                            ),
                        ]),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('₹${_available.toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 8),
                            const Text('available', style: TextStyle(color: _muted, fontSize: 14)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text('${_isSuperAdmin ? 'Credit used' : 'Spent'}: ₹${_creditUsed.toStringAsFixed(0)} of ${_creditLimit == null ? '—' : '₹${_creditLimit!.toStringAsFixed(0)}'}',
                            style: const TextStyle(color: _muted, fontSize: 13)),
                        if (_isSuperAdmin) ...[
                          const SizedBox(height: 6),
                          Text('Allocated to team: ₹${_allocated.toStringAsFixed(0)}  ·  Free to allocate: ₹${_unallocated.toStringAsFixed(0)}',
                              style: const TextStyle(color: _muted, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(children: [
                    _tile(_isSuperAdmin ? 'Team members' : 'My team', '$_teamCount'),
                    const SizedBox(width: 16),
                    _tile('Invoice', '$_invoiceCount'),
                  ]),
                  // Super admin: who has been given budget, how much, and how much
                  // of it they've spent. Tap to allocate/adjust.
                  if (_isSuperAdmin) ...[
                    const SizedBox(height: 26),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Budget allocated', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                        GestureDetector(
                          onTap: () async {
                            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxBudgetScreen()));
                            _load();
                          },
                          child: const Text('Allocate', style: TextStyle(color: _lime, fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_allocations.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
                        child: const Text('No budget allocated yet. Tap "Allocate" to give each team lead a budget.',
                            style: TextStyle(color: _muted, fontSize: 13, height: 1.4)),
                      )
                    else
                      ..._allocations.map((a) {
                        final name = (a['teamLeadName'] ?? 'Team lead').toString();
                        final allocated = ((a['allocatedAmount'] ?? 0) as num).toDouble();
                        final used = ((a['usedAmount'] ?? 0) as num).toDouble();
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 3),
                                    Text('Spent ₹${used.toStringAsFixed(0)} of ₹${allocated.toStringAsFixed(0)}',
                                        style: const TextStyle(color: _muted, fontSize: 13)),
                                  ],
                                ),
                              ),
                              Text('₹${(allocated - used).toStringAsFixed(0)} left',
                                  style: const TextStyle(color: _lime, fontSize: 13, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        );
                      }),
                  ],
                  if (_upcoming.isNotEmpty) ...[
                    const SizedBox(height: 26),
                    const Text('Upcoming bookings', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 120,
                      child: ListView(scrollDirection: Axis.horizontal, children: _upcoming.map(_bookingCard).toList()),
                    ),
                  ],
                  const SizedBox(height: 30),
                  const Text('THE ADVENTURE MENU', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  const Text('STRIKIN is your multi-sensory map to limitless fun.', style: TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                  const SizedBox(height: 18),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _carousel.length,
                itemBuilder: (c, i) => GestureDetector(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxSelectActivityScreen())),
                  child: Container(
                    width: 240,
                    margin: const EdgeInsets.only(right: 14),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
                    child: Image.asset(_carousel[i], fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)])))),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── 20. Corporate Settings ────────────────────────────────────────────────────

class CxCorporateSettings extends StatefulWidget {
  const CxCorporateSettings({super.key});
  @override
  State<CxCorporateSettings> createState() => _CxCorporateSettingsState();
}

class _CxCorporateSettingsState extends State<CxCorporateSettings> {
  bool _offers = false;

  Widget _row(IconData icon, String label, {VoidCallback? onTap, Widget? trailing}) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
            trailing ?? const Icon(Icons.chevron_right, color: _muted),
          ]),
        ),
      );

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
      );

  void _todo(String what) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what — coming soon')));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(title: 'Settings'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            _section('Account'),
            _row(Icons.manage_accounts_outlined, 'Manage profiles', onTap: () => _todo('Manage profiles')),
            // Super-admin-only: the guided setup (payment/team/budget) + direct
            // budget allocation. This is where the "Get Ready to Book" wizard now
            // lives — reachable on demand rather than as a competing home screen.
            if (AuthState.instance.user?.isSuperAdmin ?? false) ...[
              _section('Company'),
              _row(Icons.rocket_launch_outlined, 'Company setup', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxDashboardScreen()))),
              _row(Icons.pie_chart_outline, 'Budget allocation', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxBudgetScreen()))),
            ],
            _section('Payments'),
            _row(Icons.credit_card, 'Manage payments', onTap: () {
              if (AuthState.instance.user?.isSuperAdmin ?? false) {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CxPaymentPlanScreen()));
              } else {
                _todo('Only your super admin can add funds');
              }
            }),
            _section('Notifications'),
            _row(Icons.campaign_outlined, 'Offers & updates',
                trailing: Switch(value: _offers, activeThumbColor: _lime, onChanged: (v) => setState(() => _offers = v))),
            _section('Support'),
            _row(Icons.help_outline, 'Help & FAQ', onTap: () => _todo('Help & FAQ')),
            _row(Icons.headset_mic_outlined, 'Contact support', onTap: () => _todo('Contact support')),
            _section('Legal'),
            _row(Icons.description_outlined, 'Terms & conditions', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TermsScreen()))),
            _row(Icons.verified_user_outlined, 'Privacy policy', onTap: () => _todo('Privacy policy')),
            const SizedBox(height: 16),
            _greyPill('Log out', () => AuthState.instance.logout()),
          ],
        ),
      ),
    );
  }
}

// ── Corporate team join — opened from a strikin://corporate/join/<code> link ──
// An employee fills in their details (name · position · phone · email) and is
// added to the company as a member.
class CxJoinScreen extends StatefulWidget {
  final String code;
  const CxJoinScreen({super.key, required this.code});
  @override
  State<CxJoinScreen> createState() => _CxJoinScreenState();
}

class _CxJoinScreenState extends State<CxJoinScreen> {
  final _name = TextEditingController();
  final _position = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _busy = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _position.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || phone.isEmpty || email.isEmpty) {
      setState(() => _error = 'Name, phone and email are required.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.corporateJoinByCode(widget.code,
          fullName: name, phone: phone, email: email, jobTitle: _position.text.trim().isEmpty ? null : _position.text.trim());
      if (mounted) setState(() { _done = true; _busy = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _busy = false; });
    }
  }

  Widget _input(String label, TextEditingController c, {TextInputType? kb, String? hint}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _muted, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: c,
            keyboardType: kb,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFF6A6A6A)),
              filled: true,
              fillColor: _field,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Join your team', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: _done
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.check_circle, color: _lime, size: 64),
                    const SizedBox(height: 16),
                    const Text("You're in!", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    const Text('Your account has been added to the company. Log in with your email to start booking.',
                        textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 14, height: 1.4)),
                    const SizedBox(height: 24),
                    _greyPill('Done', () => Navigator.of(context).popUntil((r) => r.isFirst)),
                  ]),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  const Text('Join your company on Strikin', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('Fill in your details to be added to your company team.', style: TextStyle(color: _muted, fontSize: 14)),
                  const SizedBox(height: 22),
                  _input('Full name', _name, hint: 'e.g. Aarav Sharma'),
                  _input('Position / role', _position, hint: 'e.g. Manager'),
                  _input('Phone number', _phone, kb: TextInputType.phone, hint: '10-digit mobile'),
                  _input('Email (mail ID)', _email, kb: TextInputType.emailAddress, hint: 'you@company.com'),
                  if (_error != null)
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Color(0xFFE57373), fontSize: 13))),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _busy ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _lime,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF141414)))
                          : const Text('Join team', style: TextStyle(color: Color(0xFF141414), fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
