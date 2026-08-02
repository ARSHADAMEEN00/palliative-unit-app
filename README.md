# Palliative App - Palliative Care Management System

**Palliative App** is a comprehensive digital solution designed to support palliative care services with compassion and efficiency. This Flutter application empowers healthcare providers to deliver dignified, person-centered care to patients and families facing serious illness.

## About Palliative App

Palliative App is a complete management system that streamlines:
- **Patient Care Management**: Comprehensive patient records and care coordination
- **Home Visit Scheduling**: Efficient planning and tracking of home-based care visits
- **Equipment Tracking**: Medical equipment inventory and supply management
- **Medicine Distribution**: Medication supply tracking and distribution logs
- **Volunteer Coordination**: Manage volunteers and caregivers supporting patient care
- **Administrative Tools**: Role-based access control and secure data management

## Getting Started

This project is a Flutter application with a Node.js/Express backend.

### Prerequisites

- Flutter SDK (3.9.2 or later)
- Node.js (18+)
- MongoDB (local or Atlas)

### Project Structure

```
oruma_app/
├── lib/                      # Flutter app source
│   ├── main.dart             # App entry point
│   ├── models/               # Data models
│   │   ├── patient.dart
│   │   ├── home_visit.dart
│   │   ├── equipment.dart
│   │   ├── equipment_supply.dart
│   │   └── medicine_supply.dart
│   └── services/             # API services
│       ├── api_config.dart   # API configuration
│       ├── api_service.dart  # HTTP client wrapper
│       ├── patient_service.dart
│       ├── home_visit_service.dart
│       ├── equipment_service.dart
│       ├── equipment_supply_service.dart
│       └── medicine_supply_service.dart
└── server/                   # Backend API
    └── src/
        ├── server.ts         # Express server
        ├── routes/           # API routes
        ├── services/         # Business logic
        └── models/           # MongoDB schemas
```

## Running the App

### 1. Start the Backend

```bash
cd server
npm install
npm run dev
```

The API server will start at `http://localhost:3000`

### 2. Start the Flutter App

```bash
# For web
flutter run -d chrome

# For macOS
flutter run -d macos

# For iOS Simulator
flutter run -d ios

# For Android Emulator
flutter run -d android
```

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /health` | Health check |
| `GET /api/patients` | List all patients |
| `POST /api/patients` | Create a patient |
| `GET /api/patients/:id` | Get patient by ID |
| `PUT /api/patients/:id` | Update patient |
| `DELETE /api/patients/:id` | Delete patient |
| `GET /api/home-visits` | List all home visits |
| `POST /api/home-visits` | Schedule a home visit |
| `GET /api/equipment` | List all equipment |
| `POST /api/equipment` | Register equipment |
| `GET /api/equipment-supplies` | List equipment supplies |
| `POST /api/equipment-supplies` | Create equipment supply |
| `GET /api/medicine-supplies` | List medicine supplies |
| `POST /api/medicine-supplies` | Create medicine supply |

## Configuration

### API Base URL

The API base URL is configured in `lib/services/api_config.dart`:

```dart
/// For web/desktop development
static String get baseUrl => 'http://localhost:3000/api';

/// For Android Emulator, use:
/// static String get baseUrl => 'http://10.0.2.2:3000/api';
```

### Environment Variables

Create a `.env` file in the `server` directory:

```env
PORT=3000
MONGO_URI=mongodb://localhost:27017/carenest
```

### App Icons & Branding

The app uses **Palliative App** branding with custom icons generated from `assets/logo/app_icon.png`.

**App Name**: Palliative App
**Logo Location**: `assets/logo/app_icon.png`

Icons are automatically generated for all platforms using `flutter_launcher_icons`. To regenerate icons after updating the logo:

```bash
flutter pub get
dart run flutter_launcher_icons
```

This will create:
- **Android**: Adaptive icons (mipmap resources) with white background
- **iOS**: All required icon sizes (20x20 to 1024x1024)
- **Web**: Favicon and web app icons

The configuration is in `pubspec.yaml` under the `flutter_launcher_icons` section.


## Features

- **Patient Registration**: Add and manage patient records
- **Home Visits**: Schedule and track home visits
- **Equipment Management**: Register and track medical equipment
- **Equipment Supply**: Log equipment supplied to patients
- **Medicine Supply**: Track medicine distribution

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Express.js Documentation](https://expressjs.com/)
- [MongoDB Documentation](https://www.mongodb.com/docs/)



apk build 
flutter build apk --release

flutter build apk --release --no-tree-shake-icons
