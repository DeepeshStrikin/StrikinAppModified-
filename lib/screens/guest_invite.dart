import 'package:flutter/material.dart';
import '../api.dart';
import '../app_image.dart';
import '../models.dart';
import '../razorpay_checkout.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

/// Guest-facing screen opened from an invite link (?invite=TOKEN).
/// Shows the booking the host made, and lets the guest add their own food
/// (paid by the guest at the venue — postpaid).
class GuestInviteScreen extends StatefulWidget {
  final String token;
  const GuestInviteScreen({super.key, required this.token});

  @override
  State<GuestInviteScreen> createState() => _GuestInviteScreenState();
}

class _GuestInviteScreenState extends State<GuestInviteScreen> {
  InviteBooking? _booking;
  List<FoodItem> _food = [];
  final Map<String, int> _cart = {}; // foodId -> qty
  final _nameCtrl = TextEditingController();
  bool _loading = true, _submitting = false, _notFound = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await Api.getInvite(widget.token);
    final f = await Api.getFood();
    if (!mounted) return;
    setState(() {
      _booking = b;
      _food = f;
      _loading = false;
      _notFound = b == null;
    });
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  /// Show the full order so the guest can add/remove items and adjust quantities
  /// before paying. Payment only fires from the "Pay" button inside this sheet —
  /// so a single tap never charges them by accident.
  void _reviewAndPay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final items = _cart.entries
              .map((e) => MapEntry(_food.firstWhere((f) => f.id == e.key), e.value))
              .toList();
          void change(String id, int delta) {
            final q = (_cart[id] ?? 0) + delta;
            setState(() {
              if (q <= 0) {
                _cart.remove(id);
              } else {
                _cart[id] = q;
              }
            });
            setSheet(() {});
            if (_cart.isEmpty) Navigator.of(ctx).pop();
          }

          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.lg,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your order', style: T.h2),
                const SizedBox(height: 4),
                const Text('Add or remove items here, then pay once.', style: T.caption),
                const SizedBox(height: AppSpacing.lg),
                for (final e in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(e.key.name, style: T.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                          Text(rupees(e.key.price * e.value), style: T.caption),
                        ]),
                      ),
                      IconButton(
                        onPressed: () => change(e.key.id, -1),
                        icon: const Icon(Icons.remove_circle_outline, color: AppColors.text),
                      ),
                      Text('${e.value}', style: T.bodyStrong),
                      IconButton(
                        onPressed: () => change(e.key.id, 1),
                        icon: Icon(Icons.add_circle, color: AppColors.primary),
                      ),
                    ]),
                  ),
                const Divider(color: AppColors.border, height: AppSpacing.xl),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Total', style: T.bodyStrong),
                  Text(rupees(_cartTotal), style: T.h3),
                ]),
                const SizedBox(height: AppSpacing.lg),
                AppButton('Pay ${rupees(_cartTotal)}', onPressed: () {
                  Navigator.of(ctx).pop();
                  _submit();
                }),
                const SizedBox(height: AppSpacing.sm),
                AppButton('Add more items', variant: 'secondary', onPressed: () => Navigator.of(ctx).pop()),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (_cart.isEmpty) return;
    setState(() => _submitting = true);
    final guestName = _nameCtrl.text.trim().isEmpty ? 'Guest' : _nameCtrl.text.trim();
    final items = _cart.entries
        .map((e) => CartFood(_food.firstWhere((f) => f.id == e.key), e.value))
        .toList();

    // The guest pays for their own food online (web Razorpay) before it's added.
    final cfg = await Api.paymentsConfig();
    final payOnline = razorpayClientSupported && cfg['razorpay_enabled'] == true;
    String orderId = '', paymentId = '', signature = '';

    if (payOnline) {
      final order = await Api.createRazorpayOrder(_cartTotal, _booking!.bookingId);
      if (order == null) {
        if (!mounted) return;
        setState(() => _submitting = false);
        _toast('Could not start payment. Please try again.');
        return;
      }
      final result = await openRazorpayCheckout(
        keyId: cfg['key_id'] as String? ?? '',
        orderId: order['id'] as String,
        amountPaise: (order['amount'] as num).toInt(),
        name: guestName,
        email: '',
        contact: '',
        description: 'Food for ${_booking!.activityName}',
      );
      if (result == null) {
        if (!mounted) return;
        setState(() => _submitting = false);
        _toast('Payment cancelled.');
        return;
      }
      orderId = result.orderId;
      paymentId = result.paymentId;
      signature = result.signature;
    }

    final updated = await Api.addGuestFood(widget.token, guestName, items,
        orderId: orderId, paymentId: paymentId, signature: signature);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (updated != null) {
        _booking = updated;
        _cart.clear();
      }
    });
    _toast(updated != null
        ? 'Paid! Your food has been added to the booking.'
        : 'Could not add food. Please try again.');
  }

  double get _cartTotal => _cart.entries.fold(
      0, (s, e) => s + _food.firstWhere((f) => f.id == e.key).price * e.value);

  int get _cartCount => _cart.values.fold(0, (s, q) => s + q);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }
    if (_notFound) {
      return AppScaffold(
        child: Padding(
          padding: const EdgeInsets.only(top: 120),
          child: Column(children: [
            const Icon(Icons.link_off, color: Color(0xFF646464), size: 48),
            const SizedBox(height: AppSpacing.lg),
            Text('Invite not found', style: T.h2),
            const SizedBox(height: 6),
            Text('This invite link is invalid or has expired.', style: T.caption),
          ]),
        ),
      );
    }

    final b = _booking!;
    return AppScaffold(
      bottomBar: _cart.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: AppButton(
                _submitting
                    ? 'Processing…'
                    : 'Review order · $_cartCount item${_cartCount == 1 ? '' : 's'} · ${rupees(_cartTotal)}',
                loading: _submitting,
                onPressed: _submitting ? null : _reviewAndPay,
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const Tag("YOU'RE INVITED", tone: 'accent'),
          const SizedBox(height: AppSpacing.md),
          Text('${b.hostName} invited you', style: T.h1),
          const SizedBox(height: 4),
          const Text('View the booking and add your own food below.', style: T.caption),

          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              children: [
                _kv('Activity', b.activityName),
                const Divider(color: AppColors.border, height: AppSpacing.xl),
                _kv('Bay', b.bayName),
                const Divider(color: AppColors.border, height: AppSpacing.xl),
                _kv('When', '${b.date} · ${b.time}'),
                const Divider(color: AppColors.border, height: AppSpacing.xl),
                _kv('Players', '${b.players}'),
              ],
            ),
          ),

          if (b.guestFood.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text('Already added by guests', style: T.h3),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              child: Column(
                children: [
                  for (final g in b.guestFood)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${g.name} ×${g.quantity}', style: T.body)),
                          Text(rupees(g.itemTotal), style: T.bodyStrong),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),
          const Text('Your name', style: T.h3),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _nameCtrl,
            style: T.body,
            decoration: InputDecoration(
              hintText: 'Enter your name',
              hintStyle: const TextStyle(color: AppColors.textFaint),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          const Text('Add your food', style: T.h3),
          const SizedBox(height: 4),
          const Text('Add everything you want — you pay once, online, at the end.',
              style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
          const SizedBox(height: AppSpacing.md),
          ..._food.map(_foodRow),
        ],
      ),
    );
  }

  Widget _foodRow(FoodItem f) {
    final qty = _cart[f.id] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            if (f.image.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image(image: appImg(f.image), width: 52, height: 52, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(width: 52, height: 52, color: AppColors.surfaceElevated)),
              ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name, style: T.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(rupees(f.price), style: T.caption),
                ],
              ),
            ),
            if (qty == 0)
              TextButton(
                onPressed: () => setState(() => _cart[f.id] = 1),
                child: Text('Add', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              )
            else
              Row(children: [
                IconButton(
                  onPressed: () => setState(() {
                    if (qty <= 1) {
                      _cart.remove(f.id);
                    } else {
                      _cart[f.id] = qty - 1;
                    }
                  }),
                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.text),
                ),
                Text('$qty', style: T.bodyStrong),
                IconButton(
                  onPressed: () => setState(() => _cart[f.id] = qty + 1),
                  icon: Icon(Icons.add_circle, color: AppColors.primary),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(k, style: T.caption), Flexible(child: Text(v, style: T.bodyStrong, textAlign: TextAlign.right))],
      );

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }
}
