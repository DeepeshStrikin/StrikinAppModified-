# Strikin — Project Handoff / New-Laptop Setup

Everything needed to continue this project on another machine.

## The 3 repos (all on GitHub under `DeepeshStrikin`)
| Repo | Folder | What it is | Deployed to |
|---|---|---|---|
| `Strikin-Customer-App` (private) | `strikin_flutter` | Flutter phone + web app | APK / Netlify web |
| `Strikin-Mobile-App-Service-` | `backend` | FastAPI + Supabase backend | Railway |
| `Strikin-Admin-Hub-` | `strikin_admin` | React admin control panel | Netlify |

Clone all three:
```
gh repo clone DeepeshStrikin/Strikin-Customer-App
gh repo clone DeepeshStrikin/Strikin-Mobile-App-Service-
gh repo clone DeepeshStrikin/Strikin-Admin-Hub-
```

## Live URLs
- Backend API: https://web-production-c154d.up.railway.app
- Customer web app: https://strikinappwebversion.netlify.app
- Admin panel: (your Netlify admin site)

## Secrets to copy MANUALLY (these are git-ignored — NOT in GitHub)
Carry these by USB / password manager / secure transfer:
- `backend/.env` — DATABASE_URL (Supabase), ADMIN_PASSWORD, RAZORPAY_KEY_ID,
  RAZORPAY_KEY_SECRET, SENDGRID_API_KEY, Gmail creds
- `strikin_admin/.env.local` — `VITE_API_URL=https://web-production-c154d.up.railway.app`

## Dev tools to install on the new laptop
- Flutter SDK (this project built on 3.44.1 stable)
- Android Studio (Android SDK + platform tools)
- JDK (bundled with Android Studio's JBR)
- Git + GitHub CLI (`gh`)
- Python 3.11+ (backend)
- Node.js LTS (admin)

## How to run each part
**Backend**
```
cd backend
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000   # 0.0.0.0 lets your phone connect
```
**Flutter app — phone (talk to live backend)**
```
cd strikin_flutter
flutter pub get
flutter run --dart-define=API_URL=https://web-production-c154d.up.railway.app
```
**Flutter app — release APK to share with testers**
```
flutter build apk --release \
  --dart-define=API_URL=https://web-production-c154d.up.railway.app \
  --dart-define=WEB_URL=https://strikinappwebversion.netlify.app
# output: build/app/outputs/apk/release/app-release.apk
```
**Admin**
```
cd strikin_admin
npm install
npm run dev
```

## Payment (Razorpay) — how it works + how to TEST
- Mobile uses the **razorpay_flutter native SDK** (in-app sheet: UPI/GPay/PhonePe/cards).
- Web uses Razorpay **checkout.js**.
- TEST with **UPI**, not a card: enter **`success@razorpay`** (always succeeds in test mode).
  Use `failure@razorpay` to test the failed path.
- Do NOT test with card `4111 1111 1111 1111` — the test account has international cards
  OFF, so it shows "International cards not supported". That's an account setting, not a bug.

## Android build config note (AGP 9)
`android/gradle.properties` is tuned for low-memory machines and AGP 9:
`android.builtInKotlin=false`, `android.newDsl=false`, in-process Kotlin, small heap.
On a machine with more RAM you can raise `org.gradle.jvmargs=-Xmx`.

## Known constraint
The native SDK build needs ~2 GB free RAM. On an 8 GB laptop running an IDE + browsers
it tends to run out of memory ("Gradle daemon disappeared" / JVM crash). A machine with
16 GB+ builds it without issue.
