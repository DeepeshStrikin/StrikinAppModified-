// Data models. Field parsing targets the vendor backend (rms-master) REST API
// at /api/v1, which uses camelCase and wraps payloads in {success, data, ...}.
// (The Api client unwraps `.data` before these fromJson factories see the map.)
// Parsers stay tolerant of the old snake_case shape so bundled mock data and any
// legacy responses still parse.

/// Parse a numeric value that may arrive as a num OR a Decimal-as-string
/// (Prisma serialises Decimal columns like totalAmount as "2950").
double toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

/// Pick the first usable image from a vendor `images` array (or a plain string).
String firstImage(dynamic images) {
  if (images is List && images.isNotEmpty && images.first != null) {
    return images.first.toString();
  }
  if (images is String) return images;
  return '';
}

class ActivityType {
  final String id, name, slug, tagline, image;
  final bool isRooftopDining;
  ActivityType({
    required this.id,
    required this.name,
    required this.slug,
    required this.tagline,
    required this.image,
    this.isRooftopDining = false,
  });
  factory ActivityType.fromJson(Map<String, dynamic> j) => ActivityType(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        slug: (j['slug'] ?? '').toString(),
        // vendor sends `description`; older shape used `tagline`.
        tagline: (j['tagline'] ?? j['description'] ?? '').toString(),
        // vendor sends `images: string[]`; older shape used `image`.
        image: (j['image']?.toString().isNotEmpty ?? false) ? j['image'].toString() : firstImage(j['images']),
        isRooftopDining: (j['isRooftopDining'] ?? j['is_rooftop_dining'] ?? false) == true,
      );
}

/// The word for the party size, by activity type:
///  - games (golf, cricket, …)         → "players"
///  - cafe / rooftop dining / restaurant → "guests"
///  - mega screen / movies / cinema     → "people"
String partyNoun(ActivityType? a, {bool plural = true}) {
  final s = '${a?.name ?? ''} ${a?.slug ?? ''}'.toLowerCase();
  final isDining = (a?.isRooftopDining ?? false) ||
      s.contains('cafe') || s.contains('dining') || s.contains('restaurant') || s.contains('rooftop');
  final isScreen = s.contains('screen') || s.contains('movie') || s.contains('cinema');
  if (isDining) return plural ? 'guests' : 'guest';
  if (isScreen) return plural ? 'people' : 'person';
  return plural ? 'players' : 'player';
}

/// Capitalised party noun for headings (Players / Guests / People).
String partyTitle(ActivityType? a) {
  final n = partyNoun(a);
  return n[0].toUpperCase() + n.substring(1);
}

/// The word for the bookable unit by activity: cafe / rooftop dining → "table",
/// mega screen → "seat", everything else (golf, cricket) → "bay".
String spaceNoun(ActivityType? a, {bool plural = false}) {
  final s = '${a?.name ?? ''} ${a?.slug ?? ''}'.toLowerCase();
  final isDining = (a?.isRooftopDining ?? false) ||
      s.contains('cafe') || s.contains('dining') || s.contains('restaurant') || s.contains('rooftop');
  final isScreen = s.contains('screen') || s.contains('movie') || s.contains('cinema');
  final base = isDining ? 'table' : (isScreen ? 'seat' : 'bay');
  return plural ? '${base}s' : base;
}

/// Capitalised bookable-unit noun for headings (Bay / Table / Seat).
String spaceTitle(ActivityType? a) {
  final n = spaceNoun(a);
  return n[0].toUpperCase() + n.substring(1);
}

