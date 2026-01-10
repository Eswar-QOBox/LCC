# 🚀 LCC - Development Guide & Tasks

This document contains development tasks, guidelines, and quick reference for the LCC (Loan Credit Card) application.

---

## 📋 Quick Access

- [Current Status](#current-status)
- [Development Tasks](#development-tasks)
- [Quick Commands](#quick-commands)
- [File Structure](#file-structure)
- [Architecture Diagram](#architecture-diagram) - See [ARCHITECTURE.md](./ARCHITECTURE.md) for detailed diagrams
- [Common Issues & Solutions](#common-issues--solutions)
- [Testing Checklist](#testing-checklist)

---

## ✅ Current Status

### Completed Features

- ✅ **Step 1: Selfie/Photo** - Camera/Gallery capture with validation
- ✅ **Step 2: Aadhaar Card** - Front/Back upload with PDF support
- ✅ **Step 3: PAN Card** - Document upload with PDF support
- ✅ **Step 4: Bank Statement** - Multi-page PDF/image upload
- ✅ **Step 5: Personal Data** - Comprehensive form with 26+ fields
- ✅ **Step 6: Preview & Confirm** - Review all data before submission
- ✅ **Terms & Conditions** - Acceptance flow
- ✅ **Selfie Validation** - Face detection, background, lighting checks
- ✅ **Progress Indicators** - Consistent across all steps
- ✅ **Production-Level Code** - Error handling, validation, loading states

### In Progress

- 🔄 **Backend Integration** - API endpoints for submission
- 🔄 **Document Upload** - Cloud storage integration
- 🔄 **OCR Integration** - Name matching between documents

### Pending

- ⏳ **Face Matching** - Selfie vs Aadhaar/PAN photo comparison
- ⏳ **Offline Support** - Queue uploads when offline
- ⏳ **Push Notifications** - Status updates
- ⏳ **Agent Dashboard** - Review interface

---

## 📝 Development Tasks

### High Priority

#### 1. Backend API Integration
- [ ] Create API service layer
- [ ] Implement document upload endpoints
- [ ] Add authentication/authorization
- [ ] Handle API errors and retries
- [ ] Add request/response models

#### 2. Cloud Storage
- [ ] Set up cloud storage bucket (AWS S3 / Google Cloud Storage)
- [ ] Implement secure file upload
- [ ] Add encryption before upload
- [ ] Handle upload progress
- [ ] Implement retry mechanism

#### 3. OCR Integration
- [ ] Integrate OCR service (Google Vision / AWS Textract)
- [ ] Extract text from Aadhaar/PAN
- [ ] Implement name matching logic
- [ ] Add validation for extracted data

### Medium Priority

#### 4. Face Matching
- [ ] Integrate face recognition service
- [ ] Compare selfie with Aadhaar photo
- [ ] Compare selfie with PAN photo
- [ ] Add confidence scoring
- [ ] Handle edge cases

#### 5. Offline Support
- [ ] Implement local storage for submissions
- [ ] Queue uploads when offline
- [ ] Sync when connection restored
- [ ] Show offline indicator
- [ ] Handle conflicts

#### 6. Enhanced Validation
- [ ] Improve selfie validation accuracy
- [ ] Add document clarity checks
- [ ] Implement blur detection
- [ ] Add glare detection
- [ ] Validate document authenticity

### Low Priority

#### 7. UI/UX Improvements
- [ ] Add animations and transitions
- [ ] Improve error messages
- [ ] Add loading indicators
- [ ] Enhance accessibility
- [ ] Add dark mode support

#### 8. Testing
- [ ] Unit tests for services
- [ ] Widget tests for screens
- [ ] Integration tests for flow
- [ ] Performance testing
- [ ] Security testing

#### 9. Documentation
- [ ] API documentation
- [ ] Code comments
- [ ] Architecture diagrams
- [ ] Deployment guide
- [ ] User manual

---

## 🛠️ Quick Commands

### Development

```bash
# Run app
flutter run

# Run on specific device
flutter run -d <device-id>

# Hot reload
r (in terminal)

# Hot restart
R (in terminal)

# Analyze code
flutter analyze

# Format code
flutter format .

# Clean build
flutter clean
flutter pub get
```

### Building

```bash
# Android APK
flutter build apk

# Android App Bundle
flutter build appbundle

# iOS
flutter build ios

# Web
flutter build web

# Windows
flutter build windows
```

### Git Commands

```bash
# Check status
git status

# Add files
git add .

# Commit
git commit -m "Your message"

# Push
git push origin main

# Pull
git pull origin main

# Create branch
git checkout -b feature/your-feature
```

---

## 📁 File Structure

```
lib/
├── main.dart                    # App entry point
├── models/
│   └── document_submission.dart # Data models
├── providers/
│   └── submission_provider.dart # State management
├── screens/
│   ├── splash_screen.dart
│   ├── branding_screen.dart
│   ├── login_screen.dart
│   ├── instructions_screen.dart
│   ├── terms_screen.dart
│   ├── step1_selfie_screen.dart
│   ├── step2_aadhaar_screen.dart
│   ├── step3_pan_screen.dart
│   ├── step4_bank_statement_screen.dart
│   ├── step5_personal_data_screen.dart
│   ├── step6_preview_screen.dart
│   └── submission_success_screen.dart
├── services/
│   ├── document_service.dart   # Validation logic
│   └── file_helper_stub.dart   # Web compatibility
├── utils/
│   ├── app_routes.dart          # Route constants
│   └── app_theme.dart           # Theme configuration
└── widgets/
    ├── premium_button.dart
    ├── premium_card.dart
    ├── platform_image.dart
    └── step_progress_indicator.dart
```

---

## 🏗️ Architecture & Modules

### Architecture Diagrams
For detailed architecture diagrams, component relationships, and data flow, see **[ARCHITECTURE.md](./ARCHITECTURE.md)**.

The architecture document includes:
- High-level system architecture
- User journey flow
- Component structure
- Data flow diagrams
- Integration points
- Security architecture
- Navigation structure

### Modules & Submodules
For comprehensive documentation of all modules, submodules, and their responsibilities, see **[MODULES_README.md](./MODULES_README.md)**.

The modules document includes:
- Complete module breakdown
- Submodule details for each module
- Module dependencies
- Usage examples
- Module responsibilities
- Maintenance guidelines

---

## 🐛 Common Issues & Solutions

### Issue: RenderBox Layout Errors
**Solution:** Ensure widgets have bounded constraints. Use `SizedBox` with `width: double.infinity` or `Expanded` inside `Row`/`Column`.

### Issue: Navigation Not Working
**Solution:** Check route is defined in `main.dart`. Use `context.go()` instead of `Navigator.push()`.

### Issue: Image Not Displaying on Web
**Solution:** Use `PlatformImage` widget instead of `Image.file()`.

### Issue: Face Detection Crashes
**Solution:** Added timeouts, memory limits, and error handling. Check `document_service.dart`.

### Issue: Firebase Requests
**Solution:** This is normal - Google ML Kit includes Firebase components. Can be disabled if needed.

### Issue: Form Validation Not Working
**Solution:** Ensure `_formKey.currentState!.validate()` is called before saving.

---

## ✅ Testing Checklist

### Step 1: Selfie
- [ ] Camera capture works
- [ ] Gallery selection works
- [ ] Validation shows errors correctly
- [ ] Face detection works
- [ ] Background validation works
- [ ] Image resizing works

### Step 2: Aadhaar
- [ ] Front upload works
- [ ] Back upload works
- [ ] PDF upload works
- [ ] PDF password entry works
- [ ] Preview displays correctly

### Step 3: PAN
- [ ] Document upload works
- [ ] PDF upload works
- [ ] PDF password entry works
- [ ] Preview displays correctly

### Step 4: Bank Statement
- [ ] PDF upload works
- [ ] Multi-page capture works
- [ ] PDF password entry works
- [ ] Page count displays correctly

### Step 5: Personal Data
- [ ] All fields save correctly
- [ ] Validation works
- [ ] Date picker works
- [ ] Conditional fields show/hide correctly
- [ ] Data persists on navigation

### Step 6: Preview
- [ ] All documents display
- [ ] All personal data displays
- [ ] Edit buttons work
- [ ] Submit button works
- [ ] Success screen shows

---

## 🔧 Development Guidelines

### Code Style
- Use `dart format .` before committing
- Follow Flutter/Dart style guide
- Add comments for complex logic
- Use meaningful variable names

### State Management
- Use `Provider` for global state
- Use `setState` for local UI state
- Always check `mounted` before `setState`
- Use `context.mounted` before navigation

### Error Handling
- Always wrap async operations in try-catch
- Show user-friendly error messages
- Log errors for debugging
- Handle edge cases gracefully

### Performance
- Use `const` constructors where possible
- Avoid unnecessary rebuilds
- Optimize image loading
- Use lazy loading for lists

### Security
- Never commit API keys
- Use environment variables
- Encrypt sensitive data
- Validate all inputs

---

## 📚 Key Files Reference

### Routes
- **File:** `lib/utils/app_routes.dart`
- **Usage:** `context.go(AppRoutes.step1Selfie)`

### Theme
- **File:** `lib/utils/app_theme.dart`
- **Usage:** `Theme.of(context)` or `AppTheme.lightTheme`

### State Management
- **File:** `lib/providers/submission_provider.dart`
- **Usage:** `context.read<SubmissionProvider>()` or `context.watch<SubmissionProvider>()`

### Validation
- **File:** `lib/services/document_service.dart`
- **Method:** `DocumentService.validateSelfie()`

### Models
- **File:** `lib/models/document_submission.dart`
- **Classes:** `DocumentSubmission`, `PersonalData`, `AadhaarDocument`, etc.

---

## 🚨 Known Issues

1. **Firebase Logging** - Automatic telemetry from Google ML Kit (harmless)
2. **RenderBox Overflow** - Some buttons may overflow on small screens (minor)
3. **Web Image Preview** - May show placeholder on some browsers

---

## 📞 Support & Resources

- **Flutter Docs:** https://docs.flutter.dev/
- **Dart Docs:** https://dart.dev/
- **GoRouter Docs:** https://pub.dev/packages/go_router
- **Provider Docs:** https://pub.dev/packages/provider

---

## 🎯 Next Steps

1. Set up backend API endpoints
2. Implement cloud storage upload
3. Add OCR integration
4. Implement face matching
5. Add offline support
6. Write comprehensive tests
7. Performance optimization
8. Security audit

---

**Last Updated:** January 2025
**Version:** 1.0.0

