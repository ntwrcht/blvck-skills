# Security Patterns for Angular

This file covers Angular application security — distinct from `auth-patterns.md` which covers
JWT and session management. Focus here: XSS, CSP, CSRF, sanitization, and secure coding.

## Table of Contents
1. Angular's Built-in XSS Protection
2. DomSanitizer — Safe Bypassing
3. CSRF Protection
4. Content Security Policy
5. Sensitive Data Handling
6. Route & API Security
7. Dependency Security
8. Security Checklist

---

## 1. Angular's Built-in XSS Protection

Angular automatically escapes all interpolated values and attribute bindings. This is on by default — never disable it.

```typescript
// ✅ Safe — Angular escapes this automatically
@Component({
  template: `<p>{{ userInput }}</p>`   // user's "<script>" becomes "&lt;script&gt;"
})
export class SafeComponent {
  userInput = '<script>alert("xss")</script>';
}
```

```html
<!-- ❌ DANGEROUS — bypasses Angular's sanitization -->
<div [innerHTML]="userContent"></div>

<!-- ✅ Use the safe pipe or sanitize before binding -->
<div [innerHTML]="userContent | safeHtml"></div>
```

```typescript
// Safe HTML pipe — sanitize before trusting
@Pipe({ name: 'safeHtml', standalone: true })
export class SafeHtmlPipe implements PipeTransform {
  private sanitizer = inject(DomSanitizer);

  transform(value: string): SafeHtml {
    return this.sanitizer.sanitize(SecurityContext.HTML, value) ?? '';
  }
}
```

**When innerHTML is genuinely required** (e.g., rendering markdown-to-HTML output from a trusted server):
```typescript
// Only bypass when: content comes from your own server, has been sanitized server-side,
// and you have no way to use Angular's templating instead
export class ArticleComponent {
  private sanitizer = inject(DomSanitizer);

  get safeContent(): SafeHtml {
    // bypassSecurityTrustHtml is explicit — future readers know this is intentional
    return this.sanitizer.bypassSecurityTrustHtml(this.article.htmlContent);
  }
}
```

Never use `bypassSecurityTrustHtml` with user-generated content.

---

## 2. DomSanitizer — Safe Bypassing

`DomSanitizer` has five bypass methods — each for a different context. Use only the most specific one.

| Method | Context | Example |
|---|---|---|
| `bypassSecurityTrustHtml` | `[innerHTML]` | Server-rendered article body |
| `bypassSecurityTrustStyle` | `[style]` | Dynamic CSS from a theme config |
| `bypassSecurityTrustScript` | `<script>` | Never use in Angular apps |
| `bypassSecurityTrustUrl` | `[src]`, `[href]` | Dynamic media URLs |
| `bypassSecurityTrustResourceUrl` | `[src]` on iframes/scripts | Embedded content URLs |

```typescript
// Safe URL pipe — for dynamic media sources
@Pipe({ name: 'safeUrl', standalone: true })
export class SafeUrlPipe implements PipeTransform {
  private sanitizer = inject(DomSanitizer);

  transform(url: string): SafeUrl {
    return this.sanitizer.bypassSecurityTrustUrl(url);
  }
}
```

```html
<!-- Use for blob: URLs or trusted external media -->
<video [src]="videoUrl | safeUrl"></video>
<img [src]="avatarUrl | safeUrl" />
```

---

## 3. CSRF Protection

Angular's `HttpClient` supports CSRF token handling out of the box.

```typescript
// app.config.ts
export const appConfig: ApplicationConfig = {
  providers: [
    provideHttpClient(
      withXsrfConfiguration({
        cookieName: 'XSRF-TOKEN',     // cookie the server sets
        headerName: 'X-XSRF-TOKEN',   // header Angular sends on state-changing requests
      })
    ),
  ],
};
```

Angular reads the XSRF-TOKEN cookie and sends its value as a request header on all POST, PUT, PATCH, DELETE requests. GET and HEAD are exempt (they should be idempotent).

**Server requirements:**
- Set `XSRF-TOKEN` cookie on each response (not HttpOnly — Angular must read it with JS)
- Validate `X-XSRF-TOKEN` header on all state-changing requests
- Reject requests where header is missing or doesn't match the cookie

**SameSite cookie attribute** — additional CSRF protection layer:
```
Set-Cookie: session=...; SameSite=Strict; Secure; HttpOnly
```

---

## 4. Content Security Policy

Add CSP headers in your server or reverse proxy — not in Angular directly.

**Recommended Angular CSP:**
```
Content-Security-Policy:
  default-src 'self';
  script-src 'self';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  font-src 'self' https://fonts.gstatic.com;
  connect-src 'self' https://api.yourbackend.com;
  frame-ancestors 'none';
  base-uri 'self';
  form-action 'self';
```

**Why `'unsafe-inline'` for styles:** Angular Material and many CSS-in-JS solutions inject styles inline. Removing it requires nonce-based CSP.

