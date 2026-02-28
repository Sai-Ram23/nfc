# API Test Examples

All examples use `curl`. Replace `TOKEN` with your auth token from login or seed output.

---

## Authentication

### Login

```bash
curl -X POST http://localhost:8000/api/login/ \
  -H "Content-Type: application/json" \
  -d '{"username": "admin", "password": "admin123"}'
```

**Response (200):**
```json
{
  "status": "success",
  "token": "abc123def456...",
  "username": "admin"
}
```

**Response (401 — invalid credentials):**
```json
{
  "status": "error",
  "message": "Invalid credentials."
}
```

---

## NFC Scan

### Scan a Valid UID

```bash
curl -X POST http://localhost:8000/api/scan/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Token YOUR_TOKEN_HERE" \
  -d '{"uid": "04A23B1C5D6E80"}'
```

**Response (200):**
```json
{
  "status": "valid",
  "name": "Rahul Kumar",
  "college": "IIT Madras",
  "breakfast": false,
  "lunch": false,
  "dinner": false,
  "goodie_collected": false
}
```

### Scan an Invalid UID

```bash
curl -X POST http://localhost:8000/api/scan/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Token YOUR_TOKEN_HERE" \
  -d '{"uid": "INVALID000000"}'
```

**Response (404):**
```json
{
  "status": "invalid",
  "message": "No participant found with this NFC tag."
}
```

---

## Pre-Registration

### List Pre-Registered Teams
Fetch teams that have unassigned pre-registered member slots.

```bash
curl -X GET http://localhost:8000/api/prereg/teams/ \
  -H "Authorization: Token YOUR_TOKEN_HERE"
```

**Response (200):**
```json
[
  {
    "team_id": "team_alpha",
    "team_name": "Team Alpha",
    "unregistered_members": [
      {
        "id": 1,
        "name": "Jane Smith",
        "college": "Testing College"
      }
    ]
  }
]
```

### Register (Link) a Blank NFC Tag
Link a physical NFC tag UID to a pre-registered slot.

```bash
curl -X POST http://localhost:8000/api/prereg/register/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Token YOUR_TOKEN_HERE" \
  -d '{"uid": "NEWTAG12345", "prereg_member_id": 1}'
```

**Response (201):**
```json
{
  "status": "registered",
  "message": "Successfully linked NEWTAG12345 to Jane Smith.",
  "name": "Jane Smith",
  "team_id": "team_alpha"
}
```

---

## Food Distribution

### Give Breakfast (First Time — Success)

```bash
curl -X POST http://localhost:8000/api/give-breakfast/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Token YOUR_TOKEN_HERE" \
  -d '{"uid": "04A23B1C5D6E80"}'
```

**Response (200):**
```json
{
  "status": "success",
  "message": "Breakfast given to Rahul Kumar.",
  "name": "Rahul Kumar",
  "college": "IIT Madras"
}
```

### Give Breakfast (Second Time — Duplicate)

```bash
curl -X POST http://localhost:8000/api/give-breakfast/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Token YOUR_TOKEN_HERE" \
  -d '{"uid": "04A23B1C5D6E80"}'
```

**Response (200):**
```json
{
  "status": "already_collected",
  "message": "Breakfast already collected by Rahul Kumar.",
  "name": "Rahul Kumar",
  "college": "IIT Madras"
}
```

### Give Lunch

```bash
curl -X POST http://localhost:8000/api/give-lunch/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Token YOUR_TOKEN_HERE" \
  -d '{"uid": "04A23B1C5D6E80"}'
```

### Give Dinner

```bash
curl -X POST http://localhost:8000/api/give-dinner/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Token YOUR_TOKEN_HERE" \
  -d '{"uid": "04A23B1C5D6E80"}'
```

### Give Goodie

```bash
curl -X POST http://localhost:8000/api/give-goodie/ \
  -H "Content-Type: application/json" \
  -H "Authorization: Token YOUR_TOKEN_HERE" \
  -d '{"uid": "04A23B1C5D6E80"}'
```

---

## Dashboard Stats

```bash
curl http://localhost:8000/api/stats/ \
  -H "Authorization: Token YOUR_TOKEN_HERE"
```

**Response (200):**
```json
{
  "total_participants": 20,
  "breakfast_given": 5,
  "lunch_given": 3,
  "dinner_given": 0,
  "goodies_given": 2
}
```

---

## Testing with PowerShell (Windows)

```powershell
# Login
Invoke-RestMethod -Uri "http://localhost:8000/api/login/" -Method POST `
  -ContentType "application/json" `
  -Body '{"username": "admin", "password": "admin123"}'

# Scan (replace TOKEN)
Invoke-RestMethod -Uri "http://localhost:8000/api/scan/" -Method POST `
  -ContentType "application/json" `
  -Headers @{Authorization = "Token YOUR_TOKEN_HERE"} `
  -Body '{"uid": "04A23B1C5D6E80"}'

# Give Breakfast
Invoke-RestMethod -Uri "http://localhost:8000/api/give-breakfast/" -Method POST `
  -ContentType "application/json" `
  -Headers @{Authorization = "Token YOUR_TOKEN_HERE"} `
  -Body '{"uid": "04A23B1C5D6E80"}'
```
