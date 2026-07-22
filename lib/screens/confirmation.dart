import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../api.dart';
import '../auth.dart';
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
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, bottomSafePad(ctx, extra: AppSpacing.lg)),
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
                Api.inviteShareMessage(token),
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

  Future<void> _saveBooking(BuildContext context) async {
    final gid = AuthState.instance.user?.guestSessionId ?? '';
    if (gid.isEmpty) return;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (_) => SaveBookingSheet(guestSessionId: gid),
    );
    if (saved == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking saved to your account!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = BookingStore.instance;
    const explore = [
      'assets/images/97f99fc5e998d044.png',
      'assets/images/734475baf61e4b38.png',
      'assets/images/86da785fdc68fd9c.png',
      'assets/images/450543d2af53dc91.png',
    ];
    final subtitle =
        '${store.activity?.name ?? ''} · ${store.bays.length == 1 ? (store.bay?.name ?? '') : '${store.bays.length} bays'} · ${store.time ?? ''}';
    return AppScaffold(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Full-width green success banner (matches the corporate "Booking confirmed").
          Container(
            width: double.infinity,
            color: const Color(0xFF3E9B5F),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 22),
                SizedBox(width: 10),
                Text('Booking confirmed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Booking card: activity + QR + details + food.
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.activity?.name ?? 'Your booking', style: T.bodyStrong),
                      const SizedBox(height: 4),
                      Text(subtitle, style: T.caption),
                      const SizedBox(height: AppSpacing.lg),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(AppRadius.md)),
                          // Encodes the booking ID — the same content the venue scanner reads.
                          child: result.id.isNotEmpty
                              ? QrImageView(data: result.id, size: 170, backgroundColor: AppColors.white)
                              : const SizedBox(
                                  width: 170,
                                  height: 170,
                                  child: Center(child: Text('QR unavailable', style: TextStyle(color: Colors.black54, fontSize: 12))),
                                ),
                        ),
                      ),
                      if (result.pin.isNotEmpty) ...[
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
                              Text(result.pin, style: T.h2.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800, letterSpacing: 6)),
                            ]),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      Center(
                        child: Text(
                          result.pin.isNotEmpty
                              ? 'Show the QR code, or read out your PIN, at the entrance.'
                              : 'Show your QR code at the bay entrance to start your game.',
                          textAlign: TextAlign.center, style: T.caption),
                      ),
                      const SizedBox(height: 4),
                      const Center(
                        child: Text('Available under My Profile > Order History',
                            style: TextStyle(color: AppColors.textFaint, fontSize: 12)),
                      ),
                      const Divider(color: AppColors.border, height: AppSpacing.xl),
                      _kv('Booking ID', result.id.length > 8 ? result.id.substring(0, 8).toUpperCase() : result.id),
                      const SizedBox(height: AppSpacing.sm),
                      _kv('Amount paid', rupees(result.totalAmount)),
                      if (store.food.isNotEmpty) ...[
                        const Divider(color: AppColors.border, height: AppSpacing.xl),
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
                    ],
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.notifications_none, size: 16, color: AppColors.textFaint),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: Text('Your QR code and PIN are saved under My Profile > Order History. We\'ll remind you before your slot.', style: TextStyle(color: AppColors.textFaint, fontSize: 12))),
                ]),

                // Guest → save this booking by creating a free account.
                ListenableBuilder(
                  listenable: AuthState.instance,
                  builder: (context, _) {
                    if (AuthState.instance.user?.isGuest != true) return const SizedBox.shrink();
                    return Column(children: [
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        borderColor: AppColors.primary,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Icon(Icons.bookmark_added_outlined, color: AppColors.primary, size: 22),
                            const SizedBox(width: AppSpacing.sm),
                            const Expanded(child: Text('Save this booking', style: T.bodyStrong)),
                          ]),
                          const SizedBox(height: 4),
                          const Text('You booked as a guest. Create a free account so you can log in anytime and always keep this booking & QR.', style: T.caption),
                          const SizedBox(height: AppSpacing.md),
                          AppButton('Create account & save', onPressed: () => _saveBooking(context)),
                        ]),
                      ),
                    ]);
                  },
                ),

                // Explore other experiences
                const SizedBox(height: AppSpacing.xl),
                const Align(alignment: Alignment.centerLeft, child: Text('Explore other experiences', style: T.h3)),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 150,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: explore.length,
                    itemBuilder: (c, i) => Container(
                      width: 190,
                      margin: const EdgeInsets.only(right: 12),
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Image.asset(explore[i], fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(color: AppColors.surfaceElevated)),
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),
                AppButton('Send invite', variant: 'secondary', onPressed: () => _sendInvite(context)),
                const SizedBox(height: AppSpacing.sm),
                AppButton('Done', onPressed: () {
                  store.reset();
                  Navigator.of(context).popUntil((r) => r.isFirst);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(k, style: T.caption), Text(v, style: T.bodyStrong)],
      );
}

