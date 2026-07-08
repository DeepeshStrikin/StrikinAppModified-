import 'package:flutter/material.dart';
import '../api.dart';
import '../auth.dart';
import '../models.dart';
import '../razorpay_checkout.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/reservation_timer.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import 'activity_picker.dart';
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
  // Store the booking ID so retries reuse the same booking instead of creating
  // a new one (which causes 409 Conflict on the slot).
  String? _pendingBookingId;

  // Coupon state
  final _coupon = TextEditingController();
  String? _offerId;
  double _discount = 0;
  String? _couponMsg;
  bool _couponBusy = false;

  // Loyalty redemption (1 pt = ₹1). Points are earned on confirmed payments.
  int _loyaltyBalance = 0;
  int _loyaltyApplied = 0;
  double _loyaltyDiscount = 0;
  bool _loyaltyBusy = false;

  // Payment method: 'wallet' (corporate) | 'upi' | 'card' | 'netbanking'.
  bool get _isCorporate => AuthState.instance.user?.isCorporate ?? false;
  late String _payMethod = _isCorporate ? 'wallet' : 'upi';
  bool get _useWallet => _isCorporate && _payMethod == 'wallet';
  // Map the chosen method to the backend PaymentMethod enum.
  String get _bookingMethod {
    switch (_payMethod) {
      case 'wallet':
        return 'wallet';
      case 'card':
        return 'credit_card';
      case 'netbanking':
        return 'net_banking';
      default:
        return 'upi';
    }
  }

  @override
  void initState() {
    super.initState();
    // Prefill from the logged-in profile (corporate / b2c).
    final u = AuthState.instance.user;
    if (u != null && !u.isGuest) {
      if ((u.name ?? '').isNotEmpty) _name.text = u.name!;
      if ((u.phone ?? '').isNotEmpty) _phone.text = u.phone!;
      if ((u.email ?? '').isNotEmpty) _email.text = u.email!;
    }
    _loyaltyBalance = u?.loyaltyPoints ?? 0;
  }

  Future<void> _applyLoyalty() async {
    final base = store.combinedTotal;
    final gst = base * _gstRate;
    final billBeforeLoyalty = (base + gst - _discount).clamp(0, double.infinity).toDouble();
    final maxRedeemable = billBeforeLoyalty.floor();
    final points = _loyaltyBalance < maxRedeemable ? _loyaltyBalance : maxRedeemable;
    if (points <= 0) return;
    setState(() => _loyaltyBusy = true);
    try {
      final r = await Api.redeemLoyalty(points);
      if (!mounted) return;
      setState(() {
        _loyaltyApplied = (r['pointsRedeemed'] as num?)?.toInt() ?? points;
        _loyaltyDiscount = (r['discount'] as num?)?.toDouble() ?? points.toDouble();
        _loyaltyBalance = (r['remainingPoints'] as num?)?.toInt() ?? (_loyaltyBalance - points);
        _loyaltyBusy = false;
      });
      // Refresh the session so the Profile screen shows the reduced points too.
      AuthState.instance.refreshProfile();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _loyaltyBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loyaltyBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not apply loyalty points.')));
      }
    }
  }

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
  String get _phoneDigits => _phone.text.replaceAll(RegExp(r'\D'), '');
  // Gross = pre-tax bay/food + GST (server adds GST). Payable = gross − coupon discount.
  // combinedTotal spans every activity in the multi-activity cart + the current one.
  double get _gross => store.combinedTotal * (1 + _gstRate);
  double get _payable => (_gross - _discount).clamp(0, double.infinity).toDouble();

  Future<void> _applyCoupon() async {
    final code = _coupon.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _couponBusy = true;
      _couponMsg = null;
    });
    try {
      final r = await Api.validateCoupon(
        code: code,
        bookingAmount: _gross,
        bookingType: (AuthState.instance.user?.isGuest ?? false) ? 'guest' : 'b2c',
        activityTypeIds: store.activity != null ? [store.activity!.id] : null,
      );
      setState(() {
        _couponBusy = false;
        _offerId = r['offerId']?.toString();
        _discount = (r['discountAmount'] as num?)?.toDouble() ?? 0;
        _couponMsg = _discount > 0 ? 'Coupon applied — you save ${rupees(_discount)}' : 'Coupon applied';
      });
    } on ApiException catch (e) {
      setState(() {
        _couponBusy = false;
        _offerId = null;
        _discount = 0;
        _couponMsg = e.message;
      });
    } catch (_) {
      setState(() {
        _couponBusy = false;
        _offerId = null;
        _discount = 0;
        _couponMsg = 'Could not apply coupon. Please try again.';
      });
    }
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _fail(String msg) {
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(msg);
  }

  /// Booking flow against the vendor backend:
  ///   ensure session → lock slot(s) → create booking → pay (Razorpay) → verify → fetch QR.
  Future<void> _placeOrder() async {
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

    // 1. Ensure we have a session token — create a guest session from these details if needed.
    final auth = AuthState.instance;
    final hasToken = (auth.user?.token?.isNotEmpty ?? false);
    if (!hasToken) {
      try {
        final g = await Api.guestSession(fullName: _name.text.trim(), phone: _phoneDigits);
        await auth.login(AppUser(
          isGuest: true,
          name: _name.text.trim(),
          phone: _phoneDigits,
          token: g['token']?.toString(),
          guestSessionId: g['guestSessionId']?.toString(),
        ));
      } catch (_) {
        _fail('Could not start your session. Please try again.');
        return;
      }
    }

    // 2. Lock every selected slot across all cart legs + the current activity
    //    (skip when retrying an already-created booking).
    if (_pendingBookingId == null) {
      try {
        for (final leg in store.cart) {
          for (final b in leg.bays) {
            await Api.lockSlot(b.id, leg.date, leg.time);
          }
        }
        for (final b in store.bays) {
          await Api.lockSlot(b.id, store.date, store.time!);
        }
      } on ApiException catch (e) {
        _fail(e.code == 'CONFLICT'
            ? 'That slot was just taken. Please go back and pick another time.'
            : e.message);
        return;
      } catch (_) {
        _fail('Could not reserve your slot. Please try again.');
        return;
      }
    }

    // 3. Create ONE booking covering every activity (cart legs + current) — or
    //    reuse the pending one on retry to keep the same slot locks.
    BookingResult res;
    try {
      if (_pendingBookingId != null) {
        res = BookingResult(id: _pendingBookingId!, status: 'upcoming', totalAmount: _payable);
      } else {
        res = await Api.createBookingItems(
          items: store.buildAllItems(),
          foodOrders: store.buildAllFood(),
          bookingDate: store.date,
          offerId: _offerId,
          discountAmount: (_discount + _loyaltyDiscount) > 0 ? _discount + _loyaltyDiscount : null,
          paymentMethod: _bookingMethod,
        );
        _pendingBookingId = res.id;
      }
    } on ApiException catch (e) {
      _fail(e.message);
      return;
    } catch (_) {
      _fail('Could not create your booking. Please try again.');
      return;
    }

    // 4. Initiate payment. Corporate wallet may fully cover it (instant confirm) or
    //    split to Razorpay for the remainder; online (upi) always opens Razorpay.
    final payAmount = res.totalAmount > 0 ? res.totalAmount : _payable;
    Map<String, dynamic>? order;
    try {
      order = await Api.initiatePayment(res.id, payAmount, method: _useWallet ? 'wallet' : 'upi');
    } on ApiException catch (e) {
      _fail(e.message);
      return;
    }
    if (order == null) {
      _fail('Could not start payment. Please try again.');
      return;
    }

    // requiresCheckout == true for online, or when the wallet only partly covers it.
    if (order['requiresCheckout'] == true) {
      if (!Api.razorpayConfigured) {
        _fail('Online payments are not configured. (Set RAZORPAY_KEY_ID.)');
        return;
      }
      final amountRupees = (order['amount'] as num?)?.toDouble() ?? payAmount;
      final result = await openRazorpayCheckout(
        keyId: Api.razorpayKeyId,
        orderId: order['orderId'].toString(),
        amountPaise: (amountRupees * 100).round(),
        name: _name.text.trim(),
        email: _email.text.trim(),
        contact: _phoneDigits,
        description: '${store.activity!.name} · ${store.bay!.name}',
        bookingId: res.id,
        method: _payMethod == 'card' ? 'card' : 'upi',
      );
      if (result == null) {
        _fail('Payment cancelled. Tap "Pay" to try again.');
        return;
      }
      final verified = await Api.verifyPayment(
        bookingId: res.id,
        orderId: result.orderId,
        paymentId: result.paymentId,
        signature: result.signature,
      );
      if (!verified) {
        _fail(Api.lastPaymentError ?? 'Payment could not be verified. Please try again.');
        return;
      }
    }
    // else: paid fully from the corporate wallet — already confirmed server-side.

    // 5. Fetch the QR (generated on confirmation) and finish.
    res.qrCode = await Api.getQr(res.id);
    _pendingBookingId = null;
    await store.recordBooking(res, status: 'upcoming');
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ConfirmationScreen(result: res)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final base = store.combinedTotal; // pre-tax bay + food across every activity
        final gst = base * _gstRate;
        final payable = (base + gst - _discount - _loyaltyDiscount).clamp(0, double.infinity).toDouble();
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
                                ..._activityLines(),
                                const Divider(color: AppColors.border, height: AppSpacing.xl),
                                _row('Taxable value', base, muted: true),
                                _row('GST @ 18% (CGST 9% + SGST 9%)', gst, muted: true),
                                const SizedBox(height: AppSpacing.sm),
                                // Coupon
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _coupon,
                                        style: T.body,
                                        textCapitalization: TextCapitalization.characters,
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: 'Coupon code',
                                          hintStyle: const TextStyle(color: AppColors.textFaint),
                                          filled: true,
                                          fillColor: AppColors.surface,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 12),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(AppRadius.md),
                                            borderSide: const BorderSide(color: AppColors.border),
                                          ),
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: (_couponBusy || _discount > 0) ? null : _applyCoupon,
                                      child: Text(
                                        _discount > 0 ? 'Applied' : (_couponBusy ? '…' : 'Apply'),
                                        style: TextStyle(
                                          color: _discount > 0 ? AppColors.textFaint : AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_couponMsg != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                                    child: Text(
                                      _couponMsg!,
                                      style: TextStyle(fontSize: 12, color: _discount > 0 ? AppColors.primary : const Color(0xFFE5484D)),
                                    ),
                                  ),
                                if (_discount > 0) _row('Coupon discount', -_discount, muted: true),
                                if (_loyaltyDiscount > 0) _row('Loyalty points ($_loyaltyApplied)', -_loyaltyDiscount, muted: true),
                                const Divider(color: AppColors.border, height: AppSpacing.xl),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total payable', style: T.h3),
                                    Text(rupees(payable), style: T.h3.copyWith(color: AppColors.primary)),
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
                          const SizedBox(height: AppSpacing.lg),
                          _addActivityButton(),
                          const SizedBox(height: AppSpacing.lg),
                          _paymentMethods(),
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
                            AppButton(_useWallet ? 'Pay ${rupees(payable)} from wallet' : 'Pay ${rupees(payable)}',
                                loading: _busy, onPressed: (_busy || !_valid) ? null : _placeOrder),
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

  // "Select Payment Method" — Corporate wallet (if any), UPI, card, net banking.
  // The online methods all open Razorpay (which itself lists GPay/PhonePe/etc.).
  Widget _paymentMethods() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select Payment Method', style: T.h3),
          const SizedBox(height: AppSpacing.md),
          if (_loyaltyBalance > 0 || _loyaltyApplied > 0) _loyaltyTile(),
          if (_isCorporate) _methodTile('wallet', Icons.account_balance_wallet_outlined, 'Corporate wallet'),
          _methodTile('upi', Icons.qr_code, 'UPI (GPay / PhonePe / any UPI app)'),
          _methodTile('card', Icons.credit_card, 'Credit / Debit card'),
          _methodTile('netbanking', Icons.account_balance, 'Net banking'),
        ],
      );

  Widget _loyaltyTile() {
    final applied = _loyaltyApplied > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: applied ? AppColors.primary : AppColors.border, width: applied ? 1.5 : 1),
      ),
      child: Row(children: [
        Icon(Icons.stars_rounded, color: AppColors.primary, size: 22),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Loyalty points', style: T.bodyStrong),
              Text(applied ? '$_loyaltyApplied applied' : '$_loyaltyBalance points available', style: T.caption),
            ],
          ),
        ),
        TextButton(
          onPressed: (applied || _loyaltyBusy || _loyaltyBalance <= 0) ? null : _applyLoyalty,
          child: Text(
            applied ? 'Applied' : (_loyaltyBusy ? '…' : 'Apply'),
            style: TextStyle(color: applied ? AppColors.textFaint : AppColors.primary, fontWeight: FontWeight.w600),
          ),
        ),
      ]),
    );
  }

  Widget _methodTile(String method, IconData icon, String label) {
    final sel = _payMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _payMethod = method),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: AppColors.text, size: 22),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(label, style: T.bodyStrong)),
          Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, color: sel ? AppColors.primary : AppColors.textFaint, size: 20),
        ]),
      ),
    );
  }

  // One block per configured activity: the cart legs (with a remove control),
  // then the activity currently being configured. Each block lists its bays and
  // food so the user sees exactly what they're paying for across activities.
  List<Widget> _activityLines() {
    final lines = <Widget>[];
    for (var i = 0; i < store.cart.length; i++) {
      final leg = store.cart[i];
      lines.add(_legHeader(leg.activity, onRemove: () => setState(() => store.cart.removeAt(i))));
      lines.add(_row(
        '${leg.bays.length} ${leg.bays.length == 1 ? 'bay' : 'bays'} · ${leg.players} ${partyNoun(leg.activity, plural: leg.players != 1)} · ${leg.time}',
        leg.bayTotal,
      ));
      if (leg.foodTotal > 0) _addFoodRow(lines, leg.food, leg.foodTotal);
    }
    if (store.activity != null && store.bays.isNotEmpty) {
      lines.add(_legHeader(store.activity!));
      lines.add(_row(
        '${store.bays.length} ${store.bays.length == 1 ? 'bay' : 'bays'} · ${store.players} ${partyNoun(store.activity, plural: store.players != 1)}${store.time != null ? ' · ${store.time}' : ''}',
        store.bayTotal,
      ));
      if (store.foodTotal > 0) _addFoodRow(lines, store.food, store.foodTotal);
    }
    return lines;
  }

  void _addFoodRow(List<Widget> lines, List<CartFood> food, double total) {
    final count = food.fold<int>(0, (s, f) => s + f.quantity);
    lines.add(_row('Food & beverages ($count ${count == 1 ? 'item' : 'items'})', total));
  }

  Widget _legHeader(ActivityType a, {VoidCallback? onRemove}) => Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: 4),
        child: Row(children: [
          Icon(Icons.circle, size: 6, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(a.name, style: T.bodyStrong)),
          if (onRemove != null)
            GestureDetector(
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm),
                child: Icon(Icons.close, size: 16, color: AppColors.textFaint),
              ),
            ),
        ]),
      );

  Widget _addActivityButton() => GestureDetector(
        onTap: _addAnotherActivity,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.primary),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add, color: AppColors.primary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text('Add another activity', style: T.bodyStrong.copyWith(color: AppColors.primary)),
          ]),
        ),
      );

  // Snapshot the current activity into the cart and jump to the activity picker
  // so the user can configure another activity in the same booking.
  void _addAnotherActivity() {
    if (store.activity == null || store.bays.isEmpty || store.time == null) {
      _toast('Finish selecting this activity first.');
      return;
    }
    if (_loyaltyApplied > 0) {
      _toast('Add all your activities first, then redeem loyalty points at payment.');
      return;
    }
    if (!store.addCurrentToCart()) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ActivityPickerScreen()),
      (route) => route.isFirst,
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
