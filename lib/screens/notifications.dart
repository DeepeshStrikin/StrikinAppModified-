import 'package:flutter/material.dart';
import '../api.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';

/// In-app notification feed (booking/payment/wallet/KYC updates).
/// Reads `/api/v1/notifications`; marks everything read once viewed.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.getNotifications();
      if (!mounted) return;
      setState(() {
        _items = ((d['items'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        _loading = false;
      });
      // Mark all read now that the user has opened the feed.
      Api.markNotificationsRead().ignore();
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _icon(String type) {
    if (type.contains('payment')) return Icons.payments_outlined;
    if (type.contains('booking')) return Icons.event_available_outlined;
    if (type.contains('wallet')) return Icons.account_balance_wallet_outlined;
    if (type.contains('kyc')) return Icons.verified_user_outlined;
    if (type.contains('invoice')) return Icons.receipt_long_outlined;
    if (type.contains('credit')) return Icons.credit_score_outlined;
    if (type.contains('budget')) return Icons.pie_chart_outline;
    if (type.contains('invite')) return Icons.group_add_outlined;
    if (type.contains('offer')) return Icons.local_offer_outlined;
    if (type.contains('welcome')) return Icons.celebration_outlined;
    return Icons.notifications_none;
  }

  String _ago(String? iso) {
    if (iso == null) return '';
    final t = DateTime.tryParse(iso);
    if (t == null) return '';
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          const AppHeader(title: 'Notifications'),
          const SizedBox(height: AppSpacing.lg),
          if (_loading)
            Padding(
              padding: const EdgeInsets.only(top: 120),
              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 90),
              child: Column(children: const [
                Icon(Icons.notifications_off_outlined, size: 40, color: AppColors.textFaint),
                SizedBox(height: AppSpacing.sm),
                Text('No notifications yet', style: T.body),
                SizedBox(height: 2),
                Text('Booking and payment updates will show up here.', textAlign: TextAlign.center, style: T.caption),
              ]),
            )
          else
            ..._items.map((n) {
              final unread = n['isRead'] != true;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                      child: Icon(_icon((n['type'] ?? '').toString()), size: 20, color: AppColors.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text((n['title'] ?? 'Update').toString(), style: T.bodyStrong)),
                          if (unread)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6, top: 4),
                              decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                            ),
                        ]),
                        const SizedBox(height: 3),
                        Text((n['body'] ?? '').toString(), style: T.caption),
                        const SizedBox(height: 5),
                        Text(_ago(n['createdAt']?.toString()), style: const TextStyle(color: AppColors.textFaint, fontSize: 12)),
                      ]),
                    ),
                  ]),
                ),
              );
            }),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
