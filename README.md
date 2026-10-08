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
- Rule-based production-plan generator baseline
- API endpoint ready to be replaced with a real AI provider

## Local requirements
- Node.js 20+
- No external npm packages are required by the current build

## Local start

```bash
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

## Production environment variables

Start from `.env.example` and provide real values in your hosting provider. At minimum:

- NODE_ENV=production
- CINESET_SECRET=<random, 32+ characters — `openssl rand -hex 32`>. The server refuses to start in production without it.
- PORT=<provider-port>
- MAX_UPLOAD_MB=<chosen-limit>
- DATA_DIR / UPLOADS_DIR — where the JSON database and uploads are stored; point these at a persistent disk.

With Docker Compose, put `CINESET_SECRET=...` in a `.env` file next to `compose.yaml`.

On Render, `render.yaml` uses the `starter` plan because persistent disks are not available on the free plan, and stores data on a disk mounted at `/var/data`.

The following integration placeholders are documented for the external services you said you will connect later:

- DATABASE_URL — managed PostgreSQL / Supabase
- STORAGE_* — object storage such as Cloudflare R2 / S3
- SMTP_* — transactional email provider
- APP_BASE_URL — canonical public URL
- AI_* — real AI provider credentials/configuration

Important: the current code still uses local JSON persistence and local uploads. Those are intentionally isolated so the external integrations can replace them without changing the product UI/flow.

## Deployment starter files

- `Dockerfile`
- `compose.yaml`
- `render.yaml`
- `START-CINESET.command`

## Production integration work still required before real customer data

1. Replace `data/db.json` with managed PostgreSQL.
2. Replace `uploads/` with durable object storage.
3. Connect SMTP/transactional email for invitations and notifications.
4. Use a strong secret and HTTPS.
5. Configure backups, monitoring and log retention.
6. Put the app behind your production domain.
7. Replace the baseline AI endpoint with a real provider and server-side secret.
8. Add billing provider before enabling paid plans.

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

## Project layout

```text
CINESET-FINAL-HANDOFF/
├── public/                 # browser UI
├── data/                   # local development database
├── uploads/                # local development files
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
