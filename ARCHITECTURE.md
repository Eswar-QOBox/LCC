# 🏗️ LCC Application Architecture

This document provides a comprehensive overview of the LCC (Loan Credit Card) application architecture, including component relationships, data flow, and system design.

---

## 📊 Architecture Overview

### High-Level Architecture

```mermaid
graph TB
    subgraph "Presentation Layer"
        UI[Screens/Widgets]
        NAV[Navigation - GoRouter]
    end
    
    subgraph "State Management Layer"
        PROVIDER[SubmissionProvider]
        STATE[DocumentSubmission Model]
    end
    
    subgraph "Business Logic Layer"
        DOC_SERVICE[DocumentService]
        VALIDATION[Validation Logic]
        FACE_DETECT[Face Detection]
    end
    
    subgraph "Data Layer"
        MODELS[Data Models]
        STORAGE[Local Storage]
    end
    
    subgraph "External Services"
        CAMERA[Camera/Gallery]
        ML_KIT[Google ML Kit]
        API[Backend API - Future]
        CLOUD[Cloud Storage - Future]
    end
    
    UI --> NAV
    UI --> PROVIDER
    PROVIDER --> STATE
    UI --> DOC_SERVICE
    DOC_SERVICE --> VALIDATION
    DOC_SERVICE --> FACE_DETECT
    FACE_DETECT --> ML_KIT
    DOC_SERVICE --> CAMERA
    PROVIDER --> MODELS
    PROVIDER --> STORAGE
    UI --> API
    DOC_SERVICE --> CLOUD
    
    style UI fill:#e1f5ff
    style PROVIDER fill:#fff4e1
    style DOC_SERVICE fill:#e8f5e9
    style MODELS fill:#f3e5f5
```

---

## 🔄 Application Flow

### User Journey Flow

```mermaid
flowchart TD
    START([App Start]) --> SPLASH[Splash Screen]
    SPLASH --> BRANDING[Branding Screen]
    BRANDING --> LOGIN[Login Screen]
    LOGIN --> HOME[Home/Instructions]
    HOME --> TERMS{Terms Accepted?}
    TERMS -->|No| TERMS_SCREEN[Terms Screen]
    TERMS_SCREEN --> HOME
    TERMS -->|Yes| STEP1[Step 1: Selfie]
    STEP1 --> STEP2[Step 2: Aadhaar]
    STEP2 --> STEP3[Step 3: PAN]
    STEP3 --> STEP4[Step 4: Bank Statement]
    STEP4 --> STEP5[Step 5: Personal Data]
    STEP5 --> STEP6[Step 6: Preview]
    STEP6 --> SUBMIT{Submit?}
    SUBMIT -->|Edit| STEP1
    SUBMIT -->|Confirm| SUCCESS[Success Screen]
    SUCCESS --> HOME
    
    style START fill:#90EE90
    style SUCCESS fill:#90EE90
    style TERMS fill:#FFD700
    style SUBMIT fill:#FFD700
```

---

## 🧩 Component Architecture

### Layer Breakdown

```mermaid
graph LR
    subgraph "Layer 1: UI/Presentation"
        A1[Splash Screen]
        A2[Branding Screen]
        A3[Login Screen]
        A4[Instructions Screen]
        A5[Terms Screen]
        A6[Step 1-6 Screens]
        A7[Success Screen]
    end
    
    subgraph "Layer 2: State Management"
        B1[SubmissionProvider]
        B2[ChangeNotifier]
    end
    
    subgraph "Layer 3: Services"
        C1[DocumentService]
        C2[Validation Service]
    end
    
    subgraph "Layer 4: Models"
        D1[DocumentSubmission]
        D2[PersonalData]
        D3[AadhaarDocument]
        D4[PanDocument]
        D5[BankStatement]
    end
    
    subgraph "Layer 5: Utilities"
        E1[AppRoutes]
        E2[AppTheme]
        E3[Widgets]
    end
    
    A6 --> B1
    B1 --> C1
    C1 --> D1
    A6 --> E1
    A6 --> E2
    A6 --> E3
    
    style A6 fill:#e1f5ff
    style B1 fill:#fff4e1
    style C1 fill:#e8f5e9
    style D1 fill:#f3e5f5
```

---

## 📦 Data Flow Architecture

### State Management Flow

```mermaid
sequenceDiagram
    participant User
    participant Screen
    participant Provider
    participant Service
    participant Model
    
    User->>Screen: Upload Document
    Screen->>Service: validateDocument()
    Service-->>Screen: Validation Result
    Screen->>Provider: setDocument(path)
    Provider->>Model: Update DocumentSubmission
    Provider->>Screen: notifyListeners()
    Screen->>User: Show Success/Error
```

