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
        id: j['id'],
        name: j['name'],
        slug: j['slug'],
        tagline: j['tagline'] ?? '',
        image: j['image'] ?? '',
        isRooftopDining: j['is_rooftop_dining'] ?? false,
      );
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
  factory Bay.fromJson(Map<String, dynamic> j) => Bay(
        id: j['id'],
        activityTypeId: j['activity_type_id'],
        name: j['name'],
        bayTier: j['bay_tier'] ?? 'standard',
        pricePerSession: (j['price_per_session'] as num).toDouble(),
        maxPlayers: j['max_players'] ?? 6,
        description: j['description'] ?? '',
        image: j['image'] ?? '',
        allowSelect: j['allow_select'] ?? true,
      );
}

class Slot {
  final String time;
  final bool isAvailable;
  Slot(this.time, this.isAvailable);
  factory Slot.fromJson(Map<String, dynamic> j) => Slot(j['time'], j['is_available'] ?? true);
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
        id: j['id'],
        name: j['name'],
        description: j['description'] ?? '',
        category: j['category'] ?? 'Burgers',
        image: j['image'] ?? '',
        price: (j['price'] as num).toDouble(),
      );
}

class CartFood {
  final FoodItem item;
  int quantity;
  CartFood(this.item, this.quantity);
}

class BookingResult {
  final String id, qrCode, pin, status;
  final double totalAmount;
  final int loyaltyEarned;
  BookingResult({
    required this.id,
    required this.qrCode,
    required this.pin,
    required this.status,
    required this.totalAmount,
    required this.loyaltyEarned,
  });
  factory BookingResult.fromJson(Map<String, dynamic> j) => BookingResult(
        id: j['id'],
        qrCode: j['qr_code'],
        pin: j['pin'],
        status: j['status'] ?? 'upcoming',
        totalAmount: (j['total_amount'] as num).toDouble(),
        loyaltyEarned: (j['loyalty_earned'] as num).toInt(),
      );
}

class GuestFoodLine {
  final String name;
  final int quantity;
  final double itemTotal;
  GuestFoodLine(this.name, this.quantity, this.itemTotal);
  factory GuestFoodLine.fromJson(Map<String, dynamic> j) =>
      GuestFoodLine(j['name'] ?? '', (j['quantity'] as num).toInt(), (j['item_total'] as num).toDouble());
}

/// Read-only booking view a guest sees when opening an invite link.
class InviteBooking {
  final String bookingId, hostName, activityName, bayName, date, time;
  final int players;
  final List<GuestFoodLine> guestFood;
  InviteBooking({
    required this.bookingId,
    required this.hostName,
    required this.activityName,
    required this.bayName,
    required this.date,
    required this.time,
    required this.players,
    required this.guestFood,
  });
  factory InviteBooking.fromJson(Map<String, dynamic> j) => InviteBooking(
        bookingId: j['booking_id'] ?? '',
        hostName: j['host_name'] ?? '',
        activityName: j['activity_name'] ?? '',
        bayName: j['bay_name'] ?? '',
        date: (j['date'] ?? '').toString(),
        time: j['time'] ?? '',
        players: (j['players'] as num?)?.toInt() ?? 1,
        guestFood: ((j['guest_food'] ?? []) as List).map((e) => GuestFoodLine.fromJson(e)).toList(),
      );
}
