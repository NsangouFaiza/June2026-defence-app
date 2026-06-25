# LifeLink API Documentation

## Base URL
```
http://localhost:8000/api
```

## Authentication

All authenticated endpoints require a Bearer token in the Authorization header:
```
Authorization: Bearer <access_token>
```

## Endpoints

### Authentication

#### Register
```
POST /users/register/
```

**Request Body:**
```json
{
  "full_name": "John Doe",
  "email": "john@example.com",
  "phone_number": "+237123456789",
  "password": "securepassword123",
  "password_confirm": "securepassword123",
  "gender": "M",
  "date_of_birth": "1990-01-01",
  "blood_group": "O+",
  "address": "123 Main St",
  "city": "Douala",
  "region": "Littoral",
  "role": "donor"
}
```

#### Login
```
POST /users/login/
```

**Request Body:**
```json
{
  "email": "john@example.com",
  "password": "securepassword123"
}
```

**Response:**
```json
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

#### Get Current User
```
GET /users/me/
```

### Hospitals

#### List Hospitals
```
GET /hospitals/
```

#### Get Hospital Details
```
GET /hospitals/{id}/
```

#### Get My Hospital
```
GET /hospitals/my-hospital/
```

#### Hospital Statistics
```
GET /hospitals/statistics/
```

### Blood Inventory

#### List Inventory
```
GET /inventory/
```

#### Search Blood
```
GET /inventory/search/?blood_group=O+&region=Littoral
```

**Query Parameters:**
- `blood_group` (optional): Filter by blood group
- `region` (optional): Filter by region
- `hospital` (optional): Filter by hospital ID

#### Create Inventory Item
```
POST /inventory/
```

**Request Body:**
```json
{
  "hospital": 1,
  "blood_group": "O+",
  "quantity": 10,
  "collection_date": "2024-01-15",
  "expiration_date": "2024-07-15"
}
```

### Blood Requests

#### List My Requests
```
GET /requests/
```

#### Create Request
```
POST /requests/
```

**Request Body:**
```json
{
  "blood_group": "O+",
  "quantity": 2,
  "urgency": "HIGH",
  "hospital": 1,
  "reason": "Surgery needed"
}
```

#### Create Emergency Request
```
POST /requests/emergency/
```

**Request Body:**
```json
{
  "blood_group": "O-",
  "quantity": 4,
  "urgency": "CRITICAL",
  "reason": "Emergency surgery"
}
```

### Appointments

#### List Appointments
```
GET /appointments/
```

#### Book Appointment
```
POST /appointments/
```

**Request Body:**
```json
{
  "hospital": 1,
  "date": "2024-02-01",
  "time": "09:00",
  "notes": "First time donor"
}
```

#### Get Available Slots
```
GET /appointments/available-slots/?hospital=1&date=2024-02-01
```

### Donations

#### List Donation History
```
GET /donations/
```

#### Record Donation
```
POST /donations/
```

**Request Body:**
```json
{
  "hospital": 1,
  "blood_group": "O+",
  "units": 1,
  "notes": "Successful donation"
}
```

### Eligibility

#### Check Eligibility
```
POST /eligibility/check/
```

**Request Body:**
```json
{
  "age": 30,
  "weight": 70,
  "has_recent_surgery": false,
  "is_pregnant": false,
  "has_infectious_disease": false,
  "is_on_medication": false,
  "has_medical_condition": false
}
```

**Response:**
```json
{
  "status": "ELIGIBLE",
  "message": "You are eligible to donate blood"
}
```

### Notifications

#### List Notifications
```
GET /notifications/
```

#### Mark as Read
```
POST /notifications/{id}/mark-read/
```

#### Mark All as Read
```
POST /notifications/mark-all-read/
```

### Campaigns

#### List Campaigns
```
GET /campaigns/
```

#### Get Campaign Details
```
GET /campaigns/{id}/
```

#### Register for Campaign
```
POST /campaigns/{id}/register/
```

### Messages

#### List Conversations
```
GET /messages/conversations/
```

#### Get Messages
```
GET /messages/conversations/{id}/messages/
```

#### Send Message
```
POST /messages/conversations/{id}/messages/
```

**Request Body:**
```json
{
  "content": "Hello, I'm interested in donating"
}
```

### Payments

#### Initiate Payment
```
POST /payments/initiate/
```

**Request Body:**
```json
{
  "request_id": 1,
  "amount": 5000,
  "payment_method": "MTN",
  "phone_number": "+237123456789"
}
```

### Rewards

#### Get My Rewards
```
GET /rewards/my-rewards/
```

#### Get Leaderboard
```
GET /rewards/leaderboard/
```

### Admin

#### List Users
```
GET /admin/users/
```

#### Suspend User
```
POST /admin/users/{id}/suspend/
```

#### Activate User
```
POST /admin/users/{id}/activate/
```

#### System Statistics
```
GET /admin/statistics/
```

### Reports

#### Monthly Donations
```
GET /reports/monthly-donations/
```

#### Blood Stock by Group
```
GET /reports/blood-stock/
```

#### Statistics
```
GET /reports/statistics/
```

## Error Responses

All errors follow this format:
```json
{
  "detail": "Error message here"
}
```

## Status Codes

- `200 OK` - Request successful
- `201 Created` - Resource created
- `400 Bad Request` - Invalid request data
- `401 Unauthorized` - Authentication required
- `403 Forbidden` - Permission denied
- `404 Not Found` - Resource not found
- `500 Internal Server Error` - Server error
