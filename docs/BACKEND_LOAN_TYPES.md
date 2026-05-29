# Backend: Supported Loan Types

The Flutter app sends `loanType` when creating/updating applications. The backend currently validates:

```text
Must be one of: Personal Loan, Car Loan, Home Loan, Business Loan, Education Loan.
```

**Required changes:**

- Add **Professional Loan** to the allowed values so the app can create Professional Loan applications.
- Add **Mortgage Loan** to the allowed values so the app can create Mortgage Loan applications. The app sends the exact string `"Mortgage Loan"` (it is not remapped client-side).

## 1. Applications API

- **POST /api/v1/applications**  
  - Request body includes `loanType`.  
  - Allow: `"Professional Loan"` and `"Mortgage Loan"` in addition to the existing five types.

- **PATCH/PUT /api/v1/applications/:id**  
  - If `loanType` is validated, allow `"Professional Loan"` and `"Mortgage Loan"` here too.

## 2. Optional: Professional sub-type

For Professional Loan, the app may send a sub-type (e.g. in draft/submission payload or a separate field):

- **professionalLoanType**: `"doctor"` | `"ca"`

If your API stores or validates loan sub-types, add support for this field when `loanType === "Professional Loan"`.

## 3. Mortgage Loan property documents

Mortgage Loan reuses the standard salaried flow (KYC + bank statement + salary slips, optional co-applicant) and adds a Property Details step. The applicant can add one or more properties; each property is a named document uploaded to the lead-documents endpoint.

- **Upload endpoint**: `POST /api/lead-documents/upload` (multipart, unchanged)
- **documentType**: prefixed `applicant_mortgage_property_<entryId>` (one per property)
- **displayName**: the user-entered property name (used for CRM listing labels)

No new endpoint is required; the backend only needs to accept these `documentType` values and persist the optional `displayName` for listing.

## 4. Summary

| Loan type         | Allowed | Notes                          |
|-------------------|--------|---------------------------------|
| Personal Loan     | ✓      | Existing                       |
| Car Loan          | ✓      | Existing                       |
| Home Loan         | ✓      | Existing                       |
| Business Loan     | ✓      | Existing (has businessLoanType) |
| Education Loan    | ✓      | Existing                       |
| **Professional Loan** | **Add** | New (has professionalLoanType: doctor/ca) |
| **Mortgage Loan** | **Add** | New (adds property documents via `applicant_mortgage_property_*`) |

After adding **Professional Loan** and **Mortgage Loan** to validation, creating those applications from the app will succeed.
