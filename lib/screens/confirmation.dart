import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../api.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

class ConfirmationScreen extends StatelessWidget {
  final BookingResult result;
  const ConfirmationScreen({super.key, required this.result});

  Future<void> _sendInvite(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator(color: AppColors.primary)),
    );
    final token = await Api.createInvite(result.id);
    if (context.mounted) Navigator.of(context).pop(); // close spinner
    if (!context.mounted) return;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create invite. Try again.')),
      );
      return;
    }
    final link = Api.inviteLink(token);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceAlt,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Invite guests', style: T.h2),
            const SizedBox(height: 6),
            const Text('Share this link. Guests can view the booking and add their own food.',
                style: T.caption),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(link, style: T.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton('Share invite', onPressed: () {
              Navigator.of(ctx).pop();
              Share.share(
                'Join my Strikin booking! View it and add your food here: $link',
                subject: 'Strikin booking invite',
              );
            }),
            const SizedBox(height: AppSpacing.sm),
            AppButton('Copy link', variant: 'secondary', onPressed: () {
              Clipboard.setData(ClipboardData(text: link));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Invite link copied!')),
              );
            }),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = BookingStore.instance;
    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: AppColors.textOnAccent, size: 40),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Center(child: Text('Booking confirmed!', style: T.h1)),
          const SizedBox(height: 4),
          Center(child: Text('${store.activity?.name} · ${store.bays.length == 1 ? store.bay?.name : '${store.bays.length} bays'} · ${store.time}', style: T.caption)),

          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              children: [
                const Tag('SCAN AT YOUR BAY TO START', tone: 'success'),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: QrImageView(data: result.qrCode, size: 180, backgroundColor: AppColors.white),
                ),
                const Divider(color: AppColors.border, height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Or enter PIN at the bay', style: T.caption),
                    Text(result.pin, style: T.h2.copyWith(color: AppColors.primary, letterSpacing: 6)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              children: [
                _kv('Booking ID', result.id),
                const Divider(color: AppColors.border, height: AppSpacing.xl),
                _kv('Amount paid', rupees(result.totalAmount)),
                const Divider(color: AppColors.border, height: AppSpacing.xl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Icon(Icons.diamond, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      const Text('Loyalty earned', style: T.caption),
                    ]),
                    Text('+${result.loyaltyEarned} pts', style: T.bodyStrong.copyWith(color: AppColors.primary)),
                  ],
                ),
              ],
            ),
          ),

          // Food ordered (matches the booking-summary design)
          if (store.food.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Food ordered', style: T.bodyStrong),
                  const SizedBox(height: AppSpacing.sm),
                  ...store.food.map((f) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${f.quantity} × ${f.item.name}', style: T.caption),
                            Text(rupees(f.item.price * f.quantity), style: T.caption),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.lg),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            Icon(Icons.notifications_none, size: 16, color: AppColors.textFaint),
            SizedBox(width: AppSpacing.sm),
            Expanded(child: Text('QR & PIN sent via Email / SMS / WhatsApp. We\'ll remind you before your slot, and 15 min before it ends you can extend if the next slot is free.', style: TextStyle(color: AppColors.textFaint, fontSize: 12))),
          ]),

          const SizedBox(height: AppSpacing.xl),
          AppButton('Send invite', variant: 'secondary', onPressed: () => _sendInvite(context)),
          const SizedBox(height: AppSpacing.sm),
          AppButton('Done', onPressed: () {
            store.reset();
            Navigator.of(context).popUntil((r) => r.isFirst);
          }),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(k, style: T.caption), Text(v, style: T.bodyStrong)],
      );
}
