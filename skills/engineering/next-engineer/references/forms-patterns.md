# Forms

Start with a plain `<form action={serverAction}>`. It works without JavaScript, needs no state library, and handles the majority of cases. Add client machinery only when a specific requirement demands it.

---

## Baseline: Server Action Form

```tsx
// app/products/new/page.tsx — Server Component, no 'use client'
import { createProduct } from '@/app/actions/products'

export default function NewProductPage() {
  return (
    <form action={createProduct}>
      <label htmlFor="name">Name</label>
      <input id="name" name="name" required />

      <label htmlFor="price">Price</label>
      <input id="price" name="price" type="number" step="0.01" required />

      <button type="submit">Create</button>
    </form>
  )
}
```

No hooks, no client bundle, works with JS disabled.

---

## With Validation Feedback

```tsx
'use client'
import { useActionState } from 'react'
import { createProduct } from '@/app/actions/products'

const initialState = { errors: {}, message: '' }

export function ProductForm() {
  const [state, formAction, pending] = useActionState(createProduct, initialState)

  return (
    <form action={formAction}>
      <label htmlFor="name">Name</label>
      <input
        id="name"
        name="name"
        required
        aria-invalid={!!state.errors?.name}
        aria-describedby={state.errors?.name ? 'name-error' : undefined}
      />
      {state.errors?.name && (
        <p id="name-error" role="alert">{state.errors.name[0]}</p>
      )}

      <button type="submit" disabled={pending}>
        {pending ? 'Saving…' : 'Create'}
      </button>
    </form>
  )
}
```

`useActionState` is React 19 (Next 15+); Next 14 uses `useFormState` from `react-dom`.

Server-side validation is the real validation. HTML `required` and `type="number"` are UX affordances — anyone can POST past them.

---

## Shared Schema

One Zod schema used on both sides keeps the rules in one place.

```ts
// lib/schemas/product.ts
import { z } from 'zod'

export const ProductSchema = z.object({
  name: z.string().min(1, 'Name is required').max(200),
  price: z.coerce.number().positive('Price must be greater than zero'),
  categoryId: z.string().uuid('Select a category'),
  description: z.string().max(2000).optional(),
})

export type ProductInput = z.infer<typeof ProductSchema>
```

`z.coerce.number()` matters: every `FormData` value is a string. `z.number()` against `"19.99"` fails.

```ts
// app/actions/products.ts
'use server'
import { ProductSchema } from '@/lib/schemas/product'

export type FormState = {
  errors?: Partial<Record<keyof ProductInput, string[]>>
  message?: string
}

export async function createProduct(prev: FormState, formData: FormData): Promise<FormState> {
  const session = await verifySession()
  const parsed = ProductSchema.safeParse(Object.fromEntries(formData))
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors }

  try {
    await db.product.create({ data: { ...parsed.data, ownerId: session.userId } })
  } catch {
    return { message: 'Could not save the product.' }
  }

  revalidateTag('products')
  redirect('/products')
}
```

---

## React Hook Form

Worth the client bundle when the form has real interaction complexity: field-level validation on blur, dependent fields, dynamic arrays, multi-step wizards, or unsaved-changes warnings.

```tsx
'use client'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { ProductSchema, type ProductInput } from '@/lib/schemas/product'
import { createProductJson } from '@/app/actions/products'

export function ProductForm() {
  const {
    register,
    handleSubmit,
    formState: { errors, isSubmitting },
    setError,
  } = useForm<ProductInput>({ resolver: zodResolver(ProductSchema) })

  async function onSubmit(data: ProductInput) {
    const result = await createProductJson(data)     // action taking a typed object
    if (result?.errors) {
      Object.entries(result.errors).forEach(([field, messages]) => {
        setError(field as keyof ProductInput, { message: messages[0] })
      })
    }
  }

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      <input {...register('name')} aria-invalid={!!errors.name} />
      {errors.name && <p role="alert">{errors.name.message}</p>}

      <input type="number" step="0.01" {...register('price')} />
      {errors.price && <p role="alert">{errors.price.message}</p>}

      <button disabled={isSubmitting}>Create</button>
    </form>
  )
}
```

A Server Action can take a typed object instead of `FormData` — validate it server-side all the same. This form no longer works without JavaScript; accept that trade knowingly.

---

## Submit Button

```tsx
'use client'
import { useFormStatus } from 'react-dom'

export function SubmitButton({ children }: { children: React.ReactNode }) {
  const { pending } = useFormStatus()
  return (
    <button type="submit" disabled={pending} aria-busy={pending}>
      {pending ? 'Saving…' : children}
    </button>
  )
}
```

