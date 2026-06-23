# GymGeek – AI-Intensive Fitness Guidance System

> **Course:** Engineering of AI-Intensive Systems – JKU Linz  
> **Team:** Jeronim Bašić (K12338065) · Beibarys Abissatov (K12247487)

---

## What is GymGeek?

GymGeek is an Android Flutter app that:
- **Identifies gym equipment** in real time using the phone camera (ResNet50 → TFLite, 23-class Roboflow GymBro dataset)
- **Shows instructional videos** for correct usage (YouTube)
- **Logs sets, reps and weight** per exercise with personal-record detection (Epley 1RM formula)
- **Summarises fitness research** using Gemini 2.0 Flash + a local RAG pipeline
- **Tracks progress** on a unified activity dashboard with charts
- **Personalises recommendations** based on your fitness goal

---

## Implemented Use Cases

| Use Case | Status | Key Files |
|----------|--------|-----------|
| UC-01: Authenticate User | ✅ | `login_screen.dart` |
| UC-02: Identify Gym Equipment (AI – CV) | ✅ | `camera_screen.dart`, `detection_service.dart` |
| UC-03: View Equipment Instructions | ✅ | `video_player_screen.dart` |
| UC-04: Get Research Summary (AI – LLM + RAG) | ✅ | `research_screen.dart`, `research_service.dart` |
| UC-05: Log Workout / Sets | ✅ | `exercise_detail_screen.dart`, `video_player_screen.dart` |
| UC-06: View Progress Dashboard | ✅ | `dashboard_screen.dart` |
| UC-07: Search Equipment by Name | ✅ | `equipment_search_screen.dart`, `exercise_library_screen.dart` |
| UC-08: Set Fitness Goals | ✅ | `profile_screen.dart` |

**8 / 8 use cases implemented (100%)**

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter 3.x (Dart) |
| CV Model | ResNet50 → ONNX → TFLite float16 (46 MB, 23 gym equipment classes) |
| LLM | Gemini 2.0 Flash via Google Generative AI SDK |
| RAG | Local JSON knowledge base (`assets/research.json`) |
| Database | SQLite via sqflite (two tables: sessions + sets) |
| Charts | fl_chart |

---

## Prerequisites

| Tool | Version | Link |
|------|---------|------|
| Flutter SDK | ≥ 3.0.0 | https://flutter.dev/docs/get-started/install |
| Dart SDK | ≥ 3.0.0 | Included with Flutter |
| Android Studio | Latest | https://developer.android.com/studio |
| Git | Any | https://git-scm.com |

Verify your Flutter installation before anything else:
```bash
flutter doctor
```
All checkmarks should be green.

---

## Step-by-Step Setup

### Step 1 — Clone the repository

```bash
git clone https://github.com/8asic/gymgeek.git
cd gymgeek
```

### Step 2 — Install Flutter dependencies

```bash
flutter pub get
```

### Step 3 — Add your Gemini API key

