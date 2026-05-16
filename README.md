# GymGeek – AI-Intensive Fitness Guidance System

> **Course:** Engineering of AI-Intensive Systems – JKU Linz  
> **Team:** Jeronim Bašić (K12338065) · Beibarys Abissatov (K12247487)

---

## What is GymGeek?

GymGeek is a cross-platform Flutter app that:
- **Identifies gym equipment** in real-time using your phone camera (YOLO + TensorFlow Lite)
- **Shows instructional videos** for correct usage (YouTube)
- **Summarises fitness research** using an on-device LLM via Ollama + a RAG pipeline
- **Logs workouts** to local SQLite storage
- **Tracks progress** with a dashboard and charts
- **Personalises recommendations** based on your fitness goal

---

## Implemented Use Cases

| Use Case | Status | Where |
|----------|--------|-------|
| UC-01: Authenticate User | ✅ | `login_screen.dart` |
| UC-02: Identify Gym Equipment (AI – CV) | ✅ | `camera_screen.dart` + `tflite_service.dart` |
| UC-03: View Equipment Instructions | ✅ | `video_player_screen.dart` |
| UC-04: Get Research Summary (AI – LLM + RAG) | ✅ | `research_screen.dart` + `llm_service.dart` |
| UC-05: Log Workout Session | ✅ | `video_player_screen.dart` + `database_helper.dart` |
| UC-06: View Progress Dashboard | ✅ | `dashboard_screen.dart` |
| UC-07: Search Equipment by Name | ✅ | `search_screen.dart` |
| UC-08: Set Fitness Goals | ✅ | `profile_screen.dart` |

**8 / 8 use cases implemented (100%)**

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart) |
| CV Model | YOLO / MobileNet → TensorFlow Lite |
| LLM | Llama 3 via Ollama (local) |
| RAG | Local JSON knowledge base (research.json) |
| Database | SQLite via sqflite |
| State | Provider + StatefulWidget |
| Charts | fl_chart |

---

## Prerequisites

Install these before anything else:

| Tool | Version | Link |
|------|---------|------|
| Flutter SDK | ≥ 3.0.0 | https://flutter.dev/docs/get-started/install |
| Dart SDK | ≥ 3.0.0 | Included with Flutter |
| Android Studio | Latest | https://developer.android.com/studio |
| Xcode (iOS only) | ≥ 15 | Mac App Store |
| Ollama | Latest | https://ollama.com |
| Git | Any | https://git-scm.com |

Check your Flutter installation:
```bash
flutter doctor
```
All checkmarks should be green before proceeding.

---

## Step-by-Step Setup

### Step 1 — Clone the repository

```bash
git clone https://github.com/YOUR_USERNAME/gymgeek.git
cd gymgeek
```

### Step 2 — Install Flutter dependencies

```bash
flutter pub get
```

### Step 3 — Add the TFLite model (for real CV detection)

> **Skip this step if you want to run in demo mode first** — the app works without the model and cycles through sample detections automatically.

**Option A: Download a pre-converted gym equipment model**

The easiest option is to find a MobileNet/YOLO model already converted to `.tflite`:

1. Go to: https://www.kaggle.com/models  
   Search: "gym equipment tflite" or "exercise equipment mobilenet"
2. Download `model.tflite` and `labels.txt`
3. Place both files in the `assets/` folder

**Option B: Use Google's pre-trained object detection model**

```bash
# Download MobileNet SSD (recognises 90 COCO categories — not gym-specific but works for demo)
curl -L "https://storage.googleapis.com/download.tensorflow.org/models/tflite/coco_ssd_mobilenet_v1_1.0_quant_2018_06_29.zip" -o model.zip
unzip model.zip
cp detect.tflite assets/model.tflite
cp labelmap.txt assets/labels.txt
```

Then uncomment lines in `pubspec.yaml`:
```yaml
# assets:
#   - assets/model.tflite    ← remove the # from this line
#   - assets/labels.txt      ← remove the # from this line
```

### Step 4 — Add Android permissions

Open `android/app/src/main/AndroidManifest.xml` and add **inside `<manifest>`** (before `<application>`):

```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
<uses-feature android:name="android.hardware.camera" android:required="true"/>

<queries>
    <intent>
        <action android:name="android.intent.action.VIEW"/>
        <data android:scheme="https"/>
    </intent>
</queries>
```

Also add to the `<application>` tag:
```xml
android:requestLegacyExternalStorage="true"
```

### Step 5 — Add iOS permissions (if building for iPhone)

Open `ios/Runner/Info.plist` and add inside `<dict>`:

```xml
<key>NSCameraUsageDescription</key>
<string>GymGeek needs camera access to identify gym equipment</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>GymGeek needs photo access to analyse gym equipment images</string>
<key>io.flutter.embedded_views_preview</key>
<true/>
```

### Step 6 — Set up Ollama (for AI research summaries)

Ollama runs the LLM locally on your computer. The phone connects to it over your local network.

**Install Ollama:**
```bash
# macOS
brew install ollama

# Linux
curl -fsSL https://ollama.com/install.sh | sh

# Windows: download installer from https://ollama.com/download
```

**Download Llama 3:**
```bash
ollama pull llama3
```

**Start Ollama server** (must be running when using the Research tab):
```bash
ollama serve
```

Ollama listens on `http://localhost:11434` by default.

**Configure the app's Ollama URL:**

Open `lib/utils/constants.dart` and set the correct URL:

```dart
// Android Emulator → use this:
static const String ollamaBaseUrl = 'http://10.0.2.2:11434';

// Physical Android/iOS device → use your computer's LAN IP:
// Find your IP: run `ifconfig` (Mac/Linux) or `ipconfig` (Windows)
// Example:
static const String ollamaBaseUrl = 'http://192.168.1.45:11434';
```

