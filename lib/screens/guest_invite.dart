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
/// (paid by the guest — only their items, not the full booking amount).
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
  final _phoneCtrl = TextEditingController();
  String? _inviteJoinId; // set once the guest has joined the invite
  bool _loading = true, _submitting = false, _notFound = false;
  bool _orderSuccess = false; // show success state after adding food

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

  void _failGuest(String msg) {
    if (!mounted) return;
    setState(() => _submitting = false);
    _toast(msg);
  }

  /// Guest flow against the vendor backend: join (once) → add each food item →
  /// pay (only if the host requires guests to pay for their own food).
  Future<void> _submit() async {
    if (_cart.isEmpty) return;
    if (_nameCtrl.text.trim().isEmpty) {
      _toast('Please enter your name first');
      return;
    }
    final phoneDigits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.length != 10) {
      _toast('Please enter a valid 10-digit mobile number');
      return;
    }
    setState(() => _submitting = true);
    final guestName = _nameCtrl.text.trim();

    // 1. Join the invite once to get our inviteJoinId.
    if (_inviteJoinId == null) {
      final joinId = await Api.joinInvite(widget.token, name: guestName, phone: phoneDigits);
      if (joinId == null) {
        _failGuest('Could not join this booking — the invite may be full or expired.');
        return;
      }
      _inviteJoinId = joinId;
    }

    // 2. Add each cart item to our join.
    final items = _cart.entries
        .map((e) => MapEntry(_food.firstWhere((f) => f.id == e.key), e.value))
        .toList();
    for (final entry in items) {
      final ok = await Api.addJoinFood(widget.token, _inviteJoinId!, entry.key, entry.value);
      if (!ok) {
        _failGuest('Could not add ${entry.key.name}. Please try again.');
        return;
      }
    }

    // 3. If the host requires guests to pay for their own food, pay now.
    final mustPay = _booking?.guestsMustPayForFood ?? false;
    if (mustPay) {
      if (!Api.razorpayConfigured || !razorpayClientSupported) {
        _failGuest('Online payment is not available on this device.');
        return;
      }
      final order = await Api.joinPaymentInitiate(widget.token, _inviteJoinId!, _cartTotal);
      if (order == null) {
        _failGuest('Could not start payment. Please try again.');
        return;
      }
      final amountRupees = (order['amount'] as num?)?.toDouble() ?? _cartTotal;
      final result = await openRazorpayCheckout(
        keyId: Api.razorpayKeyId,
        orderId: (order['razorpayOrderId'] ?? '').toString(),
        amountPaise: (amountRupees * 100).round(),
        name: guestName,
        email: '',
        contact: phoneDigits,
        description: 'Food for ${_booking!.activityName}',
      );
      if (result == null) {
        _failGuest('Payment cancelled.');
        return;
      }
      final verified = await Api.joinPaymentVerify(
        widget.token,
        _inviteJoinId!,
        paymentId: result.paymentId,
        orderId: result.orderId,
        signature: result.signature,
      );
      if (!verified) {
        _failGuest('Payment could not be verified. Please try again.');
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _cart.clear();
      _orderSuccess = true;
    });
    _toast(mustPay ? 'Your food is added and paid!' : 'Your food has been added to the booking!');
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reminder that they can keep adding before paying, and only
                  // pay for their own items.
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 8),
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: const Color(0x1AD6FD31),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Add more items above if you like — you only pay for your own food, all at once.',
                            style: TextStyle(fontSize: 12, color: AppColors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppButton(
                    _submitting
                        ? 'Processing…'
                        : ((_booking?.guestsMustPayForFood ?? false)
                            ? 'Pay ${rupees(_cartTotal)} · $_cartCount item${_cartCount == 1 ? '' : 's'}'
                            : 'Add $_cartCount item${_cartCount == 1 ? '' : 's'}'),
                    loading: _submitting,
                    onPressed: _submitting ? null : _submit,
                  ),
                ],
              ),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.xl),
          const Tag("YOU'RE INVITED", tone: 'accent'),
          const SizedBox(height: AppSpacing.md),
          const Text("You're invited", style: T.h1),
          const SizedBox(height: 4),
          const Text('View the booking and add your own food below.', style: T.caption),

          // Success banner after adding food — encourages adding more
          if (_orderSuccess) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: const Color(0x1A4CAF50),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: const Color(0x554CAF50)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 20),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text('Your food was added! You can add more items below.',
                      style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13)),
                ),
              ]),
            ),
          ],

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
          const Text('Your details', style: T.h3),
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
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _phoneCtrl,
            style: T.body,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              hintText: 'Mobile number (10 digits)',
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
          const Text(
            'Tap "Add" on as many items as you like — then pay once with the button below. You only pay for your own items.',
            style: TextStyle(color: AppColors.textFaint, fontSize: 12),
          ),
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
    _phoneCtrl.dispose();
    super.dispose();
  }
}
