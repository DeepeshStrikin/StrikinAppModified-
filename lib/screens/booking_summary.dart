import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../api.dart';
import '../auth.dart';
import '../models.dart';
import '../razorpay_checkout.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

/// Booking summary opened from "My bookings" — QR, details, players & food,
/// host-pays-for-guests, invite management, and cancel.
class BookingSummaryScreen extends StatefulWidget {
  final MyBooking booking;
  const BookingSummaryScreen({super.key, required this.booking});
  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  bool _busy = false;
  Map<String, dynamic>? _game; // /bookings/{id}/game-details
  MyBooking get b => widget.booking;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final g = await Api.gameDetails(b.id);
    if (!mounted) return;
    setState(() => _game = g);
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  List<Map<String, dynamic>> get _activities =>
      ((_game?['activities'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
  List<Map<String, dynamic>> get _players =>
      ((_game?['players'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
  List<Map<String, dynamic>> get _hostFood =>
      ((_game?['hostFoodOrders'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
  double get _unpaidTotal => toDouble(_game?['unpaidTotal']);

  // ── Host pays for all guests' food ─────────────────────────────────────────────
  Future<void> _payGuestFood() async {
    if (_unpaidTotal <= 0) return;
    final isCorp = AuthState.instance.user?.isCorporate == true;
    final method = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, bottomSafePad(ctx, extra: AppSpacing.lg)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Pay for guests’ food · ${rupees(_unpaidTotal)}', style: T.h2),
          const SizedBox(height: AppSpacing.lg),
          AppButton('Pay online', onPressed: () => Navigator.pop(ctx, 'upi')),
          if (isCorp) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton('Use corporate wallet', variant: 'secondary', onPressed: () => Navigator.pop(ctx, 'wallet')),
          ],
          const SizedBox(height: AppSpacing.sm),
        ]),
      ),
    );
    if (method == null) return;
    setState(() => _busy = true);
    try {
      final res = await Api.payGuestFoodInitiate(b.id, _unpaidTotal, method: method);
      if (res == null) {
        _toast('Could not start payment.');
        return;
      }
      if (res['requiresPayment'] == true) {
        if (!Api.razorpayConfigured) {
          _toast('Online payments not configured.');
          return;
        }
        final user = AuthState.instance.user;
        final rp = await openRazorpayCheckout(
          keyId: Api.razorpayKeyId,
          orderId: (res['razorpayOrderId'] ?? '').toString(),
          amountPaise: (_unpaidTotal * 100).round(),
          name: user?.name ?? 'Strikin',
          email: user?.email ?? '',
          contact: user?.phone ?? '',
          description: 'Guest food · ${b.activity}',
          bookingId: b.id,
        );
        if (rp == null) {
          _toast('Payment cancelled.');
          return;
        }
        final ok = await Api.payGuestFoodVerify(b.id, paymentId: rp.paymentId, orderId: rp.orderId, method: method, amount: _unpaidTotal);
        if (!ok) {
          _toast('Could not verify payment.');
          return;
        }
      }
      _toast('Guests’ food paid');
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _removePlayer(Map<String, dynamic> p) async {
    final ok = await Api.removePlayer(b.id, (p['inviteJoinId'] ?? '').toString());
    if (!mounted) return;
    _toast(ok ? 'Removed ${p['name'] ?? 'player'}' : 'Could not remove (they may have paid).');
    if (ok) _load();
  }

  // ── Invites ────────────────────────────────────────────────────────────────────
  Future<void> _sendInvite() async {
    setState(() => _busy = true);
    final token = await Api.createInvite(b.id);
    setState(() => _busy = false);
    if (!mounted) return;
    if (token == null) {
      _toast('Could not create invite. Try again.');
      return;
    }
    _shareSheet(Api.inviteLink(token), token);
  }

  void _shareSheet(String link, String token) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, bottomSafePad(ctx, extra: AppSpacing.lg)),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Invite guests', style: T.h2),
          const SizedBox(height: 6),
          const Text('Share this link. Guests can view the booking and add their own food.', style: T.caption),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: AppColors.border)),
            child: Text(link, style: T.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton('Share invite', onPressed: () {
            Navigator.of(ctx).pop();
            Share.share(Api.inviteShareMessage(token), subject: 'Strikin booking invite');
          }),
          const SizedBox(height: AppSpacing.sm),
          AppButton('Copy link', variant: 'secondary', onPressed: () {
            Clipboard.setData(ClipboardData(text: link));
            Navigator.of(ctx).pop();
            _toast('Invite link copied!');
          }),
          const SizedBox(height: AppSpacing.sm),
        ]),
      ),
    );
  }

  Future<void> _manageInvites() async {
    setState(() => _busy = true);
    final invites = await Api.listInvites(b.id);
    setState(() => _busy = false);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final first = invites.isNotEmpty ? invites.first : null;
          final mustPay = first?['guestsMustPayForFood'] == true;
          return Padding(
            padding: EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.lg, bottom: bottomSafePad(ctx, extra: AppSpacing.lg)),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Manage invites', style: T.h2),
              const SizedBox(height: AppSpacing.md),
              if (invites.isEmpty)
                const Text('No active invites. Tap “Send invite” to create one.', style: T.caption)
              else
                ...invites.map((inv) {
                  final joined = inv['joinedCount'] ?? 0;
                  final cap = inv['maxPlayers'] ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(children: [
                      Expanded(child: Text('${inv['activityName'] ?? 'Invite'} · $joined joined / $cap left', style: T.caption)),
                      Tag((inv['status'] ?? 'open').toString(), tone: inv['status'] == 'open' ? 'accent' : 'neutral'),
                    ]),
                  );
                }),
              const SizedBox(height: AppSpacing.md),
              Row(children: [
                const Expanded(child: Text('Guests pay for their own food', style: T.body)),
                Switch(
                  value: mustPay,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) async {
                    final ok = await Api.updateInviteSettings(b.id, v);
                    if (ok) {
                      setSheet(() {
                        for (final inv in invites) {
                          inv['guestsMustPayForFood'] = v;
                        }
                      });
                    }
                  },
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              AppButton('Regenerate invite link', variant: 'secondary', onPressed: () async {
                final res = await Api.regenerateInvite(b.id);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                if (res != null) {
                  final newToken = (res['inviteToken'] ?? '').toString();
                  _shareSheet((res['inviteLink'] ?? Api.inviteLink(newToken)).toString(), newToken);
                } else {
                  _toast('Could not regenerate.');
                }
              }),
              const SizedBox(height: AppSpacing.sm),
            ]),
          );
        },
      ),
    );
  }

  // Cancellation policy not finalised yet — surfaced as "coming soon".
  void _cancel() => _toast('Cancellation is coming soon.');

  @override
  Widget build(BuildContext context) {
    final expired = bookingIsExpired(b);
    final cancellable = b.status == 'upcoming' && !expired;
    final hostPaid = _game?['hostPaid'] == true;
    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          const AppHeader(title: 'Booking summary'),
          const SizedBox(height: AppSpacing.lg),

          // QR + headline
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.activity, style: T.h3),
                const SizedBox(height: 4),
                Text('${b.bay} · ${b.date} · ${b.time}', style: T.caption),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
                        child: b.id.isNotEmpty
                            ? QrImageView(data: b.id, size: 170, backgroundColor: AppColors.white)
                            : const SizedBox(width: 170, height: 170, child: Center(child: Text('QR unavailable', style: TextStyle(color: Colors.black54, fontSize: 12)))),
                      ),
                      // Expired bookings keep the QR visible but clearly void it,
                      // so nobody tries to scan a code that no longer works.
                      if (expired)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xCC000000),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            alignment: Alignment.center,
                            child: const Text('EXPIRED',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2)),
                          ),
                        ),
                    ],
                  ),
                ),
                if (b.pin.isNotEmpty && !expired) ...[
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Check-in PIN', style: T.caption),
                        const SizedBox(width: 12),
                        Text(b.pin, style: T.h2.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800, letterSpacing: 6)),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Center(
                  child: Text(
                    expired
                        ? 'This booking has expired — the slot time has passed.'
                        : b.pin.isNotEmpty
                            ? 'Show the QR code, or read out your PIN, at the entrance.'
                            : 'Show your QR code at the bay entrance to start your game.',
                    textAlign: TextAlign.center,
                    style: T.caption,
                  ),
                ),
                const Divider(color: AppColors.border, height: AppSpacing.xl),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Amount', style: T.caption),
                  Text(rupees(b.amount), style: T.bodyStrong),
                ]),
                const SizedBox(height: AppSpacing.sm),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Status', style: T.caption),
                  Tag(bookingEffectiveLabel(b), tone: bookingEffectiveTone(b)),
                ]),
              ],
            ),
          ),

          // Activities
          if (_activities.isNotEmpty && cancellable) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text('Your activities', style: T.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            ..._activities.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${a['activityName'] ?? 'Activity'} · ${a['bayName'] ?? ''}', style: T.body),
                      Text('${a['numPlayers'] ?? 1} players', style: T.caption),
                    ]),
                  ),
                )),
          ],

          // Host food
          if (_hostFood.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Your food', style: T.bodyStrong),
                  Tag(hostPaid ? 'Paid' : 'Unpaid', tone: hostPaid ? 'success' : 'neutral'),
                ]),
                const SizedBox(height: AppSpacing.sm),
                for (final f in _hostFood)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Expanded(child: Text('${f['quantity'] ?? 1} × ${f['restroworksItemName'] ?? 'Item'}', style: T.caption)),
                      Text(rupees(toDouble(f['itemTotal'])), style: T.caption),
                    ]),
                  ),
              ]),
            ),
          ],

          // Players & their food
          if (_players.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text('Players', style: T.bodyStrong),
            const SizedBox(height: AppSpacing.sm),
            ..._players.map((p) {
              final paid = p['isPaid'] == true;
              final food = ((p['foodOrders'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text((p['name'] ?? 'Guest').toString(), style: T.body)),
                      Tag(paid ? 'Paid' : 'Unpaid', tone: paid ? 'success' : 'neutral'),
                      if (!paid && cancellable)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.person_remove_outlined, size: 18, color: AppColors.textMuted),
                          onPressed: _busy ? null : () => _removePlayer(p),
                        ),
                    ]),
                    for (final f in food)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Expanded(child: Text('${f['quantity'] ?? 1} × ${f['restroworksItemName'] ?? 'Item'}', style: T.caption)),
                          Text(rupees(toDouble(f['itemTotal'])), style: T.caption),
                        ]),
                      ),
                  ]),
                ),
              );
            }),
          ],

          // Host pays for guests' food
          if (_unpaidTotal > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton('Pay for guests’ food · ${rupees(_unpaidTotal)}', loading: _busy, onPressed: _busy ? null : _payGuestFood),
          ],

          // Invite
          const SizedBox(height: AppSpacing.lg),
          const Text('Invite guests', style: T.bodyStrong),
          const SizedBox(height: 4),
          const Text('Share the invite link with your guests — they can view the booking and add their own food.', style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
          const SizedBox(height: AppSpacing.md),
          AppButton(_busy ? 'Please wait…' : 'Send invite', loading: _busy, onPressed: _busy ? null : _sendInvite),
          const SizedBox(height: AppSpacing.sm),
          AppButton('Manage invites', variant: 'secondary', onPressed: _busy ? null : _manageInvites),

          if (cancellable) ...[
            const SizedBox(height: AppSpacing.sm),
            // Cancellation policy not finalised yet — surface as coming soon.
            AppButton('Cancel booking (coming soon)', variant: 'secondary', onPressed: _cancel),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}

