# Strapi Server Patterns Reference

## Table of Contents
1. Middlewares
2. Policies
3. Lifecycle Hooks
4. Custom Routes
5. Cron Jobs
6. Webhooks

---

## 1. Middlewares

Middlewares run on every matching request before it reaches the controller.
Use for cross-cutting concerns: logging, response shaping, rate-limiting, CORS overrides.

### Global middleware

Register in `config/middlewares.ts`:
```typescript
export default [
  'strapi::errors',
  'strapi::security',
  'strapi::cors',
  { name: 'global::request-logger', config: {} },
];
```

### Middleware implementation

```typescript
// src/middlewares/request-logger.ts
export default () => async (ctx: Koa.Context, next: Koa.Next) => {
  const start = Date.now();
  await next();
  const ms = Date.now() - start;
  strapi.log.info(`${ctx.method} ${ctx.url} — ${ctx.status} (${ms}ms)`);
};
```

### Route-scoped middleware

```typescript
// src/api/article/routes/article.ts
export default {
  routes: [
    {
      method: 'GET',
      path: '/articles',
      handler: 'article.find',
      config: {
        middlewares: ['global::request-logger'],
      },
    },
  ],
};
```

---

## 2. Policies

Policies are authorization checks that run before the controller.
Return `true` to allow, call `ctx.forbidden()` and return `false` to block.

```typescript
// src/policies/is-owner.ts
import type { Core } from '@strapi/strapi';

export default async (
  ctx: Core.PolicyContext,
  config: unknown,
  { strapi }: { strapi: Core.Strapi }
): Promise<boolean> => {
  const { id } = ctx.params;
  const userId = ctx.state.user?.id;

  if (!userId) {
    return ctx.forbidden('Authentication required');
  }

  const entity = await strapi.entityService.findOne('api::article.article', id, {
    populate: ['author'],
  });

  if (entity?.author?.id !== userId) {
    return ctx.forbidden('You do not own this resource');
  }

  return true;
};
```

Attach to a route:
```typescript
{
  method: 'PUT',
  path: '/articles/:id',
  handler: 'article.update',
  config: {
    policies: ['global::is-owner'],
  },
}
```

Pass config to a policy:
```typescript
config: {
  policies: [{ name: 'global::has-role', config: { role: 'editor' } }],
}
```

---

## 3. Lifecycle Hooks

Hooks intercept entity operations to run side effects or mutate data before/after persistence.

```typescript
// src/api/article/content-types/article/lifecycles.ts
export default {
  async beforeCreate(event) {
    const { data } = event.params;
    if (data.title && !data.slug) {
      data.slug = data.title
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/(^-|-$)/g, '');
    }
  },

  async afterCreate(event) {
    const { result } = event;
    await strapi.service('api::notification.notification').notify({
      type: 'new-article',
      articleId: result.id,
    });
  },

  async beforeDelete(event) {
    const { params } = event;
    const article = await strapi.entityService.findOne(
      'api::article.article', params.where.id, { populate: ['cover'] }
    );
    if (article?.cover?.id) {
      await strapi.plugins.upload.services.upload.remove({ id: article.cover.id });
    }
  },
};
```

Available hook pairs: `beforeCreate`/`afterCreate`, `beforeUpdate`/`afterUpdate`,
`beforeDelete`/`afterDelete`, `beforeFindMany`/`afterFindMany`, and more.

---

## 4. Custom Routes

### Adding extra endpoints to an existing content-type

```typescript
// src/api/article/routes/custom-article.ts
export default {
  routes: [
    {
      method: 'GET',
      path: '/articles/featured',
      handler: 'article.findFeatured',
      config: {
        auth: false,        // public endpoint
        policies: [],
        middlewares: [],
      },
    },
    {
      method: 'POST',
      path: '/articles/:id/publish',
      handler: 'article.publish',
      config: {
        policies: ['global::is-owner'],
      },
    },
  ],
};
```

Implement the handler in the controller:
```typescript
// src/api/article/controllers/article.ts
export default factories.createCoreController('api::article.article', ({ strapi }) => ({
  async findFeatured(ctx) {
    const sanitizedQuery = await this.sanitizeQuery(ctx);
    const results = await strapi
      .service('api::article.article')
      .findFeatured(sanitizedQuery);
    return this.transformResponse(results);
  },

  async publish(ctx) {
    const { id } = ctx.params;
    const article = await strapi.entityService.update('api::article.article', id, {
      data: { publishedAt: new Date().toISOString() },
    });
    return this.transformResponse(article);
  },
}));
```

---

## 5. Cron Jobs

Register recurring tasks in `bootstrap()` — never in `register()` (plugins aren't loaded yet).

```typescript
// src/index.ts  (or inside a plugin's bootstrap)
export default {
  async bootstrap({ strapi }) {
    strapi.cron.add({
      // Standard cron expression: min hour day month weekday
      '0 2 * * *': {
        task: async ({ strapi }) => {
          await strapi.service('api::article.article').archiveExpired();
        },
        options: { tz: 'Asia/Bangkok' },
      },
    });
  },
};
```

**Key rules:**
- Cron tasks receive `{ strapi }` — never close over the outer `strapi` reference (stale in tests)
- Keep tasks short; for long-running work, dispatch a job to a queue and return immediately
- Always specify `tz` — Strapi defaults to server timezone which varies across environments
- Test by extracting the task function and calling it directly (don't rely on the scheduler in unit tests)

---

## 6. Webhooks

Strapi fires outgoing webhooks for content lifecycle events (`entry.create`, `entry.update`,
`entry.delete`, `entry.publish`, `entry.unpublish`, `media.create`, etc.).

### Configure via Admin UI
Settings → Webhooks → Add new webhook. Attach to specific events and content types.

### Configure programmatically

```typescript
export default {
  async bootstrap({ strapi }) {
    await strapi.webhookStore.createWebhook({
      name: 'notify-cms-sync',
      url: strapi.config.get('custom.syncUrl'),
      headers: { 'X-Secret': strapi.config.get('custom.syncSecret') },
      events: ['entry.publish', 'entry.unpublish'],
      enabled: true,
    });
  },
};
```

### Custom webhook trigger (manual dispatch)

```typescript
await strapi.webhookRunner.executeWebhook({
  event: 'custom.article-featured',
  data: { articleId: id, featuredAt: new Date() },
});
```

**Key rules:**
- Webhook delivery is fire-and-forget — implement retry logic on the receiver side
- Never put secrets in the webhook URL (use headers instead)
- Validate the incoming payload on the receiver with a shared secret (HMAC or header token)
