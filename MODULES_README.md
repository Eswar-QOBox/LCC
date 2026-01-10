# 📦 LCC Application - Modules & Submodules Documentation

This document provides a comprehensive breakdown of all modules and submodules in the LCC (Loan Credit Card) application.

---

## 📋 Table of Contents

- [Module Overview](#module-overview)
- [Core Modules](#core-modules)
  - [Main Entry Point](#1-main-entry-point)
  - [Screens Module](#2-screens-module)
  - [Widgets Module](#3-widgets-module)
  - [Services Module](#4-services-module)
  - [Models Module](#5-models-module)
  - [Providers Module](#6-providers-module)
  - [Utils Module](#7-utils-module)
- [Module Dependencies](#module-dependencies)
- [Module Responsibilities](#module-responsibilities)

---

## 🎯 Module Overview

The LCC application follows a clean architecture pattern with clear separation of concerns:

```
lib/
├── main.dart                 # Application entry point
├── screens/                  # UI/Presentation layer
├── widgets/                  # Reusable UI components
├── services/                 # Business logic layer
├── models/                   # Data models layer
├── providers/                # State management layer
└── utils/                    # Utilities and constants
```

---

## 🏗️ Core Modules

### 1. Main Entry Point

#### `lib/main.dart`
**Purpose:** Application initialization and configuration

**Responsibilities:**
- Initialize Flutter app
- Set up Provider for state management
- Configure MaterialApp with theme
- Define GoRouter configuration
- Register all application routes

**Key Components:**
- `MyApp` - Root widget
- `_router` - GoRouter instance with all routes

**Dependencies:**
- `provider` - State management
- `go_router` - Navigation
- All screen modules
- `app_theme.dart` - Theme configuration
- `app_routes.dart` - Route constants

---

### 2. Screens Module

**Location:** `lib/screens/`

**Purpose:** Contains all application screens/pages

**Module Structure:**
```
screens/
├── Authentication & Onboarding
│   ├── splash_screen.dart
│   ├── branding_screen.dart
│   └── login_screen.dart
├── Main Flow
│   ├── home_screen.dart
│   ├── instructions_screen.dart
│   └── terms_screen.dart
├── Document Submission Steps
│   ├── step1_selfie_screen.dart
│   ├── step2_aadhaar_screen.dart
│   ├── step3_pan_screen.dart
│   ├── step4_bank_statement_screen.dart
│   ├── step5_personal_data_screen.dart
│   └── step6_preview_screen.dart
└── Completion
    └── submission_success_screen.dart
```

#### Submodules:

##### 2.1 Authentication & Onboarding Screens

**`splash_screen.dart`**
- **Purpose:** Initial app loading screen
- **Features:** Logo display, 3-second delay, navigation to branding
- **Dependencies:** `app_routes.dart`

**`branding_screen.dart`**
- **Purpose:** Company branding display
- **Features:** Logo, company name, 2-second delay, navigation to login
- **Dependencies:** `app_routes.dart`

**`login_screen.dart`**
- **Purpose:** User authentication
- **Features:** Username/password form, login button
- **Dependencies:** `app_routes.dart`, `premium_button.dart`

##### 2.2 Main Flow Screens

**`home_screen.dart`**
- **Purpose:** Main landing page after login
- **Features:** Navigation to instructions
- **Dependencies:** `app_routes.dart`

**`instructions_screen.dart`**
- **Purpose:** Process overview and document requirements
- **Features:** 
  - Terms & Conditions checkbox
  - Start Submission button (enabled when terms accepted)
  - Process instructions display
- **Dependencies:** `app_routes.dart`, `submission_provider.dart`, `premium_button.dart`

**`terms_screen.dart`**
- **Purpose:** Display Terms & Conditions
- **Features:** 
  - Read-only terms display
  - Premium UI with sections
  - Go Back button
- **Dependencies:** `app_routes.dart`, `premium_button.dart`, `premium_card.dart`

##### 2.3 Document Submission Steps

**`step1_selfie_screen.dart`**
- **Purpose:** Selfie/photo capture and validation
- **Features:**
  - Camera capture
  - Gallery selection
  - Image preview
  - Real-time validation (face detection, background, lighting)
  - Validation error display
  - Progress indicator
- **Dependencies:** 
  - `document_service.dart` - Validation logic
  - `submission_provider.dart` - State management
  - `platform_image.dart` - Image display
  - `step_progress_indicator.dart` - Progress bar
  - `image_picker` - Camera/gallery access

**`step2_aadhaar_screen.dart`**
- **Purpose:** Aadhaar card front/back upload
- **Features:**
  - Front side capture/upload
  - Back side capture/upload
  - PDF upload support
  - PDF password entry dialog
  - Image preview for both sides
  - Responsive layout
- **Dependencies:**
  - `submission_provider.dart`
  - `platform_image.dart`
  - `step_progress_indicator.dart`
  - `file_picker` - PDF selection
  - `image_picker` - Image capture

**`step3_pan_screen.dart`**
- **Purpose:** PAN card upload
- **Features:**
  - Front side capture/upload
  - PDF upload support
  - PDF password entry dialog
  - Image preview
- **Dependencies:**
  - `submission_provider.dart`
  - `platform_image.dart`
  - `step_progress_indicator.dart`
  - `file_picker`, `image_picker`

**`step4_bank_statement_screen.dart`**
- **Purpose:** Bank statement upload (6 months)
- **Features:**
  - PDF upload
  - Multi-page image capture
  - Gallery selection (multiple images)
  - PDF password entry dialog
  - Page management (add/remove pages)
  - Page count display
- **Dependencies:**
  - `submission_provider.dart`
  - `platform_image.dart`
  - `step_progress_indicator.dart`
  - `file_picker`, `image_picker`

**`step5_personal_data_screen.dart`**
- **Purpose:** Personal information form
- **Features:**
  - 26+ input fields organized in sections:
    - Basic Information (Name, DOB, PAN, Mobile, Email)
    - Residence Information (Country, Address, Type, Stability)
    - Company Information (Name, Address)
    - Personal Details (Occupation, Industry, Income, etc.)
    - Family Information (Marital Status, Spouse, Father, Mother)
    - Reference Details (2 references)
  - Form validation
  - Date picker
  - Conditional fields (Spouse name if married)
  - Input formatters (PAN uppercase, phone digits only)
  - Auto-scroll to errors
  - Loading states
  - Error handling
- **Dependencies:**
  - `submission_provider.dart`
  - `step_progress_indicator.dart`
  - `premium_button.dart`
  - `premium_card.dart`

**`step6_preview_screen.dart`**
- **Purpose:** Review all submitted data before final submission
- **Features:**
  - Display all uploaded documents (thumbnails)
  - Display all personal data fields
  - Edit buttons to navigate back to specific steps
  - Confirm & Submit button
  - Debug logging (development mode)
  - Responsive layout with overflow handling
- **Dependencies:**
  - `submission_provider.dart`
  - `platform_image.dart`
  - `step_progress_indicator.dart`
  - `premium_button.dart`
  - `premium_card.dart`

##### 2.4 Completion Screen

**`submission_success_screen.dart`**
- **Purpose:** Display submission success message
- **Features:**
  - Success animation/icon
  - Success message
  - Navigation back to home
- **Dependencies:** `app_routes.dart`, `premium_button.dart`

---

### 3. Widgets Module

**Location:** `lib/widgets/`

**Purpose:** Reusable UI components used across multiple screens

#### Submodules:

**`premium_button.dart`**
- **Purpose:** Custom styled button with gradient and animations
- **Features:**
  - Gradient background
  - Ripple effect
  - Disabled state styling
  - Customizable text and icon
- **Usage:** Used in all screens for primary actions

**`premium_card.dart`**
- **Purpose:** Custom styled card with gradient border
- **Features:**
  - Gradient border effect
  - Shadow effects
  - Customizable padding and content
- **Usage:** Used for displaying grouped content sections

**`platform_image.dart`**
- **Purpose:** Cross-platform image display widget
- **Features:**
  - Handles both web and mobile platforms
  - Supports file paths and bytes
  - Error handling for missing images
- **Usage:** Used in all document preview screens

**`step_progress_indicator.dart`**
- **Purpose:** Visual progress indicator for multi-step process
- **Features:**
  - Shows current step out of total steps
  - Visual progress bar
  - Step numbers
- **Usage:** Used in all step screens (1-6)

---

### 4. Services Module

**Location:** `lib/services/`

**Purpose:** Business logic and external service integrations

#### Submodules:

**`document_service.dart`**
- **Purpose:** Document validation and processing logic
- **Key Methods:**
  - `validateSelfie()` - Comprehensive selfie validation
    - File size validation
    - Resolution checks
    - Format validation (JPEG, PNG)
    - Image quality analysis (brightness, contrast)
    - Background uniformity check
    - Face detection using Google ML Kit
    - Face size and centering validation
  - `resizeImage()` - Image resizing to 3:4 aspect ratio
- **Features:**
  - Platform-agnostic file handling
  - Error handling with timeouts
  - Memory management (file size limits)
  - Temporary file cleanup
- **Dependencies:**
  - `image` package - Image processing
  - `google_mlkit_face_detection` - Face detection
  - `file_helper_stub.dart` - Web compatibility

**`file_helper_stub.dart`**
- **Purpose:** Web compatibility stub for `dart:io.File`
- **Features:**
  - Provides stub `File` class for web platform
  - Prevents compilation errors on web
  - Used via conditional imports
- **Usage:** Imported conditionally in `document_service.dart`

---

### 5. Models Module

**Location:** `lib/models/`

**Purpose:** Data models and domain entities

#### Submodules:

**`document_submission.dart`**
- **Purpose:** Main data model for document submission
- **Classes:**

  **`DocumentSubmission`**
  - Root model containing all submission data
  - Properties:
    - `selfiePath` - Path to selfie image
    - `aadhaar` - Aadhaar document data
    - `pan` - PAN document data
    - `bankStatement` - Bank statement data
    - `personalData` - Personal information data
    - `submittedAt` - Submission timestamp
    - `status` - Submission status enum
  - Methods:
    - `isComplete` - Checks if all required data is present

  **`AadhaarDocument`**
  - Aadhaar card document model
  - Properties:
    - `frontPath` - Front side image path
    - `backPath` - Back side image path
    - `pdfPassword` - PDF password if applicable
    - `isPdf` - Whether document is PDF
  - Methods:
    - `isComplete` - Validates both sides are present

  **`PanDocument`**
  - PAN card document model
  - Properties:
    - `frontPath` - Front side image path
    - `pdfPassword` - PDF password if applicable
    - `isPdf` - Whether document is PDF
  - Methods:
    - `isComplete` - Validates front side is present

  **`BankStatement`**
  - Bank statement document model
  - Properties:
    - `pages` - List of page paths
    - `pdfPassword` - PDF password if applicable
    - `isPdf` - Whether document is PDF
    - `statementDate` - Statement date
  - Methods:
    - `isComplete` - Validates at least one page is present

  **`PersonalData`**
  - Personal information model (26+ fields)
  - Sections:
    - **Basic Information:**
      - `nameAsPerAadhaar` - Full name
      - `dateOfBirth` - Date of birth
      - `panNo` - PAN number
      - `mobileNumber` - Mobile phone
      - `personalEmailId` - Email address
    - **Residence Information:**
      - `countryOfResidence` - Country
      - `residenceAddress` - Full address
      - `residenceType` - Type of residence
      - `residenceStability` - Stability period
    - **Company Information:**
      - `companyName` - Company name
      - `companyAddress` - Company address
    - **Personal Details:**
      - `nationality` - Nationality
      - `countryOfBirth` - Birth country
      - `occupation` - Occupation
      - `industry` - Industry sector
      - `annualIncome` - Annual income
      - `employmentType` - Employment type
      - `workExperience` - Years of experience
    - **Family Information:**
      - `maritalStatus` - Marital status
      - `spouseName` - Spouse name (conditional)
      - `fatherName` - Father's name
      - `motherName` - Mother's name
    - **Reference Details:**
      - `reference1Name` - First reference name
      - `reference1Contact` - First reference contact
      - `reference2Name` - Second reference name
      - `reference2Contact` - Second reference contact
  - Methods:
    - `isComplete` - Validates all required fields are filled

  **`SubmissionStatus`**
  - Enum for submission status
  - Values: `inProgress`, `submitted`, `approved`, `rejected`

---

### 6. Providers Module

**Location:** `lib/providers/`

**Purpose:** State management using Provider pattern

#### Submodules:

**`submission_provider.dart`**
- **Purpose:** Global state management for document submission
- **Class:** `SubmissionProvider extends ChangeNotifier`
- **State:**
  - `_submission` - `DocumentSubmission` instance
  - `_termsAccepted` - Terms acceptance flag
- **Key Methods:**
  - **Getters:**
    - `submission` - Get current submission data
    - `termsAccepted` - Get terms acceptance status
  - **Setters:**
    - `setSelfie(path)` - Set selfie image path
    - `setAadhaarFront(path, isPdf)` - Set Aadhaar front
    - `setAadhaarBack(path)` - Set Aadhaar back
    - `setAadhaarPassword(password)` - Set Aadhaar PDF password
    - `setPanFront(path, isPdf)` - Set PAN front
    - `setPanPassword(password)` - Set PAN PDF password
    - `setBankStatementPages(pages)` - Set bank statement pages
    - `addBankStatementPage(path)` - Add single page
    - `setBankStatementPassword(password)` - Set bank statement PDF password
    - `setPersonalData(data)` - Set personal data
    - `updatePersonalDataField(field, value)` - Update single field
    - `setTermsAccepted(value)` - Set terms acceptance
  - **Utilities:**
    - `reset()` - Reset all submission data
- **Usage:**
  - Accessed via `context.watch<SubmissionProvider>()` for reactive updates
  - Accessed via `context.read<SubmissionProvider>()` for one-time access
- **Dependencies:**
  - `models/document_submission.dart`

---

### 7. Utils Module

**Location:** `lib/utils/`

**Purpose:** Utilities, constants, and configuration

#### Submodules:

**`app_routes.dart`**
- **Purpose:** Centralized route constants
- **Class:** `AppRoutes`
- **Routes:**
  - Authentication & Onboarding:
    - `splash` - `/`
    - `branding` - `/branding`
    - `login` - `/login`
  - Main Flow:
    - `home` - `/home`
    - `termsAndConditions` - `/terms`
  - Document Steps:
    - `step1Selfie` - `/step1-selfie`
    - `step2Aadhaar` - `/step2-aadhaar`
    - `step3Pan` - `/step3-pan`
    - `step4BankStatement` - `/step4-bank-statement`
    - `step5PersonalData` - `/step5-personal-data`
    - `step6Preview` - `/step6-preview`
  - Completion:
    - `submissionSuccess` - `/submission-success`
- **Usage:** `context.go(AppRoutes.step1Selfie)`

**`app_theme.dart`**
- **Purpose:** Application theme configuration
- **Class:** `AppTheme`
- **Features:**
  - `lightTheme` - Light mode theme
  - `darkTheme` - Dark mode theme (optional)
  - Material Design 3 color scheme
  - Custom typography
  - Custom component themes
- **Usage:** `Theme.of(context)` or `AppTheme.lightTheme`

---

## 🔗 Module Dependencies

### Dependency Graph

```
main.dart
├── screens/ (all screens)
│   ├── providers/submission_provider.dart
│   ├── widgets/ (all widgets)
│   ├── services/document_service.dart
│   └── utils/app_routes.dart
│
providers/submission_provider.dart
└── models/document_submission.dart
│
services/document_service.dart
├── models/document_submission.dart
├── services/file_helper_stub.dart
├── image package
└── google_mlkit_face_detection
│
widgets/
└── (standalone, no internal dependencies)
│
utils/
└── (standalone, no internal dependencies)
```

### External Dependencies

- **`provider`** - State management (used in main.dart)
- **`go_router`** - Navigation (used in main.dart)
- **`image_picker`** - Camera/gallery access (used in step screens)
- **`file_picker`** - File selection (used in step screens)
- **`image`** - Image processing (used in document_service.dart)
- **`google_mlkit_face_detection`** - Face detection (used in document_service.dart)
- **`shared_preferences`** - Local storage (future use)

---

## 📊 Module Responsibilities

### Separation of Concerns

| Module | Responsibility | Should Not |
|--------|--------------|------------|
| **Screens** | UI rendering, user interaction | Business logic, data validation |
| **Widgets** | Reusable UI components | Business logic, state management |
| **Services** | Business logic, validation, external APIs | UI rendering, state management |
| **Models** | Data structure, domain entities | Business logic, UI rendering |
| **Providers** | State management, data flow | Business logic, UI rendering |
| **Utils** | Constants, configuration | Business logic, state management |

### Data Flow

```
User Action (Screen)
    ↓
Provider (State Update)
    ↓
Service (Validation/Processing)
    ↓
Model (Data Structure)
    ↓
Provider (State Update)
    ↓
Screen (UI Update)
```

---

## 🎯 Module Usage Examples

### Example 1: Adding a New Screen

```dart
// 1. Create screen in lib/screens/new_screen.dart
// 2. Add route in lib/utils/app_routes.dart
static const String newScreen = '/new-screen';

// 3. Register route in lib/main.dart
GoRoute(
  path: AppRoutes.newScreen,
  builder: (context, state) => const NewScreen(),
),

// 4. Navigate from any screen
context.go(AppRoutes.newScreen);
```

### Example 2: Using Provider

```dart
// Watch for changes (reactive)
final provider = context.watch<SubmissionProvider>();
final submission = provider.submission;

// Read once (non-reactive)
final provider = context.read<SubmissionProvider>();
provider.setSelfie(imagePath);
```

### Example 3: Using Document Service

```dart
final result = await DocumentService.validateSelfie(
  imagePath,
  imageBytes: bytes,
);

if (result.isValid) {
  // Proceed with submission
} else {
  // Show errors
  showErrors(result.errors);
}
```

### Example 4: Using Custom Widgets

```dart
PremiumButton(
  text: 'Submit',
  onPressed: () => handleSubmit(),
  icon: Icons.check,
)

PremiumCard(
  child: Column(
    children: [/* content */],
  ),
)

PlatformImage(
  imagePath: submission.selfiePath,
  width: 200,
  height: 200,
)
```

---

## 🔄 Module Evolution

### Current State
- ✅ All core modules implemented
- ✅ Clean separation of concerns
- ✅ Reusable components
- ✅ Type-safe navigation

### Future Enhancements

**Services Module:**
- `api_service.dart` - Backend API integration
- `auth_service.dart` - Authentication service
- `upload_service.dart` - Cloud storage upload
- `ocr_service.dart` - OCR integration
- `offline_queue.dart` - Offline support

**Models Module:**
- `api_models.dart` - API request/response models
- `cache_models.dart` - Caching models

**Providers Module:**
- `auth_provider.dart` - Authentication state
- `network_provider.dart` - Network status

**Utils Module:**
- `validators.dart` - Validation utilities
- `formatters.dart` - Input formatters
- `constants.dart` - App constants

---

## 📝 Module Maintenance Guidelines

### Adding New Features

1. **Identify the module** - Which module should contain the new feature?
2. **Check dependencies** - Does it need new dependencies?
3. **Follow patterns** - Use existing patterns in the module
4. **Update documentation** - Update this README if adding new modules

### Code Organization

- Keep modules focused on their responsibility
- Avoid circular dependencies
- Use dependency injection where possible
- Document public APIs

### Testing

- Unit tests for services and models
- Widget tests for widgets
- Integration tests for screens
- Provider tests for state management

---

**Last Updated:** January 2025  
**Version:** 1.0.0

