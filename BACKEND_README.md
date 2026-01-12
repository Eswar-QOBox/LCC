# 🔧 Backend API - Complete Implementation Guide

**Precise documentation for backend development to integrate with LCC Flutter application.**

---

## 📋 Table of Contents

- [Overview](#overview)
- [API Endpoints](#api-endpoints)
- [Data Models](#data-models)
- [Authentication](#authentication)
- [File Upload](#file-upload)
- [Database Schema](#database-schema)
- [Error Handling](#error-handling)
- [Setup Instructions](#setup-instructions)
- [Integration Guide](#integration-guide)
- [Testing](#testing)

---

## Overview

### Purpose

Backend API for **LCC (Loan Credit Card) Application** - Document submission and verification system.

### Tech Stack Recommendations

- **Language**: Node.js (Express) / Python (FastAPI/Django) / Java (Spring Boot)
- **Database**: MongoDB (already configured - see [MONGODB_COMPASS_VPS_SETUP.md](./MONGODB_COMPASS_VPS_SETUP.md))
- **File Storage**: AWS S3 / Google Cloud Storage / Local storage
- **Authentication**: JWT tokens
- **API Style**: RESTful

### Base URL

```
Production: https://api.yourdomain.com
Development: http://localhost:3000
```

---

## API Endpoints

### 1. Authentication

#### POST `/api/auth/login`

**Request:**
```json
{
  "username": "user@example.com",
  "password": "password123"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
      "id": "user123",
      "username": "user@example.com",
      "role": "customer"
    }
  }
}
```

**Response (401 Unauthorized):**
```json
{
  "success": false,
  "error": {
    "code": "INVALID_CREDENTIALS",
    "message": "Invalid username or password"
  }
}
```

---

### 2. Document Submission

#### POST `/api/submissions`

**Headers:**
```
Authorization: Bearer <token>
Content-Type: multipart/form-data
```

**Request Body (multipart/form-data):**

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `selfie` | File | Yes | Selfie image (JPEG/PNG, max 20MB) |
| `aadhaarFront` | File | Yes | Aadhaar front side (Image/PDF) |
| `aadhaarBack` | File | Yes | Aadhaar back side (Image/PDF) |
| `aadhaarPdfPassword` | String | No | PDF password if Aadhaar is PDF |
| `panFront` | File | Yes | PAN card front (Image/PDF) |
| `panPdfPassword` | String | No | PDF password if PAN is PDF |
| `bankStatement` | File[] | Yes | Bank statement pages (PDF or multiple images) |
| `bankStatementPdfPassword` | String | No | PDF password if bank statement is PDF |
| `personalData` | JSON String | Yes | Personal information (see PersonalData model) |

**Example `personalData` JSON:**
```json
{
  "nameAsPerAadhaar": "John Doe",
  "dateOfBirth": "1990-01-15",
  "panNo": "ABCDE1234F",
  "mobileNumber": "9876543210",
  "personalEmailId": "john@example.com",
  "countryOfResidence": "India",
  "residenceAddress": "123 Main St, City, State, 123456",
  "residenceType": "Owned",
  "residenceStability": "5 years",
  "companyName": "ABC Corp",
  "companyAddress": "456 Business Ave",
  "nationality": "Indian",
  "countryOfBirth": "India",
  "occupation": "Software Engineer",
  "educationalQualification": "B.Tech",
  "workType": "Full-time",
  "industry": "IT",
  "annualIncome": "1000000",
  "totalWorkExperience": "5 years",
  "currentCompanyExperience": "2 years",
  "loanAmountTenure": "500000 / 5 years",
  "maritalStatus": "Married",
  "spouseName": "Jane Doe",
  "fatherName": "Father Name",
  "motherName": "Mother Name",
  "reference1Name": "Ref 1 Name",
  "reference1Address": "Ref 1 Address",
  "reference1Contact": "9876543211",
  "reference2Name": "Ref 2 Name",
  "reference2Address": "Ref 2 Address",
  "reference2Contact": "9876543212"
}
```

**Response (201 Created):**
```json
{
  "success": true,
  "data": {
    "submissionId": "sub_123456789",
    "status": "pendingVerification",
    "submittedAt": "2025-01-10T10:30:00Z",
    "message": "Documents submitted successfully. Our agent will review your documents."
  }
}
```

**Response (400 Bad Request):**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Missing required fields",
    "details": {
      "selfie": "Selfie is required",
      "aadhaarFront": "Aadhaar front is required"
    }
  }
}
```

---

#### GET `/api/submissions/:submissionId`

**Headers:**
```
Authorization: Bearer <token>
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "submissionId": "sub_123456789",
    "status": "pendingVerification",
    "submittedAt": "2025-01-10T10:30:00Z",
    "reviewedAt": null,
    "reviewedBy": null,
    "documents": {
      "selfie": "https://storage.example.com/selfie_123.jpg",
      "aadhaar": {
        "front": "https://storage.example.com/aadhaar_front_123.jpg",
        "back": "https://storage.example.com/aadhaar_back_123.jpg"
      },
      "pan": {
        "front": "https://storage.example.com/pan_front_123.jpg"
      },
      "bankStatement": [
        "https://storage.example.com/bank_1.pdf"
      ]
    },
    "personalData": { /* PersonalData object */ },
    "agentNotes": null,
    "rejectionReason": null
  }
}
```

---

#### GET `/api/submissions`

**Headers:**
```
Authorization: Bearer <token>
```

**Query Parameters:**
- `status` (optional): Filter by status (`pendingVerification`, `approved`, `rejected`)
- `page` (optional): Page number (default: 1)
- `limit` (optional): Items per page (default: 10)

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "submissions": [
      {
        "submissionId": "sub_123456789",
        "status": "pendingVerification",
        "submittedAt": "2025-01-10T10:30:00Z"
      }
    ],
    "pagination": {
      "page": 1,
      "limit": 10,
      "total": 1,
      "totalPages": 1
    }
  }
}
```

---

### 3. Status Updates

#### PATCH `/api/submissions/:submissionId/status`

**Headers:**
```
Authorization: Bearer <token>
Content-Type: application/json
```

**Request (Agent only):**
```json
{
  "status": "approved",
  "agentNotes": "All documents verified. Approved.",
  "rejectionReason": null
}
```

**OR:**
```json
{
  "status": "rejected",
  "agentNotes": "PAN card is unclear",
  "rejectionReason": "Document quality issue: PAN card image is blurry"
}
```

**Response (200 OK):**
```json
{
  "success": true,
  "data": {
    "submissionId": "sub_123456789",
    "status": "approved",
    "updatedAt": "2025-01-11T14:30:00Z"
  }
}
```

---

## Data Models

### SubmissionStatus Enum

```typescript
enum SubmissionStatus {
  inProgress = "inProgress",
  pendingVerification = "pendingVerification",
  approved = "approved",
  rejected = "rejected"
}
```

### PersonalData Model

```typescript
interface PersonalData {
  // Basic Information
  nameAsPerAadhaar: string;
  dateOfBirth: string; // ISO 8601 format: "YYYY-MM-DD"
  panNo: string; // Format: ABCDE1234F
  mobileNumber: string; // 10 digits
  personalEmailId: string; // Valid email format
  
  // Residence Information
  countryOfResidence: string;
  residenceAddress: string;
  residenceType?: string; // e.g., "Owned", "Rented"
  residenceStability?: string; // e.g., "5 years"
  
  // Company Information
  companyName?: string;
  companyAddress?: string;
  
  // Personal Details
  nationality?: string;
  countryOfBirth?: string;
  occupation?: string;
  educationalQualification?: string;
  workType?: string; // e.g., "Full-time", "Part-time"
  industry?: string;
  annualIncome?: string;
  totalWorkExperience?: string;
  currentCompanyExperience?: string;
  loanAmountTenure?: string;
  
  // Family Information
  maritalStatus?: "Married" | "Unmarried";
  spouseName?: string; // Required if maritalStatus === "Married"
  fatherName?: string;
  motherName?: string;
  
  // Reference Details
  reference1Name?: string;
  reference1Address?: string;
  reference1Contact?: string;
  reference2Name?: string;
  reference2Address?: string;
  reference2Contact?: string;
}
```

### Submission Document

```typescript
interface Submission {
  _id: string; // MongoDB ObjectId
  submissionId: string; // Unique identifier: "sub_<timestamp>_<random>"
  userId: string; // User who submitted
  status: SubmissionStatus;
  
  // Document URLs (stored in cloud storage)
  documents: {
    selfie: string; // URL
    aadhaar: {
      front: string; // URL
      back: string; // URL
      pdfPassword?: string; // Encrypted
    };
    pan: {
      front: string; // URL
      pdfPassword?: string; // Encrypted
    };
    bankStatement: string[]; // Array of URLs
    bankStatementPdfPassword?: string; // Encrypted
  };
  
  // Personal Data
  personalData: PersonalData;
  
  // Metadata
  submittedAt: Date;
  reviewedAt?: Date;
  reviewedBy?: string; // Agent user ID
  agentNotes?: string;
  rejectionReason?: string;
  
  // Timestamps
  createdAt: Date;
  updatedAt: Date;
}
```

---

## Authentication

### JWT Token Structure

**Header:**
```
Authorization: Bearer <token>
```

**Token Payload:**
```json
{
  "userId": "user123",
  "username": "user@example.com",
  "role": "customer",
  "iat": 1704892800,
  "exp": 1704979200
}
```

### Token Expiration

- **Access Token**: 24 hours
- **Refresh Token**: 7 days (if implemented)

### Protected Routes

All `/api/submissions/*` endpoints require authentication.

---

## File Upload

### File Requirements

| Document | Formats | Max Size | Validation |
|----------|---------|----------|------------|
| Selfie | JPEG, PNG | 20 MB | Face detection, white background |
| Aadhaar Front/Back | JPEG, PNG, PDF | 10 MB per file | Clarity check |
| PAN Front | JPEG, PNG, PDF | 10 MB | Clarity check |
| Bank Statement | PDF, JPEG, PNG | 50 MB total | Multi-page support |

### Upload Flow

1. **Client uploads files** → Backend receives multipart/form-data
2. **Backend validates** → File type, size, format
3. **Backend stores** → Upload to cloud storage (S3/GCS)
4. **Backend saves URLs** → Store URLs in database
5. **Backend returns** → Submission ID and status

### Storage Structure

```
storage/
├── submissions/
│   ├── {submissionId}/
│   │   ├── selfie.jpg
│   │   ├── aadhaar_front.jpg
│   │   ├── aadhaar_back.jpg
│   │   ├── pan_front.jpg
│   │   └── bank_statement.pdf
```

### File URL Format

```
https://storage.example.com/submissions/{submissionId}/{filename}
```

---

## Database Schema

### MongoDB Collections

#### `submissions` Collection

```javascript
{
  _id: ObjectId("..."),
  submissionId: "sub_1704892800_abc123",
  userId: "user123",
  status: "pendingVerification", // enum
  documents: {
    selfie: "https://storage.example.com/...",
    aadhaar: {
      front: "https://storage.example.com/...",
      back: "https://storage.example.com/...",
      pdfPassword: "encrypted_password" // Optional
    },
    pan: {
      front: "https://storage.example.com/...",
      pdfPassword: "encrypted_password" // Optional
    },
    bankStatement: [
      "https://storage.example.com/..."
    ],
    bankStatementPdfPassword: "encrypted_password" // Optional
  },
  personalData: {
    nameAsPerAadhaar: "John Doe",
    dateOfBirth: ISODate("1990-01-15"),
    panNo: "ABCDE1234F",
    // ... all PersonalData fields
  },
  submittedAt: ISODate("2025-01-10T10:30:00Z"),
  reviewedAt: null,
  reviewedBy: null,
  agentNotes: null,
  rejectionReason: null,
  createdAt: ISODate("2025-01-10T10:30:00Z"),
  updatedAt: ISODate("2025-01-10T10:30:00Z")
}
```

#### Indexes

```javascript
// Create indexes for performance
db.submissions.createIndex({ "userId": 1 });
db.submissions.createIndex({ "status": 1 });
db.submissions.createIndex({ "submittedAt": -1 });
db.submissions.createIndex({ "submissionId": 1 }, { unique: true });
```

#### `users` Collection (if needed)

```javascript
{
  _id: ObjectId("..."),
  userId: "user123",
  username: "user@example.com",
  password: "hashed_password",
  role: "customer", // "customer" | "agent" | "admin"
  createdAt: ISODate("2025-01-01T00:00:00Z")
}
```

---

## Error Handling

### Error Response Format

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      // Optional: Additional error details
    }
  }
}
```

### Error Codes

| Code | HTTP Status | Description |
|------|-------------|-------------|
| `VALIDATION_ERROR` | 400 | Request validation failed |
| `UNAUTHORIZED` | 401 | Missing or invalid token |
| `FORBIDDEN` | 403 | Insufficient permissions |
| `NOT_FOUND` | 404 | Resource not found |
| `FILE_TOO_LARGE` | 413 | File exceeds size limit |
| `INVALID_FILE_TYPE` | 415 | Unsupported file format |
| `INTERNAL_ERROR` | 500 | Server error |
| `DATABASE_ERROR` | 500 | Database operation failed |
| `STORAGE_ERROR` | 500 | File storage error |

### Example Error Responses

**400 Bad Request:**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Missing required fields",
    "details": {
      "selfie": "Selfie image is required",
      "personalData.nameAsPerAadhaar": "Name is required"
    }
  }
}
```

**401 Unauthorized:**
```json
{
  "success": false,
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Invalid or expired token"
  }
}
```

**413 Payload Too Large:**
```json
{
  "success": false,
  "error": {
    "code": "FILE_TOO_LARGE",
    "message": "Selfie image exceeds maximum size of 20MB"
  }
}
```

---

## Setup Instructions

### 1. Prerequisites

- Node.js 18+ / Python 3.10+ / Java 17+
- MongoDB (see [MONGODB_COMPASS_VPS_SETUP.md](./MONGODB_COMPASS_VPS_SETUP.md))
- Cloud storage account (AWS S3 / GCS) or local storage
- Environment variables configured

### 2. Environment Variables

Create `.env` file:

```bash
# Server
PORT=3000
NODE_ENV=development

# MongoDB
MONGODB_URI=mongodb://admin:password@localhost:27017/lcc?authSource=admin

# JWT
JWT_SECRET=your-super-secret-jwt-key-change-in-production
JWT_EXPIRES_IN=24h

# File Storage
STORAGE_TYPE=s3  # or "local" or "gcs"
AWS_ACCESS_KEY_ID=your-access-key
AWS_SECRET_ACCESS_KEY=your-secret-key
AWS_REGION=us-east-1
AWS_S3_BUCKET=lcc-documents

# Or for Google Cloud Storage
GCS_PROJECT_ID=your-project-id
GCS_BUCKET_NAME=lcc-documents
GCS_KEY_FILE=path/to/service-account-key.json

# Or for local storage
LOCAL_STORAGE_PATH=./uploads
```

### 3. Installation (Node.js Example)

```bash
# Install dependencies
npm install express mongoose multer jsonwebtoken bcrypt dotenv

# Start server
npm start

# Development with hot reload
npm run dev
```

### 4. Database Setup

```bash
# Connect to MongoDB
mongosh "mongodb://admin:password@localhost:27017/lcc?authSource=admin"

# Create indexes
use lcc
db.submissions.createIndex({ "userId": 1 })
db.submissions.createIndex({ "status": 1 })
db.submissions.createIndex({ "submittedAt": -1 })
db.submissions.createIndex({ "submissionId": 1 }, { unique: true })
```

### 5. File Storage Setup

#### AWS S3
1. Create S3 bucket
2. Configure CORS
3. Set up IAM user with S3 permissions
4. Add credentials to `.env`

#### Google Cloud Storage
1. Create GCS bucket
2. Create service account
3. Download key file
4. Add credentials to `.env`

#### Local Storage
1. Create uploads directory
2. Set permissions
3. Configure `LOCAL_STORAGE_PATH` in `.env`

---

## Integration Guide

### Flutter App Integration

#### 1. Create API Service

Create `lib/services/api_service.dart`:

```dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/document_submission.dart';

class ApiService {
  static const String baseUrl = 'https://api.yourdomain.com';
  String? _token;

  void setToken(String token) {
    _token = token;
  }

  Future<Map<String, dynamic>> submitDocuments(
    DocumentSubmission submission,
    Map<String, File> files,
  ) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/submissions'),
    );

    // Add headers
    request.headers['Authorization'] = 'Bearer $_token';

    // Add files
    if (files['selfie'] != null) {
      request.files.add(
        await http.MultipartFile.fromPath('selfie', files['selfie']!.path),
      );
    }
    // ... add other files

    // Add personal data
    request.fields['personalData'] = jsonEncode({
      'nameAsPerAadhaar': submission.personalData?.nameAsPerAadhaar,
      'dateOfBirth': submission.personalData?.dateOfBirth?.toIso8601String(),
      // ... all fields
    });

    var response = await request.send();
    var responseBody = await response.stream.bytesToString();

    if (response.statusCode == 201) {
      return jsonDecode(responseBody);
    } else {
      throw Exception('Submission failed: ${response.statusCode}');
    }
  }
}
```

#### 2. Update SubmissionProvider

Add API call in `lib/providers/submission_provider.dart`:

```dart
Future<void> submitToBackend() async {
  try {
    final apiService = ApiService();
    apiService.setToken(_authToken); // Get from auth provider
    
    final result = await apiService.submitDocuments(
      _submission,
      _getFilesMap(), // Convert paths to File objects
    );
    
    // Update status
    _submission.status = SubmissionStatus.pendingVerification;
    _submission.submittedAt = DateTime.now();
    notifyListeners();
    
  } catch (e) {
    // Handle error
    throw Exception('Failed to submit: $e');
  }
}
```

---

## Testing

### API Testing with cURL

#### Login
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "user@example.com",
    "password": "password123"
  }'
```

#### Submit Documents
```bash
curl -X POST http://localhost:3000/api/submissions \
  -H "Authorization: Bearer <token>" \
  -F "selfie=@/path/to/selfie.jpg" \
  -F "aadhaarFront=@/path/to/aadhaar_front.jpg" \
  -F "aadhaarBack=@/path/to/aadhaar_back.jpg" \
  -F "panFront=@/path/to/pan.jpg" \
  -F "bankStatement=@/path/to/bank.pdf" \
  -F 'personalData={"nameAsPerAadhaar":"John Doe","dateOfBirth":"1990-01-15",...}'
```

### Postman Collection

Create Postman collection with:
- Login request
- Submit documents request
- Get submission request
- Update status request

---

## Security Checklist

- [ ] JWT tokens with secure secret
- [ ] Password hashing (bcrypt/argon2)
- [ ] File upload validation (type, size)
- [ ] Rate limiting on API endpoints
- [ ] CORS configuration
- [ ] Input sanitization
- [ ] SQL/NoSQL injection prevention
- [ ] HTTPS in production
- [ ] Environment variables for secrets
- [ ] File encryption for sensitive documents
- [ ] PDF password encryption in database

---

## Deployment

### Production Checklist

- [ ] Environment variables set
- [ ] MongoDB connection secured
- [ ] File storage configured
- [ ] HTTPS enabled
- [ ] CORS configured
- [ ] Rate limiting enabled
- [ ] Logging configured
- [ ] Error tracking (Sentry, etc.)
- [ ] Monitoring (health checks)
- [ ] Backup strategy

---

## Support & Contact

For backend implementation questions:
- Review this document
- Check [ARCHITECTURE.md](./ARCHITECTURE.md)
- Check [MODULES_README.md](./MODULES_README.md)

---

**Last Updated:** January 2025  
**Version:** 1.0.0
