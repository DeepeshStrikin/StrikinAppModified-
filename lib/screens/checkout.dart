import 'package:flutter/material.dart';
import '../api.dart';
import '../razorpay_checkout.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/reservation_timer.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import 'confirmation.dart';

const _gstRate = 0.18;

String _month(int m) =>
    const ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][m];

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final store = BookingStore.instance;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  DateTime? _dob;
  bool _busy = false;

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(1940),
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

  bool get _phoneValid => _phone.text.replaceAll(RegExp(r'\D'), '').length == 10;
  bool get _valid => _name.text.trim().isNotEmpty && _phoneValid;

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _placeOrder({bool online = true}) async {
    if (store.activity == null || store.bay == null || store.time == null) return;
    if (_name.text.trim().isEmpty) {
      _toast('Please enter your full name');
      return;
    }
    if (!_phoneValid) {
      _toast('Please enter a valid 10-digit mobile number');
      return;
    }
    setState(() => _busy = true);

    // Pay online via Razorpay when requested.
    // Always fetch config to get key_id. On web, also checks razorpay_enabled flag.
    // On mobile (stub), razorpayClientSupported is always true so we skip the enabled check.
    Map<String, dynamic> cfg = {};
    bool payOnline = false;
    if (online) {
      cfg = await Api.paymentsConfig();
      // ignore: avoid_print
      print('DEBUG baseUrl: ${Api.baseUrl}');
      // ignore: avoid_print
      print('DEBUG paymentsConfig: $cfg');
      payOnline = cfg['razorpay_enabled'] == true;
      // ignore: avoid_print
      print('DEBUG payOnline: $payOnline, razorpayClientSupported: $razorpayClientSupported');
    }

    final res = await Api.createBooking(
      activityId: store.activity!.id,
      bays: store.bays,
      date: store.date,
      time: store.time!,
      players: store.players,
      food: store.food,
      guestName: _name.text.trim(),
      guestPhone: _phone.text.trim(),
      payOnline: payOnline,
    );

    if (payOnline) {
      final order = await Api.createRazorpayOrder(store.grandTotal, res.id);
      if (order == null) {
        if (!mounted) return;
        setState(() => _busy = false);
        _toast('Could not start payment. Please try again.');
        return;
      }
      final result = await openRazorpayCheckout(
        keyId: cfg['key_id'] as String? ?? '',
        orderId: order['id'] as String,
        amountPaise: (order['amount'] as num).toInt(),
        name: _name.text.trim(),
        email: _email.text.trim(),
        contact: _phone.text.trim(),
        description: '${store.activity!.name} · ${store.bay!.name}',
        bookingId: res.id,
        method: 'upi',
      );
      if (result == null) {
        if (!mounted) return;
        setState(() => _busy = false);
        _toast('Payment cancelled.');
        return;
      }
      final verified = await Api.verifyPayment(
        bookingId: res.id,
        orderId: result.orderId,
        paymentId: result.paymentId,
        signature: result.signature,
      );
      if (!verified) {
        if (!mounted) return;
        setState(() => _busy = false);
        _toast('Payment could not be verified.');
        return;
      }
    }

    await store.recordBooking(res);
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ConfirmationScreen(result: res)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final base = store.grandTotal;
        final taxable = base / (1 + _gstRate);
        final gst = base - taxable;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg), child: AppHeader(title: 'Complete Your Payment')),
                    const ReservationTimer(),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                        children: [
                          Text('Review & confirm', style: T.h1),
                          const SizedBox(height: AppSpacing.lg),
                          AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("How you'd like to continue?", style: T.h3),
                                const SizedBox(height: 4),
                                const Text('To complete your booking we need a few quick details. A mobile number is mandatory for every participant.', style: T.caption),
                                const SizedBox(height: AppSpacing.lg),
                                AppField(icon: Icons.person_outline, hint: 'Full name', controller: _name, onChanged: (_) => setState(() {})),
                                const SizedBox(height: AppSpacing.md),
                                AppField(icon: Icons.call_outlined, hint: 'Mobile number (10 digits)', controller: _phone, keyboardType: TextInputType.phone, onChanged: (_) => setState(() {})),
                                const SizedBox(height: AppSpacing.md),
                                AppField(icon: Icons.mail_outline, hint: 'Email (optional)', controller: _email, keyboardType: TextInputType.emailAddress),
                                const SizedBox(height: AppSpacing.md),
                                GestureDetector(
                                  onTap: _pickDob,
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
                                      Expanded(
                                        child: Text(
                                          _dob == null ? 'Date of birth' : '${_dob!.day} ${_month(_dob!.month)} ${_dob!.year}',
                                          style: TextStyle(color: _dob == null ? AppColors.textFaint : AppColors.text, fontSize: 15),
                                        ),
                                      ),
                                      const Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.textFaint),
                                    ]),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                const Text('By signing up you agree to our Terms & Conditions and acknowledge the Disclaimer.', style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppCard(
                            child: Column(
                              children: [
                                const Align(alignment: Alignment.centerLeft, child: Text('Order summary', style: T.h3)),
                                const SizedBox(height: AppSpacing.md),
                                _row('${store.bays.length} ${store.bays.length == 1 ? 'bay' : 'bays'} · ${store.players} players', store.bayTotal),
                                if (store.foodTotal > 0) _row('Food & beverages', store.foodTotal),
                                const Divider(color: AppColors.border, height: AppSpacing.xl),
                                _row('Taxable value', taxable, muted: true),
                                _row('GST @ 18% (CGST 9% + SGST 9%)', gst, muted: true),
                                const Divider(color: AppColors.border, height: AppSpacing.xl),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total payable', style: T.h3),
                                    Text(rupees(base), style: T.h3.copyWith(color: AppColors.primary)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                            Icon(Icons.info_outline, size: 16, color: AppColors.textFaint),
                            SizedBox(width: AppSpacing.sm),
                            Expanded(child: Text('Free cancellation up to 24h before your slot (100% refund). Within 24h, partial refund as per policy.', style: TextStyle(color: AppColors.textFaint, fontSize: 12))),
                          ]),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        decoration: const BoxDecoration(color: AppColors.surfaceAlt, border: Border(top: BorderSide(color: AppColors.border))),
                        child: Column(
                          children: [
                            AppButton('Pay ${rupees(base)}', loading: _busy, onPressed: _busy ? null : () => _placeOrder(online: true)),
                            const SizedBox(height: AppSpacing.sm),
                            AppButton('Pay at venue', variant: 'secondary', onPressed: _busy ? null : () => _placeOrder(online: false)),
                            if (!_valid) ...[
                              const SizedBox(height: AppSpacing.sm),
                              const Text('Enter your name and a valid 10-digit mobile number to continue', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, double value, {bool muted = false}) {
    final style = muted ? T.caption : T.body;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: style)),
          Text(rupees(value), style: style),
        ],
      ),
    );
  }
}
