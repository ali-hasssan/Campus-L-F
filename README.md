# 🎓 Campus Lost & Found

<p align="center">
  <img src="assets/icon/icon.png" alt="App Icon" width="120" height="120" style="border-radius:24px"/>
</p>

<p align="center">
  A modern Flutter app that helps university students report, search, and recover lost & found items on campus — with real-time chat between students.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter" />
  <img src="https://img.shields.io/badge/Firebase-Firestore-orange?logo=firebase" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green" />
  <img src="https://img.shields.io/badge/Status-Active-brightgreen" />
</p>

---

## 📱 Screenshots

> Add screenshots here after running the app

---

## ✨ Features

| Feature | Description |
|---|---|
| 🔐 **Auth** | Email/password signup & login via Firebase Auth |
| 👤 **Student Profile** | Department, semester, phone, profile photo |
| 🏠 **Home Feed** | Browse all lost & found posts with search & filters |
| 📦 **Post Item** | Report lost or found items with photo, color, area, category |
| 🔍 **Search & Filter** | Filter by category, campus area, or Lost/Found type |
| 📋 **My Posts** | View your own posts, update status (Active / Claimed / Resolved) |
| 💬 **Real-time Chat** | 1-on-1 messaging between students about a post |
| 🖼️ **Profile Photo** | Upload profile picture stored in Firebase Storage |
| ✏️ **Edit Profile** | Update your info anytime from My Posts tab |

---

## 🏗️ Project Structure

```
lib/
├── main.dart                  # App entry, theme, routes
├── models/
│   ├── user_model.dart        # UserModel with profileImageUrl
│   └── post_model.dart        # PostModel with all item fields
├── services/
│   ├── firebase_service.dart  # Auth, Firestore CRUD, Chat, Storage
│   └── storage_service.dart   # Local SharedPreferences helpers
└── screens/
    ├── splash_screen.dart     # Auto session check & redirect
    ├── login_screen.dart      # Email/password login
    ├── signup_screen.dart     # New account registration
    ├── profile_setup_screen.dart  # First-time setup + edit mode
    ├── home_screen.dart       # Main feed + bottom navigation
    ├── create_post_screen.dart    # Create & edit posts
    ├── post_detail_screen.dart    # Full post view + chat entry
    ├── my_posts_screen.dart       # User's own posts + status
    ├── chat_screen.dart           # 1-on-1 real-time chat
    └── chats_screen.dart          # All conversations list
```

---

## 🔥 Firebase Setup (Required)

This app uses **Firebase** for backend. You must create your own Firebase project.

### Step 1 — Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click **Add project** → follow the steps
3. Enable **Google Analytics** (optional)

### Step 2 — Add Apps

**Android:**
1. Click Android icon → enter your package name (e.g. `com.yourname.campuslf`)
2. Download `google-services.json`
3. Place it at: `android/app/google-services.json`

**iOS:**
1. Click iOS icon → enter your bundle ID
2. Download `GoogleService-Info.plist`
3. Place it at: `ios/Runner/GoogleService-Info.plist`

### Step 3 — Enable Firebase Services

In Firebase Console, enable:

| Service | Path |
|---|---|
| **Authentication** | Build → Authentication → Sign-in method → Email/Password ✅ |
| **Firestore Database** | Build → Firestore Database → Create database (Start in test mode) |
| **Storage** | Build → Storage → Get started |

### Step 4 — Firestore Indexes

Go to **Firestore → Indexes → Composite** and create:

```
Collection: chats
Fields:     participants (Arrays)  +  lastMessageTime (Descending)

Collection: posts
Fields:     authorUid (Ascending)  +  createdAt (Descending)
```

> ⚠️ Without indexes, queries will throw errors on first run. Firebase will also show a direct link in the error to create the index automatically.

---

## 🚀 Getting Started

### Prerequisites

- Flutter SDK `>=3.0.0`
- Dart SDK `>=3.0.0`
- Android Studio / VS Code
- Firebase project (see above)

### Installation

```bash
# 1. Clone the repo
git clone https://github.com/YOUR_USERNAME/campus-lost-found.git
cd campus-lost-found

# 2. Install dependencies
flutter pub get

# 3. Add your Firebase config files
#    android/app/google-services.json
#    ios/Runner/GoogleService-Info.plist

# 4. Run the app
flutter run
```

---

## 📦 Dependencies

```yaml
# Firebase
firebase_core
firebase_auth
cloud_firestore
firebase_storage

# UI & Utilities
google_fonts
image_picker
shared_preferences
uuid
intl
timeago
cupertino_icons
```

---

## 🗺️ App Flow

```
Splash Screen
    │
    ├── Not logged in ──→ Login / Signup ──→ Profile Setup ──→ Home
    │
    └── Logged in ─────→ Home
                              │
                ┌─────────────┼─────────────┐
                │             │             │
             Feed          My Posts      Chats
                │             │             │
           Post Detail    Edit Profile  Chat Screen
                │
           Chat Screen
```

---

## 💬 Chat System

- Each conversation has a unique ID: `uid1_uid2` (sorted alphabetically)
- Messages stored at: `chats/{chatId}/messages`
- Chat metadata (last message, participant names/photos) stored at: `chats/{chatId}`
- When a user opens a post and taps the chat icon, the message is pre-filled:
  > *"Can I get more info about your `{item name}`?"*

---

## 🔒 Security Notes

> ⚠️ **Never push these files to GitHub:**
> - `google-services.json`
> - `GoogleService-Info.plist`
> - `android/key.properties`
> - Any `.env` files

These are already covered in `.gitignore`.

For production, set up proper [Firestore Security Rules](https://firebase.google.com/docs/firestore/security/get-started):

```js
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth.uid == userId;
    }
    match /posts/{postId} {
      allow read: if request.auth != null;
      allow create: if request.auth != null;
      allow update, delete: if request.auth.uid == resource.data.userId;
    }
    match /chats/{chatId} {
      allow read, write: if request.auth.uid in resource.data.participants;
      match /messages/{msgId} {
        allow read, write: if request.auth != null;
      }
    }
  }
}
```

---

## 👨‍💻 Developer

**Ali Hassan**  
Mobile app | Flutter & Web Developer  
Top 5% on FlutterFlow

---

## 📄 License

```
MIT License — feel free to use, modify, and distribute.
```

---

<p align="center">Made with ❤️ for university students</p>
