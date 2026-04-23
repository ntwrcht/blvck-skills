# Server-Side Rendering (SSR) — Angular 17+

Angular 17+ ships SSR built-in via `@angular/ssr`. No separate Angular Universal package needed.

## Table of Contents
1. Setup
2. Hydration
3. Transfer State (server → client data handoff)
4. Platform-Aware Code
5. SSR-Safe Service Patterns
6. Route-Level Rendering Strategies
7. SEO — Meta Tags & Title
8. SSR Checklist

---

## 1. Setup

```bash
# New project with SSR
ng new my-app --ssr

# Add SSR to existing project
ng add @angular/ssr
```

Generated files:
```
src/
├── app/
│   └── app.config.server.ts    ← server-specific providers
├── server.ts                   ← Express server entry point
└── main.server.ts              ← SSR bootstrap
```

```typescript
// src/app/app.config.ts
export const appConfig: ApplicationConfig = {
  providers: [
    provideRouter(routes),
    provideClientHydration(),   // ← required for hydration
    provideHttpClient(withFetch()),   // withFetch() is SSR-compatible; HttpClientModule is not
  ],
};
```

```typescript
// src/app/app.config.server.ts
const serverConfig: ApplicationConfig = {
  providers: [provideServerRendering()],
};

export const config = mergeApplicationConfig(appConfig, serverConfig);
```

---

## 2. Hydration

Angular 17+ hydration reuses server-rendered DOM instead of destroying and recreating it.
This eliminates the flash of blank content on first load.

```typescript
// app.config.ts — required
provideClientHydration()

// With event replay (ng18+) — replays user interactions that happened before hydration
provideClientHydration(withEventReplay())
```

**Hydration gotchas:**

```typescript
// ❌ DOM manipulation in constructor or before hydration completes
export class BadComponent {
  constructor() {
    document.querySelector('.title').textContent = 'Hello';  // breaks hydration
  }
}

// ✅ Use afterNextRender() for first-render DOM access
export class GoodComponent {
  constructor() {
    afterNextRender(() => {
      // safe — runs only in browser, after hydration
      document.querySelector('.title').textContent = 'Hello';
    });
  }
}
```

**Skip hydration for components that can't hydrate** (e.g., components using Canvas, third-party DOM libs):
```typescript
@Component({
  selector: 'app-chart',
  template: '<canvas #canvas></canvas>',
  hostDirectives: [NgSkipHydration],   // tells Angular to re-render this component on client
})
export class ChartComponent {}
```

---

## 3. Transfer State

Prevents double-fetching: data fetched on the server is serialized and sent to the client,
which reads it instead of making a second HTTP request.

`HttpClient` with `provideHttpClient(withFetch())` handles transfer state automatically.
For custom data, use `TransferState` directly:

```typescript
// src/app/core/services/config.service.ts
import { TransferState, makeStateKey, isPlatformServer } from '@angular/core';

const CONFIG_KEY = makeStateKey<AppConfig>('app-config');

@Injectable({ providedIn: 'root' })
export class ConfigService {
  private platformId = inject(PLATFORM_ID);
  private transferState = inject(TransferState);
  private http = inject(HttpClient);

  getConfig(): Observable<AppConfig> {
    // If client has server-transferred data, use it — no HTTP call
    if (this.transferState.hasKey(CONFIG_KEY)) {
      const config = this.transferState.get(CONFIG_KEY, null)!;
      this.transferState.remove(CONFIG_KEY);
      return of(config);
    }

    return this.http.get<AppConfig>('/api/config').pipe(
      tap(config => {
        // On server: serialize for client
        if (isPlatformServer(this.platformId)) {
          this.transferState.set(CONFIG_KEY, config);
        }
      })
    );
  }
}
```

---

## 4. Platform-Aware Code

Some APIs only exist in the browser (`window`, `localStorage`, `document`, `navigator`).
Always guard them — SSR runs in Node.js where these don't exist.

```typescript
import { PLATFORM_ID, inject, isPlatformBrowser, isPlatformServer } from '@angular/core';

@Injectable({ providedIn: 'root' })
export class PlatformService {
  private platformId = inject(PLATFORM_ID);

  get isBrowser(): boolean { return isPlatformBrowser(this.platformId); }
  get isServer(): boolean  { return isPlatformServer(this.platformId); }
}
```

```typescript
// ❌ Crashes on server
export class BadService {
  getToken(): string | null {
    return localStorage.getItem('token');   // ReferenceError: localStorage is not defined
  }
}

// ✅ Platform-aware
@Injectable({ providedIn: 'root' })
export class StorageService {
  private platform = inject(PlatformService);

  get(key: string): string | null {
    return this.platform.isBrowser ? localStorage.getItem(key) : null;
  }

  set(key: string, value: string): void {
    if (this.platform.isBrowser) localStorage.setItem(key, value);
  }

  remove(key: string): void {
    if (this.platform.isBrowser) localStorage.removeItem(key);
  }
}
```

---

## 5. SSR-Safe Service Patterns

