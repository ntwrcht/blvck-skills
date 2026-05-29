# Strapi Testing Reference

## Table of Contents
1. [Test Setup](#setup)
2. [Service Unit Tests](#service-tests)
3. [Controller Integration Tests](#controller-tests)
4. [Lifecycle Hook Tests](#lifecycle-tests)
5. [Policy Tests](#policy-tests)

---

## 1. Test Setup

### Install dependencies
```bash
yarn add --dev jest @types/jest supertest @types/supertest
```

### Strapi test instance helper
```typescript
// tests/helpers/strapi.ts
import Strapi from '@strapi/strapi';

let instance: Strapi.Strapi;

export async function setupStrapi() {
  if (!instance) {
    instance = await Strapi({ distDir: './dist' }).load();
    await instance.server.mount();
  }
  return instance;
}

export async function teardownStrapi() {
  await instance?.server.httpServer.close();
  await instance?.db?.connection.destroy();
}
```

---

## 2. Service Unit Tests

```typescript
// Mock strapi factory
function createMockStrapi(overrides = {}) {
  return {
    entityService: {
      findMany: jest.fn(),
      findOne: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
    },
    db: { query: jest.fn() },
    log: { warn: jest.fn(), error: jest.fn() },
    ...overrides,
  };
}

describe('ArticleService', () => {
  let mockStrapi: ReturnType<typeof createMockStrapi>;

  beforeEach(() => {
    mockStrapi = createMockStrapi();
  });

  describe('findPublished', () => {
    it('filters to published articles only', async () => {
      mockStrapi.entityService.findMany.mockResolvedValue(mockArticles);
      
      const service = createArticleService({ strapi: mockStrapi as any });
      await service.findPublished();
      
      expect(mockStrapi.entityService.findMany).toHaveBeenCalledWith(
        'api::article.article',
        expect.objectContaining({
          filters: expect.objectContaining({ publishedAt: { $notNull: true } })
        })
      );
    });
  });
});
```

---

## 3. Controller Integration Tests (Supertest)

```typescript
import request from 'supertest';

describe('Article API', () => {
  let strapi: Strapi.Strapi;
  let jwt: string;

  beforeAll(async () => {
    strapi = await setupStrapi();
    // Login and get JWT
    const res = await request(strapi.server.httpServer)
      .post('/api/auth/local')
      .send({ identifier: 'test@example.com', password: 'Test1234!' });
    jwt = res.body.jwt;
  });

  afterAll(teardownStrapi);

  it('GET /api/articles returns paginated list', async () => {
    const res = await request(strapi.server.httpServer)
      .get('/api/articles?pagination[pageSize]=5')
      .expect(200);

    expect(res.body.data).toBeInstanceOf(Array);
    expect(res.body.meta.pagination).toMatchObject({
      page: 1, pageSize: 5
    });
  });

  it('POST /api/articles requires authentication', async () => {
    await request(strapi.server.httpServer)
      .post('/api/articles')
      .send({ data: { title: 'Test' } })
      .expect(403);
  });

  it('POST /api/articles creates article when authenticated', async () => {
    const res = await request(strapi.server.httpServer)
      .post('/api/articles')
      .set('Authorization', `Bearer ${jwt}`)
      .send({ data: { title: 'New Article', content: 'Body text' } })
      .expect(200);

    expect(res.body.data.attributes.title).toBe('New Article');
  });
});
```

---

## 4. Lifecycle Hook Tests

```typescript
describe('Article lifecycle hooks', () => {
  it('sets slug from title on beforeCreate', async () => {
    const mockEvent = {
      params: { data: { title: 'Hello World Article' } }
    };
    
    await articleLifecycles.beforeCreate(mockEvent as any);
    
    expect(mockEvent.params.data.slug).toBe('hello-world-article');
  });
});
```

---

## 5. Policy Tests

```typescript
describe('isOwner policy', () => {
  it('allows owner to access their resource', async () => {
    const ctx = createMockContext({
      state: { user: { id: 1 } },
      params: { id: '10' }
    });
    mockStrapi.entityService.findOne.mockResolvedValue({ owner: { id: 1 } });

    const result = await isOwnerPolicy(ctx as any, {} as any, { strapi: mockStrapi as any });
    expect(result).toBe(true);
  });

  it('blocks non-owner from accessing resource', async () => {
    const ctx = createMockContext({ state: { user: { id: 2 } } });
    mockStrapi.entityService.findOne.mockResolvedValue({ owner: { id: 1 } });

    const result = await isOwnerPolicy(ctx as any, {} as any, { strapi: mockStrapi as any });
    expect(ctx.forbidden).toHaveBeenCalled();
    expect(result).toBe(false);
  });
});
```

---

## Test Data Management

- Use **factories** (e.g., `@factory-js/factory`) to generate mock data
- Clean database between test suites with `strapi.db.query('api::x.x').deleteMany({})`
- Use a **dedicated test database** (separate SQLite or test Postgres DB) — never run against production