Must be rendered **inside** the `<form>`, not in the component that renders it — the hook reads the nearest form context above.

---

## File Upload

```tsx
<form action={uploadAvatar} encType="multipart/form-data">
  <input type="file" name="avatar" accept="image/png,image/jpeg" required />
  <SubmitButton>Upload</SubmitButton>
</form>
```

```ts
'use server'
export async function uploadAvatar(formData: FormData) {
  const session = await verifySession()
  const file = formData.get('avatar') as File

  if (!file || file.size === 0) return { message: 'No file selected.' }
  if (file.size > 5 * 1024 * 1024) return { message: 'Maximum size is 5 MB.' }
  if (!['image/png', 'image/jpeg'].includes(file.type)) {
    return { message: 'PNG or JPEG only.' }
  }

  const bytes = Buffer.from(await file.arrayBuffer())
  const url = await storage.put(`avatars/${session.userId}`, bytes, { contentType: file.type })

  await db.user.update({ where: { id: session.userId }, data: { avatarUrl: url } })
  revalidateTag(`user-${session.userId}`)
}
```

`file.type` is client-supplied and trivially spoofed. For anything security-relevant, sniff the magic bytes server-side. Never derive a storage path from the uploaded filename — build it from ids you control.

Server Actions have a body-size limit (1 MB by default):

```ts
// next.config.ts
const nextConfig = {
  experimental: { serverActions: { bodySizeLimit: '5mb' } },
}
```

For large files, upload directly to storage with a presigned URL and send only the resulting key through the Action.

---

## Dynamic Field Arrays

```tsx
'use client'
import { useFieldArray, useForm } from 'react-hook-form'

export function InvoiceForm() {
  const { control, register, handleSubmit } = useForm<Invoice>({
    defaultValues: { lineItems: [{ description: '', amount: 0 }] },
  })
  const { fields, append, remove } = useFieldArray({ control, name: 'lineItems' })

  return (
    <form onSubmit={handleSubmit(onSubmit)}>
      {fields.map((field, i) => (
        <fieldset key={field.id}>
          <input {...register(`lineItems.${i}.description`)} />
          <input type="number" {...register(`lineItems.${i}.amount`)} />
          <button type="button" onClick={() => remove(i)}>Remove</button>
        </fieldset>
      ))}
      <button type="button" onClick={() => append({ description: '', amount: 0 })}>
        Add line
      </button>
      <button>Save</button>
    </form>
  )
}
```

Key on `field.id` from `useFieldArray`, not the index — index keys corrupt state when rows are removed.

---

## Search Form (URL State)

Search belongs in the URL: shareable, bookmarkable, survives refresh, and back works.

```tsx
'use client'
import { useRouter, useSearchParams, usePathname } from 'next/navigation'
import { useDebouncedCallback } from 'use-debounce'

export function SearchInput() {
  const searchParams = useSearchParams()
  const pathname = usePathname()
  const { replace } = useRouter()

  const onChange = useDebouncedCallback((term: string) => {
    const params = new URLSearchParams(searchParams)
    term ? params.set('q', term) : params.delete('q')
    params.delete('page')                      // reset pagination on a new query
    replace(`${pathname}?${params.toString()}`)
  }, 300)

  return (
    <input
      type="search"
      defaultValue={searchParams.get('q') ?? ''}
      onChange={e => onChange(e.target.value)}
      aria-label="Search products"
    />
  )
}
```

The page reads `searchParams` server-side and re-renders — no client fetch needed.

---

## Accessibility

- Every input has a `<label htmlFor>`. Placeholder text is not a label.
- Errors: `aria-invalid` on the input, `aria-describedby` pointing at the message, `role="alert"` on the message.
- Group related inputs in `<fieldset>` with a `<legend>`.
- Move focus to the first invalid field, or to a summary, after a failed submit.
- Use real `<button type="submit">` — a `<div onClick>` is not keyboard-operable.
- Do not disable submit purely on client validity; screen-reader users lose the path to the error.

See `references/a11y.md`.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| `price` is `NaN` | `FormData` values are strings — use `z.coerce.number()` |
| Form state never updates | Action missing the `prevState` first parameter |
| `useFormStatus` always false | Hook is not inside the `<form>` subtree |
| Uncontrolled-to-controlled warning | `value={undefined}` initially — use `defaultValue` or `?? ''` |
| Rows lose state after removal | Keyed by array index |
| Upload fails over ~1 MB | Server Action body-size limit |
| Form breaks without JS | Moved to `onSubmit`; use `action` for progressive enhancement |
| Search resets to page 5 with no results | Pagination param not cleared on a new query |
