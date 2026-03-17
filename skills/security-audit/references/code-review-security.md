# Security Code Review Reference

## Table of Contents
1. High-Risk Patterns to Flag Immediately
2. Authentication & Session Review
3. Cryptography Review
4. Dependency Review
5. Secrets & Configuration Review
6. Logging & Monitoring Review
7. Review Comment Format

---

## 1. High-Risk Patterns — Flag Immediately

These patterns are almost always vulnerabilities. Stop and investigate before proceeding.

```
eval(userInput)                    → Code injection — Critical
exec(`... ${userInput}`)           → Command injection — Critical
innerHTML = userInput              → XSS — High
document.write(userInput)          → XSS — High
dangerouslySetInnerHTML            → XSS — High (React)
[innerHTML]="userInput"            → XSS — High (Angular, without sanitizer)
JSON.parse(userInput) without try  → DoS via malformed JSON
new RegExp(userInput)              → ReDoS — denial of service via regex
__dirname + '/' + userInput        → Path traversal
fs.readFile(userPath)              → Path traversal
res.redirect(req.query.url)        → Open redirect
serialize(userInput)               → Prototype pollution / RCE (node-serialize)
```

---

## 2. Authentication & Session Review

**Checklist when reviewing auth code:**

```
[ ] Passwords hashed with bcrypt/argon2/scrypt — never MD5/SHA1/SHA256 alone
[ ] Password comparison uses timing-safe function (bcrypt.compare, not ===)
[ ] JWT secret is random and from environment variable — not hardcoded
[ ] JWT algorithm explicitly set — no alg: none accepted
[ ] Session IDs are cryptographically random (not sequential)
[ ] Sessions invalidated on logout (server-side revocation or short TTL)
[ ] Password reset tokens expire (max 1 hour) and are single-use
[ ] MFA bypass paths don't exist ("remember this device" without limit)
[ ] Account lockout after N failed attempts (with unlock mechanism)
```

```typescript
// ❌ Timing attack on password comparison
if (user.password === req.body.password) { ... }

// ✅ Timing-safe comparison
const valid = await bcrypt.compare(req.body.password, user.passwordHash);
```

---

## 3. Cryptography Review

**Common crypto mistakes:**

```typescript
// ❌ Weak — MD5 is broken for security purposes
const hash = crypto.createHash('md5').update(data).digest('hex');

// ❌ Predictable IV — same plaintext = same ciphertext
const iv = Buffer.alloc(16, 0);
const cipher = crypto.createCipheriv('aes-256-cbc', key, iv);

// ✅ Random IV every time
const iv = crypto.randomBytes(16);
const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
// Store IV alongside ciphertext — it's not secret, just needs to be unique

// ❌ Hardcoded key — in source code = compromised forever
const key = Buffer.from('mysecretkey12345');

// ✅ Key from secure environment
const key = Buffer.from(process.env.ENCRYPTION_KEY, 'hex');
```

**Crypto checklist:**
```
[ ] AES-256-GCM for symmetric encryption (not CBC — no authentication)
[ ] RSA-OAEP or ECDH for asymmetric (not RSA-PKCS1v1.5)
[ ] Random IV/nonce per encryption operation
[ ] Keys from environment / secret manager — never hardcoded
[ ] bcrypt cost factor >= 12 (or argon2id with suitable params)
[ ] No MD5 or SHA1 for security-sensitive operations
[ ] TLS 1.2+ enforced, TLS 1.0/1.1 disabled
```

---

## 4. Dependency Review

**Quick audit commands:**

```bash
# Node.js
npm audit                          # known vulnerabilities
npm audit --audit-level=high       # fail on High+
npx snyk test                      # deeper analysis

# Check for outdated packages
npm outdated

# Find packages with excessive permissions
npx lockfile-lint --path package-lock.json
```

**What to flag:**
```
[ ] Direct dependencies with known Critical/High CVEs
[ ] Packages abandoned (last publish > 2 years, no maintainer)
[ ] Packages with excessive dependencies (bloated, larger attack surface)
[ ] Packages with install scripts (postinstall can execute arbitrary code)
[ ] Unpinned versions (^ or ~ allow unexpected updates)
```

**Typosquatting check:**
Before adding a new package, verify:
- Publisher is the expected organization
- Download count is reasonable (new package with 0 downloads = suspicious)
- README matches the package purpose
- GitHub stars/activity matches claimed usage

---

## 5. Secrets & Configuration Review

**Patterns that indicate hardcoded secrets:**

```bash
# Scan for potential secrets in code
grep -rn "password\s*=\s*['\"]" src/
grep -rn "api_key\s*=\s*['\"]" src/
grep -rn "secret\s*=\s*['\"]" src/
grep -rn "BEGIN.*PRIVATE KEY" src/
grep -rn "AKIA[0-9A-Z]{16}" src/    # AWS access key pattern
```

**Checklist:**
```
[ ] No secrets in source code (use environment variables)
[ ] No secrets in .env files committed to git
[ ] .gitignore includes .env, *.pem, *.key, *secret*
[ ] Secrets in CI/CD are masked in logs
[ ] Production secrets differ from development secrets
[ ] Secret rotation process exists and is documented
[ ] Old secrets revoked when rotated (don't just add new ones)
```

**Environment variable validation at startup:**
```typescript
// Fail fast if required secrets are missing
const requiredEnvVars = ['JWT_SECRET', 'DB_URL', 'ENCRYPTION_KEY'];
for (const key of requiredEnvVars) {
  if (!process.env[key]) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
}
```

---

## 6. Logging & Monitoring Review

**What should be logged:**
```
✅ Authentication events (login success/failure, logout)
✅ Authorization failures (403 responses)
✅ Admin actions (who did what, when)
✅ Data access for sensitive resources
✅ Input validation failures (potential attack probing)
✅ Rate limit hits
✅ System errors with request ID (not stack traces)
```

**What must NEVER be logged:**
```
❌ Passwords (even failed login attempts — log email only)
❌ Full JWT tokens or API keys
❌ Payment card numbers
❌ Full PII (log user_id instead of email/phone)
❌ Request bodies on auth endpoints
❌ Stack traces in production logs visible to users
```

```typescript
// ❌ Logs password
logger.info(`Login attempt for ${email} with password ${password}`);

// ✅ Logs only what's needed
logger.info({ event: 'login_attempt', email, success: false, ip: req.ip });
```

---

## 7. Review Comment Format

```markdown
🔴 [CRITICAL] Short title
🟠 [HIGH] Short title
🟡 [MEDIUM] Short title
🔵 [LOW] Short title
⚪ [INFO] Short title

**Why this is a problem:**
One sentence on exploitability and impact.

**Evidence:**
```code snippet showing the issue```

**Fix:**
Specific remediation with code example.

**Reference:** CWE-XXX / OWASP Axx:2021
```
