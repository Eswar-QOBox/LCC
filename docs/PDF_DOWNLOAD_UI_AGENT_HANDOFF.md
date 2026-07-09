# PDF Download UI — Agent handoff (port to another project)

This document describes the **Download PDF** feature in the LCC Flutter app so another repository’s agent can reuse the UI, replace business logic, or port selectively.

**Source repo layout:** paths below are relative to the project root (e.g. `lcc/`).

---

## 1. Goal of the screen

`PdfDownloadScreen` presents:

- Gradient scaffold and custom app bar (“Download PDF”, PDF icon).
- Hero-style **header card** (“Download Your Submission”).
- **“What’s Included”** checklist with green/orange/grey states (content depends on loan type: personal vs business proprietor vs partnership vs Pvt Ltd).
- **“Use sample data”** toggle (testing).
- Primary CTA: **Generate & Download PDF** (loading state).
- Info card explaining that the PDF is a summary.

Behavior:

- On load (when not using sample data), calls `PdfGenerationService.hydrateSubmissionForPdf` (best-effort sync of uploaded docs).
- On CTA, calls `PdfGenerationService.generateApplicationPdf` then shows success/error toasts.

---

## 2. Files to copy (UI shell)

| File | Role |
|------|------|
| `lib/screens/pdf_download_screen.dart` | Entire screen (~640 lines). |
| `lib/widgets/premium_card.dart` | Card container with optional gradient. |
| `lib/widgets/premium_button.dart` | Primary button with loading animation. |
| `lib/widgets/premium_toast.dart` | Success/error/info toasts used by the screen. |
| `lib/utils/app_theme.dart` | `AppTheme.primaryColor`, `secondaryColor`, `successColor` (adjust or inline in target app). |

---

## 3. Runtime dependencies (this screen’s imports)

From `pdf_download_screen.dart`:

- `package:flutter/material.dart`
- `package:provider/provider.dart` — `context.read` / `context.watch` for `SubmissionProvider`, `ApplicationProvider`
- `package:go_router/go_router.dart` — back button uses `context.go(AppRoutes.submissionSuccess)`
- `../services/pdf_generation_service.dart`
- `../utils/app_routes.dart` — at least `AppRoutes.submissionSuccess` if you keep the same back navigation

**Route constant in this app:** `AppRoutes.pdfDownload` = `'/pdf-download'` (`lib/utils/app_routes.dart`).  
**Router registration:** `lib/main.dart` — `GoRoute(path: AppRoutes.pdfDownload, builder: … PdfDownloadScreen())`.

**Optional minimal runner** (opens only this screen): `lib/main_pdf_test.dart`.

---

## 4. Data layer this screen expects

The UI is tightly coupled to:

- **`SubmissionProvider`** (`lib/providers/submission_provider.dart`) — `submission` with fields such as `personalData`, `selfiePath`, `aadhaar`, `pan`, `bankStatement`, `salarySlips`, `businessDocuments`, `loanType`, `businessLoanType`, etc.
- **`ApplicationProvider`** (`lib/providers/application_provider.dart`) — `currentApplication` with `loanType`, `status`.

For a **different app**, the pragmatic approach is:

1. Copy the widgets in §2.
2. Replace `SubmissionProvider` / `ApplicationProvider` with your own `ChangeNotifier` (or `InheritedWidget`) **or** pass a small interface/callback into a refactored screen.
3. Simplify or remove the “What’s Included” rows to match your domain.

---

## 5. PDF generation service (large; loan-specific)

**File:** `lib/services/pdf_generation_service.dart` (~1900+ lines)

**Direct imports (indicative):** `dart:io`, `dart:typed_data`, `package:flutter/...`, `package:http/http.dart`, `package:provider/provider.dart`, `package:pdf/pdf.dart`, `package:pdf/widgets.dart`, `package:intl/intl.dart`, `package:path_provider/path_provider.dart`, `package:share_plus/share_plus.dart`, `package:image_picker/image_picker.dart`, plus project models/providers/services (`document_submission`, `additional_document`, `auth_provider`, `submission_provider`, `application_provider`, `storage_service`, `api_config`, `additional_documents_service`).

**Porting options:**

| Strategy | When to use |
|----------|-------------|
| **UI only** | Keep layout and checklist concept; implement `generatePdf()` with your stack (e.g. `pdf` + `printing` / `share_plus`) and your models. |
| **Full port** | Only if the target app mirrors the same loan submission model and APIs; expect to copy many models and services. |

---

## 6. `pubspec.yaml` packages relevant to PDF flow

Confirm versions in the source `pubspec.yaml`. This feature’s service layer typically relies on:

- `pdf`
- `path_provider`
- `share_plus`
- `http`
- `intl`
- `image_picker`
- `provider`
- `go_router`

(Plus any transitive deps already declared for the rest of the app.)

---

## 7. Checklist for the receiving agent

1. [ ] Copy §2 files; fix imports and package name.
2. [ ] Provide theme colors (or map `AppTheme` to target design tokens).
3. [ ] Register a route to `PdfDownloadScreen` (or rename) in target router.
4. [ ] Either supply `SubmissionProvider` + `ApplicationProvider` equivalents **or** refactor `pdf_download_screen.dart` to your state.
5. [ ] Replace `PdfGenerationService` with target PDF pipeline **or** port the service and its dependency graph.
6. [ ] Replace `context.go(AppRoutes.submissionSuccess)` with the correct back/success route in the target app.
7. [ ] Run analyzer/tests; fix missing symbols.

---

## 8. Source of truth

All paths refer to the **LCC / lcc** Flutter repository where this file lives. After copy, this markdown can live in the **destination** repo as onboarding for maintainers.
