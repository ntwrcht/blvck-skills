# Design System and Styling

Match the project's existing system. Introducing a second styling approach alongside one that already works is a cost with no payoff.

---

## Options

| Approach | Server Components | Notes |
|---|---|---|
| Tailwind CSS | ✅ | Default in `create-next-app`. No runtime, no client boundary. |
| CSS Modules | ✅ | Scoped, zero runtime, built in. |
| Global CSS | ✅ | Import only in the root layout. |
| Sass / SCSS | ✅ | `npm i sass`. Next 16 uses `sass-loader` v16 (modern API). |
| CSS-in-JS (styled-components, emotion) | ❌ | Requires `'use client'` and a registry; avoid in new App Router work. |
| vanilla-extract, Panda CSS | ✅ | Compile-time, zero runtime. |

CSS-in-JS libraries that read the render tree at runtime cannot run in Server Components. If a project uses one, expect `'use client'` to spread wider than it should.

---

## Tailwind

```css
/* app/globals.css — Tailwind v4 */
@import "tailwindcss";

@theme {
  --color-brand-50:  oklch(0.97 0.02 250);
  --color-brand-500: oklch(0.62 0.19 250);
  --color-brand-900: oklch(0.32 0.12 250);
  --font-sans: var(--font-inter), system-ui, sans-serif;
  --radius-card: 0.75rem;
}
```

Tailwind v4 configures through CSS `@theme` rather than `tailwind.config.js`. v3 projects keep the JS config — check which is installed before editing either.

Conditional classes need `clsx` + `tailwind-merge`, because later Tailwind classes do not reliably beat earlier ones in the stylesheet:

```ts
// lib/utils.ts
import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}
```

```tsx
<div className={cn('px-4 py-2 rounded', isActive && 'bg-brand-500', className)} />
```

Dynamic class names must be complete strings — Tailwind scans source text and cannot see `bg-${color}-500`:

```tsx
// ❌ Class never generated
<div className={`bg-${color}-500`} />

// ✅ Full strings in a lookup
const styles = { red: 'bg-red-500', blue: 'bg-blue-500' } as const
<div className={styles[color]} />
```

---

## CSS Modules

```css
/* components/card.module.css */
.card {
  padding: var(--space-4);
  border-radius: var(--radius-card);
  background: var(--color-surface);
}
.card:hover { box-shadow: var(--shadow-md); }
```

```tsx
import styles from './card.module.css'
export function Card({ children }: { children: React.ReactNode }) {
  return <div className={styles.card}>{children}</div>
}
```

Works in Server Components. Class names are hashed, so collisions are impossible.

---

## Design Tokens

Whatever the styling layer, define tokens once as CSS custom properties so both Tailwind and hand-written CSS read the same values:

```css
/* app/globals.css */
:root {
  --color-surface: oklch(1 0 0);
  --color-text: oklch(0.15 0 0);
  --color-border: oklch(0.9 0 0);
  --space-4: 1rem;
  --radius-card: 0.75rem;
  --shadow-md: 0 4px 6px -1px oklch(0 0 0 / 0.1);
}

.dark {
  --color-surface: oklch(0.18 0 0);
  --color-text: oklch(0.95 0 0);
  --color-border: oklch(0.3 0 0);
}
```

Redefining tokens under `.dark` means components need no dark-mode variants of their own.

---

## Dark Mode

```bash
npm install next-themes
```

```tsx
// app/providers.tsx
'use client'
import { ThemeProvider } from 'next-themes'

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider attribute="class" defaultTheme="system" enableSystem disableTransitionOnChange>
      {children}
    </ThemeProvider>
  )
}
```

```tsx
// app/layout.tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <body><Providers>{children}</Providers></body>
    </html>
  )
}
```

`suppressHydrationWarning` on `<html>` is required — the theme script mutates the class before React hydrates, and that is a legitimate mismatch.

A theme toggle must not render the current theme label until mounted, or the server HTML says "light" while the client says "dark":