---

## 🗂️ Detailed Component Structure

### 1. Presentation Layer (Screens)

```
lib/screens/
├── splash_screen.dart          # Initial loading
├── branding_screen.dart        # Company branding
├── login_screen.dart           # Authentication
├── instructions_screen.dart    # Process overview
├── terms_screen.dart           # Terms & Conditions
├── step1_selfie_screen.dart    # Selfie capture
├── step2_aadhaar_screen.dart   # Aadhaar upload
├── step3_pan_screen.dart       # PAN upload
├── step4_bank_statement_screen.dart  # Bank statement
├── step5_personal_data_screen.dart   # Personal info form
├── step6_preview_screen.dart   # Review & confirm
└── submission_success_screen.dart     # Success message
```

### 2. State Management (Provider)

```
lib/providers/
└── submission_provider.dart
    ├── DocumentSubmission _submission
    ├── bool _termsAccepted
    ├── setSelfie()
    ├── setAadhaarFront/Back()
    ├── setPanFront()
    ├── setBankStatementPages()
    ├── setPersonalData()
    └── reset()
```

### 3. Business Logic (Services)

```
lib/services/
├── document_service.dart
│   ├── validateSelfie()
│   │   ├── File size check
│   │   ├── Resolution check
│   │   ├── Format validation
│   │   ├── Brightness/Contrast
│   │   ├── Background uniformity
│   │   └── Face detection (ML Kit)
│   └── resizeImage()
└── file_helper_stub.dart       # Web compatibility
```

### 4. Data Models

```
lib/models/
└── document_submission.dart
    ├── DocumentSubmission
    │   ├── String? selfiePath
    │   ├── AadhaarDocument? aadhaar
    │   ├── PanDocument? pan
    │   ├── BankStatement? bankStatement
    │   └── PersonalData? personalData
    ├── PersonalData (26+ fields)
    ├── AadhaarDocument
    ├── PanDocument
    └── BankStatement
```

### 5. Utilities & Widgets

```
lib/utils/
├── app_routes.dart             # Route constants
└── app_theme.dart              # Theme configuration

lib/widgets/
├── premium_button.dart         # Custom button
├── premium_card.dart           # Custom card
├── platform_image.dart         # Cross-platform image
└── step_progress_indicator.dart # Progress bar
```

---

## 🔌 Integration Points

### Current Integrations

```mermaid
graph LR
    APP[LCC App] --> CAMERA[image_picker]
    APP --> ROUTER[go_router]
    APP --> PROVIDER[provider]
    APP --> ML_KIT[google_mlkit_face_detection]
    APP --> IMAGE[image package]
    APP --> FILE[file_picker]
    
    style APP fill:#4CAF50
    style CAMERA fill:#2196F3
    style ML_KIT fill:#FF9800
```

### Future Integrations

```
┌─────────────────┐
│   Backend API   │ ← REST/GraphQL
│   (Future)      │
└─────────────────┘
         ↑
         │
┌─────────────────┐
│  Cloud Storage  │ ← AWS S3 / GCS
│   (Future)      │
└─────────────────┘
         ↑
         │
┌─────────────────┐
│   OCR Service  │ ← Google Vision / AWS Textract
│   (Future)      │
└─────────────────┘
```

---

## 🔐 Security Architecture

### Data Flow Security

```mermaid
graph TB
    USER[User Input] --> VALIDATE[Input Validation]
    VALIDATE --> ENCRYPT[Encryption - Future]
    ENCRYPT --> STORAGE[Local Storage]
    STORAGE --> UPLOAD[Secure Upload - Future]
    UPLOAD --> CLOUD[Cloud Storage]
    
    style VALIDATE fill:#FFE082
    style ENCRYPT fill:#81C784
    style UPLOAD fill:#64B5F6
```

### Current Security Measures

- ✅ Input validation on all forms
- ✅ File type validation
- ✅ Image size/resolution checks
- ✅ Error handling and sanitization
- ⏳ Encryption (planned)
- ⏳ Secure API communication (planned)
- ⏳ Token-based authentication (planned)

---

## 📱 Platform Support

### Multi-Platform Architecture

