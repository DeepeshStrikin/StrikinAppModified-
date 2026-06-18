import 'models.dart';

/// Bundled fallback data so the UI renders even if the backend is unreachable.
final mockActivities = [
  ActivityType(id: 'act_golf', name: 'Golf', slug: 'golf', isRooftopDining: false, tagline: 'VVIP & standard simulator bays — hourly play, no hit limit', image: 'https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=900&q=80'),
  ActivityType(id: 'act_cricket', name: 'Cricket', slug: 'cricket', tagline: 'Batting nets & bowling lanes with live speed tracking', image: 'https://images.unsplash.com/photo-1531415074968-036ba1b575da?w=900&q=80'),
  ActivityType(id: 'act_dining', name: 'Rooftop Dining', slug: 'rooftop-dining', isRooftopDining: true, tagline: 'The Adventure Menu — skyline views & craft plates', image: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=900&q=80'),
  ActivityType(id: 'act_screening', name: 'Private Screening', slug: 'screening', tagline: 'Book the big screen for your crew', image: 'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?w=900&q=80'),
];

// Mirrors backend/app/seed.py exactly — Standard / VIP / VVIP only (no Gold), so the
// fallback shown when the backend is slow/unreachable matches the live catalog.
final mockBays = <String, List<Bay>>{
  'act_golf': [
    Bay(id: 'bay_golf_std', activityTypeId: 'act_golf', name: 'Standard Bay', bayTier: 'standard', pricePerSession: 2500, maxPlayers: 6, description: 'Level up your game — perfect for groups of 6', image: 'https://images.unsplash.com/photo-1535131749006-b7f58c99034b?w=600&q=80'),
    Bay(id: 'bay_golf_vip', activityTypeId: 'act_golf', name: 'VIP Bay', bayTier: 'vip', pricePerSession: 3800, maxPlayers: 8, description: 'Premium turf, lounge seating & a dedicated host', image: 'https://images.unsplash.com/photo-1587174486073-ae5e5cff23aa?w=600&q=80'),
    Bay(id: 'bay_golf_four_seasons', activityTypeId: 'act_golf', name: 'Four Seasons Room', bayTier: 'vvip', pricePerSession: 5000, maxPlayers: 10, description: 'All four seasons, one sensory bay', image: 'https://images.unsplash.com/photo-1592919505780-303950717480?w=600&q=80'),
    Bay(id: 'bay_golf_space', activityTypeId: 'act_golf', name: 'Space Room', bayTier: 'vvip', pricePerSession: 5000, maxPlayers: 10, description: 'Interstellar luxury bay', image: 'https://images.unsplash.com/photo-1611374243147-44a702c2d44c?w=600&q=80'),
  ],
  'act_cricket': [
    Bay(id: 'bay_cricket_std', activityTypeId: 'act_cricket', name: 'Standard Net', bayTier: 'standard', pricePerSession: 2500, maxPlayers: 6, description: 'Level up your game — perfect for groups of 6', image: 'https://images.unsplash.com/photo-1531415074968-036ba1b575da?w=600&q=80'),
    Bay(id: 'bay_cricket_vip', activityTypeId: 'act_cricket', name: 'VIP Net', bayTier: 'vip', pricePerSession: 3500, maxPlayers: 6, description: 'Pro-grade net with bowling machine & analytics', image: 'https://images.unsplash.com/photo-1540747913346-19e32dc3e97e?w=600&q=80'),
    Bay(id: 'bay_cricket_vvip', activityTypeId: 'act_cricket', name: 'VVIP Net', bayTier: 'vvip', pricePerSession: 5000, maxPlayers: 6, description: 'The ultimate net — premium turf, lounge & host', image: 'https://images.unsplash.com/photo-1531415074968-036ba1b575da?w=600&q=80'),
  ],
  'act_dining': [
    Bay(id: 'bay_dining_std', activityTypeId: 'act_dining', name: 'Standard Table', bayTier: 'standard', pricePerSession: 1500, maxPlayers: 6, description: 'Open-air terrace by the bar & DJ', image: 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=600&q=80'),
    Bay(id: 'bay_dining_vip', activityTypeId: 'act_dining', name: 'VIP Lounge', bayTier: 'vip', pricePerSession: 2500, maxPlayers: 6, description: 'Tropical lounge with skyline views', image: 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=600&q=80'),
    Bay(id: 'bay_dining_vvip', activityTypeId: 'act_dining', name: 'VVIP Skyline Table', bayTier: 'vvip', pricePerSession: 3500, maxPlayers: 8, description: 'Secluded corner table with the best view in the house', image: 'https://images.unsplash.com/photo-1559339352-11d035aa65de?w=600&q=80'),
  ],
  'act_screening': [
    Bay(id: 'bay_scr_std', activityTypeId: 'act_screening', name: 'Standard Lounge', bayTier: 'standard', pricePerSession: 1800, maxPlayers: 12, description: 'Bean bags & sofas up front — great for groups', image: 'https://images.unsplash.com/photo-1517604931442-7e0c8ed2963c?w=600&q=80'),
    Bay(id: 'bay_scr_vip', activityTypeId: 'act_screening', name: 'VIP Recliners', bayTier: 'vip', pricePerSession: 2800, maxPlayers: 10, description: 'Premium recliners, centre of the screen', image: 'https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=600&q=80'),
    Bay(id: 'bay_scr_vvip', activityTypeId: 'act_screening', name: 'VVIP Couple Pods', bayTier: 'vvip', pricePerSession: 3500, maxPlayers: 2, description: 'Private 2-seater pods with a side table', image: 'https://images.unsplash.com/photo-1574267432553-4b4628081c31?w=600&q=80'),
  ],
};

final mockSlots = [
  Slot('11:00 AM', true), Slot('11:30 AM', true), Slot('12:00 PM', true),
  Slot('12:30 PM', false), Slot('1:00 PM', true), Slot('1:30 PM', true),
  Slot('2:00 PM', true), Slot('2:30 PM', false), Slot('3:00 PM', true),
];

final mockFood = [
  FoodItem(id: 'food_1', name: 'Classic Cheeseburger', category: 'Burgers', price: 290, description: 'Juicy beef patty, melted cheddar, lettuce, tomato, onion', image: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400&q=80'),
  FoodItem(id: 'food_2', name: 'Spicy Jalapeno Burger', category: 'Burgers', price: 290, description: 'Beef patty, pepper jack cheese, jalapenos, chipotle mayo', image: 'https://images.unsplash.com/photo-1550547660-d9450f859349?w=400&q=80'),
  FoodItem(id: 'food_3', name: 'BBQ Bacon Burger', category: 'Burgers', price: 290, description: 'Beef patty, crispy bacon, cheddar cheese, BBQ sauce', image: 'https://images.unsplash.com/photo-1572802419224-296b0aeee0d9?w=400&q=80'),
  FoodItem(id: 'food_4', name: 'Cold Brew Coffee', category: 'Beverages', price: 180, description: 'Slow-steeped 18h, smooth and bold', image: 'https://images.unsplash.com/photo-1461023058943-07fcbe16d735?w=400&q=80'),
  FoodItem(id: 'food_5', name: 'Molten Chocolate Cake', category: 'Desserts', price: 240, description: 'Warm gooey centre, vanilla bean ice cream', image: 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=400&q=80'),
];