```tsx
'use client'
export function ThemeToggle() {
  const [mounted, setMounted] = useState(false)
  const { theme, setTheme } = useTheme()
  useEffect(() => setMounted(true), [])
  if (!mounted) return <button aria-label="Toggle theme" className="size-9" />
  return (
    <button onClick={() => setTheme(theme === 'dark' ? 'light' : 'dark')}>
      {theme === 'dark' ? '☀️' : '🌙'}
    </button>
  )
}
```

---

## shadcn/ui

Not a dependency — it copies component source into the repo, so components are yours to edit.

```bash
npx shadcn@latest init
npx shadcn@latest add button dialog form
```

Components land in `components/ui/`. Treat them as project code: edit in place, review in PRs. Re-running `add` for an existing component overwrites local edits — check the diff.

Most shadcn components are Client Components because they wrap Radix primitives. Compose them so the client boundary stays at the interactive part.

---

## Fonts

```tsx
// app/layout.tsx
import { Inter, JetBrains_Mono } from 'next/font/google'

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
})

const mono = JetBrains_Mono({
  subsets: ['latin'],
  variable: '--font-mono',
  display: 'swap',
})

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" className={`${inter.variable} ${mono.variable}`}>
      <body>{children}</body>
    </html>
  )
}
```

`next/font` self-hosts at build time: no request to Google, no privacy concern, and it generates a size-adjusted fallback that removes font-swap layout shift.

Local fonts:

```tsx
import localFont from 'next/font/local'

const brand = localFont({
  src: [
    { path: './fonts/Brand-Regular.woff2', weight: '400', style: 'normal' },
    { path: './fonts/Brand-Bold.woff2', weight: '700', style: 'normal' },
  ],
  variable: '--font-brand',
  display: 'swap',
})
```

Call `next/font` at module scope, never inside a component — it is a build-time transform.

---

## Component Variants

```tsx
import { cva, type VariantProps } from 'class-variance-authority'

const button = cva(
  'inline-flex items-center justify-center rounded font-medium transition-colors ' +
  'focus-visible:outline-none focus-visible:ring-2 disabled:opacity-50',
  {
    variants: {
      variant: {
        primary: 'bg-brand-500 text-white hover:bg-brand-600',
        outline: 'border border-border hover:bg-surface-muted',
        ghost: 'hover:bg-surface-muted',
      },
      size: { sm: 'h-8 px-3 text-sm', md: 'h-10 px-4', lg: 'h-12 px-6 text-lg' },
    },
    defaultVariants: { variant: 'primary', size: 'md' },
  }
)

type ButtonProps = React.ButtonHTMLAttributes<HTMLButtonElement> & VariantProps<typeof button>

export function Button({ variant, size, className, ...props }: ButtonProps) {
  return <button className={cn(button({ variant, size }), className)} {...props} />
}
```

This has no `'use client'` — a button with no internal state stays a Server Component and the consumer attaches handlers from its own client boundary.

---

## Layout Shift

- `next/font` with `display: 'swap'` and automatic fallback metrics.
- `next/image` with explicit `width`/`height`, or `fill` inside a sized container.
- Reserve space for anything that streams in — skeletons should match real dimensions.
- Avoid animating `width`, `height`, `top`, `left`. Animate `transform` and `opacity`.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Tailwind class has no effect | Interpolated class name, or file outside the content scan |
| Conflicting Tailwind classes | Need `twMerge`, not string concatenation |
| Hydration warning on `<html>` | Missing `suppressHydrationWarning` with `next-themes` |
| Theme toggle shows wrong icon on load | Rendering theme state before mount |
| CSS-in-JS breaks in a Server Component | Runtime CSS-in-JS needs `'use client'` and a registry |
| Fonts flash or shift | Not using `next/font`, or missing `display: 'swap'` |
| shadcn edits disappear | `npx shadcn add` re-run over a customized component |
| Styles leak between components | Global CSS where a CSS Module was needed |
