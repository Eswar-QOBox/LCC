# Interview Q&A Practice — Flask + MongoDB + VPS (Startup, Fresher)

Use this like flashcards. For each question:
- Answer in **30–60 seconds**
- Then answer the **follow-ups** (this is what startups do)

---

## How to practice (10–20 mins/day)

- Pick **10 questions/day**
- Say the answer out loud
- If you get stuck, read the “What a good answer includes”, then retry
- Repeat the same set after 2 days until it becomes automatic

---

## 1) APIs + HTTP (must-know)

### Q1. What is REST? How do you design endpoints?
**Good answer includes**
- Resources (nouns): `/users`, `/applications`
- HTTP verbs: GET/POST/PATCH/DELETE
- Status codes, consistent errors, pagination

**Follow-ups**
- Difference between PUT vs PATCH?
- What makes an operation idempotent?

---

### Q2. What status codes do you commonly use?
**Good answer includes**
- 200 OK, 201 Created
- 400 Bad Request (invalid input)
- 401 Unauthorized (no/invalid token)
- 403 Forbidden (no permission)
- 404 Not Found
- 409 Conflict (duplicate email, etc.)
- 422 Unprocessable Entity (validation error; optional depending on style)
- 500 Internal Server Error

**Follow-ups**
- When would you return 409 vs 400?

---

### Q3. How do you implement pagination?
**Good answer includes**
- `page` + `limit` (or `cursor`)
- Default limit and max limit
- Stable sorting (e.g., `created_at desc`)

**Follow-ups**
- Why cursor pagination can be better than page/limit?

---

### Q4. How do you handle request validation in Flask?
**Good answer includes**
- Validate body, query params, and types
- Use Marshmallow or Pydantic
- Return consistent validation errors

**Follow-ups**
- Where do you put validation logic (routes vs service layer)?

---

### Q5. How do you structure a Flask project for maintainability?
**Good answer includes**
- Thin routes, business logic in services
- DB access in a db module
- Centralized error handling + logging

**Follow-ups**
- Blueprint usage? Why?

---

## 2) MongoDB (core for this stack)

### Q6. Why did you choose MongoDB?
**Good answer includes**
- Flexible schema, fast iteration, nested documents
- Still enforce validation at API boundary
- Use indexes based on query patterns
- Mention when you’d pick Postgres instead (joins/reporting/transactions-heavy)

**Follow-ups**
- What are MongoDB tradeoffs vs relational DB?

---

### Q7. How do you design a MongoDB schema?
**Good answer includes**
- Start from query patterns
- Decide embed vs reference
- Add indexes for frequent filters/sorts

**Follow-ups**
- When would you embed documents vs reference them?

---

### Q8. What indexes would you add for users and applications?
**Good answer includes**
- `users.email` unique index
- `applications.user_id + created_at` for listing
- `applications.status` for filtering

**Follow-ups**
- What happens if you don’t index a frequently queried field?

---

### Q9. How do you handle “migrations” in MongoDB?
**Good answer includes**
- Backwards-compatible changes first
- Background backfill script for old docs
- Version fields if needed

**Follow-ups**
- How do you migrate without downtime?

---

### Q10. How do you avoid duplicate user registration (same email)?
**Good answer includes**
- Unique index on email
- Handle duplicate key error → return 409

**Follow-ups**
- Why app-side checks alone are not enough?

---

## 3) Auth + security (startup favorites)

### Q11. How do you store passwords securely?
**Good answer includes**
- Hash with bcrypt/argon2 + salt (library handles salt)
- Never store plain password
- Don’t log passwords

**Follow-ups**
- Why not SHA256?

---

### Q12. What is JWT and how do you use it?
**Good answer includes**
- Signed token with claims (user id, roles)
- Short-lived access token (expiry)
- Verify signature on each request

**Follow-ups**
- Where do you store JWT on frontend? (web vs mobile)
- What is refresh token and why?

---

### Q13. JWT vs sessions — which and why?
**Good answer includes**
- JWT: stateless, good for APIs, easy horizontal scaling
- Sessions: server-side control, easier invalidation

**Follow-ups**
- How do you invalidate JWT before expiry?

---

