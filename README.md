# 🛒 OptiCart

> **所見即所得，且以最優價格獲得。**  
> See it. Find it. Buy it at the best price.

OptiCart is a cross-platform mobile app built with Flutter that combines **AI-powered visual search** with **cross-platform price comparison**. Take a photo of any furniture or home decor item, and OptiCart identifies it and finds you the best price across multiple e-commerce platforms — including basket optimization to minimize total cost with shipping.

---

## ✨ Features

- 📸 **Visual Search** — snap or upload a photo to identify products instantly using computer vision
- 🔍 **Cross-Platform Price Comparison** — compare prices across major e-commerce platforms in real time
- 🧺 **Basket Optimization** — find the cheapest combination of sellers for your entire shopping list, factoring in shipping costs
- 🤖 **AI Product Matching** — powered by Google Gemini for accurate product recognition and matching
- 🔐 **Authentication** — Google Sign-In + Firebase Auth with guest mode support
- 💾 **Persistent Preferences** — remember your favorite stores and settings via SharedPreferences
- 🌐 **Cross-Platform** — runs on Android, iOS, Web, Windows, Linux, and macOS

---

## 🛠 Tech Stack

| Layer | Technology |
|-------|------------|
| Framework | Flutter 3.x + Dart 3 |
| State Management | Riverpod 2.x |
| Networking | Dio 5.x |
| AI / Vision | Google Gemini API (`google_generative_ai`) |
| Camera | `camera` + `image_picker` |
| Authentication | Firebase Auth + Google Sign-In |
| Database | Cloud Firestore |
| Routing | GoRouter 17.x |
| Styling | Google Fonts + Flutter SVG |

---

## 🏗 Project Structure

```
lib/
├── core/
│   ├── models/          # Data models (Product, Cart, PriceResult, etc.)
│   ├── services/        # Business logic (VisionService, PriceService, etc.)
│   ├── providers/       # Riverpod state management
│   └── widgets/         # Shared UI components
├── screens/             # App pages (Home, Search, Cart, Results)
└── utils/               # Helpers and constants
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter 3.9.0+
- Dart 3.0+
- A Firebase project (for Auth + Firestore)
- Google Gemini API key

### Setup

```bash
# Clone the repo
git clone https://github.com/StarCloud0417/OptiCart.git
cd OptiCart

# Install dependencies
flutter pub get

# Configure environment
cp .env.example .env
# Fill in your API keys in .env
```

### Environment Variables

Create a `.env` file at the project root:

```
GEMINI_API_KEY=your_google_gemini_api_key
```

Firebase config goes in `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) per the standard Firebase setup.

### Run

```bash
# Debug mode
flutter run --debug

# Release mode
flutter run --release

# Build APK
flutter build apk --release
```

---

## 💡 Business Model

OptiCart is designed around an **affiliate marketing** revenue model:

| Stream | Description | Est. Revenue |
|--------|-------------|-------------|
| Affiliate Commission | Earn commission when users buy through OptiCart links | 70% |
| Data & Advertising | Trend reports and product recommendation ads for brands | 20% |
| Premium Subscription | Ad-free, price history tracking, designer discounts | 10% |

---

## 📋 Roadmap

- [x] Flutter project architecture
- [x] Camera & image picker integration
- [x] Google Gemini visual search integration
- [x] Firebase Auth & Firestore setup
- [x] Riverpod state management
- [ ] Cross-platform price scraping engine
- [ ] Basket optimization algorithm
- [ ] Product knowledge graph
- [ ] UI/UX polishing
- [ ] App Store & Play Store release

---

## 📄 License

MIT License — see [LICENSE](LICENSE) for details.