class Bay {
  final String id, activityTypeId, name, bayTier, description, image;
  final double pricePerSession;
  final int maxPlayers;
  final bool allowSelect; // true = customer picks the specific (themed) bay; false = generic grid
  Bay({
    required this.id,
    required this.activityTypeId,
    required this.name,
    required this.bayTier,
    required this.pricePerSession,
    required this.maxPlayers,
    required this.description,
    this.image = '',
    this.allowSelect = true,
  });
  // Tolerant parser. The vendor's bay rows live nested inside tierGroups and
  // carry price/allowBaySelect at the TIER level — the Api client flattens those
  // into Bay objects directly, so this factory mainly serves mock data + fallbacks.
  factory Bay.fromJson(Map<String, dynamic> j) => Bay(
        id: j['id'].toString(),
        activityTypeId: (j['activityTypeId'] ?? j['activity_type_id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        bayTier: (j['bayTier'] ?? j['bay_tier'] ?? 'standard').toString(),
        pricePerSession: toDouble(j['pricePerSession'] ?? j['price_per_session']),
        maxPlayers: ((j['maxPlayers'] ?? j['max_players'] ?? 6) as num).toInt(),
        description: (j['description'] ?? '').toString(),
        image: (j['image']?.toString().isNotEmpty ?? false) ? j['image'].toString() : firstImage(j['images']),
        allowSelect: (j['allowSelect'] ?? j['allow_select'] ?? true) == true,
      );
}

class Slot {
  final String time; // 24-hour "HH:mm" — sent verbatim to lock/booking
  final bool isAvailable;
  Slot(this.time, this.isAvailable);
  factory Slot.fromJson(Map<String, dynamic> j) {
    // vendor sends `status: available|locked|booked|blocked`; older shape used `is_available`.
    final bool avail = j['status'] != null
        ? j['status'].toString() == 'available'
        : (j['is_available'] ?? true) == true;
    return Slot((j['time'] ?? '').toString(), avail);
  }
}

class FoodItem {
  final String id, name, description, category, image;
  final double price;
  FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.image,
    required this.price,
  });
  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
        id: j['id'].toString(),
        name: (j['name'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        category: (j['category'] ?? 'Food').toString(),
        // vendor sends `imageUrl`; older shape used `image`.
        image: (j['imageUrl'] ?? j['image'] ?? '').toString(),
        price: toDouble(j['price']),
      );
}

class CartFood {
  final FoodItem item;
  int quantity;
  CartFood(this.item, this.quantity);
}

/// Result of creating a booking. The vendor backend computes [totalAmount]
/// (incl. GST) server-side and returns it as a string. [qrCode] and [pin] are
/// null until the payment is verified — they're filled afterwards from
/// GET /bookings/:id/qr, hence they're mutable. [loyaltyEarned] has no source
/// in the vendor backend and is kept (zero) only so existing UI compiles.
class BookingResult {
  final String id, status;
  String qrCode;
  String pin;
  final double totalAmount;
  final int loyaltyEarned;
  BookingResult({
    required this.id,
    required this.status,
    this.qrCode = '',
    this.pin = '',
    required this.totalAmount,
    this.loyaltyEarned = 0,
  });
  factory BookingResult.fromJson(Map<String, dynamic> j) => BookingResult(
        id: (j['id'] ?? '').toString(),
        status: (j['status'] ?? 'upcoming').toString(),
        qrCode: (j['qrCode'] ?? j['qr_code'] ?? '').toString(),
        totalAmount: toDouble(j['totalAmount'] ?? j['total_amount']),
      );
}

class GuestFoodLine {
  final String name;
  final int quantity;
  final double itemTotal;
  GuestFoodLine(this.name, this.quantity, this.itemTotal);
  factory GuestFoodLine.fromJson(Map<String, dynamic> j) => GuestFoodLine(
        (j['name'] ?? j['restroworksItemName'] ?? '').toString(),
        ((j['quantity'] ?? 1) as num).toInt(),
        toDouble(j['item_total'] ?? j['itemTotal']),
      );
}

/// Read-only booking view a guest sees when opening an invite link.
/// Parsed from GET /api/v1/join/{token} (the vendor's nested shape) with a
/// fallback to the older flat shape.
class InviteBooking {
  final String token;
  final String inviteJoinNeeded; // kept for compatibility (unused placeholder)
  final String bookingId, hostName, activityName, bayName, date, time;
  final int players;
  final bool guestsMustPayForFood;
  final List<GuestFoodLine> guestFood;
  InviteBooking({
    this.token = '',
    this.inviteJoinNeeded = '',
    required this.bookingId,
    required this.hostName,
    required this.activityName,
    required this.bayName,
    required this.date,
    required this.time,
    required this.players,
    this.guestsMustPayForFood = false,
    required this.guestFood,
  });

