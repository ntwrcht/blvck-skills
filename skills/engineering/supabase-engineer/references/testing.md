# Testing

The thing most worth testing in a Supabase project is the thing most often untested: **RLS policies**. A policy is access control, and untested access control is a guess.

---

## Layers

| Layer | Tool | Covers |
|---|---|---|
| Policies | pgTAP (`supabase test db`) | Who can read and write which rows |
| Database functions | pgTAP | Business rules, constraints, triggers |
| Application code | Vitest / Jest | Query construction, error handling |
| Integration | Vitest against a local Supabase | Client → policy → data, end to end |
| E2E | Playwright | Real auth flows |

---

## pgTAP Policy Tests

```bash
supabase test new posts_rls
supabase test db
```

```sql
-- supabase/tests/posts_rls.test.sql
begin;
select plan(7);

-- Fixtures, inserted as the owner (RLS bypassed here)
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'a@test.dev'),
  ('22222222-2222-2222-2222-222222222222', 'b@test.dev');

insert into public.posts (id, author_id, title, status) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'A draft',  'draft'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'A public', 'published'),
  ('aaaaaaaa-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'B draft',  'draft');

-- The table is protected at all
select ok(
  (select relrowsecurity from pg_class where oid = 'public.posts'::regclass),
  'RLS is enabled on posts'
);

-- Anonymous
set local role anon;
select results_eq(
  $$ select count(*)::int from public.posts $$, ARRAY[1],
  'anon sees only published posts'
);

-- User A
set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select results_eq(
  $$ select count(*)::int from public.posts $$, ARRAY[2],
  'user A sees their draft plus the published post'
);
select is_empty(
  $$ select 1 from public.posts where id = 'aaaaaaaa-0000-0000-0000-000000000003' $$,
  'user A cannot see user B draft'
);
select throws_ok(
  $$ delete from public.posts where id = 'aaaaaaaa-0000-0000-0000-000000000003' $$,
  null, null,
  'user A cannot delete user B post'
);
select throws_ok(
  $$ insert into public.posts (author_id, title) values ('22222222-2222-2222-2222-222222222222','spoof') $$,
  '42501', null,
  'user A cannot post as user B'
);
select throws_ok(
  $$ update public.posts set author_id = '22222222-2222-2222-2222-222222222222'
     where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  '42501', null,
  'user A cannot reassign their post to user B'
);

select * from finish();
rollback;
```

**Test the negative cases.** A suite proving owners can read their own rows has tested the query, not the policy. The assertions that matter are the ones that must fail:

- Anonymous cannot read private rows
- User A cannot read, update, or delete user B's rows
- User A cannot create a row attributed to user B
- User A cannot reassign a row to user B (the missing `with check` bug)

`rollback` at the end means fixtures never persist between tests.

Add a suite for every table with a non-trivial policy, and one global assertion that no table lacks RLS:

```sql
select is_empty(
  $$ select c.relname from pg_class c
     join pg_namespace n on n.oid = c.relnamespace
     where n.nspname = 'public' and c.relkind in ('r','p') and not c.relrowsecurity $$,
  'every public table has RLS enabled'
);
```

---

## Function Tests

```sql
begin;
select plan(3);

set local role authenticated;
set local request.jwt.claims = '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}';

select throws_ok(
  $$ select public.transfer_credits('22222222-2222-2222-2222-222222222222', 999999) $$,
  'P0001', null, 'rejects a transfer above the balance'
);

select lives_ok(
  $$ select public.transfer_credits('22222222-2222-2222-2222-222222222222', 10) $$,
  'allows a valid transfer'
);

select results_eq(
  $$ select credits from public.wallets where user_id = '11111111-1111-1111-1111-111111111111' $$,
  ARRAY[90], 'debits the sender'
);

select * from finish();
rollback;
```

Test that the failure path rolls the whole thing back — that is the reason the logic is in a function rather than in client code.

---

## Integration Tests

Run against a local Supabase rather than mocking the client. Mocks encode assumptions about PostgREST and RLS that are exactly what you want verified.

