# LifeLink Database Schema

## Overview

This document describes the SQLite database schema for the LifeLink application.

## Entity Relationship Diagram

```
User (1) ----< (N) Donor
User (1) ----< (N) Patient
User (1) ----< (N) HospitalStaff
User (1) ----< (N) BloodBankAdmin
User (1) ----< (N) SystemAdmin

Hospital (1) ----< (N) HospitalStaff
Hospital (1) ----< (N) BloodInventory
Hospital (1) ----< (N) Appointment
Hospital (1) ----< (N) Donation
Hospital (1) ----< (N) BloodRequest

Donor (1) ----< (N) Donation
Donor (1) ----< (N) Appointment
Donor (1) ----< (N) EligibilityCheck
Donor (1) ----< (N) DonorReward

Patient (1) ----< (N) BloodRequest

BloodInventory (1) ----< (N) BloodRequest

BloodRequest (1) ----< (N) Payment

Appointment (1) ----< (N) Donation

Donation (1) ----< (N) BloodInventory

Campaign (1) ----< (N) CampaignParticipant

User (1) ----< (N) Conversation (as participant1)
User (1) ----< (N) Conversation (as participant2)
Conversation (1) ----< (N) Message

User (1) ----< (N) Notification
```

## Tables

### Users Table

```sql
CREATE TABLE users_user (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    password VARCHAR(128) NOT NULL,
    last_login DATETIME NULL,
    is_superuser BOOLEAN NOT NULL DEFAULT 0,
    username VARCHAR(150) NOT NULL UNIQUE,
    first_name VARCHAR(150) NOT NULL DEFAULT '',
    last_name VARCHAR(150) NOT NULL DEFAULT '',
    email VARCHAR(254) NOT NULL,
    is_staff BOOLEAN NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT 1,
    date_joined DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    full_name VARCHAR(300) NOT NULL,
    gender VARCHAR(1) NULL,
    date_of_birth DATE NULL,
    blood_group VARCHAR(3) NULL,
    phone_number VARCHAR(20) NOT NULL,
    address TEXT NULL,
    city VARCHAR(100) NULL,
    region VARCHAR(100) NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'donor',
    notification_preferences BOOLEAN NOT NULL DEFAULT 1,
    email_notifications BOOLEAN NOT NULL DEFAULT 1,
    language VARCHAR(2) NOT NULL DEFAULT 'en',
    profile_picture VARCHAR(255) NULL,
    is_verified BOOLEAN NOT NULL DEFAULT 0,
    verification_token VARCHAR(100) NULL,
    reset_password_token VARCHAR(100) NULL,
    reset_password_expires DATETIME NULL
);
```

**Indexes:**
- `idx_users_email` on `email`
- `idx_users_role` on `role`
- `idx_users_blood_group` on `blood_group`

### Hospitals Table

