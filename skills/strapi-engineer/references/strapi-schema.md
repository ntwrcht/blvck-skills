# Strapi Schema & Relations Reference

## Table of Contents
1. Relation Types
2. Custom Plugins
3. Extensions (Overriding Core)
4. Document Service API (Strapi v5)

---

## 1. Relation Types

Choose the right cardinality for schema.json relations:

| Type | When to use | Example |
|---|---|---|
| `oneToOne` | Entity owns exactly one related record | User → Profile |
| `manyToOne` | Many children point to one parent | Article → Category |
| `oneToMany` | Parent lists its children (inverse of manyToOne) | Category → Articles |
| `manyToMany` | Peers reference each other bidirectionally | Articles ↔ Tags |
| `morphTo` (polymorphic) | Target type varies per record | Comment on Article OR Video |

**Decision rules:**
- Prefer `manyToOne` + `oneToMany` pair over `manyToMany` unless the relation is truly symmetric — join table queries are harder to optimize and filter
- Polymorphic (`morphTo`) relations cannot be filtered in `entityService` / Document Service with standard filters; use `db.query` for complex polymorphic queries
- Bidirectional relations (`oneToMany` ↔ `manyToOne`) must be declared on both sides of the schema — Strapi won't auto-create the inverse

---

## 2. Custom Plugins

Plugins are the recommended way to bundle reusable, self-contained features in Strapi.

Generate a plugin scaffold:
```bash
yarn strapi generate plugin my-plugin
```

Plugin structure:
```
src/plugins/my-plugin/
├── server/
│   ├── index.ts           # Plugin registration
│   ├── content-types/     # Plugin-owned schemas
│   ├── controllers/
│   ├── routes/
│   └── services/
└── admin/
    └── src/               # Optional admin panel extensions
```

Register the plugin in `src/plugins/my-plugin/server/index.ts`:
```typescript
export default {
  register({ strapi }) {
    strapi.customFields.register({
      name: 'color',
      plugin: 'my-plugin',
      type: 'string',
    });
  },
  bootstrap({ strapi }) {
    // Runs after all plugins are loaded — good for seeding data or registering hooks
  },
  controllers: { myController },
  services:    { myService },
  routes:      { 'my-router': { type: 'content-api', routes: myRoutes } },
};
```

Enable in `config/plugins.ts`:
```typescript
export default {
  'my-plugin': { enabled: true, resolve: './src/plugins/my-plugin' },
};
```

---

## 3. Extensions (Overriding Core)

To override a plugin's behavior (e.g., `users-permissions`) without forking it, use `src/extensions/`.

```
src/extensions/
└── users-permissions/
    └── strapi-server.ts   # Merged with the plugin's server config
```

```typescript
// src/extensions/users-permissions/strapi-server.ts
export default (plugin) => {
  const originalRegister = plugin.controllers.auth.register;

  plugin.controllers.auth.register = async (ctx) => {
    // Add custom validation before the original handler
    const { email } = ctx.request.body;
    if (!email.endsWith('@mycompany.com')) {
      return ctx.badRequest('Only company email addresses are allowed');
    }
    return originalRegister(ctx);
  };

  return plugin;
};
```

---

## 4. Document Service API (Strapi v5)

Strapi v5 introduces the **Document Service** to replace `entityService` for content-types.
It is locale- and draft/publish-aware by default.

**Always use `strapi.documents()` for new v5 code. Never mix with `entityService` in the same file.**

```typescript
// Find (with optional locale + status)
const articles = await strapi.documents('api::article.article').findMany({
  filters: { category: 'tech' },
  locale: 'en',
  status: 'published',
  populate: ['author', 'cover'],
  sort: { publishedAt: 'desc' },
  limit: 10,
});

// Find one by documentId
const article = await strapi.documents('api::article.article').findOne({
  documentId: 'abc123xyz',
  locale: 'en',
  status: 'published',
});

// Create
const created = await strapi.documents('api::article.article').create({
  data: { title: 'Hello World', content: '...' },
  locale: 'en',
});

// Update
await strapi.documents('api::article.article').update({
  documentId: created.documentId,
  data: { title: 'Updated Title' },
  locale: 'en',
});

// Publish
await strapi.documents('api::article.article').publish({
  documentId: created.documentId,
  locale: 'en',
});

// Delete
await strapi.documents('api::article.article').delete({
  documentId: created.documentId,
  locale: 'en',
});
```

`entityService` still works in v5 as a compatibility shim — use only when maintaining v4 compatibility.
