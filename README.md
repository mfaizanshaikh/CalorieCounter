# CalorieCounter

An AI-powered iOS app that estimates calories from food photos using computer vision.

![iOS](https://img.shields.io/badge/iOS-17.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.0-orange.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-purple.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Features

### AI-Powered Food Analysis
- Take a photo of your meal and get instant calorie estimates
- Identifies multiple food items in a single image
- Provides calorie ranges (min/max/average) for accuracy
- Detects portion sizes from visual context
- Shows confidence levels for each food item
- Displays assumptions made during analysis

### Smart Tracking
- Automatic meal type classification based on time of day
- Adjustable calorie estimates with intuitive sliders
- Edit individual food items or total meal calories
- Search and filter your meal history

### Analytics Dashboard
- Daily calorie progress with visual progress bar
- Weekly calorie trends with bar charts
- Meal type distribution analysis
- Monthly calorie totals
- Remaining calories for the day

### Personalization
- Customizable daily calorie goals (1000-4000 cal)
- Quick presets for common goals (Weight Loss, Maintenance, Bulking, etc.)
- Optional calorie range display

## Screenshots

| Capture | Analysis | Dashboard | History |
|---------|----------|-----------|---------|
| Take food photos | Review AI analysis | Track progress | Browse meals |

## Requirements

- iOS 17.0+
- Xcode 15.0+
- OpenAI API key

## Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/CalorieCounter.git
cd CalorieCounter
```

2. Open the project in Xcode:
```bash
open CalorieCounter.xcodeproj
```

3. Configure your OpenAI API key in `CalorieCounter/Models/UserSettings.swift`:
```swift
static let openAIAPIKey = "sk-your-api-key-here"
```

4. Build and run on your device or simulator.

## Configuration

### API Key Setup

The app uses OpenAI's GPT-5 Mini vision model for food analysis. To get an API key:

1. Create an account at [platform.openai.com](https://platform.openai.com)
2. Generate an API key from the API Keys section
3. Add your key to `UserSettings.swift` as shown above

### Daily Calorie Goal

You can customize your daily calorie goal in the Settings tab:
- Use the slider to set a custom value (1000-4000 calories)
- Or choose from quick presets:
  - Weight Loss: 1500 cal
  - Moderate Loss: 1750 cal
  - Maintenance: 2000 cal
  - Moderate Gain: 2250 cal
  - Weight Gain: 2500 cal
  - Bulking: 3000 cal

## Architecture

```
CalorieCounter/
├── Models/
│   ├── MealEntry.swift        # Core meal data model
│   ├── FoodItem.swift         # Individual food item model
│   ├── CalorieEstimation.swift # API response model
│   └── UserSettings.swift     # User preferences
├── Views/
│   ├── ContentView.swift      # Tab navigation
│   ├── Camera/                # Photo capture
│   ├── Analysis/              # AI analysis results
│   ├── Dashboard/             # Analytics & stats
│   ├── History/               # Meal history
│   └── Settings/              # User settings
├── ViewModels/
│   ├── AnalysisViewModel.swift
│   ├── DashboardViewModel.swift
│   ├── HistoryViewModel.swift
│   └── CameraViewModel.swift
├── Services/
│   ├── OpenAIService.swift    # OpenAI API integration
│   ├── MealClassifier.swift   # Time-based meal classification
│   └── CalorieCalculator.swift # Statistics calculations
└── Utilities/
    ├── ImageProcessor.swift   # Image compression
    └── DateExtensions.swift   # Date helpers
```

## Technology Stack

- **UI Framework:** SwiftUI
- **Data Persistence:** SwiftData
- **Charts:** Swift Charts
- **AI/Vision:** OpenAI GPT-5 Mini Vision API
- **Concurrency:** Swift async/await

## How It Works

1. **Capture**: Take a photo of your food or select from your photo library
2. **Analyze**: The image is compressed and sent to OpenAI's vision model
3. **Review**: See detected food items with calorie estimates and confidence levels
4. **Adjust**: Fine-tune the estimates if needed using sliders
5. **Save**: Store the meal with all nutritional data
6. **Track**: View your progress on the dashboard and history

## Data Privacy

- All meal data is stored locally on your device using SwiftData
- Images are compressed and stored on-device
- Only food images are sent to the OpenAI API for analysis
- No personal data is collected or transmitted

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.