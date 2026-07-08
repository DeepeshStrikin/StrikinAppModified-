import 'dart:convert';
import 'package:flutter/material.dart';
import '../api.dart';
import '../app_image.dart';
import '../auth.dart';
import '../models.dart';
import '../razorpay_checkout.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/scaffold.dart';
import '../widgets/ui.dart';
import 'confirmation.dart';

const _wd = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _mo = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "2026-07-02" → "Thu, 2 Jul"
String _prettyDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${_wd[d.weekday % 7]}, ${d.day} ${_mo[d.month]}';
}

/// "18:30" → "6:30 PM"
String _pretty12h(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return hhmm;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = parts[1];
  final ampm = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:$m $ampm';
}

/// Poster image provider that also handles base64 data URLs (admin uploads).
ImageProvider _posterProvider(String url) {
  if (url.startsWith('data:')) {
    final i = url.indexOf(',');
    return MemoryImage(base64Decode(i >= 0 ? url.substring(i + 1) : url));
  }
  return appImg(url);
}

/// Mega Screen entry: a list of upcoming shows (posters). Tap → seat picker.
class ShowsScreen extends StatefulWidget {
  const ShowsScreen({super.key});
  @override
  State<ShowsScreen> createState() => _ShowsScreenState();
}

class _ShowsScreenState extends State<ShowsScreen> {
  final store = BookingStore.instance;
  List<Show>? _shows;

  @override
  void initState() {
    super.initState();
    final act = store.activity;
    if (act != null) {
      Api.getShows(act.id).then((s) {
        if (mounted) setState(() => _shows = s);
      });
    } else {
      _shows = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final shows = _shows;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                const Padding(padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg), child: AppHeader()),
                Expanded(
                  child: shows == null
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : shows.isEmpty
                          ? _empty()
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
                              children: [
                                Text('What\'s on', style: T.h1),
                                const SizedBox(height: 4),
                                const Text('Pick a show, then choose your seats.',
                                    style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
                                const SizedBox(height: AppSpacing.lg),
                                ...shows.map(_showCard),
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.movie_outlined, size: 48, color: AppColors.textFaint),
              const SizedBox(height: AppSpacing.md),
              Text('No shows scheduled yet', style: T.h3),
              const SizedBox(height: 6),
              const Text('Check back soon — new shows are added regularly.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textFaint, fontSize: 14)),
            ],
          ),
        ),
      );