### Q14. What are common API security risks and your mitigation?
**Good answer includes**
- Input validation
- AuthZ checks (401 vs 403)
- Rate limiting concept
- Avoid logging secrets
- Use HTTPS

**Follow-ups**
- What is CORS and when does it matter?

---

## 4) VPS deployment (your big differentiator)

### Q15. How do you deploy Flask on a VPS?
**Good answer includes**
- Gunicorn to run Flask app
- Nginx reverse proxy (80/443) → Gunicorn (127.0.0.1:8000)
- systemd to keep it running and restart on crash
- Config via env vars

**Follow-ups**
- Why not use `flask run` in production?

---

### Q16. How do you secure MongoDB on a VPS?
**Good answer includes**
- Bind MongoDB to `127.0.0.1`
- Enable auth
- Create least-privilege DB user
- Firewall only 22/80/443
- Backups

**Follow-ups**
- What’s the risk of exposing MongoDB publicly?

---

### Q17. How do you debug a production issue on VPS?
**Good answer includes**
- Reproduce and check Nginx logs
- Check systemd logs: `journalctl -u <service>`
- Isolate: Nginx → app → DB
- Fix + add test + restart service

**Follow-ups**
- How do you know if it’s a DB slowdown vs app bug?

---

### Q18. How do you roll out an update safely?
**Good answer includes**
- Pull code, install deps, restart service
- Verify health endpoint
- Keep config unchanged, avoid downtime if possible

**Follow-ups**
- What’s your rollback plan?

---

## 5) Testing + quality

### Q19. What tests would you write first?
**Good answer includes**
- Register/login happy path
- Protected route requires JWT
- CRUD happy path
- Invalid payload validation error

**Follow-ups**
- Unit vs integration tests — what’s the difference?

---

### Q20. How do you test MongoDB-related code?
**Good answer includes**
- Use a test database
- Clean collections between tests
- Mock external services if any

**Follow-ups**
- Why is “mock everything” not enough?

---

## 6) Performance + scalability (basic, not deep system design)

### Q21. An endpoint is slow. What do you do?
**Good answer includes**
- Add logs/measure time
- Check Mongo query patterns + indexes
- Reduce payload, paginate
- Cache if needed

**Follow-ups**
- What is N+1 in APIs (even with Mongo, e.g., repeated lookups)?

---

### Q22. How would you handle background work (emails/PDF/OCR)?
**Good answer includes**
- Queue + worker (RQ/Celery)
- Store job status
- Retries and idempotency

**Follow-ups**
- What if the worker crashes mid-job?

---

## 7) Behavioral (what actually decides fresher selection)

### Q23. Tell me about a difficult bug you fixed.
**Good answer includes**
- STAR format (Situation/Task/Action/Result)
- Clear debugging steps + what you learned

**Follow-ups**
- How did you prevent it from happening again?

---

### Q24. How do you handle unclear requirements?
**Good answer includes**
- Ask clarifying questions
- Propose a minimal version first
- Confirm edge cases

**Follow-ups**
- Give an example of tradeoff you made.

---

### Q25. What will you do in your first 2 weeks at our startup?
**Good answer includes**
- Understand product + codebase
- Pick 1 small feature/bug and ship
- Add tests/logs, improve docs

**Follow-ups**
- How do you communicate progress?

---

## 8) Mini “mock interview” (practice this sequence)

1) Explain your project in **2 minutes**
2) Answer **Q11 (password hashing)** + follow-up
3) Answer **Q15 (deploy)** + follow-up
4) Answer **Q21 (slow endpoint)** + follow-up
5) One behavioral story (**Q23**)

---

## Your 2-minute script (copy/paste and memorize)

“I built a Flask REST API with MongoDB. It supports register/login with hashed passwords and JWT auth for protected endpoints. I designed users and applications collections and added indexes for common queries like listing a user’s applications and filtering by status. The service runs on a VPS using Gunicorn behind Nginx and is managed by systemd, with secrets stored in environment variables. MongoDB is secured by binding to localhost, enabling auth, and restricting the firewall. I wrote pytest tests for auth and the core CRUD flow, and I can debug issues using Nginx logs and systemd journal logs.”