The app uses [Google Gemini 2.0 Flash](https://aistudio.google.com) for AI research summaries.

1. Go to **https://aistudio.google.com/apikey**
2. Click **"Create API key"** → **"Create API key in new project"**
3. Copy the key (it starts with `AIzaSy…`)
4. Open `lib/utils/app_constants.dart` and replace the placeholder:

```dart
static const String geminiApiKey = 'AIzaSy_YOUR_KEY_HERE';
```

> **If you skip this step** the Research tab still works — it falls back to showing raw paper excerpts from the local RAG knowledge base, with an error banner at the top explaining why AI generation is unavailable.

### Step 4 — Run on a physical Android device

The CV detection requires a real camera — **emulators do not work** for the Scan tab.

1. Enable **Developer Options** on your phone  
   (Settings → About Phone → tap **Build Number** 7 times)
2. Enable **USB Debugging** in Developer Options
3. Connect via USB and accept the "Allow USB debugging" prompt on the phone
4. Verify the device is detected:
   ```bash
   flutter devices
   ```
5. Run:
   ```bash
   flutter run
   ```

> **Demo mode** — if you want to run on an emulator anyway, the Scan tab enters demo mode and cycles through 8 realistic equipment detections automatically. All other tabs (Exercise Library, Dashboard, Research, Profile) work fully on emulators.

### Step 5 — iOS (Mac only, optional)

1. Open `ios/Runner.xcworkspace` in Xcode
2. Set your Apple ID under **Signing & Capabilities**
3. Select your device and press **Run**, or:
   ```bash
   flutter run --release
   ```

---

## Demo Login Credentials

| Field | Value |
|-------|-------|
| Email | `demo@gymgeek.app` |
| Password | `gymgeek123` |

Any email + password ≥ 4 characters also works.

---

## App Structure

```
gymgeek/
├── lib/
│   ├── main.dart                         # Entry point + auth gate
│   ├── screens/
│   │   ├── login_screen.dart             # UC-01: Authentication
│   │   ├── home_shell.dart               # Bottom nav (IndexedStack)
│   │   ├── camera_screen.dart            # UC-02: Equipment detection (CV/AI)
│   │   ├── equipment_search_screen.dart  # UC-07: Manual equipment search
│   │   ├── exercise_library_screen.dart  # UC-07: Exercise browser + muscle filters
│   │   ├── exercise_detail_screen.dart   # UC-05: Set/rep/weight logging + PR detection
│   │   ├── video_player_screen.dart      # UC-03: Instructions + UC-05: session log
│   │   ├── dashboard_screen.dart         # UC-06: Unified activity dashboard
│   │   ├── research_screen.dart          # UC-04: Gemini + RAG research summary
│   │   └── profile_screen.dart           # UC-08: Fitness goals + GDPR settings
│   ├── services/
│   │   ├── detection_service.dart        # ResNet50 TFLite inference (AI/CV)
│   │   ├── research_service.dart         # Gemini + RAG pipeline (AI/LLM)
│   │   ├── equipment_service.dart        # Equipment catalogue + label matching
│   │   ├── exercise_service.dart         # Exercise catalogue loader
│   │   └── database_service.dart         # SQLite CRUD, audit log, GDPR wipe
│   ├── models/
│   │   ├── equipment.dart
│   │   ├── exercise.dart
│   │   ├── workout_session.dart
│   │   ├── workout_set.dart              # Also holds PersonalRecord
│   │   └── goal.dart
│   ├── widgets/
│   │   ├── bottom_nav_bar.dart
│   │   └── equipment_card.dart
│   └── utils/
│       ├── app_theme.dart                # AppColors + Material theme
│       └── app_constants.dart            # API key, confidence threshold, timeouts
├── assets/
│   ├── equipment_classifier.tflite       # ResNet50 float16 model (46 MB, bundled)
│   ├── equipment_labels.txt              # 23 Roboflow GymBro class names
│   ├── equipment.json                    # 19 equipment entries (tips, videos, labels)
│   ├── exercises.json                    # Exercise catalogue with muscle filters
│   └── research.json                     # 8 research papers (RAG knowledge base)
├── tools/
│   ├── convert_model.py                  # PyTorch → ONNX → TFLite conversion script
│   ├── gym_equipment_resnet50.pt         # Original PyTorch checkpoint (teammate's model)
│   └── gym_equipment_resnet50.onnx       # Intermediate ONNX conversion
├── android/
├── test/
│   └── widget_test.dart
├── pubspec.yaml
└── README.md
```

---

## CV Model Details

The bundled `assets/equipment_classifier.tflite` is a **ResNet50** trained on the [Roboflow GymBro dataset](https://universe.roboflow.com) (23 gym equipment classes).

**Conversion pipeline** (in `tools/convert_model.py`):
```
gym_equipment_resnet50.pt  →  gym_equipment_resnet50.onnx  →  equipment_classifier.tflite
     (TorchScript)               (onnx2tf)                       (float16, 46 MB)
```

**23 recognised classes:**
`abdominal-machine`, `arm-extension`, `back-extension`, `bench-press`, `cable-lat-pulldown`,
`chest-press`, `hip-abduction-adduction`, `lat-pulldown`, `leg-extension`, `leg-press`,
`lying-down-leg-curl`, `overhead-shoulder-press`, `seated-cable-row`, `seated-leg-curl`,
`smith-machine`, `squat-rack`, `stair-climber`, `stationary-bike`, `torso-rotation-machine`,
`treadmill`, `upright-bike`, `vertical-knee-raise`, `weight-assisted-chin-dip-machine`

If no model is found at startup the app enters **demo mode** — the Scan tab cycles through
8 representative detections automatically, confidence scores included.

---

## Architecture Overview

```
Phone (Flutter App)
├── Scan tab      → DetectionService (TFLite on-device) → EquipmentService (JSON catalogue)
│                                                        → DatabaseService (audit log)
├── Library tab   → ExerciseService (JSON) → ExerciseDetailScreen
│                                           → DatabaseService (sets/reps/weight + PR)
├── Dashboard tab → DatabaseService (sessions + sets) → fl_chart
├── Research tab  → ResearchService: RAG (research.json) → Gemini 2.0 Flash API
└── Profile tab   → DatabaseService (goals, settings, GDPR wipe)
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `flutter pub get` fails | Run `flutter upgrade` then try again |
| Camera not working on emulator | Use a physical device — emulators lack a real camera |
| CV detection always shows demo | Model is loading; if it persists, check `assets/equipment_classifier.tflite` is present |
| Research tab shows orange warning | Add a valid Gemini API key to `app_constants.dart` (see Step 3) |
| Gemini quota exceeded (limit: 0) | The API key's project has no free quota; create a new key at aistudio.google.com/apikey |
| iOS build fails | Open in Xcode, check signing team under "Signing & Capabilities" |
| App crashes on launch | Run `flutter clean && flutter pub get && flutter run` |
| Build number too low | Ensure `minSdkVersion` ≥ 21 in `android/app/build.gradle.kts` |

---

*GymGeek – Engineering of AI-Intensive Systems, JKU Linz, 2026*
