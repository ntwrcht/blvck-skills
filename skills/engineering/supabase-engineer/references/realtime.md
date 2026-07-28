# Realtime

Three features on one WebSocket connection. Choosing between them is mostly a scaling decision.

| Feature | Carries | Use for |
|---|---|---|
| **Broadcast** | Arbitrary messages between clients | Cursors, typing indicators, game state, chat — and database changes at scale |
| **Postgres Changes** | Row-level WAL events | Small-scale change subscriptions, prototypes |
| **Presence** | Synchronized per-client state | Who is online, active viewers |

**Prefer Broadcast over Postgres Changes for anything with real traffic.** Postgres Changes evaluates RLS for every subscribed client on every change, so cost grows with connections × changes. Broadcast from a trigger evaluates once and fans out.

---

## Broadcast

```ts
const supabase = createClient(url, publishableKey)
await supabase.realtime.setAuth()          // required for private channels

const channel = supabase.channel('room:42', { config: { private: true } })

channel
  .on('broadcast', { event: 'cursor' }, ({ payload }) => {
    updateCursor(payload.userId, payload.x, payload.y)
  })
  .subscribe(status => {
    if (status !== 'SUBSCRIBED') return
    channel.send({ type: 'broadcast', event: 'cursor', payload: { userId, x, y } })
  })
```

Send only after `SUBSCRIBED` — messages sent before are dropped.

### Authorization

Private channels are gated by RLS on `realtime.messages`:

```sql
create policy "members can read room broadcasts"
on realtime.messages for select
to authenticated
using (
  exists (
    select 1 from public.room_members
    where room_id = (split_part(realtime.topic(), ':', 2))::uuid
      and user_id = (select auth.uid())
  )
);

create policy "members can write room broadcasts"
on realtime.messages for insert
to authenticated
using ( … same predicate … );
```

`using ( true )` here makes every topic readable by every authenticated user. Since topic names are guessable, that is a leak.

`setAuth()` must be called before subscribing, and again after a token refresh.

---

## Broadcast from Database

The scalable way to stream row changes: a trigger publishes once, Realtime fans out.

```sql
create or replace function public.broadcast_order_changes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.broadcast_changes(
    'orders:' || coalesce(new.org_id, old.org_id)::text,   -- topic
    tg_op,                                                  -- event
    tg_op,                                                  -- operation
    tg_table_name,
    tg_table_schema,
    new,
    old
  );
  return null;
end;
$$;

create trigger orders_broadcast
after insert or update or delete on public.orders
for each row execute function public.broadcast_order_changes();
```

```ts
supabase
  .channel(`orders:${orgId}`, { config: { private: true } })
  .on('broadcast', { event: 'INSERT' }, ({ payload }) => addOrder(payload.record))
  .on('broadcast', { event: 'UPDATE' }, ({ payload }) => updateOrder(payload.record))
  .subscribe()
```

Scoping the topic by tenant (`orders:<org_id>`) rather than using one global topic is what keeps fan-out proportional. Combined with a policy on `realtime.messages`, it is also the authorization boundary.

The trigger runs inside the write transaction, so keep it to the `perform` call.

---

## Postgres Changes

```ts
const channel = supabase
  .channel('posts-feed')
  .on('postgres_changes',
    { event: 'INSERT', schema: 'public', table: 'posts', filter: 'status=eq.published' },
    payload => prepend(payload.new)
  )
  .on('postgres_changes',
    { event: 'UPDATE', schema: 'public', table: 'posts' },
    payload => replace(payload.new)
  )
  .subscribe()
```

Requires the table to be in the publication:

```sql
alter publication supabase_realtime add table public.posts;
alter table public.posts replica identity full;   -- include old values on update/delete
```

Without `replica identity full`, `payload.old` contains only the primary key — so a `DELETE` handler cannot see what was removed, and `UPDATE` cannot diff.

Constraints worth knowing before building on it:

- Filters are limited: one filter per subscription, equality-style operators only.
- RLS is evaluated per subscribed client per change. This is the scaling limit.
- `DELETE` events do not respect RLS — they carry the primary key regardless. Do not treat row existence as private.
- Large payloads are truncated.

---

## Presence

```ts
const channel = supabase.channel('room:42', {
  config: { presence: { key: userId } },
})

channel
  .on('presence', { event: 'sync' }, () => {
    setOnline(Object.values(channel.presenceState()).flat())
  })
  .on('presence', { event: 'join' }, ({ newPresences }) => { … })
  .on('presence', { event: 'leave' }, ({ leftPresences }) => { … })
  .subscribe(async status => {
    if (status !== 'SUBSCRIBED') return
    await channel.track({ userId, name, online_at: new Date().toISOString() })
  })

// on unmount
await channel.untrack()
supabase.removeChannel(channel)
```

Presence state is replicated to every member of the channel on every change, so it is the most expensive of the three per message. Keep tracked payloads tiny — an id and a name, not a profile.

---

## Lifecycle

```tsx
'use client'
useEffect(() => {
  const supabase = createClient()
  const channel = supabase.channel('…').on(…).subscribe()

  return () => { supabase.removeChannel(channel) }   // not optional
}, [])
```

Leaked channels accumulate across navigations until the connection limit is hit, at which point subscriptions fail silently for the whole app.

```ts
supabase.removeChannel(channel)     // one
supabase.removeAllChannels()        // all
```

Handle reconnection explicitly — after a dropped connection the client resubscribes but has missed events in the gap. Refetch on `SUBSCRIBED` if consistency matters:

```ts
.subscribe(status => {
  if (status === 'SUBSCRIBED') refetch()
  if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') scheduleRetry()
})
```

---

## Rate Limits

```ts
createClient(url, key, {
  realtime: { params: { eventsPerSecond: 10 } },
})
```

Throttle high-frequency senders (cursor position, typing) client-side rather than relying on the server limit — dropped messages are invisible.

---

## Choosing

```
Ephemeral, client-to-client (cursors, typing, chat)
  → Broadcast

Database rows, meaningful traffic or many subscribers
  → Broadcast from Database via trigger, topic scoped per tenant

Database rows, prototype or small scale
  → Postgres Changes

Who is here right now
  → Presence
```

---

## Common Failure Modes

| Symptom | Cause |
|---|---|
| No events at all | Table not in `supabase_realtime`, or RLS blocks the row |
| Subscriptions stop working after navigating | Channels not removed on unmount |
| `payload.old` only has the id | `replica identity full` not set |
| Every authenticated user reads every topic | `using ( true )` on `realtime.messages` |
| Private channel receives nothing | `setAuth()` not called before subscribe |
| Messages sent but never delivered | Sent before status was `SUBSCRIBED` |
| Realtime degrades as users grow | Postgres Changes at scale — move to Broadcast from Database |
| Missed events after a network blip | No refetch on resubscribe |
| Writes slowed after adding realtime | Heavy work in the broadcast trigger |
