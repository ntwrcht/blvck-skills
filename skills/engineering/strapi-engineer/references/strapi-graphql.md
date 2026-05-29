# Strapi GraphQL Reference

## Table of Contents
1. Setup & Configuration
2. Extending the Auto-Generated Schema
3. Restricting Fields & Types
4. Key Rules

---

## 1. Setup & Configuration

Install:
```bash
yarn add @strapi/plugin-graphql
```

Enable in `config/plugins.ts`:
```typescript
export default {
  graphql: {
    enabled: true,
    config: {
      endpoint: '/graphql',
      shadowCRUD: true,        // auto-generates types from content types
      playgroundAlways: false, // disable in production
      depthLimit: 7,           // prevent deeply nested query attacks
      amountLimit: 100,        // max records per query
    },
  },
};
```

**Always set `depthLimit` and `amountLimit`** — without them, a single nested query can DDoS the DB.

---

## 2. Extending the Auto-Generated Schema

Add custom queries and mutations via the extension service in `register()`:

```typescript
// src/index.ts
export default {
  register({ strapi }) {
    const extensionService = strapi.plugin('graphql').service('extension');

    extensionService.use(({ nexus }) => ({
      types: [
        nexus.extendType({
          type: 'Query',
          definition(t) {
            t.field('featuredArticles', {
              type: nexus.list('ArticleEntityResponse'),
              resolve: async (_root, _args, ctx) => {
                // Delegate to service — keep resolvers thin like controllers
                return strapi.service('api::article.article').findFeatured();
              },
            });
          },
        }),

        nexus.extendType({
          type: 'Mutation',
          definition(t) {
            t.field('publishArticle', {
              type: 'ArticleEntityResponse',
              args: { id: nexus.nonNull(nexus.idArg()) },
              resolve: async (_root, { id }, ctx) => {
                // Check auth via ctx.state.user — same JWT as REST
                if (!ctx.state.user) {
                  throw new Error('Unauthorized');
                }
                return strapi.service('api::article.article').publish(id);
              },
            });
          },
        }),
      ],
    }));
  },
};
```

---

## 3. Restricting Fields & Types

Limit access to auto-generated queries/mutations using `resolversConfig`:

```typescript
extensionService.use(() => ({
  resolversConfig: {
    // Restrict to admin scope only
    'Query.usersPermissionsUsers': {
      auth: { scope: ['admin::auth.default'] },
    },
    // Make a field public (no auth required)
    'Query.articles': {
      auth: false,
    },
  },
}));
```

Disable specific auto-generated operations:
```typescript
extensionService.use(() => ({
  resolversConfig: {
    'Mutation.createArticle': { auth: { scope: ['admin::auth.default'] } },
    'Mutation.deleteArticle': { auth: { scope: ['admin::auth.default'] } },
  },
}));
```

---

## 4. Key Rules

- **`shadowCRUD: true`** auto-generates CRUD queries/mutations from content types — disable individual ones via `resolversConfig` if not needed
- **Custom resolvers must delegate to services** — keep resolvers as thin as controllers, no business logic inside
- **Authentication context** is available via `ctx.state.user` — identical to the REST layer
- **Enable GraphQL** when clients have diverse, unpredictable data-shape needs (mobile + web + third-party). Stick with REST for a single consumer or performance-critical paths
- Both GraphQL and REST can coexist in the same Strapi project
