# Angular Integration — GA4 & GTM

## Table of Contents
1. AnalyticsService (Single Source of Truth)
2. Router Tracking (SPA Page Views)
3. gtag.js Setup
4. GTM + dataLayer Setup
5. Performance Tracking (Web Vitals)
6. Error Tracking Integration
7. User Properties Setup
8. Testing & Validation

---

## 1. AnalyticsService — Single Source of Truth

**Never call `gtag()` or push to `dataLayer` directly in components.**
All tracking goes through this service — it enforces naming conventions,
blocks tracking in non-production, and makes testing trivial.

```typescript
// src/app/core/services/analytics.service.ts
import { Injectable, isDevMode } from '@angular/core';
import { environment } from '../../../environments/environment';

export interface EventParams {
  [key: string]: string | number | boolean | null | undefined;
}

@Injectable({ providedIn: 'root' })
export class AnalyticsService {
  private isEnabled = !isDevMode() && environment.production;

  // Set user context once (on login / app init)
  setUserProperties(props: {
    userId: string;
    plan: 'free' | 'sme' | 'enterprise';
    orgId: string;
  }): void {
    if (!this.isEnabled) return;

    gtag('set', 'user_properties', {
      plan: props.plan,
      org_id: props.orgId,
    });
    gtag('config', environment.ga4MeasurementId, {
      user_id: props.userId,
    });
  }

  // Track a business event
  track(eventName: string, params: EventParams = {}): void {
    if (!this.isEnabled) {
      console.debug('[Analytics]', eventName, params);  // dev visibility
      return;
    }

    const enriched = {
      ...params,
      app_version: environment.appVersion,
      environment: 'production',
    };

    // Supports both gtag.js and GTM dataLayer
    if (typeof gtag !== 'undefined') {
      gtag('event', eventName, enriched);
    }

    // Always push to dataLayer (GTM reads this)
    this.pushDataLayer(eventName, enriched);
  }

  // Track page views manually (for SPA route changes)
  trackPageView(pagePath: string, pageTitle: string): void {
    if (!this.isEnabled) return;

    gtag('event', 'page_view', {
      page_path: pagePath,
      page_title: pageTitle,
      page_location: window.location.href,
    });
  }

  private pushDataLayer(event: string, params: EventParams): void {
    if (typeof window === 'undefined') return;
    (window as any).dataLayer = (window as any).dataLayer || [];
    (window as any).dataLayer.push({
      event,
      event_params: params,
    });
  }
}
```

Usage in components:
```typescript
@Component({ ... })
export class BotCreatePageComponent {
  private analytics = inject(AnalyticsService);

  onBotCreated(bot: Bot, timeMs: number): void {
    this.analytics.track('item_created', {
      bot_type: bot.type,
      template_used: bot.templateId ?? null,
      channel_count: bot.channels.length,
      time_to_complete_ms: timeMs,
    });
  }
}
```

---

## 2. Router Tracking (SPA Page Views)

GA4 does not automatically track navigation in Angular SPAs.
Register a Router listener in `AppComponent` to fire page_view on every route change.

```typescript
// src/app/app.component.ts
@Component({
  selector: 'app-root',
  standalone: true,
  template: '<router-outlet />',
})
export class AppComponent implements OnInit {
  private router = inject(Router);
  private analytics = inject(AnalyticsService);
  private titleService = inject(Title);
  private destroy$ = new Subject<void>();

  ngOnInit(): void {
    this.router.events.pipe(
      filter(event => event instanceof NavigationEnd),
      takeUntil(this.destroy$),
    ).subscribe((event: NavigationEnd) => {
      // Small delay ensures page title is updated before tracking
      setTimeout(() => {
        this.analytics.trackPageView(
          event.urlAfterRedirects,
          this.titleService.getTitle()
        );
      }, 0);
    });
  }

  ngOnDestroy(): void { this.destroy$.next(); this.destroy$.complete(); }
}
```

---

## 3. gtag.js Setup

### index.html

```html
<!-- Load GA4 async — place in <head> -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-XXXXXXXXXX"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());

  // Do NOT call gtag('config') here — AnalyticsService handles it after user login
  // This prevents sending anonymous hits before user context is set
</script>
```

### environment.ts

```typescript
export const environment = {
  production: false,
  ga4MeasurementId: '',           // empty string disables tracking in dev
  appVersion: '2.4.1',
  // ...
};
```

```typescript
// environment.prod.ts
export const environment = {
  production: true,
  ga4MeasurementId: 'G-XXXXXXXXXX',
  appVersion: '2.4.1',
};
```

### TypeScript declaration (avoid `any` for gtag)

```typescript
// src/typings.d.ts
declare function gtag(
  command: 'event' | 'config' | 'set',
  targetId: string,
  params?: Record<string, unknown>
): void;
declare function gtag(command: 'js', date: Date): void;
declare const dataLayer: unknown[];
```

