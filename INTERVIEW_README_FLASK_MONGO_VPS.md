# Interview README — Flask + MongoDB on VPS (Fresher, Startup)

This is a **single document** to help you prepare and speak confidently in a startup backend interview using **Flask + MongoDB deployed on a VPS** (not DSA-heavy).

> Use this as your daily practice sheet: build the demo project, deploy once on a VPS, then rehearse the 2‑minute walkthrough + debugging talk-track.

---

## Quick navigation

- [What startups evaluate](#what-startups-usually-evaluate-so-you-prep-the-right-things)
- [Demo project scope](#the-demo-project-you-will-build-and-talk-about)
- [API endpoints](#api-endpoints-simple--interview-ready)
- [MongoDB schema + indexes](#mongodb-data-model-what-to-explain)
- [Auth + security](#auth--security-basics-what-you-must-know)
- [VPS deployment (Mongo + Gunicorn + systemd + Nginx)](#vps-deployment-ubuntu--the-exact-process-to-memorize)
- [Backups + updates](#backups-simple-but-impressive)
- [Debugging playbook](#debugging-talk-track-memorize)
- [7/14 day plans](#7-day-sprint-plan-fastest-interview-readiness)
- [2-minute script](#2-minute-project-walkthrough-script-practice-daily)

---

## What startups usually evaluate (so you prep the right things)

| Area | What they check | What you should demonstrate |
|---|---|---|
| API fundamentals | status codes, validation, pagination, errors | consistent responses + clean route/service split |
| Auth + security | hashing, JWT, permissions, secrets | bcrypt/argon2, JWT expiry, env vars, no secret logging |
| MongoDB thinking | schema, indexes, query patterns | “design from queries”, indexes for filters/sorts |
| Shipping mindset | deploy + run reliably | Gunicorn + Nginx + systemd, logs, backups |
| Debugging | how you investigate | reproduce → logs → isolate layer → fix → add test |
| Communication | clarity + ownership | tradeoffs, edge cases, next improvements |

---

## The “demo project” you will build (and talk about)

Build one small backend you can explain end-to-end in 2 minutes.

### Project: Application Service API

Use a simple and believable domain (fintech/ecommerce/edtech). Example entities:
- Users
- Applications (or Orders)

### Features checklist (minimum viable but interview-strong)

- [ ] **Flask REST API** under `/api/v1`
- [ ] **Auth**: register + login, JWT protected routes
- [ ] **MongoDB**: `users` + `applications` collections
- [ ] **Validation**: Marshmallow (common with Flask) or Pydantic (also fine)
- [ ] **Indexes**: unique email + query indexes for list/filter endpoints
- [ ] **Testing**: pytest (auth + one protected flow + one invalid input test)
- [ ] **Logging**: request logs + error logs (no secrets)
- [ ] **Deployment**: VPS (Ubuntu) + Gunicorn + Nginx + systemd
- [ ] **Security**: Mongo auth enabled, Mongo bound to localhost, firewall configured

---

## Suggested project structure (what you’ll show in interview)

```
app/
  __init__.py              # create_app()
  config.py                # config from env vars
  extensions.py            # mongo client, jwt, etc.
  routes/
    auth.py
    users.py
    applications.py
  services/
    auth_service.py
    applications_service.py
  db/
    mongo.py               # connection helpers + indexes init
  schemas/
    auth_schemas.py
    application_schemas.py
  utils/
    errors.py              # consistent API errors
    logging.py             # request-id, formatters
tests/
  test_auth.py
  test_applications.py
wsgi.py                    # gunicorn entrypoint
requirements.txt
.env.example
Dockerfile                 # optional (good extra)
README.md                  # your main app readme (already exists)
INTERVIEW_README_FLASK_MONGO_VPS.md   # this file
```

---

## API endpoints (simple + interview-ready)

| Method | Path | Auth | Notes |
|---|---|---|---|
| GET | `/api/v1/health` | Public | quick “is service alive?” |
| POST | `/api/v1/auth/register` | Public | create user |
| POST | `/api/v1/auth/login` | Public | returns JWT |
| GET | `/api/v1/users/me` | JWT | current user |
| POST | `/api/v1/applications` | JWT | create |
| GET | `/api/v1/applications?status=&page=&limit=` | JWT | list + filter + paginate |
| GET | `/api/v1/applications/<id>` | JWT | fetch one |
| PATCH | `/api/v1/applications/<id>` | JWT | partial update |
| DELETE | `/api/v1/applications/<id>` | JWT | delete |

**Response rules**
- Use correct codes: **200/201**, **400**, **401**, **403**, **404**, **409**, **422**, **500**
- Keep a consistent error shape, e.g. `{ "error": { "code": "...", "message": "...", "details": {...} } }`

---

## MongoDB data model (what to explain)

Mongo is flexible, but you still design **documents + indexes + validation**.

### Collection: `users`

| Field | Type | Notes |
|---|---|---|
| `_id` | ObjectId | primary key |
| `name` | string |  |
| `email` | string | **unique index** |
| `password_hash` | string | bcrypt/argon2 |
| `roles` | array | e.g. `["user"]` |
| `created_at` | datetime |  |

**Indexes**
- `email` (unique)

### Collection: `applications`

| Field | Type | Notes |
|---|---|---|
| `_id` | ObjectId | primary key |
| `user_id` | ObjectId | reference to `users` |
| `status` | string | `draft/pending/approved/rejected` |
| `amount` | number |  |
| `metadata` | object | flexible fields |
| `created_at` | datetime |  |
| `updated_at` | datetime |  |

**Indexes (based on query patterns)**
- `user_id` + `created_at` (list “my applications” newest first)
- `status` (filter by status)

What you’ll say in interview:
- “MongoDB helps when fields evolve quickly (e.g. `metadata`).”
- “I still enforce input validation at the API boundary and add indexes for key queries.”
- “For relational reporting-heavy needs, I’d consider Postgres.”

---

## Auth + security basics (what you must know)

### Passwords
- Never store plain passwords.
- Use **bcrypt** or **argon2**.

### JWT
- Access token has **expiry**.
- Store secret in env var: `JWT_SECRET`.
- Protect routes with JWT, check user role for admin endpoints.

### Common security “green flags” (say these)
- “I don’t log tokens or passwords.”
- “Secrets live in environment variables, not in git.”
- “MongoDB is not exposed publicly; it’s bound to localhost + firewall.”

---

## VPS deployment (Ubuntu) — the exact process to memorize

Below assumes **Ubuntu 22.04+** and that **MongoDB + Flask app are on the same VPS** (simple and common for interviews).

### Request flow (what happens in production)

```text
Internet
  |
  | 80/443 (public)
  v
Nginx (reverse proxy, TLS)
  |
  | 127.0.0.1:8000 (private)
  v
Gunicorn (runs Flask)
  |
  | 127.0.0.1:27017 (private)
  v
MongoDB (auth enabled, bound to localhost)
```

### 0) Server basics

Update packages:

```bash
sudo apt update && sudo apt upgrade -y
```

Install essentials:

```bash
sudo apt install -y git curl ufw python3 python3-venv python3-pip nginx
```

Enable firewall:

```bash
sudo ufw allow OpenSSH
sudo ufw allow "Nginx Full"
sudo ufw enable
sudo ufw status
```

### 1) Install and secure MongoDB

Install MongoDB (use official MongoDB docs for your Ubuntu version).

Security checklist (must do):
- **Bind to localhost** only
- **Enable authorization**
- Create a **least-privilege DB user**

`/etc/mongod.conf` essentials (conceptually):
- `net.bindIp: 127.0.0.1`
- `security.authorization: enabled`

Restart MongoDB:

```bash
sudo systemctl enable mongod
sudo systemctl restart mongod
sudo systemctl status mongod
```

Create admin and app user (example steps; adjust DB/user names):

<details>
<summary><strong>MongoDB user setup (click to expand)</strong></summary>

1) Connect locally:

```bash
mongosh
```

2) Create admin (first time before enabling auth, or use localhost exception):

```javascript
use admin
db.createUser({ user: "admin", pwd: "STRONG_PASSWORD", roles: [ { role: "userAdminAnyDatabase", db: "admin" }, { role: "readWriteAnyDatabase", db: "admin" } ] })
```

3) Create app DB user:

```javascript
use lcc_app
db.createUser({ user: "lcc_user", pwd: "STRONG_PASSWORD", roles: [ { role: "readWrite", db: "lcc_app" } ] })
```

Key talking point:
- “MongoDB is only reachable from the VPS itself; the public only hits Nginx (80/443).”

</details>

### 2) Deploy the Flask app

Create a dedicated Linux user:

```bash
sudo adduser --disabled-password --gecos "" lccapp
```

App folder (example):

```bash
sudo mkdir -p /srv/lcc-backend
sudo chown -R lccapp:lccapp /srv/lcc-backend
```

Clone your repo / copy code into `/srv/lcc-backend`.

Create venv and install deps (as `lccapp` user):

```bash
sudo -u lccapp bash -lc "cd /srv/lcc-backend && python3 -m venv .venv && . .venv/bin/activate && pip install -r requirements.txt"
```

Create a production `.env` (never commit it):

**`.env` example keys**
- `FLASK_ENV=production`
- `APP_SECRET=...`
- `JWT_SECRET=...`
- `MONGO_URI=mongodb://lcc_user:STRONG_PASSWORD@127.0.0.1:27017/lcc_app?authSource=lcc_app`
- `LOG_LEVEL=INFO`

### 3) Run with Gunicorn (not flask dev server)

Example command:

```bash
/srv/lcc-backend/.venv/bin/gunicorn -w 2 -b 127.0.0.1:8000 wsgi:app
```

### 4) systemd service (so it restarts and logs properly)

Create:
- `/etc/systemd/system/lcc-backend.service`

Concept (what it should do):
- run as `lccapp`
- working directory `/srv/lcc-backend`
- load env from `/srv/lcc-backend/.env`
- start gunicorn bound to `127.0.0.1:8000`

Reload and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable lcc-backend
sudo systemctl start lcc-backend
sudo systemctl status lcc-backend
```

Logs (important for debugging):

```bash
sudo journalctl -u lcc-backend -f
```

### 5) Nginx reverse proxy (public traffic → app)

Nginx sits in front of your app and handles the “internet-facing” part:
- **Accepts public traffic** on ports **80/443**
- **Reverse proxies** requests to Gunicorn on `127.0.0.1:8000` (private)
- Can add **HTTPS**, **compression**, **rate limiting**, and better **timeouts**
- Lets you run multiple services on one VPS by routing via domain/path

#### Minimal reverse proxy config (template)

1) Create a site file (example):
- `/etc/nginx/sites-available/lcc-backend`

2) Paste a basic config like this (adjust `server_name`):

```nginx
server {
    listen 80;
    server_name your-domain.com;

    # Helpful request size limit for JSON/file upload endpoints
    client_max_body_size 10m;

    location / {
        proxy_pass http://127.0.0.1:8000;

        # Preserve client + protocol details for your app logs
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Sensible timeouts (tune if you have slow endpoints)
        proxy_connect_timeout 5s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}
```

3) Enable the site and reload Nginx:

```bash
sudo ln -s /etc/nginx/sites-available/lcc-backend /etc/nginx/sites-enabled/lcc-backend
sudo nginx -t
sudo systemctl reload nginx
```

#### “Interview talking points” for Nginx
- **Why Gunicorn is bound to 127.0.0.1**: so the app is not directly exposed; only Nginx is public.
- **Why Nginx is used**: stable public entry point, TLS termination, better handling of connections, easier routing.
- **What headers are for**: the app can know the real client IP and whether the request was HTTPS.

#### Debugging checklist (common issues)

Check Nginx config and logs:

```bash
sudo nginx -t
sudo systemctl status nginx
sudo tail -n 50 /var/log/nginx/error.log
sudo tail -n 50 /var/log/nginx/access.log
```

Common errors you should recognize:

| Error | Usually means | What to check first |
|---|---|---|
| **502 Bad Gateway** | app/gunicorn down or wrong upstream | `systemctl status lcc-backend`, `journalctl -u lcc-backend -f`, port in `proxy_pass` |
| **504 Gateway Timeout** | app too slow or timeouts too low | endpoint performance, `proxy_read_timeout`, DB indexes |
| **413 Request Entity Too Large** | request body too big | increase `client_max_body_size` |
 
Also confirm your app is listening locally:

```bash
curl -f http://127.0.0.1:8000/api/v1/health
```

### 6) HTTPS (bonus)

Use Let’s Encrypt / Certbot once DNS is set. In interviews you can say:
- “I’d terminate TLS at Nginx using Let’s Encrypt certificates.”

Extra talking points (good to mention):
- Redirect HTTP → HTTPS.
- Use HSTS after confirming HTTPS works.
- Keep TLS config in Nginx; keep app running plain HTTP behind it.

---

## Backups (simple but impressive)

Daily backup with `mongodump` (store outside the repo):

```bash
mkdir -p /srv/backups/mongo
mongodump --uri="mongodb://lcc_user:PASSWORD@127.0.0.1:27017/lcc_app?authSource=lcc_app" --out /srv/backups/mongo/$(date +%F)
```

Talking point:
- “I schedule backups and monitor disk usage; backups are useless if disk fills.”

---

## Safe update process (what you do on deploy day)

- Pull latest code
- Install new dependencies (if any)
- Restart service
- Verify health endpoint

Example (conceptual):

```bash
cd /srv/lcc-backend
git pull
. .venv/bin/activate
pip install -r requirements.txt
sudo systemctl restart lcc-backend
curl -f http://127.0.0.1:8000/api/v1/health
```

---

## Testing plan (minimum)

Write pytest tests for:
- register success
- login success + token returned
- protected endpoint requires token
- create application and fetch it
- invalid payload returns 400/422

Talking point:
- “I focus tests on the highest-risk flows: auth + protected routes + core CRUD.”

---

## Debugging talk-track (memorize)

When something breaks:
- Reproduce → check Nginx logs → check app logs (`journalctl`) → inspect Mongo query/index → fix → add test → redeploy

When endpoint is slow:
- Verify query pattern → add index → paginate → reduce payload → consider caching

---

## 7-day sprint plan (fastest interview readiness)

| Day | Outcome |
|---|---|
| 1 | Flask skeleton + `/health` + clean structure |
| 2 | Mongo connection + collections + **indexes** |
| 3 | Auth (hash + JWT) + protected `/users/me` |
| 4 | Applications CRUD + pagination + validation |
| 5 | pytest tests (auth + one CRUD flow + validation failure) |
| 6 | Deploy to VPS (Mongo secure + Gunicorn + Nginx + systemd) |
| 7 | Mock interview: 2-minute demo + debugging drills |

---

## 14-day plan (more polished, production signals)

### Week 1 (build it)
Same as the 7-day plan but slower and cleaner.

### Week 2 (production signals)
- Better logging (request-id), consistent error format
- Add one extra: **Redis cache** OR a **background worker**
- Add rate-limiting concept (even if you don’t implement)
- Improve README and add clear setup commands

---

## Common interview questions + answers (quick)

### Why MongoDB?
“Fast iteration and flexible documents; I still enforce validation and indexes. If reporting/joins dominate, I’d move to Postgres.”

### How do you secure Mongo on a VPS?
“Bind to localhost, enable auth, create least-privilege DB user, firewall only 22/80/443, backups.”

### How do you deploy Flask?
“Gunicorn behind Nginx, managed by systemd, configs in env vars, logs in journalctl/Nginx logs.”

### How do you handle schema changes in Mongo?
“Backwards-compatible changes + background backfill scripts; version changes carefully.”

### How do you debug a production issue?
“Reproduce, inspect logs, isolate the layer, fix, add regression test, deploy safely, verify health endpoint.”

---

## 2-minute project walkthrough script (practice daily)

> “I built a Flask REST API with MongoDB. It supports registration/login with hashed passwords and JWT authentication. I designed two main collections—users and applications—and added indexes for common queries like listing a user’s applications. The app runs on a VPS using Gunicorn behind Nginx, managed by systemd, with secrets in environment variables. MongoDB is secured by binding to localhost and enabling auth. I wrote pytest tests for auth and the core CRUD flow, and I can debug issues using Nginx logs and systemd journald logs.”

