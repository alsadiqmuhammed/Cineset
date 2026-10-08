# CINESET 2.0.0 — Final Application Handoff

CINESET is a server-backed production workspace and client portal for creators, production teams and clients.

## Included in this handoff

### Accounts & access
- Creator and Client roles
- HTTP-only session authentication
- Creator registration
- Client invitation and activation
- Role-aware navigation
- Project-level access isolation
- Team permissions

### Production workspace
- Projects
- Video review
- Timecode feedback
- Resolve / Reopen feedback
- Version tracking
- Approval workflow
- Secure project-scoped file access
- Byte-range video streaming
- Production calendar

### Client & business workflow
- Client directory
- Invitations
- Quotes
- Invoices
- Contracts
- Notifications

### Portfolio
- Portfolio management
- Public creator portfolio page
- Public/private portfolio items

### AI
- Production plans written by Claude (Anthropic), with a built-in template when no API key is set

## Local requirements
- Node.js 20+

## Local start

```bash
npm install
node server.js
```

Open:

http://localhost:3000

Demo Creator:
- Email: creator@cineset.local
- Password: Demo1234

Demo Client:
- Email: client@cineset.local
- Password: Demo1234

Demo accounts are only created and accepted outside production (`NODE_ENV` not `production`). In production, sign up from the login page with "Create an account"; clients join through invite links. Set `CINESET_SEED_DEMO=true` to force demo accounts on.

Locally, with no integrations configured, data is stored in `data/db.json`, uploads in `uploads/`, emails are not sent and the AI assistant uses a built-in template.

## Production environment variables

Start from `.env.example` and provide real values in your hosting provider. Required:

- NODE_ENV=production
- CINESET_SECRET=<random, 32+ characters — `openssl rand -hex 32`>. The server refuses to start in production without it.
- APP_BASE_URL=<your public URL, used for links in emails>

`GET /api/health` shows which integrations are active, and the server prints them on startup:
`Integrations: database=postgres storage=s3 email=smtp ai=claude (claude-opus-5-5)`.

## Integrations

Each integration is switched on by setting its environment variables. Anything left empty falls back to the local version, so you can connect them one at a time.

### Database — PostgreSQL (`DATABASE_URL`)
Any PostgreSQL works: Supabase, Neon, Render PostgreSQL, Railway, AWS RDS.

1. Create a database and copy its connection string (Supabase: Project Settings → Database → Connection string → URI).
2. Set `DATABASE_URL=postgres://user:password@host:5432/dbname?sslmode=require`.
3. Start the app. It creates its table (`cineset_records`) itself. If the database is empty and a `data/db.json` exists, that data is imported automatically.

If the connection fails with a certificate error, set `DATABASE_SSL=no-verify`.

How it works: each record is a row (`collection`, `id`, `data` as JSONB). The app keeps a working copy in memory and writes only changed rows, in a transaction, right after each change. This means **run a single instance** of the app; to scale to several instances, the data layer would need to query PostgreSQL directly.

### File storage — S3-compatible (`STORAGE_*`)
Works with Cloudflare R2, AWS S3, Backblaze B2, MinIO.

Cloudflare R2:
1. R2 → Create bucket (e.g. `cineset-uploads`). Keep it private.
2. R2 → Manage API tokens → Create token with "Object Read & Write" on that bucket.
3. Set `STORAGE_ENDPOINT=https://<account-id>.r2.cloudflarestorage.com`, `STORAGE_BUCKET=cineset-uploads`, `STORAGE_REGION=auto`, `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`.

AWS S3: leave `STORAGE_ENDPOINT` empty and set `STORAGE_REGION` to the bucket's region (e.g. `eu-central-1`).

Files stay private: downloads go through the app, which checks project access and supports video seeking (range requests). Files uploaded earlier to local disk are not moved to the bucket automatically.

### Email — SMTP (`SMTP_*`)
Works with Resend, Postmark, SendGrid, Mailgun, Amazon SES, or any SMTP server.

Set `SMTP_HOST`, `SMTP_PORT` (587 for STARTTLS, 465 for TLS), `SMTP_USER`, `SMTP_PASSWORD`, `SMTP_FROM` (an address on a domain you've verified with the provider) and `APP_BASE_URL`.

Invite links are emailed to the client, and each in-app notification (new project, file, version, quote, invoice, contract, feedback, approvals) is also emailed. Set `EMAIL_NOTIFICATIONS=false` to email only invites. The invite link is still shown to the creator so it can be shared manually.

### AI — Claude (`AI_API_KEY`)
1. Create an API key at https://console.anthropic.com.
2. Set `AI_API_KEY`. Optionally set `AI_MODEL` (default `claude-opus-5-5`) and `AI_REQUESTS_PER_HOUR` (default 20 per user).

The AI assistant then writes a treatment, shot list, lighting, camera notes and a checklist from the brief, in the brief's language. Each plan costs API usage on your Anthropic account. Plans show "Claude" or "basic template" so you can tell which produced them.

## Deployment

- `Dockerfile` / `compose.yaml` — put `CINESET_SECRET` and any integration variables in a `.env` file next to `compose.yaml`, then `docker compose up -d --build`.
- `render.yaml` — Render Blueprint. Render asks for the integration values when you create it. It uses the `starter` plan with a disk at `/var/data` for the local fallbacks; once `DATABASE_URL` and `STORAGE_BUCKET` are set you can remove the disk.
- `START-CINESET.command` — double-click on macOS to run locally.

## Still to do before launch

1. Put the app behind your domain with HTTPS.
2. Configure database backups (most managed PostgreSQL providers include them), monitoring and log retention.
3. Add a billing provider before enabling paid plans.

## Smoke test

```bash
npm run check
```

The source was checked with Node syntax validation, and the core HTTP paths were smoke-tested for:
- health
- creator login
- client login
- project listing
- project isolation
- public portfolio
- calendar
- quotes
- invoices
- contracts
- notifications
- AI production plan

The integrations were tested against PostgreSQL 16, an S3-compatible server, an SMTP server and a mock of the Claude API.

## Project layout

```text
CINESET-FINAL-HANDOFF/
├── public/                 # browser UI
├── data/                   # local development database
├── uploads/                # local development files
├── lib/                    # database, file storage, email and AI integrations
├── server.js               # HTTP API + application server
├── package.json
├── render.yaml
├── compose.yaml
├── Dockerfile
├── .env.example
└── START-CINESET.command
```

## License

Provided for the CINESET project as a handoff build.
