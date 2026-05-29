# API Security Reference

## Table of Contents
1. Authentication
2. Authorization
3. Input Validation
4. Rate Limiting & Abuse Prevention
5. Data Exposure
6. JWT Security
7. API Keys

---

## 1. Authentication

### JWT Best Practices

```typescript
// ❌ Weak — short secret, no expiry
jwt.sign({ userId: 1 }, 'secret');

// ✅ Strong
jwt.sign(
  { sub: userId, role: user.role },
  process.env.JWT_SECRET,   // min 256-bit random secret
  {
    expiresIn: '15m',        // short-lived access tokens
    issuer: 'api.example.com',
    audience: 'app.example.com',
  }
);
```

**Check for:**
- `alg: none` accepted (allows unsigned tokens — critical vulnerability)
- Weak or hardcoded secrets
- No expiry (`expiresIn` missing)
- Sensitive data in payload (email, role in plain JWT — not encrypted)
- Token not invalidated on logout (use token blacklist or short TTL + refresh)
- Refresh tokens with no rotation (stolen refresh token = permanent access)

### Algorithm Confusion Attack

```typescript
// ❌ Vulnerable — accepts algorithm from token header
jwt.verify(token, secret);   // if secret is also used as public key

// ✅ Safe — explicitly specify expected algorithm
jwt.verify(token, secret, { algorithms: ['HS256'] });
```

---

## 2. Authorization

**Every endpoint must enforce authorization — never trust the frontend.**

```typescript
// ❌ Trusts frontend to not call admin endpoints
app.delete('/api/users/:id', async (req, res) => {
  await User.deleteById(req.params.id);
});

// ✅ Checks role server-side on every request
app.delete('/api/users/:id',
  authenticate,           // verifies JWT
  requireRole('admin'),   // checks role claim
  async (req, res) => {
    await User.deleteById(req.params.id);
  }
);
```

**Authorization checklist:**
```
[ ] Every endpoint has explicit auth middleware (no "default public")
[ ] Role/permission checked server-side, not from JWT claims alone
[ ] Resource ownership verified before read/write/delete (see IDOR)
[ ] Privilege escalation prevented — users cannot assign themselves higher roles
[ ] Service-to-service calls use separate credentials (not user tokens)
```

---

## 3. Input Validation

**Validate everything at the API boundary — never trust client input.**

```typescript
// ❌ No validation — attacker sends malformed data
app.post('/api/users', async (req, res) => {
  await User.create(req.body);
});

// ✅ Schema validation with Zod (or Joi / class-validator)
import { z } from 'zod';

const CreateUserSchema = z.object({
  email: z.string().email().max(255),
  name: z.string().min(1).max(100).regex(/^[a-zA-Z\s]+$/),
  role: z.enum(['user', 'editor']),   // never accept 'admin' from client
});

app.post('/api/users', async (req, res) => {
  const result = CreateUserSchema.safeParse(req.body);
  if (!result.success) return res.status(400).json(result.error);
  await User.create(result.data);
});
```

**What to validate:**
- Type (string, number, boolean)
- Length / range limits
- Format (email, URL, UUID)
- Allowed values (enum) for fields like `role`, `status`, `type`
- File uploads: type (MIME, not extension), size, content scanning

**Mass assignment protection:**
```typescript
// ❌ Vulnerable — client can set isAdmin: true
await User.update(req.params.id, req.body);

// ✅ Explicit allowlist of updatable fields
const { name, email, bio } = req.body;   // only these fields
await User.update(req.params.id, { name, email, bio });
```

---

## 4. Rate Limiting & Abuse Prevention

```typescript
import rateLimit from 'express-rate-limit';

// Auth endpoints — strict
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,   // 15 minutes
  max: 10,                      // 10 attempts per window
  message: { error: 'Too many attempts, try again later' },
  standardHeaders: true,
  legacyHeaders: false,
});
app.use('/api/auth/', authLimiter);

// General API — generous but bounded
const apiLimiter = rateLimit({
  windowMs: 60 * 1000,    // 1 minute
  max: 100,
});
app.use('/api/', apiLimiter);
```

**Rate limit checklist:**
```
[ ] Login / register endpoints rate-limited (prevent brute force)
[ ] Password reset endpoints rate-limited (prevent enumeration)
[ ] Rate limits applied per-IP AND per-user (bypass: rotate IPs)
[ ] Expensive operations (file upload, export) have lower limits
[ ] Rate limit headers returned (X-RateLimit-Remaining)
[ ] 429 response doesn't reveal internal rate limit implementation
```

**Account enumeration prevention:**
```typescript
// ❌ Leaks whether email exists
if (!user) return res.status(404).json({ error: 'User not found' });
if (!validPassword) return res.status(401).json({ error: 'Wrong password' });

// ✅ Same message regardless of which check failed
if (!user || !validPassword) {
  return res.status(401).json({ error: 'Invalid credentials' });
}
```

---

## 5. Data Exposure

**Return only what the client needs — nothing more.**

```typescript
// ❌ Returns entire DB document including internal fields
res.json(user);

// ✅ Explicit output shape
res.json({
  id: user.id,
  name: user.name,
  email: user.email,
  // NOT: passwordHash, internalFlags, otherUsersData
});
```

**Pagination safety:**
```typescript
// ❌ Allows unbounded queries
const limit = req.query.limit;           // attacker sends limit=999999

// ✅ Cap at safe maximum
const limit = Math.min(parseInt(req.query.limit) || 20, 100);
```

**Error response safety:**
```typescript
// ❌ Leaks stack trace and internal details
res.status(500).json({ error: err.stack });

// ✅ Generic message externally, full error logged internally
logger.error({ err, requestId: req.id });
res.status(500).json({ error: 'Internal server error', requestId: req.id });
```

---

## 6. JWT Security

**Token storage:**

| Storage | XSS Risk | CSRF Risk | Recommendation |
|---|---|---|---|
| `localStorage` | High (JS readable) | None | ❌ Avoid for sensitive apps |
| `sessionStorage` | High (JS readable) | None | ❌ Avoid |
| HTTP-only cookie | None (not JS readable) | High | ✅ Use with CSRF protection |
| Memory (JS variable) | Low (lost on refresh) | None | ✅ For access tokens |

**Best pattern:**
- Access token: in-memory (short TTL, 15 min)
- Refresh token: HTTP-only, Secure, SameSite=Strict cookie (longer TTL, rotated on use)

---

## 7. API Keys

```
[ ] API keys are minimum 32 random bytes (256-bit)
[ ] Keys stored hashed in DB (like passwords) — never plaintext
[ ] Keys have defined scopes (read-only, write, admin)
[ ] Keys can be revoked without affecting other keys
[ ] Last-used timestamp tracked (detect stale/compromised keys)
[ ] Keys never logged (scrub from request logs)
[ ] Keys rotated on suspected compromise
```

```typescript
// Generating a secure API key
import crypto from 'crypto';
const apiKey = `sk_${crypto.randomBytes(32).toString('hex')}`;

// Storing — hash it, return plaintext once to user
const hashedKey = await bcrypt.hash(apiKey, 12);
await ApiKey.create({ hashedKey, userId, scope });
return apiKey;   // shown to user ONCE — never again
```
