# Framework Detection

Two passes. Glob for the manifest file, then grep for the signature that confirms it — a `package.json` alone tells you almost nothing.

## Backend

| Stack | Glob for | Grep to confirm | Route signature |
| :--- | :--- | :--- | :--- |
| Spring Boot | `pom.xml`, `build.gradle*` | `@SpringBootApplication` | `@RestController`, `@GetMapping`, `@PostMapping` |
| FastAPI | `requirements.txt`, `pyproject.toml` | `from fastapi import` | `@app.get`, `@router.post`, `APIRouter(` |
| Django | `manage.py`, `settings.py` | `from django` | `urlpatterns`, `path(`, `re_path(` |
| Flask | `requirements.txt`, `app.py` | `from flask import Flask` | `@app.route` |
| Express | `package.json` | `require('express')`, `from 'express'` | `app.get(`, `router.post(` |
| NestJS | `nest-cli.json` | `@nestjs/common` | `@Controller`, `@Get`, `@Post` |
| Next.js route handlers | `next.config.*` | `from 'next` | `app/**/route.ts`, `pages/api/**` |
| Go net/http or chi | `go.mod` | `net/http`, `go-chi/chi` | `mux.HandleFunc`, `r.Get(` |
| Rails | `Gemfile`, `config/routes.rb` | `rails` in Gemfile | `resources :`, `get '/'` |
| Laravel | `composer.json`, `artisan` | `laravel/framework` | `Route::get`, `Route::post` |

## Data layer

| Stack | Glob for | Grep to confirm | Entity signature |
| :--- | :--- | :--- | :--- |
| JPA / Hibernate | `pom.xml` | `jakarta.persistence`, `javax.persistence` | `@Entity`, `@Table`, `@ManyToOne` |
| SQLAlchemy | `requirements.txt` | `from sqlalchemy` | `class X(Base)`, `__tablename__` |
| Prisma | `schema.prisma` | — | `model X {` |
| TypeORM | `package.json` | `typeorm` | `@Entity()`, `@Column()` |
| Drizzle | `package.json` | `drizzle-orm` | `pgTable(`, `sqliteTable(` |
| Django ORM | `models.py` | `from django.db import models` | `class X(models.Model)` |
| Raw SQL migrations | `migrations/`, `*.sql` | `CREATE TABLE` | `CREATE TABLE`, `ALTER TABLE` |

## Infrastructure

| Stack | Glob for | Grep to confirm | What it yields |
| :--- | :--- | :--- | :--- |
| Terraform | `*.tf` | `resource "`, `provider "` | Deployment topology, managed services |
| Pulumi | `Pulumi.yaml` | `import pulumi`, `@pulumi/` | Same, plus program logic |
| AWS CDK | `cdk.json` | `aws-cdk-lib` | Stacks, constructs, environments |
| Kubernetes | `*.yaml` under `k8s/`, `deploy/`, `charts/` | `kind: Deployment` | Containers, replicas, resource limits |
| Docker Compose | `docker-compose*.yml` | `services:` | Local topology, service dependencies |
| Dockerfile | `Dockerfile*` | `FROM ` | Runtime, base image, exposed ports |
| GitHub Actions | `.github/workflows/*.yml` | `on:`, `jobs:` | Build, test, and deploy pipeline |

## Frontend

| Stack | Glob for | Grep to confirm |
| :--- | :--- | :--- |
| React | `package.json` | `"react":` |
| Next.js | `next.config.*` | `"next":` |
| Angular | `angular.json` | `@angular/core` |
| Vue | `vite.config.*`, `package.json` | `"vue":` |
| Svelte | `svelte.config.js` | `"svelte":` |

## What each layer feeds

| Layer read | Feeds |
| :--- | :--- |
| Entry point, config, env vars | arc42 §1–4, C4 Context |
| Route handlers | OpenAPI spec, C4 Container |
| Entities and migrations | ER diagram, arc42 §5 |
| Service classes | C4 Component, arc42 §5–6 |
| Auth config, middleware | arc42 §8, OpenAPI security schemes |
| Dockerfile, IaC, CI workflows | arc42 §7, deployment diagram, runbooks |

## When detection fails

Do not guess a framework from a filename. If the manifest is present but no signature matches — a bespoke framework, a heavily wrapped one, or a monorepo with several stacks — list what was found and ask which stack to treat as primary.

In a monorepo, detect per package rather than per repo. Document one service at a time; a single architecture doc spanning eight services is a table of contents, not documentation.