---

## 4. GTM + dataLayer Setup

### index.html (GTM snippet)

```html
<!-- GTM in <head> — as high as possible -->
<script>
(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
})(window,document,'script','dataLayer','GTM-XXXXXXX');
</script>

<!-- GTM noscript in <body> immediately after opening tag -->
<noscript>
  <iframe src="https://www.googletagmanager.com/ns.html?id=GTM-XXXXXXX"
  height="0" width="0" style="display:none;visibility:hidden"></iframe>
</noscript>
```

### dataLayer push structure

```typescript
// AnalyticsService already handles this — but if you need a raw push:
(window as any).dataLayer.push({
  event: 'item_published',           // GTM trigger listens for this
  event_params: {
    channel_type: 'line',
    is_first_publish: true,
    time_since_created_ms: 86400000,
  },
  user_properties: {
    plan: 'enterprise',
    org_id: 'org_abc123',
  },
});
```

---

## 5. Performance Tracking (Web Vitals)

```bash
npm install web-vitals
```

```typescript
// src/app/core/services/performance.service.ts
import { Injectable } from '@angular/core';
import { onLCP, onFID, onCLS, onTTFB } from 'web-vitals';

@Injectable({ providedIn: 'root' })
export class PerformanceService {
  private analytics = inject(AnalyticsService);
  private router = inject(Router);

  init(): void {
    const currentPage = () =>
      this.router.url.split('?')[0].replace(/\/[0-9a-f-]{36}/g, '/{id}');  // normalize IDs

    onLCP(({ value }) => this.reportVital('lcp_ms', value, currentPage()));
    onFID(({ value }) => this.reportVital('fid_ms', value, currentPage()));
    onCLS(({ value }) => this.reportVital('cls_score', value, currentPage()));
    onTTFB(({ value }) => this.reportVital('ttfb_ms', value, currentPage()));
  }

  private reportVital(metric: string, value: number, page: string): void {
    this.analytics.track('performance_page_loaded', {
      page,
      [metric]: Math.round(value),
    });
  }
}
```

Call `performanceService.init()` once in `AppComponent.ngOnInit()`.

---

## 6. Error Tracking Integration

Connect to the existing `GlobalErrorHandler`:

```typescript
// src/app/core/services/global-error-handler.ts
@Injectable()
export class GlobalErrorHandler implements ErrorHandler {
  private analytics = inject(AnalyticsService);

  handleError(error: unknown): void {
    const err = error instanceof Error ? error : new Error(String(error));

    // Sanitize — never send user data in error messages
    const sanitizedMessage = err.message
      .replace(/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-z]{2,}/g, '[email]')
      .replace(/\b\d{10,}\b/g, '[id]')
      .substring(0, 100);

    this.analytics.track('error_ui_crashed', {
      component: this.getComponentName(err),
      error_type: err.name,
      error_message: sanitizedMessage,
      page_path: window.location.pathname,
    });

    console.error(error);  // still log for dev tools
  }

  private getComponentName(err: Error): string {
    const match = err.stack?.match(/at (\w+Component)/);
    return match?.[1] ?? 'Unknown';
  }
}
```

---

## 7. User Properties Setup (On Login)

```typescript
// Call this after successful login/auth check
@Injectable({ providedIn: 'root' })
export class AuthService {
  private analytics = inject(AnalyticsService);

  private onLoginSuccess(user: AuthUser): void {
    // Set analytics context immediately after login
    this.analytics.setUserProperties({
      userId: this.hashUserId(user.id),   // one-way hash — never raw ID
      plan: user.org.plan,
      orgId: this.hashOrgId(user.org.id),
    });
  }

  private hashUserId(id: number): string {
    // Simple deterministic anonymization — use proper hash in production
    return `user_${btoa(String(id)).replace(/=/g, '')}`;
  }
}
```

---

## 8. Testing & Validation

```typescript
// src/app/core/services/analytics.service.spec.ts
describe('AnalyticsService', () => {
  let service: AnalyticsService;

  beforeEach(() => {
    TestBed.configureTestingModule({});
    service = TestBed.inject(AnalyticsService);

    // Mock gtag
    (window as any).gtag = jasmine.createSpy('gtag');
    (window as any).dataLayer = [];
  });

  it('should push to dataLayer when track() is called', () => {
    service['isEnabled'] = true;   // force enable in test

    service.track('item_created', { bot_type: 'faq' });

    const pushed = (window as any).dataLayer[0];
    expect(pushed.event).toBe('item_created');
    expect(pushed.event_params.bot_type).toBe('faq');
  });

  it('should not call gtag in dev mode', () => {
    service['isEnabled'] = false;

    service.track('item_created', {});

    expect((window as any).gtag).not.toHaveBeenCalled();
  });
});
```

For live validation → read `references/debugging.md`.