```
                    ┌─────────────┐
                    │  Flutter    │
                    │   Engine    │
                    └──────┬──────┘
                           │
        ┌──────────────────┼──────────────────┐
        │                  │                  │
   ┌────▼────┐      ┌──────▼──────┐    ┌─────▼─────┐
   │ Android │      │     iOS     │    │    Web    │
   └─────────┘      └─────────────┘    └───────────┘
        │                  │                  │
        └──────────────────┼──────────────────┘
                           │
                    ┌──────▼──────┐
                    │  Platform   │
                    │  Adaptations│
                    └─────────────┘
```

### Platform-Specific Handling

- **Web**: Uses `file_helper_stub.dart` for file operations
- **Mobile**: Native file system access via `dart:io`
- **Image Display**: `PlatformImage` widget handles both platforms

---

## 🧪 Testing Architecture

### Testing Layers (Planned)

```mermaid
graph TB
    UNIT[Unit Tests]
    WIDGET[Widget Tests]
    INTEGRATION[Integration Tests]
    
    UNIT --> SERVICES[Service Tests]
    UNIT --> MODELS[Model Tests]
    UNIT --> PROVIDERS[Provider Tests]
    
    WIDGET --> SCREENS[Screen Tests]
    WIDGET --> WIDGETS[Widget Tests]
    
    INTEGRATION --> FLOW[User Flow Tests]
    INTEGRATION --> API[API Integration Tests]
```

---

## 🚀 Deployment Architecture

### Build Targets

```
┌─────────────────────────────────────┐
│         Flutter Build              │
└──────────────┬──────────────────────┘
               │
    ┌──────────┼──────────┐
    │          │          │
┌───▼───┐ ┌───▼───┐ ┌───▼───┐
│  APK  │ │  iOS  │ │  Web  │
│  AAB  │ │  IPA  │ │  HTML │
└───────┘ └───────┘ └───────┘
```

---

## 📈 Performance Considerations

### Optimization Strategies

1. **Image Processing**
   - Resize images before validation
   - Limit file sizes (20MB for loading, 5MB for face detection)
   - Use timeouts for long operations

2. **State Management**
   - Use `context.watch()` only when needed
   - Use `context.read()` for one-time operations
   - Check `mounted` before `setState()`

3. **Memory Management**
   - Clean up temporary files
   - Dispose controllers properly
   - Use `const` constructors where possible

---

## 🔄 Navigation Architecture

### Route Structure

```mermaid
graph LR
    SPLASH[/] --> BRANDING[/branding]
    BRANDING --> LOGIN[/login]
    LOGIN --> HOME[/home]
    HOME --> TERMS[/terms]
    HOME --> STEP1[/step1-selfie]
    STEP1 --> STEP2[/step2-aadhaar]
    STEP2 --> STEP3[/step3-pan]
    STEP3 --> STEP4[/step4-bank-statement]
    STEP4 --> STEP5[/step5-personal-data]
    STEP5 --> STEP6[/step6-preview]
    STEP6 --> SUCCESS[/submission-success]
    SUCCESS --> HOME
```

---

## 📝 Key Design Decisions

### 1. State Management
- **Choice**: Provider pattern
- **Reason**: Simple, built-in Flutter support, sufficient for current needs
- **Alternative Considered**: Riverpod, Bloc

### 2. Navigation
- **Choice**: GoRouter
- **Reason**: Declarative routing, type-safe, deep linking support
- **Alternative Considered**: Navigator 2.0, AutoRoute

### 3. Image Processing
- **Choice**: `image` package + Google ML Kit
- **Reason**: Cross-platform, good performance, face detection support
- **Alternative Considered**: Firebase ML, custom solutions

### 4. File Handling
- **Choice**: Platform-agnostic approach with stubs
- **Reason**: Support both web and mobile with same codebase
- **Alternative Considered**: Platform channels

---

## 🔮 Future Architecture Enhancements

### Planned Additions

1. **Backend Integration Layer**
   ```
   lib/services/
   ├── api_service.dart
   ├── auth_service.dart
   └── upload_service.dart
   ```

2. **Offline Support**
   ```
   lib/services/
   ├── offline_queue.dart
   └── sync_service.dart
   ```

3. **Caching Layer**
   ```
   lib/services/
   └── cache_service.dart
   ```

4. **Analytics & Monitoring**
   ```
   lib/services/
   ├── analytics_service.dart
   └── error_tracking.dart
   ```

---

## 📚 References

- [Flutter Architecture](https://docs.flutter.dev/development/data-and-backend/state-mgmt)
- [Provider Package](https://pub.dev/packages/provider)
- [GoRouter](https://pub.dev/packages/go_router)
- [Google ML Kit](https://developers.google.com/ml-kit)

---

**Last Updated:** January 2025  
**Version:** 1.0.0

