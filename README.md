# ARchitect AI

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?logo=fastapi&logoColor=white)
![ARCore](https://img.shields.io/badge/ARCore-Google-4285F4?logo=google&logoColor=white)
![YOLOv8](https://img.shields.io/badge/YOLOv8-Ultralytics-purple)
![OpenAI](https://img.shields.io/badge/OpenAI-API-412991?logo=openai&logoColor=white)

> Point your camera at a plot of land — ARchitect AI detects it using YOLOv8,
> then overlays a 3D building model on it in real time using Google ARCore.
> Powered by OpenAI for a smart conversational assistant.

---

## How It Works

```
📱 Phone Camera
      │
      ▼
📦 Flutter AR App  ──── WiFi ────►  🖥️  Python Server
      │                                    │
      │  ◄──── JSON result ──────────────  ├── YOLOv8 (land detection)
      │                                    └── FastAPI endpoint
      ▼
🏗️  ARCore overlays 3D building on detected land
```

The app sends a photo to the local Python server, which runs a custom-trained YOLOv8 model to detect empty land and returns the bounding coordinates. The app then places a 3D building model precisely on the detected land area using Google ARCore.

---

## Features

- **Real-time land detection** using a custom-trained YOLOv8 model
- **3D building overlay** rendered directly on the land with Google ARCore
- **10+ building types** to choose from (house, school, hospital, mosque, and more)
- **AI chat assistant** powered by OpenAI GPT for smart architectural guidance
- **Arabic / English** bilingual interface
- **Works on any ARCore-compatible Android device**

---

## Project Structure

```
ARchitect-AI/
├── flutter_app/        ← Android AR application (Flutter + ARCore + Dart)
│   ├── lib/            ← App source code
│   ├── assets/         ← Icons, HTML viewers, thumbnail images
│   ├── android/        ← Android project configuration
│   ├── local_packages/ ← Local Flutter packages
│   └── pubspec.yaml    ← Flutter dependencies
│
└── server/             ← Detection & model server (FastAPI + YOLOv8)
    ├── server.py        ← FastAPI server (main entry point)
    ├── detect_land.py   ← YOLO inference — OBB bounding box output
    ├── detect_land2.py  ← YOLO inference — segmentation mask output
    ├── blender_build.py ← 3D building generation via Blender (headless)
    ├── homography.py    ← Homography utilities
    ├── data.yaml        ← YOLO dataset configuration
    ├── requirements.txt ← Python dependencies
    ├── start_server.bat ← One-click server launcher (Windows)
    └── models/          ← 3D .glb building models (download separately)
        └── MODELS.md    ← Model download instructions
```

---

## Prerequisites

| Requirement | Version |
|-------------|---------|
| Python | 3.10+ |
| Flutter SDK | 3.x |
| Android device | ARCore-compatible |
| Network | Both phone and PC on same WiFi |

---

## Server Setup

```bash
cd server

# Install Python dependencies
pip install -r requirements.txt

# Download YOLO model weights (see below) and place as:
#   server/best (4).pt

# Start the server (Windows)
start_server.bat

# Or start manually
uvicorn server:app --host 0.0.0.0 --port 8000
```

The server exposes:
- `POST /detect` — accepts an image, returns land detection JSON
- `GET /models` — lists available 3D building models

---

## Flutter App Setup

```bash
cd flutter_app

# Install Flutter dependencies
flutter pub get

# Build the APK
flutter build apk --release

# Install on connected phone
flutter install
```

Or install the pre-built APK directly from the `Releases` page.

---

## Configuration

### 1. Server IP Address

Edit `flutter_app/lib/config.dart`:

```dart
const String serverBaseUrl = 'http://YOUR_PC_IP:8000';
```

Find your PC's WiFi IP:
- **Windows**: run `ipconfig` → look for "IPv4 Address"
- **Mac/Linux**: run `ifconfig` → look for `inet` on your WiFi interface

### 2. OpenAI API Key

Edit `flutter_app/lib/config.dart`:

```dart
const String openAiApiKey = 'YOUR_OPENAI_API_KEY_HERE';
```

Get an API key at [platform.openai.com](https://platform.openai.com/api-keys).


---

## YOLO Model & 3D Models

These files are too large for git and must be downloaded separately.

### YOLO Model Weights

Download `best (4).pt` and place it in `server/`:

> **[[Download Link](https://drive.google.com/drive/folders/10xMhzuhg3Hss5NjFIOW5T_dIf29CVVGO?usp=drive_link)]**

### 3D Building Models (`.glb`)

Download and place in `server/models/`. See [`server/models/MODELS.md`](server/models/MODELS.md) for details.

> **[[Download Link](https://drive.google.com/drive/folders/1wTIzaqTqCmhsyCBGlRL4KuUmbQdMvegJ?usp=drive_link)]**

---

## Tech Stack

| Layer | Technologies |
|-------|-------------|
| Mobile App | Flutter, Dart, Google ARCore (`arcore_flutter_plugin`) |
| AR Rendering | ARCore, Babylon.js (WebView) |
| AI Assistant | OpenAI GPT API |
| Server | Python, FastAPI, Uvicorn |
| Land Detection | YOLOv8 (Ultralytics), OpenCV |
| 3D Generation | Blender (headless) |
| Communication | HTTP/REST over local WiFi |

---

## Screenshots
How our model can detect land on a brand new image that was not used in training dataset 
<img width="813" height="611" alt="Screenshot 2026-07-25 014603" src="https://github.com/user-attachments/assets/40afaaf3-a217-48f0-93d0-11f677c748a1" />


---

## License

This project is for educational and personal use.
