# AI Calorie Coach

An AI-powered iOS app that estimates calories from food photos using computer vision and lets you manually log meals from a database of 9,600+ foods.

[![App Store](https://img.shields.io/badge/App_Store-Available-blue.svg)](https://apps.apple.com/app/ai-calorie-coach/id6741466804)
![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-purple.svg)

## Features

### AI-Powered Food Analysis
- Take a photo of your meal and get instant calorie estimates
- Uses OpenAI's vision model (o3) for accurate food detection
- Identifies multiple food items in a single image
- Provides calorie ranges (min/max/average) for accuracy
- Detects portion sizes from visual context
- Shows confidence levels (High/Medium/Low) for each food item
- Displays assumptions made during analysis
- Works out of the box with built-in daily limits — no API key required
- Optionally add your own OpenAI API key for unlimited usage

### Manual Food Logging
- Search a local database of 9,600+ foods with full macro information
- AI-powered online search fallback for foods not in the database
- Quick access to recently logged and frequently used foods
- Customizable quantity and serving size selection
- Add multiple items to a meal basket before saving
- Support for all meal types: Breakfast, Lunch, Dinner, Snack, Late Snack

### Smart Tracking
- Automatic meal type classification based on time of day
- Adjustable calorie estimates with intuitive sliders (50%–200%)
- Edit individual food items or total meal calories inline
- Reset to original AI analysis with one tap
- Search and filter your meal history

### Analytics Dashboard
- Daily calorie progress with visual progress bar and remaining calories
- Calorie trend charts with time period filters (1 Week, 2 Weeks, 1 Month, 3 Months, All Time)
- Meal type distribution analysis with pie/donut chart
- Daily average calorie metrics
- Goal progress percentage indicator

### Comprehensive Nutrition Data
- Detailed nutrition facts panel for each meal
- Macros: protein, carbohydrates, fat
- Micros: fiber, sugar, sodium, cholesterol, potassium
- Per-food-item and per-meal breakdowns

### Personalization
- Customizable daily calorie goals (1,000–4,000 cal)
- Quick presets: Weight Loss (1,500), Moderate Loss (1,750), Maintenance (2,000), Moderate Gain (2,250), Weight Gain (2,500), Bulking (3,000)
- Optional calorie range display toggle
- Secure API key management via iOS Keychain

## Screenshots

| Capture | Analysis | Manual Log | Dashboard | History |
|---------|----------|------------|-----------|---------|
| Take food photos | Review AI analysis | Search & add foods | Track progress | Browse meals |

## Requirements

- iOS 17.0+
- Xcode 15.0+
- OpenAI API key (optional — app works with built-in limits)

## Installation

1. Clone the repository:
```bash
git clone https://github.com/mfaizanshaikhh/CalorieCounter.git
cd CalorieCounter
```

2. Open the project in Xcode:
```bash
open CalorieCounter.xcodeproj
```

3. Build and run on your device or simulator.

4. (Optional) Add your own OpenAI API key in Settings for unlimited usage.

## Architecture

```
CalorieCounter/
├── Models/
│   ├── MealEntry.swift           # Core meal data model
│   ├── FoodItem.swift            # Individual food item with full nutrition
│   ├── SavedFood.swift           # User-saved frequently logged foods
│   ├── CalorieEstimation.swift   # AI response model
│   └── UserSettings.swift        # Preferences + Keychain integration
├── Views/
│   ├── ContentView.swift         # Tab navigation
│   ├── Camera/                   # Photo capture & manual food logging
│   ├── Analysis/                 # AI analysis results & editing
│   ├── Dashboard/                # Analytics, charts & stats
│   ├── History/                  # Meal history & detail views
│   ├── Settings/                 # User settings & about
│   └── Components/               # Nutrition summary panel
├── ViewModels/
│   ├── AnalysisViewModel.swift
│   ├── DashboardViewModel.swift
│   ├── ManualFoodLogViewModel.swift
│   ├── CameraViewModel.swift
│   └── SettingsViewModel.swift
├── Services/
│   ├── OpenAIService.swift       # OpenAI Responses API (o3 vision)
│   ├── FoodSearchService.swift   # Local DB search + AI fallback
│   ├── LLaVAService.swift        # Legacy wrapper → OpenAIService
│   ├── MealClassifier.swift      # Time-based meal classification
│   └── CalorieCalculator.swift   # Statistics calculations
├── Resources/
│   ├── FoodDatabase.json         # 9,600+ foods with per-100g macros
│   └── PrivacyInfo.xcprivacy     # App privacy manifest
└── Utilities/
    ├── KeychainHelper.swift      # Secure API key storage
    └── DateExtensions.swift      # Date helpers
```

## Technology Stack

- **UI Framework:** SwiftUI
- **Data Persistence:** SwiftData (on-device, with graceful fallback)
- **Charts:** Swift Charts
- **AI/Vision:** OpenAI Responses API (o3 for vision, gpt-4o-mini for food search)
- **Security:** iOS Keychain for API key storage
- **Concurrency:** Swift async/await with Actor isolation

## How It Works

1. **Capture** — Take a photo of your food or select from your photo library
2. **Analyze** — The image is compressed and sent to OpenAI's vision model for identification
3. **Review** — See detected food items with calorie estimates, confidence levels, and full nutrition data
4. **Adjust** — Fine-tune estimates with sliders or edit individual items inline
5. **Save** — Store the meal with all nutritional data locally on your device
6. **Track** — View your progress on the dashboard with charts and analytics

Or skip the camera and **manually log** foods by searching the built-in database of 9,600+ items.

## Data Privacy

- All meal data is stored locally on your device using SwiftData
- Images are compressed and stored on-device
- Only food images are sent to the OpenAI API for analysis — no personal data
- API keys are stored securely in the iOS Keychain (device-only, no iCloud sync)
- No tracking or analytics SDKs
- [Privacy Policy](https://mfaizanshaikh.wordpress.com/2026/02/27/privacy-policy-ai-calorie-coach/)

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.