**Angular-specific CSP note:** Angular's template compiler generates inline styles for component encapsulation. In production builds, these are extracted to CSS files — no `'unsafe-inline'` needed if you're using the default build.

**Nginx example:**
```nginx
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; connect-src 'self' https://api.example.com;" always;
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geofencing=()" always;
```

---

## 5. Sensitive Data Handling

### Never store sensitive data in:
- `localStorage` / `sessionStorage` — accessible to any JS on the page, survives XSS
- URL query params — logged by servers, browsers, CDNs; appear in referrer headers
- `window` / global variables — accessible to any script
- Angular component state exposed via DevTools

### Prefer:
- `HttpOnly` cookies for session tokens — JS cannot read them, survives XSS
- Memory-only storage for access tokens (stored in service, lost on refresh)
- Short-lived tokens with silent refresh

```typescript
// ✅ Memory-only token storage — XSS can't steal what localStorage doesn't have
@Injectable({ providedIn: 'root' })
export class TokenService {
  private accessToken: string | null = null;   // in memory only

  set(token: string): void { this.accessToken = token; }
  get(): string | null { return this.accessToken; }
  clear(): void { this.accessToken = null; }
}
```

### Masking sensitive data in templates

```html
<!-- Never render raw sensitive values -->
<p>Card: **** **** **** {{ payment.last4 }}</p>
<p>SSN: ***-**-{{ user.ssnLast4 }}</p>

<!-- Use a mask pipe for configurable display -->
<p>{{ user.phone | phoneMask }}</p>
```

### Logging — never log sensitive fields

```typescript
// ❌ Logs full user object including PII
console.log('User logged in:', user);

// ✅ Log only what you need for debugging
console.log('User logged in:', { id: user.id, role: user.role });
```

---

## 6. Route & API Security

### Open redirect prevention

```typescript
// ❌ Dangerous — user controls returnUrl, could redirect to attacker's site
const returnUrl = this.route.snapshot.queryParams['returnUrl'];
this.router.navigateByUrl(returnUrl);

// ✅ Safe — validate returnUrl is a relative path only
const returnUrl = this.route.snapshot.queryParams['returnUrl'] ?? '/dashboard';
const safeUrl = returnUrl.startsWith('/') && !returnUrl.startsWith('//') ? returnUrl : '/dashboard';
this.router.navigateByUrl(safeUrl);
```

### Route state — never pass sensitive data

```typescript
// ❌ Visible in history.state, accessible to any script
this.router.navigate(['/confirm'], { state: { password: formValue.password } });

// ✅ Use a short-lived service store instead
this.pendingActionService.set({ action: 'change-password', token: serverToken });
this.router.navigate(['/confirm']);
```

### Guard all admin/sensitive routes

```typescript
// Ensure both canActivate (runtime) AND canMatch (prevents bundle download) are set
{
  path: 'admin',
  loadChildren: () => import('./features/admin/admin.routes'),
  canMatch: [authGuard, roleGuard('ADMIN')],
}
```

---

## 7. Dependency Security

```bash
# Audit npm dependencies for known vulnerabilities
npm audit

# Fix automatically where possible
npm audit fix

# Check for outdated packages (especially security-critical ones)
npm outdated

# Use a lock file — always commit package-lock.json
# Never use npm install --no-package-lock in production
```

Set up automated auditing in CI:
```yaml
# .github/workflows/security.yml
- name: Audit dependencies
  run: npm audit --audit-level=high
  # Fails the build if high or critical vulnerabilities are found
```

**Angular-specific:** Keep `@angular/*`, `@angular/material`, and `rxjs` updated together.
Use `ng update` rather than manual npm installs to avoid version skew.

---

## 8. Security Checklist

**XSS**
- [ ] No `[innerHTML]` bindings with user-generated content
- [ ] All `bypassSecurityTrust*` calls documented with WHY and source of content
- [ ] Dynamic URLs use `safeUrl` pipe or `bypassSecurityTrustUrl`

**CSRF**
- [ ] `withXsrfConfiguration()` configured in `provideHttpClient()`
- [ ] Server validates `X-XSRF-TOKEN` on all state-changing requests
- [ ] Session cookies use `SameSite=Strict` or `SameSite=Lax`

**Sensitive data**
- [ ] No tokens or PII in `localStorage` (use `HttpOnly` cookies or memory)
- [ ] No sensitive data in URL params or route state
- [ ] Logs scrubbed of PII before shipping to monitoring

**Routes**
- [ ] All protected routes have `canMatch` (prevents bundle download) and `canActivate`
- [ ] `returnUrl` validated as relative path before redirect
- [ ] Admin/sensitive routes use role guard in addition to auth guard

**Infrastructure**
- [ ] CSP headers set on all responses
- [ ] `X-Frame-Options: DENY` or `frame-ancestors 'none'` in CSP
- [ ] `X-Content-Type-Options: nosniff` set
- [ ] `npm audit` runs in CI — build fails on high/critical vulnerabilities
- [ ] HTTPS enforced — no HTTP in production