### Auth service — token from request cookie (server) vs localStorage (client)

```typescript
@Injectable({ providedIn: 'root' })
export class AuthService {
  private platform = inject(PlatformService);
  private request = inject(REQUEST, { optional: true });  // only available on server

  getToken(): string | null {
    if (this.platform.isServer) {
      // Read from cookie in the incoming HTTP request
      return this.request?.cookies?.['auth_token'] ?? null;
    }
    return localStorage.getItem('auth_token');
  }
}
```

### Window / document access

```typescript
// Use injection tokens instead of direct globals
import { DOCUMENT } from '@angular/common';

@Injectable({ providedIn: 'root' })
export class ScrollService {
  private document = inject(DOCUMENT);

  scrollToTop(): void {
    this.document.defaultView?.scrollTo({ top: 0, behavior: 'smooth' });
  }
}
```

### afterNextRender vs afterRender

```typescript
// afterNextRender — fires once after first render (browser only)
// Use for: third-party lib init, one-time DOM reads, chart setup
export class MapComponent {
  constructor() {
    afterNextRender(() => {
      this.initMap();
    });
  }
}

// afterRender — fires after every render (browser only)
// Use for: syncing DOM state on every change
export class ResizableComponent {
  constructor() {
    afterRender(() => {
      this.measureDimensions();
    });
  }
}
```

---

## 6. Route-Level Rendering Strategies

Configure per route in `app.routes.server.ts`:

```typescript
// src/app/app.routes.server.ts
import { RenderMode, ServerRoute } from '@angular/ssr';

export const serverRoutes: ServerRoute[] = [
  // Prerender at build time — for fully static content
  { path: '', renderMode: RenderMode.Prerender },
  { path: 'about', renderMode: RenderMode.Prerender },
  { path: 'pricing', renderMode: RenderMode.Prerender },

  // Server-render on each request — for dynamic, auth-dependent content
  { path: 'dashboard', renderMode: RenderMode.Server },
  { path: 'profile', renderMode: RenderMode.Server },

  // Client-side only — for highly interactive, auth-gated tools
  { path: 'editor', renderMode: RenderMode.Client },

  // Prerender with params — generate at build time for known IDs
  {
    path: 'products/:id',
    renderMode: RenderMode.Prerender,
    async getPrerenderParams() {
      // Fetch product IDs at build time
      const ids = await fetch('/api/products?ids-only=true').then(r => r.json());
      return ids.map((id: string) => ({ id }));
    },
  },
];
```

**When to use each:**

| Strategy | Use for | Freshness |
|---|---|---|
| `Prerender` | Marketing pages, docs, product catalogs | Build time |
| `Server` | User-specific pages, search results, dashboards | Every request |
| `Client` | Heavy editors, maps, canvas-heavy tools | Browser only |

---

## 7. SEO — Meta Tags & Title

```typescript
// src/app/core/services/seo.service.ts
import { Meta, Title } from '@angular/platform-browser';

@Injectable({ providedIn: 'root' })
export class SeoService {
  private title = inject(Title);
  private meta = inject(Meta);

  setPage(config: { title: string; description: string; image?: string; url?: string }): void {
    this.title.setTitle(`${config.title} | MyApp`);

    this.meta.updateTag({ name: 'description', content: config.description });

    // Open Graph
    this.meta.updateTag({ property: 'og:title', content: config.title });
    this.meta.updateTag({ property: 'og:description', content: config.description });
    if (config.image) this.meta.updateTag({ property: 'og:image', content: config.image });
    if (config.url) this.meta.updateTag({ property: 'og:url', content: config.url });

    // Twitter Card
    this.meta.updateTag({ name: 'twitter:card', content: 'summary_large_image' });
    this.meta.updateTag({ name: 'twitter:title', content: config.title });
    this.meta.updateTag({ name: 'twitter:description', content: config.description });
  }
}
```

Call in a resolver or in the page component's `ngOnInit`:
```typescript
ngOnInit(): void {
  this.seoService.setPage({
    title: this.product.name,
    description: this.product.description,
    image: this.product.imageUrl,
    url: `https://myapp.com/products/${this.product.id}`,
  });
}
```

---

## 8. SSR Checklist

Before shipping an SSR feature:

- [ ] No bare `window`, `document`, `localStorage`, `navigator` references — wrapped in `PlatformService`
- [ ] DOM manipulation uses `afterNextRender()`, not constructor or `ngOnInit`
- [ ] `HttpClient` uses `withFetch()`, not `HttpClientModule`
- [ ] `provideClientHydration()` in `app.config.ts`
- [ ] Third-party libs that touch the DOM are guarded with `isPlatformBrowser`
- [ ] `TransferState` used for any non-HTTP server data that's needed on client
- [ ] Route render modes configured in `app.routes.server.ts`
- [ ] SEO meta tags set for every server-rendered route
- [ ] Test with `ng build` + `node dist/server/server.mjs` — not just `ng serve`
- [ ] Check Network tab: server response contains full HTML, not empty `<app-root>`