```ts
// test/setup.ts
import { createClient } from '@supabase/supabase-js'
import type { Database } from '@/lib/database.types'

export const admin = createClient<Database>(
  process.env.SUPABASE_URL!,
  process.env.SUPABASE_SECRET_KEY!,
  { auth: { persistSession: false } }
)

export async function asUser(email: string, password = 'password123') {
  const client = createClient<Database>(
    process.env.SUPABASE_URL!,
    process.env.SUPABASE_PUBLISHABLE_KEY!,
    { auth: { persistSession: false } }
  )
  await client.auth.signInWithPassword({ email, password })
  return client
}
```

```ts
import { beforeEach, describe, expect, it } from 'vitest'
import { admin, asUser } from './setup'

describe('posts', () => {
  beforeEach(async () => {
    await admin.from('posts').delete().neq('id', '00000000-0000-0000-0000-000000000000')
  })

  it('hides other users drafts', async () => {
    const a = await asUser('a@test.dev')
    const b = await asUser('b@test.dev')

    await a.from('posts').insert({ title: 'A draft', status: 'draft' })

    const { data } = await b.from('posts').select()
    expect(data).toEqual([])
  })

  it('rejects posting as another user', async () => {
    const a = await asUser('a@test.dev')
    const { error } = await a.from('posts').insert({
      title: 'spoof',
      author_id: '22222222-2222-2222-2222-222222222222',
    })
    expect(error?.code).toBe('42501')
  })
})
```

Two clients, two real sessions, one assertion about what the second cannot see. This is the shape that catches real policy bugs.

Note the distinction from pgTAP: `error?.code` here is what the client actually receives, so it also verifies the error surfaces usefully.

---

## Seeding

```ts
// test/seed.ts
export async function seedUsers() {
  for (const email of ['a@test.dev', 'b@test.dev']) {
    await admin.auth.admin.createUser({ email, password: 'password123', email_confirm: true })
  }
}
```

Auth users cannot be seeded from `seed.sql` — the rows carry hashed credentials and identity records. Use the admin API.

Fixed UUIDs in `supabase/seed.sql` for reference data make tests deterministic across resets.

---

## Mocking the Client

Only for unit tests of code that merely constructs a query. Anything asserting on data or policies should hit a real local database.

```ts
const mockSupabase = {
  from: vi.fn(() => ({
    select: vi.fn(() => ({
      eq: vi.fn(() => Promise.resolve({ data: [{ id: '1' }], error: null })),
    })),
  })),
}
```

The chained-builder shape makes these brittle and they prove very little. Prefer the real client.

---

## CI

```yaml
name: Database
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: supabase/setup-cli@v1
        with: { version: latest }
      - uses: actions/setup-node@v4
        with: { node-version: 20, cache: npm }

      - run: supabase start
      - run: supabase db reset          # proves migrations build from scratch
      - run: supabase test db           # pgTAP, including policy tests

      - run: npm ci
      - run: npm run test:integration
        env:
          SUPABASE_URL: http://127.0.0.1:54321
          SUPABASE_PUBLISHABLE_KEY: ${{ env.ANON_KEY }}
          SUPABASE_SECRET_KEY: ${{ env.SERVICE_ROLE_KEY }}

      - run: supabase gen types typescript --local > /tmp/types.ts
      - run: diff -q /tmp/types.ts lib/database.types.ts
```

`supabase start` prints local keys; capture them into the environment rather than hardcoding.

---

## What to Cover

Order by cost of being wrong:

1. RLS policies — the negative cases especially.
2. `security definer` functions — that they authorize, and that `execute` is revoked.
3. Constraints and business rules in functions.
4. Auth flows — sign-up, sign-in, password reset, role changes.
5. Error paths and empty states.
6. A regression test for every fixed bug.

Do not test PostgREST itself, or that Postgres honors a `not null`.

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| Policy bug reaches production | Only positive cases tested |
| Tests pass, production leaks | Tests run as the secret key, bypassing RLS |
| Tests interfere with each other | No `rollback`, or shared fixtures |
| Test suite drifts from schema | `db reset` not run in CI |
| Mocked tests pass while queries fail | Mock encodes assumptions instead of behavior |
| Cannot seed auth users from SQL | Use `auth.admin.createUser` |
| `42501` where a row was expected | RLS denial — the test is working |
| CI green, types stale | No `gen types` diff step |
