# Performance Optimization for Angular 14

## 1. OnPush Change Detection

The single biggest win in Angular performance. With `Default` CD, Angular checks every component on every event. With `OnPush`, a component only re-checks when:
- An `@Input()` reference changes (not mutation — new reference)
- An event from the component itself fires
- An `async` pipe emits a new value
- You manually call `markForCheck()`

```typescript
// Always start with OnPush — only drop down to Default if you have a specific reason
@Component({
  selector: 'app-product-card',
  templateUrl: './product-card.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,  // ← always
})
export class ProductCardComponent {
  @Input() product!: Product;
}
```

**Common OnPush gotcha — mutation doesn't trigger re-render:**
```typescript
// ❌ BAD — mutating the array, OnPush won't detect the change
addProduct(product: Product): void {
  this.products.push(product);  // same reference, no re-render
}

// ✅ GOOD — new array reference triggers OnPush
addProduct(product: Product): void {
  this.products = [...this.products, product];
}
```

**When you need to trigger CD manually** (e.g., data changed outside Angular):
```typescript
constructor(private cdr: ChangeDetectorRef) {}

onExternalDataChange(data: Data): void {
  this.data = data;
  this.cdr.markForCheck();  // schedules a check for this component and ancestors
}
```

---

## 2. trackBy with *ngFor

Without `trackBy`, Angular destroys and recreates every DOM element on any array change. With `trackBy`, it only updates what actually changed.

```typescript
// Component
trackById(_index: number, item: { id: number }): number {
  return item.id;
}

// For string-keyed items
trackByKey(_index: number, item: { key: string }): string {
  return item.key;
}
```

```html
<!-- Template -->
<tr *ngFor="let row of rows$ | async; trackBy: trackById">
  <td>{{ row.name }}</td>
</tr>
```

---

## 3. Pure Pipes Instead of Method Calls in Templates

Methods in templates are called on **every change detection cycle**. Pipes with `pure: true` (the default) are only called when inputs change.

```typescript
// ❌ BAD — called every CD cycle, even when data hasn't changed
// template: {{ formatCurrency(product.price) }}

// ✅ GOOD — only called when price changes
@Pipe({ name: 'currency14', pure: true })
export class Currency14Pipe implements PipeTransform {
  transform(value: number, currency = 'USD'): string {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(value);
  }
}
// template: {{ product.price | currency14 }}
```

For complex computed values in a smart component, use `async` + a derived observable instead:
```typescript
// ❌ BAD — method in template
// template: <p>Active: {{ getActiveCount() }}</p>

// ✅ GOOD — derived observable, works perfectly with OnPush + async
activeCount$ = this.userService.users$.pipe(
  map(users => users.filter(u => u.status === 'active').length)
);
// template: <p>Active: {{ activeCount$ | async }}</p>
```

---

## 4. Lazy Loading Feature Modules

Every feature should load only when its route is first visited. Never import feature modules directly in AppModule.

```typescript
// app-routing.module.ts
const routes: Routes = [
  {
    path: 'dashboard',
    loadChildren: () =>
      import('./features/dashboard/dashboard.module').then(m => m.DashboardModule),
  },
  {
    path: 'users',
    loadChildren: () =>
      import('./features/users/users.module').then(m => m.UsersModule),
  },
  {
    path: 'products',
    loadChildren: () =>
      import('./features/products/products.module').then(m => m.ProductsModule),
  },
];
```

**Preloading strategy** — preload all lazy modules after initial load completes:
```typescript
// app-routing.module.ts
@NgModule({
  imports: [RouterModule.forRoot(routes, {
    preloadingStrategy: PreloadAllModules,  // load lazy chunks in background after app starts
  })],
  exports: [RouterModule],
})
export class AppRoutingModule {}
```

---

## 5. Virtual Scrolling for Long Lists

Rendering 500+ rows kills performance. Use CDK virtual scrolling to render only visible rows.

```typescript
// module: import ScrollingModule from '@angular/cdk/scrolling'
import { ScrollingModule } from '@angular/cdk/scrolling';
```

```html
<!-- Only renders ~10 visible items at a time regardless of list size -->
<cdk-virtual-scroll-viewport itemSize="56" style="height: 400px;">
  <div *cdkVirtualFor="let item of items; trackBy: trackById" class="row">
    {{ item.name }}
  </div>
</cdk-virtual-scroll-viewport>
```

For `mat-table` with virtual scrolling, use `@angular/cdk/table` with a virtual data source:
```typescript
import { DataSource } from '@angular/cdk/collections';
import { BehaviorSubject, Observable } from 'rxjs';

export class VirtualTableDataSource<T> extends DataSource<T> {
  private data = new BehaviorSubject<T[]>([]);

  setData(items: T[]): void { this.data.next(items); }
  connect(): Observable<T[]> { return this.data.asObservable(); }
  disconnect(): void { this.data.complete(); }
}
```

---

## 6. Bundle Size Analysis

Run this to see what's making your bundle large:
```bash
ng build --stats-json
npx webpack-bundle-analyzer dist/<project>/stats.json
```

Common quick wins:
- Are you importing entire icon libraries? Import only what you use.
- Are you importing `moment`? Replace with `date-fns` (tree-shakeable).
- Is `@angular/material` fully imported? Use the individual entry-points.
- Any third-party libraries over 50KB? Look for lighter alternatives.

**Lazy load heavy third-party libraries** (e.g., chart libraries, PDF viewers):
```typescript
async loadChart(): Promise<void> {
  const { Chart } = await import('chart.js');  // loaded on demand
  // use Chart here
}
```

---

## 7. HTTP Caching with shareReplay

Prevent duplicate HTTP calls when multiple components need the same data:
```typescript
@Injectable({ providedIn: 'root' })
export class ReferenceDataService {
  // These are called once per session — cache the result
  readonly countries$ = this.http.get<Country[]>('/api/countries').pipe(
    shareReplay(1)
  );

  readonly currencies$ = this.http.get<Currency[]>('/api/currencies').pipe(
    shareReplay(1)
  );

  constructor(private http: HttpClient) {}
}
```

---

## 8. Performance Checklist

Before releasing a feature, verify:

- [ ] All new components use `ChangeDetectionStrategy.OnPush`
- [ ] All `*ngFor` loops over object arrays have `trackBy`
- [ ] No method calls in templates — use pipes or `async` + observables
- [ ] Feature module is lazy-loaded (open DevTools Network tab, confirm chunk loads on navigation)
- [ ] Lists with 100+ items use CDK virtual scroll
- [ ] No `shareReplay` missing on HTTP observables used by multiple components
- [ ] Images have `loading="lazy"` and explicit `width`/`height`
- [ ] Run `ng build --prod` and check bundle sizes — no unexpected large additions
