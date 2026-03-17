# Web Vulnerabilities Reference

## Table of Contents
1. Injection (SQL, NoSQL, Command, LDAP)
2. Cross-Site Scripting (XSS)
3. Cross-Site Request Forgery (CSRF)
4. Insecure Direct Object Reference (IDOR)
5. Security Misconfiguration
6. Sensitive Data Exposure
7. Broken Access Control
8. Security Headers

---

## 1. Injection

### SQL Injection
**Risk:** Attacker reads/modifies/deletes entire database, bypasses authentication.

```javascript
// ❌ Vulnerable — string concatenation
const query = `SELECT * FROM users WHERE email = '${email}'`;

// ✅ Safe — parameterized query
const query = 'SELECT * FROM users WHERE email = $1';
db.query(query, [email]);
```

**Check for:**
- String concatenation in any database query
- ORM raw query methods with unsanitized input
- Dynamic `ORDER BY` / `LIMIT` clauses from user input

### NoSQL Injection (MongoDB)
**Risk:** Attacker bypasses auth or extracts all documents.

```javascript
// ❌ Vulnerable — user controls query operators
User.findOne({ email: req.body.email, password: req.body.password });
// Attacker sends: { "password": { "$gt": "" } } → matches all users

// ✅ Safe — sanitize operator injection
import { sanitize } from 'mongo-sanitize';
User.findOne({ email: sanitize(req.body.email), password: sanitize(req.body.password) });
```

### Command Injection
**Risk:** Attacker executes arbitrary OS commands on the server.

```javascript
// ❌ Vulnerable
exec(`convert ${userFilename} output.pdf`);

// ✅ Safe — use array form, never shell interpolation
execFile('convert', [userFilename, 'output.pdf']);
```

---

## 2. Cross-Site Scripting (XSS)

### Reflected XSS
**Risk:** Attacker injects script via URL parameter, executed in victim's browser.

```typescript
// ❌ Vulnerable — Angular bypasses DomSanitizer
this.element.innerHTML = this.route.snapshot.queryParams['message'];

// ✅ Safe — use Angular interpolation (auto-escaped)
// In template: {{ message }}   ← Angular escapes this automatically

// If you MUST insert HTML, sanitize first
import { DomSanitizer } from '@angular/platform-browser';
this.safeHtml = this.sanitizer.bypassSecurityTrustHtml(
  DOMPurify.sanitize(userContent)  // DOMPurify first, then trust
);
```

### Stored XSS
**Risk:** Malicious script stored in database, executed for every user who views it.

**Check for:**
- User-supplied content rendered as HTML (`innerHTML`, `[innerHTML]`)
- Rich text editors that don't sanitize output
- Markdown renderers without XSS protection
- API responses inserted directly into DOM

### DOM-based XSS
**Check for:**
- `document.write()`, `eval()`, `setTimeout(string)` with user data
- `location.hash` or `location.search` inserted into DOM
- `postMessage` handlers that don't validate origin

---

## 3. Cross-Site Request Forgery (CSRF)

**Risk:** Attacker tricks authenticated user into making unintended requests.

**When it applies:** Cookie-based sessions (not JWT in Authorization header).

```typescript
// ✅ Angular HttpClient auto-reads XSRF-TOKEN cookie
// Backend must set: Set-Cookie: XSRF-TOKEN=<token>; Path=/; SameSite=Strict

// Verify backend reads X-XSRF-TOKEN header on state-changing requests
```

**Check for:**
- State-changing endpoints (POST/PUT/DELETE) without CSRF token validation
- `SameSite=None` cookies without `Secure` flag
- Missing CSRF middleware on form submissions

**Mitigations (pick one):**
- CSRF tokens (synchronizer token pattern)
- `SameSite=Strict` or `SameSite=Lax` cookie attribute
- `Origin` / `Referer` header validation
- Double-submit cookie pattern

---

## 4. Insecure Direct Object Reference (IDOR)

**Risk:** Attacker accesses or modifies another user's data by changing an ID.

```typescript
// ❌ Vulnerable — trusts user-supplied ID
app.get('/api/documents/:id', async (req, res) => {
  const doc = await Document.findById(req.params.id);
  res.json(doc);  // returns document regardless of ownership
});

// ✅ Safe — verify ownership before returning
app.get('/api/documents/:id', authenticate, async (req, res) => {
  const doc = await Document.findOne({
    _id: req.params.id,
    ownerId: req.user.id,   // ← ownership check
  });
  if (!doc) return res.status(404).json({ error: 'Not found' });
  res.json(doc);
});
```

**Check for:**
- Any endpoint that fetches/updates/deletes by ID without ownership verification
- Bulk endpoints that don't filter by current user
- File download endpoints with predictable paths
- Sequential or guessable IDs (use UUIDs)

---

## 5. Security Misconfiguration

**High-risk misconfigurations to check:**

```
[ ] Debug mode / verbose errors enabled in production
[ ] Default credentials not changed (admin/admin, root/root)
[ ] Directory listing enabled on web server
[ ] Unnecessary HTTP methods enabled (TRACE, OPTIONS)
[ ] CORS allows * (wildcard) with credentials
[ ] Stack traces exposed in API error responses
[ ] Admin panels publicly accessible (no IP restriction)
[ ] Old / unused endpoints still active
```

**CORS misconfiguration:**
```javascript
// ❌ Dangerous — reflects any origin with credentials
app.use(cors({
  origin: req.headers.origin,   // reflects attacker's origin
  credentials: true,
}));

// ✅ Safe — explicit allowlist
app.use(cors({
  origin: ['https://app.example.com', 'https://admin.example.com'],
  credentials: true,
}));
```

---

## 6. Sensitive Data Exposure

**Check for:**
- Passwords stored in plaintext or weak hash (MD5, SHA1 — use bcrypt/argon2)
- PII in URL parameters (logged by proxies, browser history)
- Sensitive data in JWT payload without encryption
- API responses returning more fields than needed
- Logs containing passwords, tokens, or PII
- Secrets in error messages or stack traces

```typescript
// ❌ PII in URL — logged everywhere
GET /api/search?email=user@example.com

// ✅ PII in request body (POST) or hashed identifier
POST /api/search  { "emailHash": "sha256(email)" }
```

---

## 7. Broken Access Control

**Vertical privilege escalation** — regular user accesses admin functions:
```
[ ] Role checks on every privileged endpoint (not just frontend routes)
[ ] JWT claims validated server-side on every request
[ ] Admin-only routes protected at API layer, not just UI layer
```

**Horizontal privilege escalation** — user accesses another user's data (see IDOR above).

**Check for:**
- `isAdmin` flag stored in JWT that client can modify (use server-side role lookup)
- Feature flags checked only on frontend
- Mass assignment — API accepts `role` or `isAdmin` in update body

---

## 8. Security Headers

Required headers for every web application:

```
Content-Security-Policy: default-src 'self'; script-src 'self'; ...
X-Content-Type-Options: nosniff
X-Frame-Options: DENY
Strict-Transport-Security: max-age=31536000; includeSubDomains
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

Test with: [securityheaders.com](https://securityheaders.com)

**Content-Security-Policy pitfalls:**
- `unsafe-inline` for scripts defeats XSS protection — use nonces instead
- `unsafe-eval` allows `eval()` — avoid
- Too permissive `script-src` allows CDN-hosted malware