> **Tip:** If Ollama is unavailable, the Research tab still works — it shows the raw paper excerpts from the local RAG knowledge base without LLM generation.

---

## Running the App

### On Android Emulator

```bash
# Start an AVD in Android Studio first, then:
flutter run
```

### On a Physical Android Device

1. Enable **Developer Options** on your phone (Settings → About Phone → tap Build Number 7 times)
2. Enable **USB Debugging**
3. Connect via USB
4. Run:
```bash
flutter run
```

### On iOS Simulator (Mac only)

```bash
open -a Simulator
flutter run
```

### On a Physical iPhone (Mac only)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Set your Apple ID in Signing & Capabilities
3. Select your device and press Run in Xcode, or:
```bash
flutter run --release
```

---

## Demo Login Credentials

| Field | Value |
|-------|-------|
| Email | `demo@gymgeek.app` |
| Password | `gymgeek123` |

Any email + password ≥ 4 characters also works for the prototype.

---

## App Structure

```
gymgeek/
├── lib/
│   ├── main.dart                    # Entry point + auth gate
│   ├── screens/
│   │   ├── login_screen.dart        # UC-01: Authentication
│   │   ├── home_shell.dart          # Bottom nav wrapper
│   │   ├── camera_screen.dart       # UC-02: Equipment detection (AI/CV)
│   │   ├── search_screen.dart       # UC-07: Manual search
│   │   ├── video_player_screen.dart # UC-03: Instructions + UC-05: Log workout
│   │   ├── dashboard_screen.dart    # UC-06: Progress dashboard
│   │   ├── research_screen.dart     # UC-04: LLM + RAG research summary
│   │   └── profile_screen.dart      # UC-08: Fitness goals + GDPR settings
│   ├── services/
│   │   ├── tflite_service.dart      # CV model inference (AI component)
│   │   ├── llm_service.dart         # Ollama LLM + RAG pipeline (AI component)
│   │   ├── equipment_service.dart   # Equipment database + search
│   │   └── database_helper.dart     # SQLite CRUD + audit log
│   ├── models/
│   │   ├── equipment.dart
│   │   ├── workout.dart
│   │   └── goal.dart
│   ├── widgets/
│   │   ├── bottom_nav_bar.dart
│   │   └── equipment_card.dart
│   └── utils/
│       └── constants.dart           # Ollama URL, confidence threshold, theme
├── assets/
│   ├── equipment.json               # 12 equipment entries (name, tips, video URL)
│   ├── research.json                # 8 research papers (RAG knowledge base)
│   ├── model.tflite                 # ← ADD THIS (see Step 3)
│   └── labels.txt                   # ← ADD THIS (see Step 3)
├── documentation/
│   └── GymGeek_Documentation.pdf
├── android/
│   └── PERMISSIONS.md              # Reminder for manifest changes
├── pubspec.yaml
└── README.md
```

---

## CV Demo Mode

If no `model.tflite` is found at startup, the app enters **Demo Mode**:
- A banner appears on the camera screen ("DEMO MODE")
- Every scan cycles through: Treadmill → Leg Press → Bench Press → Rowing Machine → Stationary Bike
- Confidence scores are realistic (78–93%)
- All other features (save workout, dashboard, search, research) work identically

This is useful for demonstrating the full UC flow without a gym-specific model.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `flutter pub get` fails | Run `flutter upgrade` then try again |
| Camera permission denied | Check AndroidManifest.xml / Info.plist changes in Steps 4–5 |
| Ollama not connecting on emulator | Use `http://10.0.2.2:11434` (not `localhost`) |
| Ollama not connecting on real device | Use your computer's LAN IP (e.g. `192.168.1.X:11434`) |
| `ollama serve` already running error | Run `pkill ollama` then `ollama serve` again |
| iOS build fails | Open in Xcode, check signing team in "Signing & Capabilities" |
| App crashes on launch | Run `flutter clean && flutter pub get && flutter run` |
| TFLite model slow | Use a quantised model (INT8) — look for `_quant` in filename |

---

## Architecture Overview

```
Phone (Flutter App)
├── Camera Screen ──→ TFLite Service ──→ Equipment Database
│                     (on-device AI)       (local JSON)
├── Search Screen ──→ Equipment Service ──→ Equipment Database  
├── Video Screen  ──→ YouTube (url_launcher) + SQLite (workout log)
├── Dashboard     ──→ SQLite (workout history) + fl_chart
├── Research      ──→ RAG (research.json) ──→ Ollama HTTP ──→ Llama 3
│                                              (local network)
└── Profile       ──→ SQLite (goals, settings) + Recommendation engine
```

---

## Demo Video

[Insert link here after recording]

**Suggested demo order for video (5–7 min):**

1. `0:00` Launch app → Login (UC-01)
2. `0:30` Camera tab → point at equipment → detection result (UC-02)
3. `1:15` Tap "View Instructions" → video thumbnail + tips (UC-03)
4. `1:45` Save workout → 30 min → "Saved!" toast (UC-05)
5. `2:00` Search tab → type "treadmill" → select → view instructions (UC-07)
6. `2:30` Dashboard tab → show bar chart + sessions (UC-06)
7. `3:00` Research tab → type "stretching injury prevention" → AI summary + sources (UC-04)
8. `4:00` Profile tab → select "Strength" goal → recommendations appear (UC-08)
9. `4:30` Profile → toggle GDPR consent, show "Delete All Data" dialog
10. `5:00` Back to camera → DEMO MODE banner visible if no model loaded

---

*GymGeek – Engineering of AI-Intensive Systems, JKU Linz, 2026*
