# 📱 Customer App – Phase 1 (Documents Capture Flow)

A Flutter application for customer document submission and verification.

## 📋 Table of Contents

- [Overview](#overview)
- [Product Requirements](#product-requirements)
  - [1. Splash Screen](#1-splash-screen)
  - [2. Branding Screen](#2-branding-screen)
  - [3. Login Screen](#3-login-screen)
  - [4. Home / Instructions Page](#4-home--instructions-page)
  - [5. Document Submission Steps](#5-document-submission-steps)
  - [6. After Submission](#6-after-submission)
- [Technical Requirements](#technical-requirements)
- [UI/UX Deliverables](#uiux-deliverables)
- [Development Setup](#development-setup)
- [Project Structure](#project-structure)

---

## Overview

This application enables customers to submit required documents for verification through a guided, step-by-step process. The app supports document capture via camera, gallery selection, and file uploads with validation and security features.

---

## Product Requirements

### 1. Splash Screen

- Show app/logo animation (optional)
- Brief loading screen before authentication

### 2. Branding Screen

- **Logo** display
- **Company Name** display

### 3. Login Screen

**Fields:**
- Username input
- Password input
- Login button
- Forgot password link (optional)

---

### 4. Home / Instructions Page

**Display:**
- Process overview
- Required documents information
- Instructions for users

**Actions:**
- **T&C** button (Terms & Conditions)
- **Start** button (begins document submission flow)

---

### 5. Document Submission Steps

#### 🟣 Step 1: Selfie / Photo

**User Options:**
- **Capture via Camera**
- **Select from Gallery**

**Requirements Checklist:**
- ✅ White background (passport style)
- ✅ Face clearly visible
- ✅ Good lighting
- ✅ No filters / editing
- ✅ No shadows

**Validation Rules:**
- If validation fails → **Reject** (show reason)
- Allow retry after rejection

---

#### 🟩 Step 2: Aadhaar Card

**User Options:**
- Capture via camera
- Upload (Image/PDF)

**Submission Rules:**
- Must include **Front & Back** sides
- No blur allowed
- No glare allowed
- If PDF → may have password
  - App should allow entering PDF password

**Validation:**
- Check clarity
- Check name consistency (optional future enhancement)

---

#### 🟦 Step 3: PAN Card

**User Options:**
- Camera capture
- Upload (Image/PDF)

**Submission Rules:**
- Must be clear
- If PDF → allow password entry
- Accept front only (PAN has only front side)

---

#### 🟨 Step 4: Bank Statement (6 months)

**User Options:**
- Upload PDF
- Capture using camera (pages)

**Rules:**
- Must be **last 6 months**
- If PDF locked → ask for password
- Support multi-page capture

---

#### 🟧 Step 5: Personal Data Form

**User Input Fields:**
- Full Name
- Date of Birth (DOB)
- Address
- Mobile Number
- Email Address
- Employment status
- Income details
- *(Final fields based on domain requirements)*

---

#### 🟫 Step 6: Preview & Confirm

**Display:**
- Uploaded documents (thumbnails)
- Captured selfie
- Personal form data summary

**Actions:**
- **Edit any section** (navigate back to specific step)
- **Confirm & Submit** (final submission)

---

### 6. After Submission

**Success Message:**
> "Our agent will review your documents. You will be contacted shortly."

**Status:**
- Mark as **Pending Verification**
- Show submission timestamp
- Option to view submitted documents

---

## Technical Requirements

### Document Validations

- **OCR** for name matching (Aadhaar vs PAN)
- **PDF password unlock** support
- **Image blur detection**
- **Face matching** (Selfie vs PAN/Aadhaar photo)

### Storage & Security

- **Encrypt on device** before upload
- **Upload to secure cloud bucket**
- Secure transmission (HTTPS/TLS)

### Backend Integration

- Document verification workflow API
- Agent review dashboard integration
- Status tracking and notifications

### Additional Features

- Offline support (queue uploads when connection restored)
- Progress tracking for multi-page documents
- Error handling and retry mechanisms

---

## UI/UX Deliverables

The UI/UX team will need to design screens for:

1. **Splash Screen** - App logo and loading animation
2. **Login Screen** - Authentication interface
3. **Instructions + T&C** - Home page with process overview
4. **Selfie Capture** - Camera/gallery interface with validation checklist
5. **Aadhaar Upload** - Front/back capture with validation
6. **PAN Upload** - Document capture interface
7. **Bank Statement Upload** - Multi-page PDF/image capture
8. **Personal Info Form** - Data entry form
9. **Preview & Confirm** - Review screen with edit options
10. **Submission Success** - Confirmation screen with status

### Additional Deliverables (Optional)

- ✅ User flow diagram
- ✅ Wireframe sketches
- ✅ API design documentation
- ✅ Validation rules document
- ✅ OCR + Face Match architecture
- ✅ SOP for agents

---

## Development Setup

### Prerequisites

- Flutter SDK (3.10.4 or higher)
- Dart SDK
- Android Studio / Xcode (for mobile development)
- VS Code or Android Studio (recommended IDEs)

### Installation

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd lcc
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Run the app:
   ```bash
   flutter run
   ```

### Running the App

- **Mobile (iOS/Android)**: `flutter run`
- **Web**: `flutter run -d chrome`
- **Desktop**: `flutter run -d windows` (or `macos`, `linux`)

### Building for Production

- **Android**: `flutter build apk` or `flutter build appbundle`
- **iOS**: `flutter build ios`
- **Web**: `flutter build web`
- **Windows**: `flutter build windows`

---

## Project Structure

```
lib/
  └── main.dart          # Application entry point
```

*Project structure will be expanded as development progresses.*

---

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Documentation](https://dart.dev/)
- [Flutter Cookbook](https://docs.flutter.dev/cookbook)

---

## License

This project is private and not intended for publication.
