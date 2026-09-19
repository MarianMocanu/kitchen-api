# kitchen-api

Express + TypeScript API for FoodLens: upload a meal photo, identify foods, compute nutrition from Postgres, return an editable meal.

The AI (later: Ollama) only names foods and estimates grams. **This API owns calories and macros.** Clients can always PATCH portion size or food identity; we recalculate from the `Food` table.

Product plan: [`../PLAN.md`](../PLAN.md).

## Status

Empty repo. Next step is a Dockerized hello world: Dockerfile, Compose (API + Postgres), and `GET /health`.

Do not add Ollama, Redis, or auth until meals work with a mock analyzer.

## Stack

| Piece | Choice |
|-------|--------|
| Runtime | Node.js + Express + TypeScript |
| Validation | Zod |
| Database | PostgreSQL |
| Tests | Vitest + Supertest |
| Dev environment | Docker Compose |

## Why Docker first

You will learn Docker by using it as the normal way to run this service, not as a later “deployment” topic.

Start with the smallest useful Compose file:

- `api` — Node app
- `postgres` — database + named volume

That is enough to learn images, containers, networks, env files, and persistent volumes. Image storage, Ollama, and workers are later Compose services.

### Concepts you will hit immediately

| Concept | How it shows up here |
|---------|----------------------|
| Image vs container | `Dockerfile` builds the image; Compose runs a container from it |
| Compose service name | The API connects to `postgres:5432`, not `localhost:5432` |
| `localhost` | Inside the API container, `localhost` is the API itself |
| Bind mount | Your `src/` on the Mac is mounted into the container so edits reload |
| Named volume | Postgres data survives `docker compose down` |
| Env file | `.env` for secrets; `.env.example` is committed |

## Prerequisites

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Compose V2 included)
- Optional on the host: Node.js 22+ for the editor / running a single unit test outside Docker

You do not need a local Postgres install.

## Planned layout

```
kitchen-api/
  Dockerfile
  docker-compose.yml
  .env.example
  package.json
  src/
    index.ts              # HTTP entry
    domain/               # NutritionCalculator, Zod schemas
    analyzer/             # FoodAnalyzer (mock, then Ollama)
    db/                   # Postgres pool, migrations, repositories
  tests/
```

## How we will run it (after scaffold)

```bash
cp .env.example .env
docker compose up --build
```

Then:

| Action | Command |
|--------|---------|
| Health check | `curl http://localhost:3000/health` |
| Tests in the container | `docker compose exec api npm test` |
| Stop | `docker compose down` |
| Stop and wipe DB volume | `docker compose down -v` |

Host port `3000` maps to the API. Host port `5432` can map to Postgres for GUI tools; the API still uses the internal hostname `postgres`.

## API (MVP)

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Process is up (Compose / later proxy) |
| POST | `/meals/analyze` | Multipart image upload → analyze → persist |
| GET | `/meals` | List meals |
| GET | `/meals/:id` | One meal |
| PATCH | `/meals/:id` | Correct foods or grams; recalculate macros |
| DELETE | `/meals/:id` | Delete meal |

`POST /meals/analyze` pipeline:

1. Validate the upload.
2. `FoodAnalyzer` returns `{ foods: [{ name, estimatedWeightGrams }], confidence }` (mock first).
3. Zod-parse that payload. Invalid JSON → 4xx, never a crash.
4. Match names to `Food` rows; compute macros from per-100g values × grams.
5. Persist `Meal`, `MealItem`s, and raw analysis metadata.
6. Return the meal. If the analyzer is down → 503.

Auth is out of scope until this slice works.

## Data

```
Meal
  MealItem[]          # food + grams + computed kcal/macros
  AnalysisMetadata    # raw AI JSON + confidence
MealItem → Food       # calories/protein/carbs/fat per 100g
```

## Tests

Write tests before the production code for that slice.

| Test | Needs Docker? |
|------|----------------|
| Nutrition math for 200g of a known food | No |
| Zod rejects negative grams / bad AI JSON | No |
| Analyzer mock / 503 when AI is down | No |
| Insert meal, read it back from Postgres | Yes (Compose) |
| `POST /meals/analyze` with a fixture image | Yes |

Always mock `FoodAnalyzer` in API tests. Do not call a real model from Vitest.

## Roadmap (this repo only)

1. Dockerfile + Compose + `/health`
2. Nutrition domain + Zod (TDD)
3. Postgres schema + repository tests
4. Analyze endpoint with mock AI + uploads volume
5. GET / PATCH / DELETE
6. Ollama as a third Compose service
7. Redis + worker after sync analysis works
