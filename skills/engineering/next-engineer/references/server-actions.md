# Server Actions

Async functions marked `'use server'` that run on the server and are callable from the client. Next.js generates a public HTTP endpoint for each one.

**Treat every Server Action as a public API endpoint.** The `'use server'` directive creates a route anyone can POST to, with any payload. Authorization and validation are not optional.

---

## Defining

```ts
// app/actions/products.ts
'use server'

import { revalidatePath } from 'next/cache'
import { redirect } from 'next/navigation'
import { verifySession } from '@/lib/dal'
import { z } from 'zod'

const CreateProduct = z.object({
  name: z.string().min(1).max(200),
  price: z.coerce.number().positive(),
  categoryId: z.string().uuid(),
})

export async function createProduct(formData: FormData) {
  const session = await verifySession()
  if (session.role !== 'admin') throw new Error('Unauthorized')

  const parsed = CreateProduct.safeParse(Object.fromEntries(formData))
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors }

  const product = await db.product.create({ data: parsed.data })
  revalidatePath('/products')
  redirect(`/products/${product.id}`)
}
```

A file-level `'use server'` marks every export as an action. Inline `'use server'` inside a Server Component marks one function:

```tsx
export default function Page() {
  async function deleteItem(formData: FormData) {
    'use server'
    const session = await verifySession()
    await db.item.delete({ where: { id: formData.get('id') as string, userId: session.userId } })
  }
  return <form action={deleteItem}>…</form>
}
```

Note the `userId` in the `where` clause. Scoping the query to the session is what actually enforces ownership — a check like `if (item.userId !== session.userId)` after a fetch works too, but scoping is harder to forget.

---

## Calling from a Form

```tsx
'use client'
import { useActionState } from 'react'
import { createProduct } from '@/app/actions/products'

const initialState = { errors: {}, message: '' }

export function ProductForm() {
  const [state, formAction, pending] = useActionState(createProduct, initialState)

  return (
    <form action={formAction}>
      <input name="name" required />
      {state.errors?.name && <p role="alert">{state.errors.name}</p>}

      <input name="price" type="number" step="0.01" required />
      {state.errors?.price && <p role="alert">{state.errors.price}</p>}

      <button disabled={pending}>{pending ? 'Saving…' : 'Create'}</button>
    </form>
  )
}
```

`useActionState` passes previous state as the **first** argument, so the action signature becomes `(prevState, formData)`:

```ts
export async function createProduct(prevState: State, formData: FormData): Promise<State> { … }
```

`useActionState` is React 19 (Next 15+). In Next 14 it is `useFormState` from `react-dom`.

A `<form action={serverAction}>` works without JavaScript. That progressive enhancement is free — do not throw it away by moving to `onSubmit` + `fetch` unless something genuinely requires it.

---

## `useFormStatus`

```tsx
'use client'
import { useFormStatus } from 'react-dom'

export function SubmitButton({ children }: { children: React.ReactNode }) {
  const { pending } = useFormStatus()
  return <button type="submit" disabled={pending} aria-busy={pending}>{children}</button>
}
```

Must be in a **child** of the `<form>`, not the component rendering the form. It reads the nearest form context above it.

---

## Optimistic Updates

```tsx
'use client'
import { useOptimistic, startTransition } from 'react'
import { addTodo } from '@/app/actions/todos'

export function TodoList({ todos }: { todos: Todo[] }) {
  const [optimisticTodos, addOptimistic] = useOptimistic(
    todos,
    (state, newTodo: Todo) => [...state, newTodo]
  )

  async function handleAdd(formData: FormData) {
    const title = formData.get('title') as string
    startTransition(() => {
      addOptimistic({ id: crypto.randomUUID(), title, done: false, pending: true })
    })
    await addTodo(formData)
  }

  return (
    <>
      <form action={handleAdd}><input name="title" /><button>Add</button></form>
      <ul>
        {optimisticTodos.map(t => (
          <li key={t.id} style={{ opacity: t.pending ? 0.5 : 1 }}>{t.title}</li>
        ))}
      </ul>
    </>
  )
}
```

The optimistic state reverts automatically when the action's revalidation delivers real data.

---

## Calling Outside a Form

Actions are just functions — call them from event handlers or effects, inside a transition:

