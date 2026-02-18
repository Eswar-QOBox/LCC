# Backend: Supported Loan Types

The Flutter app sends `loanType` when creating/updating applications. The backend currently validates:

```text
Must be one of: Personal Loan, Car Loan, Home Loan, Business Loan, Education Loan.
```

**Required change:** Add **Professional Loan** to the allowed values so the app can create Professional Loan applications.

## 1. Applications API

- **POST /api/v1/applications**  
  - Request body includes `loanType`.  
  - Allow: `"Professional Loan"` in addition to the existing five types.

- **PATCH/PUT /api/v1/applications/:id**  
  - If `loanType` is validated, allow `"Professional Loan"` here too.

## 2. Optional: Professional sub-type

For Professional Loan, the app may send a sub-type (e.g. in draft/submission payload or a separate field):

- **professionalLoanType**: `"doctor"` | `"ca"`

If your API stores or validates loan sub-types, add support for this field when `loanType === "Professional Loan"`.

## 3. Summary

| Loan type         | Allowed | Notes                          |
|-------------------|--------|---------------------------------|
| Personal Loan     | ✓      | Existing                       |
| Car Loan          | ✓      | Existing                       |
| Home Loan         | ✓      | Existing                       |
| Business Loan     | ✓      | Existing (has businessLoanType) |
| Education Loan    | ✓      | Existing                       |
| **Professional Loan** | **Add** | New (has professionalLoanType: doctor/ca) |

After adding **Professional Loan** to validation, creating a Professional Loan from the app will succeed.
