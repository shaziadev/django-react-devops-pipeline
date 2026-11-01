# Django + React DevOps Pipeline

[![CI](https://github.com/shaziadev/django-react-devops-pipeline/actions/workflows/ci.yml/badge.svg)](https://github.com/shaziadev/django-react-devops-pipeline/actions/workflows/ci.yml)
[![Deploy](https://github.com/shaziadev/django-react-devops-pipeline/actions/workflows/deploy.yml/badge.svg)](https://github.com/shaziadev/django-react-devops-pipeline/actions/workflows/deploy.yml)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![Django](https://img.shields.io/badge/Django-5-092E20?logo=django&logoColor=white)
![React](https://img.shields.io/badge/React-18-61DAFB?logo=react&logoColor=black)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-EC2-FF9900?logo=amazonaws&logoColor=white)

A complete CI/CD setup for a full-stack **Django REST Framework + React** app:

- **Every pull request** runs linting and tests for both the backend and the frontend, and checks that the Docker images build.
- **Every merge to `main`** builds production Docker images and pushes them to GitHub Container Registry. A deploy job then ships them to an **AWS EC2** server over SSH and runs a health check against the live site. The deploy job is switched on per repository with a `DEPLOY_ENABLED` variable; no public server is running for this repo right now, so it is currently skipped.
- **Nginx** sits in front as a reverse proxy with **HTTPS from Let's Encrypt** (auto-renewing).
- **Staging and production** are separate environments with their own servers, secrets and Django settings.

The app itself is intentionally small (a "Status Board" for team notes) so the focus stays on the pipeline.

---

## Architecture

```mermaid
flowchart LR
    Dev[Developer] -->|pull request| CI
    subgraph GitHub Actions
        CI[CI: ruff + pytest<br/>eslint + vitest<br/>docker build]
        CD[Deploy: build & push images]
    end
    Dev -->|merge to main / staging| CD
    CI --> CD
    CD -->|push images| GHCR[(GitHub Container<br/>Registry)]
    CD -->|SSH: deploy.sh| EC2

    subgraph EC2[AWS EC2 server]
        Nginx[Nginx<br/>HTTPS + React build] -->|/api, /admin| Gunicorn[Django + Gunicorn]
        Gunicorn --> PG[(PostgreSQL)]
        Certbot[Certbot<br/>renews certs] -.-> Nginx
    end
    GHCR -->|docker compose pull| EC2
    User[Browser] -->|HTTPS 443| Nginx
```

### Request flow in production

1. The browser connects to `https://your-domain` → **Nginx** (port 443, TLS from Let's Encrypt). Port 80 only serves the certificate challenge and redirects to HTTPS.
2. Static React files are served directly by Nginx (hashed assets cached for a year).
3. `/api/*` and `/admin/*` are proxied to **Gunicorn** running Django. Nginx sends `X-Forwarded-Proto` so Django knows the request was HTTPS.
4. Django talks to **PostgreSQL** in its own container with a persistent volume.

---

## Project structure

```
.
├── backend/                     Django + DRF API
│   ├── config/settings/         base.py, development.py, staging.py, production.py
│   ├── notes/                   Note model, serializer, viewset, /api/health/
│   ├── tests/                   pytest tests
│   ├── Dockerfile               multi-stage: build wheels → slim non-root runtime
│   └── entrypoint.sh            migrate + collectstatic, then start gunicorn
├── frontend/                    React (Vite) app
│   ├── src/                     App, API client, Vitest tests
│   └── Dockerfile               multi-stage: npm build → nginx image
├── nginx/default.conf.template  HTTPS, HTTP→HTTPS redirect, /api proxy
├── docker-compose.yml           local development (hot reload)
├── docker-compose.prod.yml      production: nginx, gunicorn, postgres, certbot
├── scripts/
│   ├── ec2-bootstrap.sh         one-time server setup (Docker, firewall)
│   ├── init-letsencrypt.sh      first HTTPS certificate
│   ├── deploy.sh                pull images + restart (called by CI)
│   └── healthcheck.sh           post-deploy check with retries
└── .github/workflows/
    ├── ci.yml                   lint + test on every PR
    └── deploy.yml               build, push, deploy on main / staging
```

---

## The pipeline

### `ci.yml` — on every pull request

| Job | What it does |
|---|---|
| **Backend** | Installs dependencies, runs `ruff check` + `ruff format --check`, fails on missing migrations, runs `pytest` against a real PostgreSQL service container |
| **Frontend** | `npm ci`, `eslint`, `vitest`, `vite build` |
| **Docker** | Builds both production images (with layer caching) to catch Dockerfile errors before merge |

Tip: in the repository settings, add a **branch protection rule** on `main` that requires the CI checks to pass before merging.

### `deploy.yml` — on push to `main` or `staging`

1. **test** – reuses `ci.yml` (`workflow_call`), so nothing ships without passing CI.
2. **build** – builds the backend and frontend images and pushes them to `ghcr.io/<owner>/<repo>/{backend,frontend}`, tagged with the **commit SHA** and the branch name. The SHA is also baked into the image as `APP_VERSION`, so `/api/health/` shows exactly which commit is live.
3. **deploy** – picks the GitHub Environment from the branch (`main` → `production`, `staging` → `staging`), copies `docker-compose.prod.yml` and `scripts/` to `/opt/app` on the server, then runs `scripts/deploy.sh` over SSH, which pulls the new images and restarts the containers (migrations run automatically in the backend entrypoint).
4. **health check** – calls `https://<domain>/api/health/` with retries. If the database is unreachable the endpoint returns `503` and the workflow fails.

Rolling back is just re-deploying an older SHA: `TAG=<old-sha> bash scripts/deploy.sh` on the server, or re-run an older workflow run.

---

## Environments and settings

`DJANGO_SETTINGS_MODULE` is always `config.settings`; the `DJANGO_ENV` variable picks the file:

| `DJANGO_ENV` | Settings file | Behaviour |
|---|---|---|
| `development` (default) | `development.py` | `DEBUG=True`, SQLite unless `POSTGRES_DB` is set |
| `staging` | `staging.py` | Same as production, with `DEBUG`-level logging |
| `production` | `production.py` | `DEBUG=False`, requires `DJANGO_SECRET_KEY`, secure cookies, HSTS, trusts Nginx's HTTPS header |

All secrets come from environment variables (`/opt/app/.env` on the server). See [`.env.production.example`](.env.production.example).

---

## GitHub setup

Create two **Environments** in *Settings → Environments*: `staging` and `production`. Each gets the same secret/variable names with its own values:

| Name | Type | Example | Purpose |
|---|---|---|---|
| `EC2_HOST` | Secret | `3.110.25.40` | Public IP or DNS of the server |
| `EC2_USER` | Secret | `ubuntu` | SSH user |
| `EC2_SSH_KEY` | Secret | `-----BEGIN OPENSSH PRIVATE KEY-----…` | Private key of a key pair allowed on the server |
| `DOMAIN` | Variable | `app.example.com` | Used for the health check and environment URL |

Finally, add a repository variable `DEPLOY_ENABLED` = `true` (*Settings → Secrets and variables → Actions → Variables*). Until it exists, pushes to `main` still run the tests and build/push the images, but the deploy job is skipped, so the pipeline stays green before a server is set up.

`GITHUB_TOKEN` is provided automatically and is used to push images to GHCR and to log the server in to pull them. You can add *required reviewers* to the `production` environment so production deploys need an approval.

---

## Server setup (AWS EC2)

1. **Launch an instance** – Ubuntu 24.04, `t3.small` or larger. Security group: allow inbound **22** (your IP), **80** and **443** (anywhere). Attach an Elastic IP.
2. **Point DNS** – create an `A` record for your domain → the Elastic IP.
3. **Bootstrap Docker**
   ```bash
   scp scripts/ec2-bootstrap.sh ubuntu@<ip>:~
   ssh ubuntu@<ip> 'bash ec2-bootstrap.sh'
   ```
4. **Create the environment file** – copy `.env.production.example` to `/opt/app/.env` on the server and fill in real values (generate the secret key with `python -c "import secrets; print(secrets.token_urlsafe(50))"`).
5. **Copy the deploy files** – `scp -r docker-compose.prod.yml scripts ubuntu@<ip>:/opt/app/`
6. **Log the server in to GHCR** – `echo <token> | docker login ghcr.io -u <github-user> --password-stdin` (a token with `read:packages`).
7. **Enable HTTPS** – run `init-letsencrypt.sh` as shown below, with `TAG=main` so it uses the images CI already pushed.
8. **Turn on deploys** – add the `DEPLOY_ENABLED=true` repository variable (see [GitHub setup](#github-setup)). From now on every merge to `main` deploys automatically.

## HTTPS with Let's Encrypt

Nginx can't start without a certificate, and Let's Encrypt needs Nginx running to verify the domain. `scripts/init-letsencrypt.sh` solves this:

1. creates a temporary self-signed certificate,
2. starts Nginx,
3. requests the real certificate using the webroot challenge (`/.well-known/acme-challenge/`),
4. reloads Nginx.

```bash
ssh ubuntu@<ip>
cd /opt/app
export TAG=main                               # images built by CI for the main branch
STAGING=1 bash scripts/init-letsencrypt.sh   # optional dry run with Let's Encrypt's test CA
bash scripts/init-letsencrypt.sh
```

After that, the `certbot` container tries to renew twice a day and Nginx reloads every 6 hours to pick up renewed certificates — no cron jobs needed.

---

## Local development

**With Docker (recommended)**

```bash
docker compose up --build
```

- React (hot reload): http://localhost:5173
- API: http://localhost:8000/api/health/ and http://localhost:8000/api/notes/

**Without Docker**

```bash
# Backend
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
python manage.py migrate
python manage.py runserver

# Frontend (new terminal)
cd frontend
npm install
npm run dev
```

## Running checks locally

```bash
# Backend
cd backend
ruff check . && ruff format --check .
pytest

# Frontend
cd frontend
npm run lint
npm test
npm run build
```

## API

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/api/health/` | App + database status, environment and deployed version |
| `GET` | `/api/notes/` | List notes (pinned first, paginated) |
| `POST` | `/api/notes/` | Create a note `{ "title": "...", "body": "...", "pinned": false }` |
| `PATCH` | `/api/notes/<id>/` | Update a note |
| `DELETE` | `/api/notes/<id>/` | Delete a note |

---

## Known limitations

- The notes API is intentionally unauthenticated: it is a small demo payload for the pipeline, not a product. A real app would add authentication (e.g. `IsAuthenticatedOrReadOnly`) before exposing write endpoints.
- There is no public demo server; the deploy job is skipped until `DEPLOY_ENABLED` is set.

## What I'd add next

- Database backups to S3 with a nightly job
- Blue-green or rolling deploys for zero downtime
- Infrastructure as code (Terraform) for the EC2 instance and security group
- Monitoring with Prometheus/Grafana or CloudWatch alarms on the health endpoint

## License

[MIT](LICENSE) © 2026 Shazia Abbas