  Widget _showCard(Show s) {
    final poster = s.posterUrl ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SeatPickerScreen(show: s))),
        child: AppCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: poster.isEmpty
                      ? Container(
                          color: AppColors.surfaceElevated,
                          child: const Center(child: Icon(Icons.movie_creation_outlined, size: 40, color: AppColors.textFaint)),
                        )
                      : Image(
                          image: _posterProvider(poster),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: AppColors.surfaceElevated,
                            child: const Center(child: Icon(Icons.broken_image_outlined, color: AppColors.textFaint)),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title, style: T.h3),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(Icons.event, size: 15, color: AppColors.textFaint),
                        const SizedBox(width: 6),
                        Text('${_prettyDate(s.showDate)} · ${_pretty12h(s.startTime)}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      ]),
                      if ((s.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(s.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.caption),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Seat map for one show: colour-coded by price, tap to select, then book + pay.
class SeatPickerScreen extends StatefulWidget {
  final Show show;
  const SeatPickerScreen({super.key, required this.show});
  @override
  State<SeatPickerScreen> createState() => _SeatPickerScreenState();
}

class _SeatPickerScreenState extends State<SeatPickerScreen> {
  final store = BookingStore.instance;
  ShowSeatMap? _map;
  final Set<String> _selected = {};
  bool _busy = false;
  String? _filterTier; // tapped tier filter (dims other zones)
  final TransformationController _tc = TransformationController();
  bool _didFit = false;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  // distinct prices (ascending) → palette colour (fallback when a seat has no tier)
  List<double> _priceTiers = [];
  static const _palette = [
    Color(0xFF8AADF4), // blue
    Color(0xFFA6DA95), // green
    Color(0xFFEED49F), // yellow
    Color(0xFFF5A97F), // orange
    Color(0xFFF5BDE6), // pink
    Color(0xFF8BD5CA), // teal
  ];

  @override
  void initState() {
    super.initState();
    Api.getShowSeats(widget.show.id).then((m) {
      if (!mounted) return;
      setState(() {
        _map = m;
        _priceTiers = m == null ? [] : (m.seats.map((s) => s.price).toSet().toList()..sort());
      });
    });
  }

  Color _priceColor(double price) {
    final i = _priceTiers.indexOf(price);
    if (i < 0) return _palette.first;
    return _palette[i % _palette.length];
  }

  List<SeatOption> get _selectedSeats =>
      (_map?.seats ?? []).where((s) => _selected.contains(s.id)).toList();

  double get _total => _selectedSeats.fold<double>(0, (a, s) => a + s.price);

  void _toggle(SeatOption s) {
    if (s.booked) return;
    setState(() {
      if (_selected.contains(s.id)) {
        _selected.remove(s.id);
      } else {
        _selected.add(s.id);
      }
    });
  }

  void _toast(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _fail(String m) {
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(m);
  }

  @override
  Widget build(BuildContext context) {
    final map = _map;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: AppHeader(title: widget.show.title),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('${_prettyDate(widget.show.showDate)} · ${_pretty12h(widget.show.startTime)}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ),
                ),
                if (map != null && map.tiers.isNotEmpty) _tierBar(map),
                Expanded(
                  child: map == null
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : Container(
                          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.border),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _seatMap(map),
                        ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Pinch to zoom · drag to pan', style: TextStyle(color: AppColors.textFaint, fontSize: 11)),
                ),
                _bottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Cosm-style price-zone chips (colour + name + "From ₹X"). Tap to focus a zone.
  Widget _tierBar(ShowSeatMap map) => SizedBox(
        height: 60,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 6, AppSpacing.lg, 6),
          children: [for (final t in map.tiers) _tierChip(t)],
        ),
      );

  Widget _tierChip(SeatTier t) {
    final active = _filterTier == t.id;
    final c = _hexColor(t.color) ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _filterTier = active ? null : t.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? c.withOpacity(0.22) : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: active ? c : AppColors.border, width: active ? 2 : 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.name, style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('From ${rupees(t.fromPrice)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _seatMap(ShowSeatMap map) {
    final positions = _computePositions(map.seats);
    double minX = 1e9, maxX = 0, maxY = 300;
    for (final o in positions.values) {
      if (o.dx < minX) minX = o.dx;
      if (o.dx > maxX) maxX = o.dx;
      if (o.dy > maxY) maxY = o.dy;
    }
    if (minX > maxX) minX = 0;
    final seatCenterX = (minX + maxX) / 2;
    final canvasW = maxX + 60;
    final canvasH = maxY + 60;
    return LayoutBuilder(
      builder: (ctx, cons) {
        if (!_didFit && cons.maxWidth.isFinite) {
          _didFit = true;
          final fit = (cons.maxWidth / canvasW).clamp(0.25, 1.0);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _tc.value = Matrix4.diagonal3Values(fit, fit, 1);
          });
        }
        return InteractiveViewer(
          transformationController: _tc,
          constrained: false,
          minScale: 0.25,
          maxScale: 4,
          boundaryMargin: const EdgeInsets.all(400),
          child: SizedBox(
            width: canvasW,
            height: canvasH,
            child: Stack(
              children: [
                Positioned(
                  top: 6,
                  left: seatCenterX - 150,
                  width: 300,
                  height: 32,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.05), AppColors.primary.withOpacity(0.4), AppColors.primary.withOpacity(0.05)]),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(120)),
                      border: Border(top: BorderSide(color: AppColors.primary, width: 2)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('SCREEN', style: TextStyle(color: AppColors.textMuted, fontSize: 10, letterSpacing: 4)),
                  ),
                ),
                for (final s in map.seats)
                  if (positions[s.id] != null)
                    Positioned(
                      left: positions[s.id]!.dx - 13,
                      top: positions[s.id]!.dy - 13,
                      child: _seatDot(s, map),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _seatDot(SeatOption s, ShowSeatMap map) {
    final sel = _selected.contains(s.id);
    final dim = _filterTier != null && s.tierId != _filterTier;
    final c = _seatColor(s, map);
    final label = RegExp(r'\d+$').firstMatch(s.seatLabel)?.group(0) ?? s.seatLabel;
    Color bg, border, fg;
    if (s.booked) {
      bg = AppColors.surfaceElevated;
      border = AppColors.border;
      fg = AppColors.textFaint;
    } else if (sel) {
      bg = AppColors.primary;
      border = AppColors.primary;
      fg = AppColors.textOnAccent;
    } else {
      bg = c.withOpacity(0.30);
      border = c;
      fg = AppColors.text;
    }
    return Opacity(
      opacity: s.booked ? 0.4 : (dim ? 0.22 : 1),
      child: GestureDetector(
        onTap: (s.booked || dim) ? null : () => _toggle(s),
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border, width: sel ? 2 : 1),
          ),
          child: s.booked
              ? const Icon(Icons.close, size: 11, color: AppColors.textFaint)
              : Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: fg)),
        ),
      ),
    );
  }

  Color _seatColor(SeatOption s, ShowSeatMap map) {
    if (s.tierId != null) {
      for (final t in map.tiers) {
        if (t.id == s.tierId) return _hexColor(t.color) ?? _priceColor(s.price);
      }
    }
    return _priceColor(s.price);
  }

  /// Canvas position for each seat: real posX/posY when present, else a curved
  /// theatre fan derived from sortRow/sortCol (until the real plan is loaded).
  Map<String, Offset> _computePositions(List<SeatOption> seats) {
    final out = <String, Offset>{};
    final rows = <int, List<SeatOption>>{};
    for (final s in seats) {
      (rows[s.sortRow] ??= []).add(s);
    }
    final rowKeys = rows.keys.toList()..sort();
    for (int ri = 0; ri < rowKeys.length; ri++) {
      final rowSeats = rows[rowKeys[ri]]!..sort((a, b) => a.sortCol.compareTo(b.sortCol));
      final n = rowSeats.length;
      const gap = 30.0;
      final y = 90.0 + ri * 64.0;
      for (int i = 0; i < n; i++) {
        final s = rowSeats[i];
        if (s.posX != null && s.posY != null) {
          out[s.id] = Offset(s.posX!, s.posY!);
          continue;
        }
        final x = 500.0 + (i - (n - 1) / 2) * gap;
        final normX = n > 1 ? (i - (n - 1) / 2) / ((n - 1) / 2) : 0.0;
        out[s.id] = Offset(x, y - normX * normX * 28.0);
      }
    }
    return out;
  }

  Color? _hexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var h = hex.replaceFirst('#', '');
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? null : Color(v);
  }

  Widget _bottomBar() {
    final n = _selected.length;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: const BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(n == 0 ? 'Select your seats' : '$n ${n == 1 ? 'seat' : 'seats'} selected', style: T.caption),
                Text(rupees(_total), style: T.h3.copyWith(color: AppColors.primary)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(n == 0 ? 'Book & Pay' : 'Book & Pay ${rupees(_total)}',
                loading: _busy, onPressed: (_busy || n == 0) ? null : _bookAndPay),
          ],
        ),
      ),
    );
  }

  Future<void> _bookAndPay() async {
    final seatIds = _selectedSeats.map((s) => s.id).toList();
    if (seatIds.isEmpty) return;
    setState(() => _busy = true);

    // 1. Ensure a session + contact details (guests give name + phone once).
    final auth = AuthState.instance;
    final u = auth.user;
    var name = u?.name ?? '';
    var phone = u?.phone ?? '';
    var email = u?.email ?? '';
    final hasToken = (u?.token?.isNotEmpty ?? false);
    if (!hasToken || name.isEmpty || phone.length < 10) {
      final d = await _collectDetails(name: name, phone: phone, email: email);
      if (d == null) {
        setState(() => _busy = false);
        return;
      }
      name = d['name']!;
      phone = d['phone']!;
      email = d['email'] ?? '';
      if (!hasToken) {
        try {
          final g = await Api.guestSession(fullName: name, phone: phone);
          await auth.login(AppUser(
            isGuest: true,
            name: name,
            phone: phone,
            token: g['token']?.toString(),
            guestSessionId: g['guestSessionId']?.toString(),
          ));
        } catch (_) {
          _fail('Could not start your session. Please try again.');
          return;
        }
      }
    }

    // 2. Create the seat booking.
    Map<String, dynamic> booking;
    try {
      booking = await Api.bookShowSeats(widget.show.id, seatIds);
    } on ApiException catch (e) {
      if (e.code == 'CONFLICT') {
        // Some seats were taken — refresh the map so the user re-picks.
        final fresh = await Api.getShowSeats(widget.show.id);
        if (mounted && fresh != null) {
          setState(() {
            _map = fresh;
            _selected.clear();
          });
        }
      }
      _fail(e.message);
      return;
    } catch (_) {
      _fail('Could not reserve your seats. Please try again.');
      return;
    }

    final bookingId = (booking['bookingId'] ?? '').toString();
    final amount = (booking['amount'] as num?)?.toDouble() ?? _total;
    if (bookingId.isEmpty) {
      _fail('Booking failed. Please try again.');
      return;
    }

    // 3. Pay (Razorpay) → verify. Reuses the standard booking payment endpoints.
    //    On any failure below, release the held seats so they free up immediately.
    Map<String, dynamic>? order;
    try {
      order = await Api.initiatePayment(bookingId, amount, method: 'upi');
    } on ApiException catch (e) {
      await Api.releaseShowSeats(bookingId);
      _fail(e.message);
      return;
    }
    if (order == null) {
      await Api.releaseShowSeats(bookingId);
      _fail('Could not start payment. Please try again.');
      return;
    }
    if (order['requiresCheckout'] == true) {
      if (!Api.razorpayConfigured) {
        await Api.releaseShowSeats(bookingId);
        _fail('Online payments are not configured. (Set RAZORPAY_KEY_ID.)');
        return;
      }
      final amountRupees = (order['amount'] as num?)?.toDouble() ?? amount;
      final result = await openRazorpayCheckout(
        keyId: Api.razorpayKeyId,
        orderId: order['orderId'].toString(),
        amountPaise: (amountRupees * 100).round(),
        name: name,
        email: email,
        contact: phone,
        description: '${store.activity?.name ?? 'Mega Screen'} · ${widget.show.title}',
        bookingId: bookingId,
        method: 'upi',
      );
      if (result == null) {
        await Api.releaseShowSeats(bookingId);
        _fail('Payment cancelled. Your seats were released — tap "Book & Pay" to try again.');
        return;
      }
      final ok = await Api.verifyPayment(
        bookingId: bookingId,
        orderId: result.orderId,
        paymentId: result.paymentId,
        signature: result.signature,
      );
      if (!ok) {
        _fail(Api.lastPaymentError ?? 'Payment could not be verified. Please try again.');
        return;
      }
    }

    // 4. Fetch the QR, record locally, and show the ticket.
    final qr = await Api.getQr(bookingId);
    final res = BookingResult(id: bookingId, status: 'upcoming', totalAmount: amount, qrCode: qr);
    await store.recordBookingRow(MyBooking(
      id: bookingId,
      activity: store.activity?.name ?? 'Mega Screen',
      bay: '${seatIds.length} ${seatIds.length == 1 ? 'seat' : 'seats'} · ${widget.show.title}',
      date: widget.show.showDate,
      time: widget.show.startTime,
      status: 'upcoming',
      qr: qr,
      pin: '',
      amount: amount,
      loyalty: 0,
      createdAtMs: DateTime.now().millisecondsSinceEpoch,
    ));
    if (!mounted) return;
    setState(() => _busy = false);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ConfirmationScreen(result: res)));
  }

  /// Bottom sheet collecting name + phone (+ optional email) for guests.
  Future<Map<String, String>?> _collectDetails({required String name, required String phone, required String email}) {
    final nameC = TextEditingController(text: name);
    final phoneC = TextEditingController(text: phone);
    final emailC = TextEditingController(text: email);
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceAlt,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(width: 44, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Your details', style: T.h2),
              const SizedBox(height: 4),
              const Text('We need a name and mobile number to hold your seats.',
                  style: TextStyle(color: AppColors.textFaint, fontSize: 13)),
              const SizedBox(height: AppSpacing.lg),
              AppField(icon: Icons.person_outline, hint: 'Full name', controller: nameC),
              const SizedBox(height: AppSpacing.md),
              AppField(icon: Icons.call_outlined, hint: 'Mobile number (10 digits)', controller: phoneC, keyboardType: TextInputType.phone),
              const SizedBox(height: AppSpacing.md),
              AppField(icon: Icons.mail_outline, hint: 'Email (optional)', controller: emailC, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: AppSpacing.lg),
              AppButton('Continue to payment', onPressed: () {
                final n = nameC.text.trim();
                final p = phoneC.text.replaceAll(RegExp(r'\D'), '');
                if (n.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please enter your name')));
                  return;
                }
                if (p.length != 10) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Enter a valid 10-digit mobile number')));
                  return;
                }
                Navigator.pop(ctx, {'name': n, 'phone': p, 'email': emailC.text.trim()});
              }),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        );
      },
    );
  }
}
