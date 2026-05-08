# 🚀Chronova

https://github.com/user-attachments/assets/8f9542ff-1c44-4161-8135-220ae6898653

**Samsung Hackathon MVP — AI-powered time management assistant**

**NOTE: APK file is in the releases section**

---

## 🧠 Current MVP Architecture

### Interactive Frontend
- **Provider-based local app state** via `AppStateProvider`
- All screens are fully interactive — no static mock data visible to users
- Every data source is clearly labeled: **User Entered**, **Demo/Mock**, or **AI Placeholder**

### Features Implemented
| Feature | Status | Data Source |
|---|---|---|
| Smart Alarm — create/edit/delete/toggle | ✅ | User Entered |
| Alarm ON/OFF toggle | ✅ | User Entered |
| Destination + Arrival time + Transport mode | ✅ | User Entered |
| Check Traffic Now | ✅ | Mock Traffic Service |
| Simulate Traffic Increase | ✅ | Mock Traffic Service |
| Dynamic traffic delay (per transport mode) | ✅ | Mock (Car 20–45m, Bike 10–30m, Bus 25–50m, Metro 5–15m) |
| AI-updated alarm + notification preview | ✅ | Mock OpenClaw Agent |
| Schedule Planner — add/delete tasks | ✅ | User Entered |
| Generate AI Plan | ✅ | Mock OpenClaw Agent |
| AI vs User task labels | ✅ | Clearly labeled |
| Productivity — Demo/Real mode toggle | ✅ | Demo: Mock Data |
| Usage Access permission card (Android) | ✅ | Placeholder |
| Meeting Assistant — paste email + generate brief | ✅ | Mock OpenClaw Agent |
| Meeting summary, talking points, questions, prep score | ✅ | Mock OpenClaw Agent |
| Context-aware OpenClaw Chat | ✅ | Mock with full app context |
| Quick suggestion chips in Chat | ✅ | User Triggered |

---

## ⏰ Current Working Alarm Features

### ✅ Fully Functional
- **Create Alarm**: User can create alarms with title, destination, wake-up time, arrival time, transport mode
- **Turn ON/OFF**: Toggle switch to enable/disable alarms
- **Edit Alarm**: Modify existing alarm details
- **Delete Alarm**: Remove alarms from the list
- **Test Alarm Notification**: Schedule a test notification after 5 seconds to verify ringing
- **Traffic Simulation**: Check traffic and reschedule alarm dynamically
- **Real Android Notifications**: Uses flutter_local_notifications for actual device notifications

### ⚠️ Important Limitations
- **Chrome/Web**: Cannot ring real Android alarms (use Android emulator or device)
- **Android Emulator**: Shows notifications but may not play sound/vibrate
- **Real Phone**: Best for testing full alarm experience (sound + vibration)
- **Background Traffic Check**: Requires WorkManager/foreground service for hourly checks (not implemented)
- **Exact Alarm Permission**: May require user permission on Android 12+ for precise scheduling

### 🔧 Technical Implementation
- **Notification Channel**: `timepilot_alarm_channel` (high importance, sound, vibration)
- **Permissions**: POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM
- **Scheduling**: Uses flutter_local_notifications with timezone support
- **Rescheduling**: Cancels old notification and schedules new one on traffic update

---

## 🔌 Production Version Roadmap

### 1. Traffic Intelligence
**Replace:** `MockTrafficService.getLiveTrafficDelay()`  
**With:** Google Maps Directions API
```
GET https://maps.googleapis.com/maps/api/directions/json
  ?origin=<lat,lng>
  &destination=<destination>
  &departure_time=now
  &key=<API_KEY>
```
Methods ready for replacement:
- `getLiveTrafficDelay(destination, departureTime, transportMode)`
- `getRecommendedTransport(destination)`
- `getEstimatedTravelTime(destination, mode)`

### 2. Screen Time Analytics
**Replace:** `MockScreenTimeService`  
**With:** Android `UsageStatsManager`
- Requires `PACKAGE_USAGE_STATS` permission
- User must grant via Settings → Usage Access
- Uses `UsageStatsManager.queryUsageStats()` for real app durations

### 3. Meeting Intelligence
**Replace:** `MockOpenClawAgent.generateMeetingBrief()`  
**With:** Gmail API + OAuth 2.0
- Fetch emails containing meeting keywords
- Parse attendees, agenda, attachments
- Send to OpenClaw backend for real AI summarization

### 4. Push Notifications
**Replace:** `MockNotificationService` (in-app SnackBar)  
**With:** Firebase Cloud Messaging (FCM)
- Background traffic monitoring via Android WorkManager
- Periodic alarm adjustment notifications

### 5. AI Backend (OpenClaw)
**Replace:** `MockOpenClawAgent`  
**With:** Secure backend service calling real LLM (GPT/Gemini)
- All context (alarm, schedule, traffic, meetings) sent as structured payload
- Returns dynamic, personalized responses

### 6. Persistent Storage
**Add:** Firebase Firestore
- Sync alarms, tasks, meeting briefs across devices
- User authentication via Firebase Auth

---

## 📁 Folder Structure

```
lib/
├── main.dart                    # App entry + navigation
├── models/
│   ├── alarm_model.dart         # Alarm with transport, destination, arrival
│   ├── schedule_model.dart      # Task with isUserAdded flag
│   ├── meeting_model.dart       # Meeting with questions, prep score
│   └── productivity_model.dart  # App usage + score
├── providers/
│   └── app_state_provider.dart  # Single source of truth (ChangeNotifier)
├── screens/
│   ├── dashboard_screen.dart    # Overview dashboard
│   ├── smart_alarm_screen.dart  # Interactive alarm management
│   ├── schedule_planner_screen.dart  # Task input + AI plan generation
│   ├── productivity_screen.dart # Demo/real mode screen time
│   ├── meeting_assistant_screen.dart # Email input + brief generation
│   └── ai_chat_screen.dart      # Context-aware OpenClaw chat
├── services/
│   ├── mock_traffic_service.dart     # → Google Maps Directions API
│   ├── mock_openclaw_agent.dart      # → Real AI backend endpoint
│   ├── mock_screen_time_service.dart # → Android UsageStatsManager
│   ├── mock_meeting_service.dart     # → Gmail API + OAuth
│   └── mock_notification_service.dart # → Firebase Cloud Messaging
└── widgets/
    ├── custom_card.dart
    └── primary_button.dart
```

---

## 🛠️ Run Locally

```bash
cd timepilot_ai
flutter pub get
flutter run
```

## 🔍 Analyze

```bash
flutter analyze
```

---

## 🎯 UX Honesty Principle

Every data point in the app is clearly labeled:
- **User Entered** — data the user typed or selected
- **Demo/Mock** — simulated data (clearly badged in orange)
- **AI Generated** — output from mock/real OpenClaw agent (purple badge)
- **API Placeholder** — where real API will connect (documented in code)

This ensures the app is demo-ready and honest about its data sources.
