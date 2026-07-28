# Storage

S3-compatible object storage with metadata in Postgres, so access control is RLS on `storage.objects` — the same mechanism as any other table.

---

## Buckets

```sql
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars',   'avatars',   true,  5242880,  array['image/png','image/jpeg','image/webp']),
  ('documents', 'documents', false, 52428800, array['application/pdf']);
```

| Public | Behavior |
|---|---|
| `true` | Anyone with the URL can read. No policy needed for reads; writes still need one. |
| `false` | Every access goes through policies or a signed URL. |

Object paths are frequently guessable (`avatars/<user-id>/photo.jpg`). A public bucket means anyone who can guess a path can read it — fine for avatars, wrong for anything else.

`file_size_limit` and `allowed_mime_types` are enforced server-side. Set them; client-side checks are advisory.

---

## Policies

Storage has no RLS of its own — it is policies on `storage.objects`.

```sql
-- Per-user folder: avatars/<uid>/...
create policy "users manage their own avatar folder"
on storage.objects for all
to authenticated
using (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'avatars'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

-- Public read on a private bucket, scoped
create policy "org members read org documents"
on storage.objects for select
to authenticated
using (
  bucket_id = 'documents'
  and ((storage.foldername(name))[1])::uuid = any (select public.user_org_ids())
);
```

`storage.foldername(name)` splits the object path into an array, so `[1]` is the first folder. Structuring paths as `<bucket>/<tenant-or-user-id>/<file>` makes the policy a single indexed comparison.

Notes:

- `for all` covers select, insert, update, delete — but `upsert` needs both select and update, so `all` is often the practical choice.
- Without any policy, a private bucket rejects every operation. That is the correct default.
- The secret key bypasses all of it.

---

## Upload

```ts
const supabase = createClient()

const { data, error } = await supabase.storage
  .from('avatars')
  .upload(`${userId}/avatar.png`, file, {
    cacheControl: '3600',
    upsert: true,
    contentType: file.type,
  })
```

```ts
// Build the path yourself — never from the uploaded filename
const ext = file.name.split('.').pop()?.toLowerCase()
if (!['png', 'jpg', 'jpeg', 'webp'].includes(ext ?? '')) throw new Error('Unsupported type')
const path = `${userId}/${crypto.randomUUID()}.${ext}`
```

A user-supplied filename can contain `../`, unicode lookalikes, or collide with another user's object. Derive the path from ids you control.

`file.type` comes from the browser and is trivially spoofed. The bucket's `allowed_mime_types` is the real check; sniff magic bytes server-side if the content matters.

### Large files

```ts
// Signed upload URL — client uploads directly, server never proxies the bytes
const { data } = await supabaseAdmin.storage
  .from('documents')
  .createSignedUploadUrl(`${orgId}/${crypto.randomUUID()}.pdf`)

await supabase.storage.from('documents').uploadToSignedUrl(data.path, data.token, file)
```

Resumable uploads use the TUS protocol (works with Uppy) for files large enough that a dropped connection matters. The S3-compatible endpoint supports multipart for existing S3 tooling.

---

## Download and Serving

```ts
// Public bucket — permanent URL, no request
const { data } = supabase.storage.from('avatars').getPublicUrl(`${userId}/avatar.png`)

// Private bucket — time-limited URL
const { data, error } = await supabase.storage
  .from('documents')
  .createSignedUrl(`${orgId}/report.pdf`, 60)          // seconds

// Several at once
const { data } = await supabase.storage
  .from('documents')
  .createSignedUrls(paths, 60)

// Bytes directly (server-side)
const { data: blob } = await supabase.storage.from('documents').download(path)
```

`getPublicUrl` is a pure string builder — it does not check existence or permissions, and on a private bucket it returns a URL that will 400.

Keep signed URL expiry short. It is a bearer token in a query string: it lands in logs, referrer headers, and shared screenshots.

---

## Image Transformations

```ts
const { data } = supabase.storage.from('avatars').getPublicUrl(path, {
  transform: { width: 128, height: 128, resize: 'cover', quality: 75 },
})

const { data } = await supabase.storage.from('documents').createSignedUrl(path, 60, {
  transform: { width: 800, resize: 'contain' },
})
```

Transforms are generated on demand and cached at the CDN. Request the size actually rendered rather than downloading a 4 MB original for a 64 px thumbnail.

With `next/image`, either point at the transform URL directly or set `unoptimized` to avoid paying for two optimization layers.

---

## Managing Objects

```ts
await supabase.storage.from('avatars').list(userId, {
  limit: 100,
  sortBy: { column: 'created_at', order: 'desc' },
})

await supabase.storage.from('avatars').remove([`${userId}/old.png`])
await supabase.storage.from('avatars').move(from, to)
await supabase.storage.from('avatars').copy(from, to)
```

`list()` is filtered by the same select policies, so a user only sees their own objects.

---

## Keeping Postgres and Storage in Sync

Deleting a row does not delete its file. Files whose rows are gone accumulate as unreferenced objects and keep costing money.

```sql
create or replace function public.delete_avatar_object()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  delete from storage.objects
  where bucket_id = 'avatars' and name = old.avatar_path;
  return old;
end;
$$;

create trigger profiles_delete_avatar
after delete on public.profiles
for each row execute function public.delete_avatar_object();
```

Alternatively reconcile on a schedule — see `references/queues-jobs.md`. Either way, decide who owns cleanup rather than discovering the orphans in a storage bill.

Store the object path in your own table so the relationship is queryable, rather than reconstructing paths by convention.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Every upload rejected | Private bucket with no insert policy |
| Files readable by strangers | Public bucket where signed URLs were needed |
| `getPublicUrl` returns a 400 URL | Bucket is private |
| Signed URL expired mid-download | Expiry too short for the file size |
| `upsert: true` fails | Policy grants insert but not select + update |
| One user overwrites another's file | Path derived from the uploaded filename |
| Oversized or wrong-type uploads succeed | `file_size_limit` / `allowed_mime_types` not set on the bucket |
| Storage bill grows without new users | Orphaned objects — no cleanup on row delete |
| Thumbnails slow and expensive | Full-size originals served without `transform` |
| Transform has no effect | Applied to `download()` instead of a URL |