```tsx
'use client'
import { useTransition } from 'react'
import { toggleLike } from '@/app/actions/posts'

export function LikeButton({ postId, liked }: { postId: string; liked: boolean }) {
  const [pending, startTransition] = useTransition()
  return (
    <button
      disabled={pending}
      onClick={() => startTransition(async () => { await toggleLike(postId) })}
    >
      {liked ? '♥' : '♡'}
    </button>
  )
}
```

Bind extra arguments rather than smuggling them through hidden inputs:

```tsx
const deleteWithId = deleteItem.bind(null, item.id)
return <form action={deleteWithId}><button>Delete</button></form>
```

Bound arguments are encrypted by Next.js, so they cannot be tampered with client-side. A hidden `<input name="id">` can be. Still authorize server-side either way — encryption proves the value came from your render, not that this user may act on it.

---

## Revalidation After Mutation

| API | When |
|---|---|
| `updateTag(tag)` | Cache Components. The acting user must see their own write. |
| `revalidateTag(tag, profile)` | Eventual consistency is fine. Next 16 requires the profile argument. |
| `revalidatePath(path)` | Invalidate by route rather than tag. |
| `refresh()` | Cache Components. Refresh uncached data only. |
| `router.refresh()` | Client-side, refetch the current route's RSC payload. |

```ts
'use server'
import { updateTag } from 'next/cache'

export async function updateProfile(data: FormData) {
  const session = await verifySession()
  await db.user.update({ where: { id: session.userId }, data: parse(data) })
  updateTag(`user-${session.userId}`)   // read-your-writes
}
```

---

## Redirect and Error Semantics

```ts
'use server'
export async function createPost(prevState: State, formData: FormData): Promise<State> {
  const session = await verifySession()
  const parsed = PostSchema.safeParse(Object.fromEntries(formData))
  if (!parsed.success) return { errors: parsed.error.flatten().fieldErrors }

  let post
  try {
    post = await db.post.create({ data: { ...parsed.data, authorId: session.userId } })
  } catch (e) {
    console.error(e)
    return { message: 'Could not create the post. Try again.' }   // generic to the user
  }

  revalidateTag('posts')
  redirect(`/posts/${post.id}`)     // OUTSIDE the try — redirect() throws internally
}
```

Two rules that cause most Action bugs:

1. `redirect()` and `notFound()` throw. Call them after the `try`, never inside one whose `catch` swallows everything.
2. Return expected failures as state; throw only for unexpected ones. A validation failure is data, not an exception.

In production, uncaught errors surface to the client as a generic message with a digest — real details stay server-side. Never return the raw error message to the user.

---

## Security Checklist

- Verify the session **inside** the action. A UI that hides the button proves nothing.
- Check authorization for the specific record, not just "is logged in."
- Validate and coerce every field with a schema. `formData.get()` returns `FormDataEntryValue | null`, never a number.
- Scope queries by the session's user id rather than trusting a client-supplied id.
- Rate-limit actions reachable by unauthenticated users (login, signup, password reset, contact).
- Never return internal error text, stack traces, or raw DB errors.
- Actions defined in a file with `'use server'` are all public — do not put helper functions there.

```ts
// ❌ Every export in a 'use server' file is a public endpoint
'use server'
export async function deleteUser(id: string) { await db.user.delete({ where: { id } }) }
export function buildQuery(f: Filters) { … }   // now also publicly callable

// ✅ Helpers live elsewhere
'use server'
import { buildQuery } from '@/lib/queries'
export async function deleteUser(id: string) {
  const session = await verifySession()
  if (session.role !== 'admin') throw new Error('Unauthorized')
  await db.user.delete({ where: { id } })
}
```

Next.js encrypts action ids per build and dead-code-eliminates unused ones, but neither is an access control. Authorization in the function body is.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| `Functions cannot be passed directly to Client Components` | Passing a non-action function as a prop |
| Redirect does nothing | `redirect()` inside a `try` with a broad `catch` |
| Form state never updates | Action signature missing the `prevState` first parameter |
| `useFormStatus` always `pending: false` | Hook called in the component that renders the form, not a child |
| Action runs but UI is stale | No `revalidateTag`/`revalidatePath`/`updateTag` call |
| `price` is `NaN` | `FormData` values are strings — use `z.coerce.number()` |
| Optimistic update warns about non-transition | `useOptimistic` setter called outside `startTransition` |
| Action callable by anyone | No session check in the body |
