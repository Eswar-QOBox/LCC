# Backend: Supported Loan Types

The Flutter app sends `loanType` when creating/updating applications.

> **Verified against the current JHipster backend (`A:/mememates-/backend`):**
> `LoanSubmission.loanType` is a free-form `String(100)` with **no enum and no allow-list**
> (`@NotNull @Size(max = 100)`), and `LoanSubmissionResource` does not validate the value.
> This means **`"Mortgage Loan"` and `"Professional Loan"` are already accepted as-is — no
> backend change is required today.** The list below is the canonical set of strings the app
> sends, kept here so that *if* a future allow-list / reporting bucket / DB enum is introduced,
> all values are included. See `backend/MOBILE_MORTGAGE_PROPERTY_INTEGRATION.md` for the full
> integration contract.

Canonical loan-type strings sent by the app:

```text
Personal Loan, Car Loan, Home Loan, Business Loan, Education Loan, Professional Loan, Mortgage Loan
```

Notes:

- The app sends `"Mortgage Loan"` verbatim (it is not remapped client-side).
- Professional Loan and Student Loan are remapped client-side before sending (Professional Loan -> `Personal Loan`, Student Loan -> `Education Loan`).

## 1. Applications API

The app uses JHipster's loan-submission endpoints (not `/api/v1/applications`):

- **POST /api/loan-submissions** — request body includes `loanType`. Accepts any string up to 100 chars, so `"Professional Loan"` and `"Mortgage Loan"` already work.
- **PUT/PATCH /api/loan-submissions/:id** — same; `loanType` is not validated against an allow-list.

No change is needed unless/until an allow-list is introduced (see the note at the top of this file).

## 2. Optional: Professional sub-type

For Professional Loan, the app may send a sub-type (e.g. in draft/submission payload or a separate field):

- **professionalLoanType**: `"doctor"` | `"ca"`

If your API stores or validates loan sub-types, add support for this field when `loanType === "Professional Loan"`.

## 3. Home Loan & Mortgage Loan property documents

Home Loan and Mortgage Loan reuse the standard salaried flow (KYC + bank statement + salary slips, optional co-applicant) and add a Property Details step. The applicant can add one or more properties; each property is a named document uploaded to the lead-documents endpoint.

- **Upload endpoint**: `POST /api/lead-documents/upload` (multipart, unchanged)
- **documentType**: prefixed `applicant_property_<entryId>` (one per property)
- **displayName**: the user-entered property name (used for CRM listing labels)

No new endpoint is required. The current `LeadDocumentResource.uploadLeadDocumentFile(...)` already accepts arbitrary `documentType` strings (stored verbatim as `documentKey`) and persists the optional `displayName` as the document `name`. `applicant_property_*` values resolve to `DocumentType.OTHER` and are fully listable/deletable — **already working, no change needed.**

## 4. Summary

| Loan type         | Accepted today | Notes                          |
|-------------------|----------------|---------------------------------|
| Personal Loan     | ✓ | Existing |
| Car Loan          | ✓ | Existing |
| Home Loan         | ✓ | Existing — now also collects property documents via `applicant_property_*` |
| Business Loan     | ✓ | Existing (has businessLoanType) |
| Education Loan    | ✓ | Existing |
| Professional Loan | ✓ | Remapped to `Personal Loan` client-side (has professionalLoanType: doctor/ca) |
| Mortgage Loan     | ✓ | Sent verbatim; adds property documents via `applicant_property_*` |

Because `loanType` is a free-form string on the backend, **all of the above already succeed from the app with no backend change.** This file should be updated if a validating allow-list is ever added.
