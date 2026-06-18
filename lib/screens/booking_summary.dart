import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../api.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

/// Booking summary opened from "My bookings" — shows the QR, details, invite & cancel.
class BookingSummaryScreen extends StatefulWidget {
  final MyBooking booking;
  const BookingSummaryScreen({super.key, required this.booking});
  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  bool _busy = false;
  List<Map<String, dynamic>> _hostFood = [];
  List<Map<String, dynamic>> _guestFood = [];
  MyBooking get b => widget.booking;

  @override
  void initState() {
    super.initState();
    _loadFood();
  }

  Future<void> _loadFood() async {
    final d = await Api.bookingDetails(b.id);
    if (!mounted || d == null) return;
    setState(() {
      _hostFood = List<Map<String, dynamic>>.from(d['host_food'] ?? []);
      _guestFood = List<Map<String, dynamic>>.from(d['guest_food'] ?? []);
    });
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _sendInvite() async {
    setState(() => _busy = true);
    final token = await Api.createInvite(b.id);
    setState(() => _busy = false);
    if (!mounted) return;
    if (token == null) {
      _toast('Could not create invite. Try again.');
      return;
    }
    final link = Api.inviteLink(token);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
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
            Share.share('Join my Strikin booking! View it and add your food: $link', subject: 'Strikin booking invite');
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

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceAlt,
        title: const Text('Cancel booking?', style: TextStyle(color: AppColors.text)),
        content: const Text('This frees the slot for others. This cannot be undone.', style: TextStyle(color: AppColors.textMuted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancel booking', style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    final done = await Api.cancelBooking(b.id);
    setState(() => _busy = false);
    if (!mounted) return;
    if (done) {
      BookingStore.instance.cancelLocal(b.id);
      _toast('Booking cancelled');
      Navigator.of(context).pop();
    } else {
      _toast('Could not cancel. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cancellable = b.status == 'upcoming';
    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          const AppHeader(title: 'Booking summary'),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.activity, style: T.h3),
                const SizedBox(height: 4),
                Text('${b.bay} · ${b.date} · ${b.time}', style: T.caption),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: QrImageView(data: b.qr, size: 170, backgroundColor: AppColors.white),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Center(child: Text('Show your QR code at the bay entrance to start your game.',
                    textAlign: TextAlign.center, style: T.caption)),
                const Divider(color: AppColors.border, height: AppSpacing.xl),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('PIN', style: T.caption),
                  Text(b.pin, style: T.h3.copyWith(color: AppColors.primary, letterSpacing: 5)),
                ]),
                const Divider(color: AppColors.border, height: AppSpacing.xl),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Amount', style: T.caption),
                  Text(rupees(b.amount), style: T.bodyStrong),
                ]),
                const SizedBox(height: AppSpacing.sm),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Status', style: T.caption),
                  Tag(b.status.toUpperCase(),
                      tone: b.status == 'upcoming' ? 'accent' : b.status == 'completed' ? 'success' : 'danger'),
                ]),
              ],
            ),
          ),

          if (_hostFood.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Food ordered', style: T.bodyStrong),
                  const SizedBox(height: AppSpacing.sm),
                  for (final f in _hostFood)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(child: Text('${f['quantity']} × ${f['name']}', style: T.caption)),
                        Text(rupees((f['total'] as num).toDouble()), style: T.caption),
                      ]),
                    ),
                ],
              ),
            ),
          ],

          if (_guestFood.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Guests added', style: T.bodyStrong),
                  const SizedBox(height: AppSpacing.sm),
                  for (final f in _guestFood)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Expanded(child: Text('${f['guest']}: ${f['quantity']} × ${f['name']}', style: T.caption)),
                        Text(rupees((f['total'] as num).toDouble()), style: T.caption),
                      ]),
                    ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          const Text('Invite guests', style: T.bodyStrong),
          const SizedBox(height: 4),
          const Text('Share the invite link to your guests. They can view the booking and add their own food (paid by them).',
              style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
          const SizedBox(height: AppSpacing.md),
          AppButton(_busy ? 'Please wait…' : 'Send invite', loading: _busy, onPressed: _busy ? null : _sendInvite),

          if (cancellable) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton('Cancel booking', variant: 'secondary', onPressed: _busy ? null : _cancel),
          ],
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