```sql
CREATE TABLE hospitals_hospital (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    region VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    email VARCHAR(254) NULL,
    description TEXT NULL,
    latitude FLOAT NULL,
    longitude FLOAT NULL,
    is_active BOOLEAN NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**Indexes:**
- `idx_hospitals_region` on `region`
- `idx_hospitals_city` on `city`

### Hospital Staff Table

```sql
CREATE TABLE hospitals_hospitalstaff (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users_user(id),
    hospital_id INTEGER NOT NULL REFERENCES hospitals_hospital(id),
    position VARCHAR(100) NULL,
    department VARCHAR(100) NULL,
    is_active BOOLEAN NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### Blood Banks Table

```sql
CREATE TABLE blood_banks_bloodbank (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(200) NOT NULL,
    address TEXT NOT NULL,
    city VARCHAR(100) NOT NULL,
    region VARCHAR(100) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    email VARCHAR(254) NULL,
    manager_name VARCHAR(200) NULL,
    capacity INTEGER NOT NULL DEFAULT 1000,
    current_stock INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### Blood Inventory Table

```sql
CREATE TABLE inventory_bloodinventory (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    hospital_id INTEGER NOT NULL REFERENCES hospitals_hospital(id),
    blood_group VARCHAR(3) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 0,
    collection_date DATE NOT NULL,
    expiration_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'available',
    donor_id INTEGER NULL REFERENCES donors_donor(id),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**Indexes:**
- `idx_inventory_hospital` on `hospital_id`
- `idx_inventory_blood_group` on `blood_group`
- `idx_inventory_status` on `status`
- `idx_inventory_expiration` on `expiration_date`

### Donors Table

```sql
CREATE TABLE donors_donor (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users_user(id),
    total_donations INTEGER NOT NULL DEFAULT 0,
    total_units INTEGER NOT NULL DEFAULT 0,
    is_eligible BOOLEAN NOT NULL DEFAULT 1,
    eligibility_status VARCHAR(30) NULL,
    last_donation_date DATE NULL,
    next_eligible_date DATE NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### Patients Table

```sql
CREATE TABLE patients_patient (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL UNIQUE REFERENCES users_user(id),
    emergency_contact_name VARCHAR(200) NULL,
    emergency_contact_phone VARCHAR(20) NULL,
    medical_history TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### Blood Requests Table

```sql
CREATE TABLE requests_bloodrequest (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    patient_id INTEGER NOT NULL REFERENCES patients_patient(id),
    hospital_id INTEGER NULL REFERENCES hospitals_hospital(id),
    blood_group VARCHAR(3) NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1,
    urgency VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    is_emergency BOOLEAN NOT NULL DEFAULT 0,
    reason TEXT NULL,
    approved_by_id INTEGER NULL REFERENCES users_user(id),
    approved_at DATETIME NULL,
    fulfilled_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**Indexes:**
- `idx_requests_patient` on `patient_id`
- `idx_requests_status` on `status`
- `idx_requests_urgency` on `urgency`
- `idx_requests_emergency` on `is_emergency`

### Appointments Table

```sql
CREATE TABLE appointments_appointment (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    donor_id INTEGER NOT NULL REFERENCES donors_donor(id),
    hospital_id INTEGER NOT NULL REFERENCES hospitals_hospital(id),
    date DATE NOT NULL,
    time VARCHAR(5) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    notes TEXT NULL,
    confirmed_at DATETIME NULL,
    cancelled_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**Indexes:**
- `idx_appointments_donor` on `donor_id`
- `idx_appointments_hospital` on `hospital_id`
- `idx_appointments_date` on `date`
- `idx_appointments_status` on `status`

### Donations Table

```sql
CREATE TABLE donations_donation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    donor_id INTEGER NOT NULL REFERENCES donors_donor(id),
    hospital_id INTEGER NOT NULL REFERENCES hospitals_hospital(id),
    blood_group VARCHAR(3) NOT NULL,
    units INTEGER NOT NULL DEFAULT 1,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    date DATE NOT NULL,
    notes TEXT NULL,
    verified_by_id INTEGER NULL REFERENCES users_user(id),
    verified_at DATETIME NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**Indexes:**
- `idx_donations_donor` on `donor_id`
- `idx_donations_hospital` on `hospital_id`
- `idx_donations_date` on `date`
- `idx_donations_status` on `status`

### Eligibility Checks Table

```sql
CREATE TABLE eligibility_eligibilitycheck (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    donor_id INTEGER NOT NULL REFERENCES donors_donor(id),
    age INTEGER NOT NULL,
    weight FLOAT NOT NULL,
    has_recent_surgery BOOLEAN NOT NULL DEFAULT 0,
    is_pregnant BOOLEAN NOT NULL DEFAULT 0,
    has_infectious_disease BOOLEAN NOT NULL DEFAULT 0,
    is_on_medication BOOLEAN NOT NULL DEFAULT 0,
    has_medical_condition BOOLEAN NOT NULL DEFAULT 0,
    status VARCHAR(30) NOT NULL,
    notes TEXT NULL,
    checked_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### Messages Table

```sql
CREATE TABLE messages_app_conversation (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    participant1_id INTEGER NOT NULL REFERENCES users_user(id),
    participant2_id INTEGER NOT NULL REFERENCES users_user(id),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

```sql
CREATE TABLE messages_app_message (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    conversation_id INTEGER NOT NULL REFERENCES messages_app_conversation(id),
    sender_id INTEGER NOT NULL REFERENCES users_user(id),
    content TEXT NOT NULL,
    attachment_url VARCHAR(255) NULL,
    is_read BOOLEAN NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**Indexes:**
- `idx_messages_conversation` on `conversation_id`
- `idx_messages_sender` on `sender_id`
- `idx_messages_created` on `created_at`

### Notifications Table

```sql
CREATE TABLE notifications_notification (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL REFERENCES users_user(id),
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(50) NOT NULL DEFAULT 'info',
    is_read BOOLEAN NOT NULL DEFAULT 0,
    data JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**Indexes:**
- `idx_notifications_user` on `user_id`
- `idx_notifications_is_read` on `is_read`
- `idx_notifications_created` on `created_at`

### Campaigns Table

```sql
CREATE TABLE campaigns_campaign (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    type VARCHAR(50) NOT NULL,
    image_url VARCHAR(255) NULL,
    location VARCHAR(200) NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    participants_count INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT 1,
    created_by_id INTEGER NOT NULL REFERENCES users_user(id),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### Campaign Participants Table

```sql
CREATE TABLE campaigns_campaignparticipant (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    campaign_id INTEGER NOT NULL REFERENCES campaigns_campaign(id),
    user_id INTEGER NOT NULL REFERENCES users_user(id),
    registered_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    attended BOOLEAN NOT NULL DEFAULT 0,
    UNIQUE(campaign_id, user_id)
);
```

### Rewards Table

```sql
CREATE TABLE rewards_badge (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR(100) NOT NULL,
    description TEXT NULL,
    type VARCHAR(50) NOT NULL,
    icon VARCHAR(50) NOT NULL,
    criteria JSON NOT NULL,
    points_required INTEGER NOT NULL DEFAULT 0
);
```

```sql
CREATE TABLE rewards_donorreward (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    donor_id INTEGER NOT NULL REFERENCES donors_donor(id),
    total_points INTEGER NOT NULL DEFAULT 0,
    current_level VARCHAR(50) NOT NULL DEFAULT 'Bronze',
    level_progress FLOAT NOT NULL DEFAULT 0.0,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

```sql
CREATE TABLE rewards_donorreward_badges (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    donorreward_id INTEGER NOT NULL REFERENCES rewards_donorreward(id),
    badge_id INTEGER NOT NULL REFERENCES rewards_badge(id),
    earned_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(donorreward_id, badge_id)
);
```

### Payments Table

```sql
CREATE TABLE payments_payment (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    request_id INTEGER NOT NULL REFERENCES requests_bloodrequest(id),
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(20) NOT NULL,
    phone_number VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    transaction_id VARCHAR(100) NULL,
    provider VARCHAR(50) NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

### Audit Logs Table

```sql
CREATE TABLE audit_auditlog (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NULL REFERENCES users_user(id),
    action VARCHAR(100) NOT NULL,
    model_name VARCHAR(100) NOT NULL,
    object_id INTEGER NULL,
    changes JSON NULL,
    ip_address VARCHAR(45) NULL,
    user_agent TEXT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);
```

**Indexes:**
- `idx_audit_user` on `user_id`
- `idx_audit_action` on `action`
- `idx_audit_created` on `created_at`

## Data Constraints

### Blood Groups
Valid values: A+, A-, B+, B-, AB+, AB-, O+, O-

### Urgency Levels
Valid values: LOW, MEDIUM, HIGH, CRITICAL

### User Roles
Valid values: donor, patient, hospital_staff, lab_technician, blood_bank_admin, system_admin

### Appointment Status
Valid values: PENDING, CONFIRMED, COMPLETED, CANCELLED

### Donation Status
Valid values: PENDING, COMPLETED, CANCELLED

### Request Status
Valid values: PENDING, APPROVED, REJECTED, FULFILLED

### Eligibility Status
Valid values: ELIGIBLE, TEMPORARY_INELIGIBLE, PERMANENT_INELIGIBLE

### Payment Status
Valid values: PENDING, SUCCESS, FAILED, CANCELLED

### Payment Methods
Valid values: MTN, ORANGE

## Migrations

To create migrations:
```bash
python manage.py makemigrations
python manage.py migrate
```

To reset database:
```bash
python manage.py flush
```
