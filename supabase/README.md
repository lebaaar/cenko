# Supabase Edge Functions

Edge functions run on Deno and are deployed to Supabase's global edge network.
Each function lives in its own directory under `supabase/functions/<function-name>/index.ts`.

## Functions

| Function | Trigger | Description |
|---|---|---|
| `delete-my-account` | HTTP POST (authenticated) | Cleans up all user data, then deletes the auth account |

### `delete-my-account`

Performs a safe, ordered deletion to avoid FK violations before calling
`auth.admin.deleteUser()`, which triggers PostgreSQL cascade deletes for
most data. Manual cleanup steps:

1. Block if user owns any **shared** list (other members present) -> return `409`
2. Null out `bought_by_user_id` references (nullable FK, no `ON DELETE`)
3. Delete `shopping_list_item` rows added by the user on lists they don't own (`NOT NULL` FK, no `ON DELETE`)
4. Delete pending `shopping_list_invitation` rows sent or received by the user (no `ON DELETE`)
5. `auth.admin.deleteUser(uid)` — cascades: `public.user` -> `shopping_list` -> `shopping_list_member` / `shopping_list_item` / `receipt` / `receipt_item`

**Responses**

| Status | Body | Meaning |
|---|---|---|
| `200` | `{ "success": true }` | Account deleted |
| `401` | `{ "error": "..." }` | Missing or invalid JWT |
| `409` | `{ "error": "...", "owned_lists": ["List A"] }` | User owns shared list(s) |
| `500` | `{ "error": "..." }` | Unexpected server error |

## Prerequisites
- [Docker](https://docs.docker.com/engine/install/) — required to run the local Supabase stack
- [Supabase CLI](https://supabase.com/docs/guides/local-development/cli/getting-started) ≥ 2.x
- [Deno](https://deno.com) ≥ 2.x — only needed for IDE type-checking; the CLI bundles its own runtime

## Local Development
### 1. Start the local Supabase stack
```bash
supabase start
```

This spins up Postgres, Auth, Storage, Edge Runtime, and Studio locally via Docker.
On first run it pulls images — takes a few minutes.

After startup, `supabase status` prints the local credentials:

```
API URL:          http://127.0.0.1:54321
GraphQL URL:      http://127.0.0.1:54321/graphql/v1
Studio URL:       http://127.0.0.1:54323
...
anon key:         eyJ...
service_role key: eyJ...
```

### 2. Seed the database (optional)
Apply schema and RLS policies to the local DB:

```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f docs/schema.sql
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f docs/rls.sql
```

Or use Supabase Studio at http://127.0.0.1:54323.

### 3. Serve functions locally
```bash
supabase functions serve
```

This hot-reloads all functions under `supabase/functions/`. The edge runtime
automatically injects `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
`SUPABASE_SERVICE_ROLE_KEY` from the local stack — no `.env.local` needed
unless you want to override them.

If you do need a `.env.local`:

```bash
cp supabase/.env.local.example supabase/.env.local
# fill in values from `supabase status`
supabase functions serve --env-file supabase/.env.local
```

### 4. Test a function
```bash
# Get a valid JWT — sign in via the local Supabase Auth and copy the access_token
curl -s -X POST http://127.0.0.1:54321/auth/v1/token?grant_type=password \
  -H "apikey: <anon-key>" \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"yourpassword"}' \
  | jq '.access_token'

# Call the function
curl -X POST http://127.0.0.1:54321/functions/v1/delete-my-account \
  -H "Authorization: Bearer <access-token>" \
  -H "Content-Type: application/json"
```

### 5. Stop the local stack
```bash
supabase stop
```
Data is persisted between runs unless you pass `--no-backup`.


## Deploying to Production
See [CONTRIBUTING.md](CONTRIBUTING.md#supabase-stuff) for Supabase setup instructions.

### Deploy a single function

```bash
supabase functions deploy `function-name`
```

### Deploy all functions
```bash
supabase functions deploy
```

### Set production secrets
Edge function environment variables are managed via the CLI (not `.env` files).
`SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are
**already injected automatically** in production — you don't need to set them.

If a future function needs additional secrets (e.g. an external API key):

```bash
supabase secrets set MY_SECRET=value
supabase secrets list # verify
```

## Adding a New Function
```bash
supabase functions new my-function-name
```

This creates `supabase/functions/my-function-name/index.ts` with a starter template.

- Use `jsr:@supabase/supabase-js@2` imports (Deno JSR — no `npm install` needed)
- Always verify the caller's JWT via `admin.auth.getUser(token)` before doing anything
- Add the function to the table in this README
- Update `CONTRIBUTING.md` if the function introduces new infrastructure requirements