/// Guest → real account: register with the guest's name + phone + an email,
/// verify the OTP, then claim the guest's bookings onto the new account.
class SaveBookingSheet extends StatefulWidget {
  final String guestSessionId;
  const SaveBookingSheet({super.key, required this.guestSessionId});
  @override
  State<SaveBookingSheet> createState() => SaveBookingSheetState();
}

class SaveBookingSheetState extends State<SaveBookingSheet> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  String _step = 'email'; // email | otp
  bool _busy = false;
  String? _error, _hint;

  bool get _emailValid => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final user = AuthState.instance.user;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.register(fullName: user?.name ?? 'Guest', phone: user?.phone ?? '', email: _email.text.trim());
      setState(() {
        _busy = false;
        _step = 'otp';
        _hint = 'Code sent to ${_email.text.trim()}';
        _code.clear();
      });
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Could not send the code. Please try again.';
      });
    }
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await Api.verifyRegisterOtp(_email.text.trim(), _code.text.trim());
      final token = data['token']?.toString();
      if (token == null || token.isEmpty) {
        setState(() {
          _busy = false;
          _error = 'Verification failed. Please try again.';
        });
        return;
      }
      final user = AuthState.instance.user;
      // Log in as the new real account, then move the guest's bookings over.
      await AuthState.instance.login(AppUser(
        email: _email.text.trim(),
        name: (data['fullName'] ?? user?.name)?.toString(),
        phone: user?.phone,
        token: token,
        role: (data['role'] ?? 'b2c').toString(),
      ));
      await Api.claimGuestBookings(widget.guestSessionId);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Could not verify. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthState.instance.user;
    return Padding(
      padding: EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.lg, top: AppSpacing.lg, bottom: bottomSafePad(context, extra: AppSpacing.lg)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Save your booking', style: T.h2),
        const SizedBox(height: 6),
        Text("Creating a free account for ${user?.name ?? 'you'} (${user?.phone ?? ''}). You'll log in with your email and always keep this booking.", style: T.caption),
        const SizedBox(height: AppSpacing.lg),
        if (_step == 'email') ...[
          const Text('EMAIL ADDRESS', style: T.label),
          const SizedBox(height: AppSpacing.sm),
          AppField(icon: Icons.mail_outline, hint: 'you@email.com', controller: _email, keyboardType: TextInputType.emailAddress, onChanged: (_) => setState(() {})),
          if (_error != null) ...[const SizedBox(height: AppSpacing.md), Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))],
          const SizedBox(height: AppSpacing.lg),
          AppButton('Send code', loading: _busy, onPressed: (_emailValid && !_busy) ? _send : null),
        ] else ...[
          const Text('ENTER THE 6-DIGIT CODE', style: T.label),
          const SizedBox(height: AppSpacing.sm),
          AppField(icon: Icons.lock_outline, hint: '6-digit code', controller: _code, keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
          if (_hint != null) ...[const SizedBox(height: AppSpacing.sm), Text(_hint!, style: TextStyle(color: AppColors.primary, fontSize: 13))],
          if (_error != null) ...[const SizedBox(height: AppSpacing.md), Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13))],
          const SizedBox(height: AppSpacing.lg),
          AppButton('Verify & save booking', loading: _busy, onPressed: (_code.text.trim().length == 6 && !_busy) ? _verify : null),
          const SizedBox(height: AppSpacing.sm),
          Center(child: TextButton(onPressed: _busy ? null : () => setState(() { _step = 'email'; _error = null; }), child: const Text('Change email', style: T.caption))),
        ],
        const SizedBox(height: AppSpacing.sm),
      ]),
    );
  }
}
