# Debugging & Validation

## Table of Contents
1. GA4 DebugView
2. GTM Preview Mode
3. Browser Console Validation
4. Common Issues & Fixes
5. Pre-Production Checklist

---

## 1. GA4 DebugView

Real-time event stream for a single device — the fastest way to validate events.

### Enable debug mode

**Method A: Chrome Extension (recommended)**
Install [Google Analytics Debugger](https://chrome.google.com/webstore/detail/google-analytics-debugger/jnkmfdileelhofjcijamephohjechhna) — sets `debug_mode=true` automatically.

**Method B: URL parameter**
Add `?_ga_debug=1` to any page URL — enables debug for that session.

**Method C: gtag config (dev only)**
```typescript
// In AnalyticsService — dev environment only
if (!environment.production) {
  gtag('config', environment.ga4MeasurementId, { debug_mode: true });
}
```

### Reading DebugView

Go to **GA4** → **Configure** → **DebugView**

- Events appear in real-time as you interact with the app
- Click any event to see its parameters
- Red events = validation errors (e.g. reserved name, parameter too long)
- Check that `user_id` and `plan` appear on every event

---

## 2. GTM Preview Mode

Validates that GTM triggers fire correctly before publishing.

1. In GTM → **Preview** → enter your site URL
2. Interact with your app — GTM debugger shows every dataLayer push
3. For each push, verify:
   - **Tag fired**: The GA4 event tag triggered
   - **Variables**: `event_params.*` variables resolved correctly
   - **Trigger condition**: The trigger matched the expected event name

### Common GTM Debug Checks

```
✅ dataLayer push appears in "Data Layer" tab
✅ Tag "GA4 - bot_created" shows "Fired" not "Not Fired"
✅ Variable {{event_params.bot_type}} shows correct value
✅ No "Blocked" or "Paused" status on tags
```

---

## 3. Browser Console Validation

Quick checks without opening GA4:

```javascript
// Check dataLayer contents
console.table(window.dataLayer);

// Watch for new pushes in real-time
const originalPush = window.dataLayer.push.bind(window.dataLayer);
window.dataLayer.push = function(...args) {
  console.log('[dataLayer push]', ...args);
  return originalPush(...args);
};

// Check gtag calls (if using gtag.js directly)
const originalGtag = window.gtag;
window.gtag = function(...args) {
  console.log('[gtag]', ...args);
  return originalGtag?.(...args);
};
```

In `AnalyticsService`, dev mode logs every event to console automatically:
```
[Analytics] bot_created { bot_type: 'faq', template_used: null, ... }
```

---

## 4. Common Issues & Fixes

### Events not appearing in GA4

| Symptom | Likely Cause | Fix |
|---|---|---|
| No events in DebugView | `isEnabled = false` in dev | Set `debug_mode: true` in gtag config |
| Events in console but not GA4 | Wrong Measurement ID | Check `environment.prod.ts` → `ga4MeasurementId` |
| Events appear but no parameters | GTM variable not mapped | Check GTM variable config matches dataLayer key |
| Events delayed 24–48hrs | Normal for non-realtime reports | Use DebugView or Realtime report |

### Parameter values missing or `undefined`

```typescript
// ❌ Wrong — sends undefined if bot.templateId is undefined
this.analytics.track('bot_created', {
  template_used: bot.templateId,
});

// ✅ Correct — explicit null is valid, undefined is dropped by GA4
this.analytics.track('bot_created', {
  template_used: bot.templateId ?? null,
});
```

### Page views double-firing

Caused by both automatic page_view (from gtag config) AND manual Router tracking.

Fix: Disable automatic page view in gtag config:
```typescript
gtag('config', environment.ga4MeasurementId, {
  send_page_view: false,   // let Router tracking handle it
});
```

### User ID not appearing on events

User properties must be set BEFORE events fire. Check that `setUserProperties()` is called
on login/app init before any `track()` calls.

### Events hitting wrong GA4 property

Verify measurement ID matches environment:
```typescript
// In browser console
window.gtag('get', 'G-XXXXXXXX', 'measurement_id', (val) => console.log(val));
```

---

## 5. Pre-Production Checklist

Run this before every release that includes new tracking:

**Implementation**
- [ ] All new events are documented in `event-taxonomy.md`
- [ ] No `gtag()` calls outside `AnalyticsService`
- [ ] `isEnabled` check prevents firing in development
- [ ] All required parameters are present (check taxonomy)
- [ ] No PII in parameters (no email, phone, real names)
- [ ] Null used instead of undefined for optional parameters

**Validation**
- [ ] GA4 DebugView shows event firing correctly
- [ ] All parameters appear with correct types and values
- [ ] `user_id`, `plan`, `org_id` present on every event
- [ ] No duplicate events (check for multiple triggers)
- [ ] `flow_abandoned` fires when navigating away from flows

**GTM (if applicable)**
- [ ] GTM Preview mode confirms tags fire
- [ ] Variables resolve to correct values
- [ ] GTM container published after validation

**Funnel Integrity**
- [ ] Funnel steps fire in correct order
- [ ] No step fires without its prerequisite
- [ ] `is_first_*` boolean is accurate