  factory InviteBooking.fromJson(Map<String, dynamic> j) {
    // Vendor nested shape: { bookingId, guestsMustPayForFood, booking:{...,items:[...]},
    //                        bookingItem:{ activityName, bayName, slotDate, slotTime } }
    final booking = j['booking'];
    final bookingItem = j['bookingItem'];
    if (booking is Map || bookingItem is Map) {
      final items = (booking is Map ? booking['items'] : null);
      final firstItem = (items is List && items.isNotEmpty) ? items.first : null;
      String activity = '';
      String bay = '';
      if (bookingItem is Map) {
        activity = (bookingItem['activityName'] ?? '').toString();
        bay = (bookingItem['bayName'] ?? '').toString();
      }
      if (activity.isEmpty && firstItem is Map) {
        final b = firstItem['bay'];
        if (b is Map) {
          bay = (b['name'] ?? '').toString();
          final at = b['activityType'];
          if (at is Map) activity = (at['name'] ?? '').toString();
        }
      }
      String time = '';
      String date = '';
      if (bookingItem is Map) {
        time = (bookingItem['slotTime'] ?? '').toString();
        date = (bookingItem['slotDate'] ?? '').toString();
      }
      if (date.isEmpty && booking is Map) date = (booking['bookingDate'] ?? '').toString();
      return InviteBooking(
        bookingId: (j['bookingId'] ?? (booking is Map ? booking['id'] : '') ?? '').toString(),
        hostName: '',
        activityName: activity,
        bayName: bay,
        date: date,
        time: time,
        players: ((j['maxPlayers'] ?? 1) as num).toInt(),
        guestsMustPayForFood: (j['guestsMustPayForFood'] ?? false) == true,
        guestFood: const [],
      );
    }
    // Legacy flat shape.
    return InviteBooking(
      bookingId: (j['booking_id'] ?? '').toString(),
      hostName: (j['host_name'] ?? '').toString(),
      activityName: (j['activity_name'] ?? '').toString(),
      bayName: (j['bay_name'] ?? '').toString(),
      date: (j['date'] ?? '').toString(),
      time: (j['time'] ?? '').toString(),
      players: (j['players'] as num?)?.toInt() ?? 1,
      guestFood: ((j['guest_food'] ?? []) as List).map((e) => GuestFoodLine.fromJson(e)).toList(),
    );
  }
}

// ── Theatre / Mega Screen ────────────────────────────────────────────────────

/// "2026-07-02T00:00:00.000Z" or "2026-07-02" → "2026-07-02"
String _dateOnly(dynamic v) {
  final s = (v ?? '').toString();
  return s.length >= 10 ? s.substring(0, 10) : s;
}

/// "1970-01-01T18:30:00.000Z" or "18:30:00" → "18:30"
String _timeOnly(dynamic v) {
  final s = (v ?? '').toString();
  final t = s.contains('T') ? s.split('T').last : s;
  return t.length >= 5 ? t.substring(0, 5) : t;
}

/// A scheduled show on the Mega Screen (what's playing + poster + when).
class Show {
  final String id, title, showDate, startTime, status;
  final String? description, posterUrl;
  Show({
    required this.id,
    required this.title,
    required this.showDate,
    required this.startTime,
    this.status = 'upcoming',
    this.description,
    this.posterUrl,
  });
  factory Show.fromJson(Map<String, dynamic> j) => Show(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        showDate: _dateOnly(j['showDate'] ?? j['show_date']),
        startTime: _timeOnly(j['startTime'] ?? j['start_time']),
        status: (j['status'] ?? 'upcoming').toString(),
        description: j['description']?.toString(),
        posterUrl: (j['posterUrl'] ?? j['poster_url'])?.toString(),
      );
}

/// A price zone / tier (Cosm-style: "The Dome", "The Hall", "General Admission").
class SeatTier {
  final String id, name, slug;
  final String? color; // hex
  final double basePrice, fromPrice;
  final int sortOrder;
  SeatTier({
    required this.id,
    required this.name,
    required this.slug,
    required this.basePrice,
    required this.fromPrice,
    this.color,
    this.sortOrder = 0,
  });
  factory SeatTier.fromJson(Map<String, dynamic> j) => SeatTier(
        id: (j['id'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        slug: (j['slug'] ?? '').toString(),
        color: j['color']?.toString(),
        basePrice: toDouble(j['basePrice'] ?? j['base_price']),
        fromPrice: toDouble(j['fromPrice'] ?? j['from_price'] ?? j['basePrice']),
        sortOrder: (j['sortOrder'] ?? j['sort_order'] ?? 0) as int,
      );
}

/// A single, individually-priced theatre seat (price varies by view).
class SeatOption {
  final String id, section, rowLabel, seatLabel;
  final String? category, tierId;
  final double price;
  final int level, sortRow, sortCol;
  final double? posX, posY; // layout coords (0..1000); null → derive from sort
  final bool booked;
  SeatOption({
    required this.id,
    required this.section,
    required this.rowLabel,
    required this.seatLabel,
    required this.price,
    required this.sortRow,
    required this.sortCol,
    this.category,
    this.tierId,
    this.level = 1,
    this.posX,
    this.posY,
    this.booked = false,
  });
  factory SeatOption.fromJson(Map<String, dynamic> j) => SeatOption(
        id: (j['id'] ?? '').toString(),
        section: (j['section'] ?? '').toString(),
        rowLabel: (j['rowLabel'] ?? j['row_label'] ?? '').toString(),
        seatLabel: (j['seatLabel'] ?? j['seat_label'] ?? '').toString(),
        category: j['category']?.toString(),
        tierId: (j['tierId'] ?? j['tier_id'])?.toString(),
        price: toDouble(j['price']),
        level: (j['level'] ?? 1) as int,
        posX: j['posX'] != null || j['pos_x'] != null ? toDouble(j['posX'] ?? j['pos_x']) : null,
        posY: j['posY'] != null || j['pos_y'] != null ? toDouble(j['posY'] ?? j['pos_y']) : null,
        sortRow: (j['sortRow'] ?? j['sort_row'] ?? 0) as int,
        sortCol: (j['sortCol'] ?? j['sort_col'] ?? 0) as int,
        booked: (j['booked'] ?? false) == true,
      );
}

/// The full seat map for a show: header + price tiers + every seat + availability.
class ShowSeatMap {
  final String showId, title;
  final String? posterUrl;
  final List<SeatTier> tiers;
  final List<SeatOption> seats;
  ShowSeatMap({required this.showId, required this.title, this.posterUrl, required this.tiers, required this.seats});
  factory ShowSeatMap.fromJson(Map<String, dynamic> j) {
    final show = Map<String, dynamic>.from((j['show'] as Map?) ?? const {});
    final tiers = ((j['tiers'] as List?) ?? const [])
        .map((e) => SeatTier.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final seats = ((j['seats'] as List?) ?? const [])
        .map((e) => SeatOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ShowSeatMap(
      showId: (show['id'] ?? '').toString(),
      title: (show['title'] ?? '').toString(),
      posterUrl: (show['posterUrl'] ?? show['poster_url'])?.toString(),
      tiers: tiers,
      seats: seats,
    );
  }
}
