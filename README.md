# Content Search

Content Search is a small Rails API that implements the IIIF Content Search v2.0 response format for OCR text.
Given a manifest id and a query, it looks up matches in Solr and returns IIIF annotations ("highlights in context")
that viewers like [Mirador](https://github.com/ProjectMirador/mirador) can display.

## Quick Start (Docker, recommended)

1. Install Docker Desktop.
1. Copy `.env.example` to `.env`.
1. Fill in the values in `.env`. For team values, see 1Password (details below).
1. Run `docker compose up --build --force-recreate`.

The API will be available at `http://localhost:3000`.

Try it:

```bash
curl "http://localhost:3000/search/69429/m00k26971j31?q=test"
```

## Docker Desktop + WSL2 (Windows + Ubuntu)

These steps set up Docker Desktop to build containers in Ubuntu on WSL2.

1. Install Docker Desktop (Windows).
1. Ensure Docker Desktop uses the WSL2 engine: Docker Desktop → Settings → General → check `Use the WSL 2 based engine`.
1. Install WSL + Ubuntu in PowerShell (Admin):

```powershell
wsl --install -d Ubuntu
```

1. Reboot if prompted.
1. Launch Ubuntu from the Start menu or run `wsl`.
1. Update Ubuntu packages:

```bash
sudo apt update
sudo apt upgrade -y
```

1. In Ubuntu, navigate to the repo and build:

```bash
cd /mnt/c/Users/BrittnyLapierre/Documents/github/crkn_iiif_content_search
docker compose build
```

## Quick Start (Local Ruby)

1. Install Ruby 3.4.x (matches `Dockerfile`) and Bundler.
1. Run `bundle install`.
1. Copy `.env.example` to `.env` and fill in values.
1. Run `bin/rails server`.

You can also run `bin/setup` to install dependencies and start the server.

## Secrets and .env (1Password)

`.env` is loaded in development and test via `dotenv-rails`.

Required variables:

- `SOLR_URL` - Solr core URL for content search.
- `IIIF_CANVAS_URL` - Base canvas URL used to build IIIF targets.
- `RAILS_ENV` - Use `development` for local work.
- `SECRET_KEY_BASE` - Needed for production-like use. Generate with `bin/rails secret`.

The canonical `.env` values for this service are stored in 1Password. Search for the CRKN content search item
in the shared vault and copy the values. Do not commit `.env`.

## API Basics

Endpoint:

- `GET /search/*id` with query param `q`.

Parameters:

- `q` (required) - Search text.
- `start` (optional) - Pagination offset.
- `canvas` (optional) - Limit results to a single canvas id.

Notes:

- `id` can be a short id like `69429/m00k26971j31` or a full manifest URL. If you pass a full URL, make sure it is URL-encoded. The service normalizes to the last two path segments.
- The response is an IIIF Content Search v2 `AnnotationPage` with `items`.

Examples:

```bash
curl "http://localhost:3000/search/69429/m00k26971j31?q=test&start=0"
curl "http://localhost:3000/search/69429/m00k26971j31?q=test&canvas=69429/m00k26971j31/canvas/1"
```

Health checks:

- `GET /status` (OkComputer)
- `GET /sidekiq` (Sidekiq UI, if enabled)

## IIIF in 2 Minutes

- A Manifest describes a digital item.
- A Canvas is a single page or view inside a manifest.
- This service returns Annotations that highlight matching OCR text on a canvas.

Useful docs:

- IIIF overview: https://iiif.io/
- IIIF Content Search API v2: https://iiif.io/api/search/2.0/

## Rails in 2 Minutes

Common commands:

- `bin/rails server` - Start the app.
- `bin/rails console` - Interactive Rails console.
- `bin/rails routes` - List routes and controllers.
- `bin/rails log:tail` - Tail development logs.

Debugging:

- Add `binding.break` in Ruby code, then hit the endpoint.
- Rails guide: https://guides.rubyonrails.org/debugging_rails_applications.html

## Project Map

Key files:

- `app/controllers/search_controller.rb` - HTTP entry point.
- `app/models/search.rb` - Solr queries and parameters.
- `app/models/iiif_content_search_response.rb` - Builds the IIIF response.
- `solr/conf/` - Solr schema and config for this service.

## Solr Notes

This repo includes Solr config under `solr/conf/`. Docker compose only runs the Rails app, so Solr must be provided separately. For local work, either:

- Point `SOLR_URL` to an existing Solr core.
- Run your own Solr and use the config files in `solr/conf/`.

To clear the Solr index:

```bash
curl -X POST -H "Content-Type: application/json" "http://username:password@host/solr/content_search/update?commit=true" -d '{ "delete": {"query":"*:*"} }'
```

### Production Solr Setup (CRKN)
For CRKN production, Solr runs in a docker container. The data dir needs to be a volume.
High-level steps:
1. SSH to the Solr container.
2. Create the `blacklight_marc` core and `conf` directory.
3. Copy the default configset.
4. Replace `solrconfig.xml` and `managed-schema.xml` with the versions from this repo.
5. Restart Solr.

## Development

Run container:
```bash
docker compose up
```

Run tests:

```bash
bundle exec rspec
```

Lint:

```bash
bundle exec rubocop
```

## Deployment (CRKN Servers)

We deploy to CRKN internal servers using `./deployImage.sh`, which builds and pushes the image to the internal Docker
registry.

Prereqs:

- Docker Desktop installed and running (Linux containers).
- VPN connected (OpenVPN).
- Registry credentials from 1Password (item: `docker.c7a.ca`).

Deploy:

```bash
./deployImage.sh
```

Notes:
- The script will prompt you to create a ticket in this repo. Create it and copy the image name from that ticket.


## Docs
- IIIF overview: https://iiif.io/
- IIIF Content Search API v2: https://iiif.io/api/search/2.0/
- Debugging Rails: https://guides.rubyonrails.org/debugging_rails_applications.html
