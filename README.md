# 🎯 Strikin Mobile App — Flutter

**Strikin** is a cross-platform mobile booking app (Android, iOS, Web) for sports activities, entertainment, and rooftop dining. Users can browse activities, book bays/seats, invite friends, pay securely, and check in with QR codes.

Built with **Flutter** • **Dart** • **Razorpay** payments • **MSG91** messaging (Email, SMS, WhatsApp)

---

## 📋 Table of Contents

- [Quick Start (TL;DR)](#-quick-start-tldr)
- [What You Get](#-what-you-get)
- [Tech Stack](#-tech-stack)
- [Project Structure](#-project-structure)
- [Prerequisites](#-prerequisites)
- [Setup & Installation](#-setup--installation)
- [How to Run](#-how-to-run)
- [MSG91 Configuration](#-msg91-configuration--sms-email-whatsapp)
- [Razorpay Setup](#-razorpay-real-payments)
- [Build & Deploy](#-build--deploy)
- [Troubleshooting](#-troubleshooting)
- [API Reference](#-api-reference)

---

## ⚡ Quick Start (TL;DR)

```bash
# 1. Clone and install
git clone https://github.com/StrikinTech/StrikinAppModified-Android.git
cd StrikinAppModified-Android
flutter pub get

# 2. Start backend (in another terminal)
cd ../StrikinMobileServiceModifiedBackendAdmin
yarn dev  # Runs at http://localhost:3000

# 3. Run Flutter app (web is easiest)
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8090

# 4. Open browser
# http://localhost:8090

# 5. Test the flow: Login → Browse → Book → Pay → Check-in
```

---

## 🎨 What You Get

### User Flows

**Guest (No Account)**
- Browse activities without login
- Make bookings as guest
- Add food items
- Pay with Razorpay
- Invite friends to join

**Registered Users**
- OTP-based login (email/phone)
- Profile with loyalty points
- Booking history
- Loyalty rewards
- Multiple accounts on same phone

**Corporate (Team Lead / Super Admin)**
- Team management
- Budget allocation
- Wallet funding
- KYC submissions
- Company dashboard

### Features

✅ **Browse Activities**
- Sports (Badminton, Cricket, Squash, etc.)
- Entertainment (Mega Screens, Shows)
- Rooftop Dining

✅ **Slot Management**
- Real-time availability
- Slot locking (30 min hold)
- Date/time selection
- Multiple bays support

✅ **Food Ordering**
- Category-based menu
- Real-time pricing
- Tax calculation
- Item customization

✅ **Payments**
- Razorpay integration
- UPI, Cards, Wallets, Net Banking
- Payment verification
- Receipt & invoice generation

✅ **Guest Invites**
- Shareable invite links
- QR code + PIN
- Guest food payment
- Attendance tracking

✅ **Notifications**
- In-app notifications
- Booking reminders
- Payment status
- SMS/Email/WhatsApp (via MSG91)

✅ **Check-in**
- Scan QR or enter PIN
- Arrival confirmation
- Real-time updates

---

## 🔧 Tech Stack

| Component | Technology |
|-----------|-----------|
| **Language** | Dart 3.12+ |
| **Framework** | Flutter 3.44+ |
| **State Management** | ChangeNotifier (Provider) |
| **HTTP Client** | http package |
| **Payments** | Razorpay Flutter SDK |
| **Local Storage** | SharedPreferences |
| **QR Generation** | qr_flutter |
| **Messaging** | MSG91 (via backend) |
| **UI Kit** | Material Design 3 |
| **Fonts** | Poppins (4 weights) |

### Key Dependencies

```yaml
http: ^1.2.2                    # REST API calls
shared_preferences: ^2.3.2      # Token & user persistence
razorpay_flutter: ^1.3.7        # Payment processing
qr_flutter: ^4.1.0              # QR code generation
flutter_svg: ^2.0.10+1          # SVG rendering
url_launcher: ^6.3.0            # Link handling
share_plus: ^10.1.4             # Share invites
webview_flutter: ^4.10.0        # Web content
file_picker: ^8.1.4             # Document upload
app_links: ^6.3.2               # Deep linking
```

---

## 📁 Project Structure

```
lib/
├── main.dart              🎬 Entry point → Auth Gate → Shell
├── theme.dart             🎨 Design tokens (dark mode, lime #D6FD31)
├── api.dart               🌐 REST client (tRPC endpoints)
├── auth.dart              🔐 Authentication state (ChangeNotifier)
├── models.dart            📦 Data models (Activity, Booking, Food, etc.)
├── store.dart             💾 Booking draft storage (ChangeNotifier)
├── mock.dart              📋 Offline fallback data
├── app_nav.dart           🗺️ Navigation setup
├── deep_link.dart         🔗 Deep link handling
│
├── screens/               📱 Full-page UI
│   ├── login.dart         Login/Register/OTP flow
│   ├── shell.dart         Tabbed navigation (Home, Bookings, etc.)
│   ├── home.dart          Activity browsing
│   ├── activity_booking.dart    Booking flow
│   ├── food.dart          Food ordering
│   ├── checkout.dart      Payment summary
│   ├── confirmation.dart  Booking success
│   ├── bookings.dart      Booking history
│   ├── loyalty.dart       Loyalty points
│   ├── profile.dart       User settings
│   ├── corporate_cx.dart  Corporate dashboard
│   └── guest_invite.dart  Invite join flow
│
├── widgets/               🧩 Reusable components
│   ├── animated_splash.dart    Logo animation
│   ├── brand_mark.dart         Logo
│   ├── scaffold.dart           Custom app bar
│   └── [other UI components]
│
└── assets/                🎭 Images, fonts, SVGs
    ├── fonts/Poppins-*.ttf
    ├── images/
    └── ring1..4.svg
```

### How It All Fits Together

```
User opens app → RootGate (auth check) → Animated splash
   ↓
If not logged in → LoginScreen (OTP flow)
   ↓
If logged in → AppShell (tabbed navigation)
   ↓
Browse activities (lib/api.dart queries /api/v1/attractions)
   ↓
Select bay → Lock slot (30 min hold)
   ↓
Add food items + payment method
   ↓
Create booking (backend creates DB record)
   ↓
Razorpay opens → User pays
   ↓
Backend verifies signature → Booking confirmed
   ↓
Get QR code + PIN for check-in
   ↓
Check-in at venue (scan QR or PIN)
```

---

## 📦 Prerequisites

### Required

- **Flutter SDK**: 3.44+ (Dart 3.12+)
  - Download: https://flutter.dev/docs/get-started/install
  - Verify: `flutter --version`

- **Android SDK**: API 24+ (for native Android builds)
  - Included with Android Studio
  - Set `ANDROID_HOME` environment variable

- **Backend Running**: http://localhost:3000
  - Clone: `StrikinMobileServiceModifiedBackendAdmin`
  - Run: `yarn dev`

### Optional (but recommended)

- **Xcode** (for iOS builds)
- **Git** (for version control)
- **Postman** (for API testing)

### Verify Installation

```bash
flutter doctor
# Should show:
# ✓ Flutter (Channel stable)
# ✓ Android Studio / Xcode
# ✓ Android SDK
# ✓ No issues found
```

---

## 🚀 Setup & Installation

### 1. Clone the Repository

```bash
git clone https://github.com/StrikinTech/StrikinAppModified-Android.git
cd StrikinAppModified-Android
```

### 2. Install Dependencies

```bash
flutter pub get
# Downloads all packages from pubspec.yaml
```

### 3. Generate Launchers (Android/iOS Icons)

```bash
flutter pub run flutter_launcher_icons:main
# Creates app icons in android/ and ios/
```

### 4. Verify Setup

```bash
flutter devices
# Shows connected devices/emulators
# Example output:
# Android Emulator • emulator-5554 • android • Android 13 (API 33)
# Chrome • chrome • web-javascript • Google Chrome
```

---

## 🏃 How to Run

### Option A: Web (Fastest for Testing)

Perfect for quick testing on desktop or mobile browser on same Wi-Fi.

```bash
# Terminal 1: Start backend
cd ../StrikinMobileServiceModifiedBackendAdmin
yarn dev  # http://localhost:3000

# Terminal 2: Start Flutter web
cd ../StrikinAppModified-Android
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8090

# Open in browser
# http://localhost:8090  (same network)
# http://<your-pc-ip>:8090  (from phone)
```

**How the app finds the backend:**
- Checks `--dart-define=API_URL=...` (see Option B below)
- Falls back to `http://localhost:3000` if on localhost
- Falls back to same domain (production)

### Option B: Android Emulator or Device

Native Android build with custom backend URL.

```bash
# List devices
flutter devices
# Output: Android Emulator • emulator-5554 • android • Android 13 (API 33)

# Run with default backend (localhost:3000)
flutter run -d emulator-5554

# OR run with custom backend URL
flutter run -d emulator-5554 \
  --dart-define=API_URL=http://192.168.0.13:3000 \
  --dart-define=RAZORPAY_KEY_ID=rzp_test_xxxxx
```

**For a physical device:**
```bash
# Connect device via USB with debugging enabled
# Then use same commands, but device ID will be different

adb devices  # List devices
# Example: FA8EYx1A1234 device

flutter run -d FA8EYx1A1234 \
  --dart-define=API_URL=http://192.168.0.13:3000 \
  --dart-define=RAZORPAY_KEY_ID=rzp_test_xxxxx
```

### Option C: Release APK (Install on Phone)

Ready for distribution or offline testing.

```bash
# Build release APK
flutter build apk --release \
  --dart-define=API_URL=http://192.168.0.13:3000 \
  --dart-define=RAZORPAY_KEY_ID=rzp_test_xxxxx

# Output: build/app/outputs/flutter-apk/app-release.apk (~50 MB)

# Install on connected device
adb install -r build/app/outputs/flutter-apk/app-release.apk

# Or share the APK file directly
```

### Option D: iOS (Mac Only)

```bash
# Build for iOS simulator
flutter run -d "iPhone 14"

# Or device (requires provisioning profile):
flutter run -d <device-id>

# Build release IPA for App Store:
flutter build ipa --release
```

---

## 💬 MSG91 Configuration (SMS, Email, WhatsApp)

All messaging is **handled by the backend**, but you need to set up MSG91 credentials there.

### What is MSG91?

**MSG91** is India's SMS + Email + WhatsApp provider. The backend sends messages through MSG91 when:
- User requests OTP (SMS or Email)
- Booking is confirmed (SMS/Email)
- Payment received (Email)
- WhatsApp reminder sent

### 1. Get MSG91 Credentials

1. **Sign up** at https://msg91.com (free trial available)
2. **Generate Auth Key** → Dashboard → API → Copy 32-char key
3. **Register WhatsApp Business** number (optional but recommended)
4. **Verify email domain** for email delivery (SPF/DKIM records)

### 2. Configure Backend (.env)

Once you have MSG91 credentials, configure the **backend** (not this Flutter app):

```bash
# In StrikinMobileServiceModifiedBackendAdmin/.env

# ── Email ──────────────────────────────────────
EMAIL_PROVIDER=msg91                      # Enable MSG91
EMAIL_FROM=noreply@strikin.com

# ── MSG91 Auth Key (shared across all channels) ──
MSG91_AUTH_KEY=your_32_char_key_from_msg91_dashboard

# ── SMS Configuration ──────────────────────────
SMS_PROVIDER=msg91
MSG91_SENDER_ID=STRIKN                    # 6 chars max
MSG91_DLT_TE_ID=your_dlt_template_id      # DLT registration
MSG91_OTP_TEMPLATE_ID=your_otp_template   # Fallback template

# ── WhatsApp (optional) ────────────────────────
WHATSAPP_PROVIDER=msg91
MSG91_WHATSAPP_INTEGRATED_NUMBER=91XXXXXXXXXX  # +91 prefix
MSG91_WHATSAPP_TEMPLATE_NAMESPACE=your_namespace_from_meta
MSG91_WHATSAPP_TEMPLATE_LANG=en
```

### 3. Verify Backend Configuration

Test that MSG91 is working by triggering an OTP:

```bash
# Start backend
cd StrikinMobileServiceModifiedBackendAdmin
yarn dev

# In another terminal, request OTP via guest session:
curl -X POST http://localhost:3000/api/trpc/guest.createSession \
  -H "Content-Type: application/json" \
  -d '{
    "fullName": "Test User",
    "phone": "9876543210",
    "email": "your-email@gmail.com"
  }'

# Response: { result: { data: { sessionId: "abc-123" } } }

# Now request OTP:
curl -X POST http://localhost:3000/api/trpc/booking.requestOtp \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "abc-123",
    "email": "your-email@gmail.com"
  }'

# In DEVELOPMENT (no real keys):
#   → Check terminal for: 🔑 [DEV OTP] Email: ... | OTP: 123456
#   → No actual SMS/Email sent

# In PRODUCTION (with MSG91 keys):
#   → Email arrives in inbox
#   → OR SMS arrives on phone (if phone number used)
```

### 4. Test in Flutter App

Once backend has MSG91 configured:

```bash
# Run the Flutter app
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8090

# On the login screen:
# Enter your email or phone
# Click "Send OTP"
# In DEV: check backend terminal for OTP
# In PROD: check email/SMS inbox
# Enter OTP in the app
```

### MSG91 Common Issues

| Issue | Solution |
|-------|----------|
| "OTP not received" | Check `MSG91_AUTH_KEY` is correct in `.env` |
| " SMS not sent" | Verify `SMS_PROVIDER=msg91` and DLT registration |
| "Email bounces" | Verify email domain (add SPF/DKIM records) |
| "WhatsApp not working" | Ensure phone is registered in MSG91 dashboard |

---

## 💳 Razorpay Real Payments

### 1. Get Razorpay Keys

1. **Sign up** at https://razorpay.com (free account)
2. **Get Test Keys**:
   - Dashboard → Settings → API Keys
   - Copy **Key ID** (starts with `rzp_test_`)
   - Copy **Key Secret**

### 2. Build Flutter App with Razorpay Key

```bash
# Test build (use test keys)
flutter build apk --release \
  --dart-define=API_URL=http://192.168.0.13:3000 \
  --dart-define=RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxxx

# Production build (use live keys)
flutter build apk --release \
  --dart-define=API_URL=https://api.strikin.com \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_xxxxxxxxxxxxx
```

### 3. Test Payments

Use Razorpay's test cards:

| Card | Number | Exp | CVV |
|------|--------|-----|-----|
| Visa | `4111 1111 1111 1111` | Any future | `123` |
| Mastercard | `5555 5555 5555 4444` | Any future | `123` |
| Amex | `3782 822463 10005` | Any future | `1234` |

**Flow:**
1. Open Flutter app
2. Create a booking
3. Click "Pay Now"
4. Razorpay checkout opens
5. Enter test card above
6. Enter OTP when prompted (use `123456`)
7. Payment confirmed → booking success

### 4. Configure Backend for Razorpay

Backend also needs Razorpay keys:

```bash
# In StrikinMobileServiceModifiedBackendAdmin/.env
RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxxx
RAZORPAY_KEY_SECRET=your_secret_key
RAZORPAY_WEBHOOK_SECRET=your_webhook_secret
NEXT_PUBLIC_RAZORPAY_KEY_ID=rzp_test_xxxxxxxxxxxxx  # Public, safe to expose
```

---

## 🏗️ Build & Deploy

### Android (APK/AAB)

```bash
# Debug APK (fast, large, not optimized)
flutter build apk --debug

# Release APK (smaller, optimized)
flutter build apk --release \
  --dart-define=API_URL=https://api.strikin.com \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_xxxxx

# App Bundle (for Google Play)
flutter build appbundle --release \
  --dart-define=API_URL=https://api.strikin.com \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_xxxxx

# Output:
# APK: build/app/outputs/flutter-apk/app-release.apk
# AAB: build/app/outputs/bundle/release/app-release.aab
```

### iOS (IPA for App Store)

```bash
flutter build ipa --release \
  --dart-define=API_URL=https://api.strikin.com \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_xxxxx

# Output: build/ios/ipa/strikin.ipa
```

### Web (Static Files)

```bash
flutter build web --release \
  --dart-define=API_URL=https://api.strikin.com \
  --dart-define=RAZORPAY_KEY_ID=rzp_live_xxxxx

# Output: build/web/
# Deploy to Firebase, Netlify, or any static host
```

### Pre-Deployment Checklist

- [ ] Backend running and accessible at `API_URL`
- [ ] Razorpay keys set (live keys for production)
- [ ] MSG91 credentials configured in backend
- [ ] All environment variables set correctly
- [ ] Tested complete flow (login → book → pay → check-in)
- [ ] Icons generated (`flutter_launcher_icons`)
- [ ] Version bumped in `pubspec.yaml`
- [ ] Changelog updated
- [ ] Privacy policy & ToS reviewed

---

## 🐛 Troubleshooting

### App Can't Reach Backend

**Symptom:** "Network error" when logging in

**Solution:**
```bash
# Check backend is running
curl http://localhost:3000/api/v1/attractions

# On Android/emulator, use:
flutter run --dart-define=API_URL=http://10.0.2.2:3000

# On iOS simulator, use:
flutter run --dart-define=API_URL=http://localhost:3000

# On real device, use your PC's local IP:
flutter run --dart-define=API_URL=http://192.168.x.x:3000
# (find with: ipconfig getifaddr en0)
```

### Razorpay Payment Fails

**Symptom:** "Invalid signature" error

**Solution:**
- Verify `RAZORPAY_KEY_ID` and `RAZORPAY_KEY_SECRET` match
- Check test cards are correct
- Ensure app was built with matching key

### OTP Not Received

**Symptom:** No SMS/Email after requesting OTP

**Solution:**
- Check backend `.env` has `MSG91_AUTH_KEY`
- Verify `EMAIL_PROVIDER=msg91` or `SMS_PROVIDER=msg91`
- Check backend terminal for errors
- In dev mode, OTP prints to terminal (look for 🔑 emoji)

### App Won't Start

**Symptom:** "Error launching application"

**Solution:**
```bash
# Clean build
flutter clean
flutter pub get
flutter run

# Or with verbose output
flutter run -v
```

### Hot Reload Not Working

**Solution:**
```bash
# Restart the dev server
Ctrl+C in terminal
flutter run
```

---

## 📚 API Reference

### Core Auth Endpoints

All calls go to `http://localhost:3000/api/v1` (or custom `API_URL`).

#### Guest Session

```dart
// Create anonymous session (no registration required)
final session = await Api.guestSession(
  fullName: "John Doe",
  phone: "9876543210",
  dateOfBirth: DateTime(1990, 5, 1),
  gender: "male",
);
// Returns: {guestSessionId: "xyz", token: "abc"}
```

#### Login (OTP)

```dart
// Step 1: Request OTP
await Api.requestLoginOtp("9876543210");  // or "email@example.com"
// Backend sends OTP via SMS/Email

// Step 2: Verify OTP
final result = await Api.loginVerify("9876543210", "123456");
// Returns: {token: "xyz", fullName: "John", role: "b2c", ...}

// Step 3: Save session
AuthState.instance.login(AppUser(
  token: result['token'],
  name: result['fullName'],
  // ... other fields
));
```

#### Register

```dart
await Api.register(
  fullName: "Jane Smith",
  phone: "9876543210",
  email: "jane@example.com",
  dateOfBirth: DateTime(1992, 3, 15),
  gender: "female",
);
// OTP sent via email (if provided) or SMS
```

### Booking Endpoints

```dart
// Get activities
final activities = await Api.getActivities();

// Get bays for activity
final bays = await Api.getBays(activityId, date: "2024-08-01");

// Get time slots
final slots = await Api.getSlots(bayId, "2024-08-01");

// Lock a slot (required before booking)
final lock = await Api.lockSlot(bayId, "2024-08-01", "15:00");
// Returns: {locked: true, expiresAt: "...", lockKey: "..."}

// Create booking
final booking = await Api.createBooking(
  bays: [bay1, bay2],
  date: "2024-08-01",
  time: "15:00",
  players: 4,
  food: [CartFood(item, quantity)],
  paymentMethod: "upi",
);
// Returns: {bookingId: "xyz", totalAmount: 5000, ...}

// Initiate payment
final paymentOrder = await Api.initiatePayment(bookingId, 5000);
// Returns: {orderId: "order_...", amount: 5000, requiresCheckout: true}

// Verify payment (after Razorpay checkout)
final success = await Api.verifyPayment(
  bookingId: bookingId,
  orderId: "order_...",
  paymentId: "pay_...",
  signature: "sig_...",
);

// Get booking details
final details = await Api.bookingDetails(bookingId);

// Get QR code for check-in
final qr = await Api.getQr(bookingId);
// Returns: {qr: "qr_data", pin: "1234"}
```

### Invite Endpoints

```dart
// Create invite
final token = await Api.createInvite(
  bookingId,
  maxPlayers: 10,
  guestsMustPayForFood: true,
);

// Get shareable link
final link = Api.inviteLink(token);
// Returns: "https://strikin.com/?invite=<token>"

// Get deep link
final deepLink = Api.inviteDeepLink(token);
// Returns: "strikin://join/<token>"

// Join as guest
final joinId = await Api.joinInvite(
  token,
  name: "Guest Name",
  phone: "9876543210",
);

// Add food to invite join
await Api.addJoinFood(token, joinId, foodItem, quantity);

// Pay for guest food
final payment = await Api.joinPaymentInitiate(token, joinId, 500);
```

### Full Docs

See `lib/api.dart` for 100+ methods covering all features.

---

## 📞 Support & Links

- **Backend Repo:** https://github.com/StrikinTech/StrikinMobileServiceModifiedBackendAdmin
- **Integration Guide:** See `INTEGRATION_GUIDE.md` in backend repo
- **Flutter Docs:** https://flutter.dev/docs
- **Razorpay Docs:** https://razorpay.com/docs
- **MSG91 Docs:** https://msg91.com/help/api

---

## 📄 License

Proprietary - Strikin Technologies

---

## 🚀 Next Steps

1. ✅ Clone this repo
2. ✅ Run `flutter pub get`
3. ✅ Start backend (`yarn dev`)
4. ✅ Run Flutter app (`flutter run -d web-server`)
5. ✅ Test guest booking flow
6. ✅ Configure MSG91 in backend
7. ✅ Build release APK for distribution

Happy coding! 🎉
