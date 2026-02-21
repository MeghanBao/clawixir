# Clawixir Browser Service

Standalone Node.js microservice providing browser automation to the Elixir Gateway via HTTP.
Uses [Playwright](https://playwright.dev/) under the hood.

The Elixir Gateway **never** runs Playwright directly —
it delegates all browser work here. This keeps BEAM processes clean.

## API

| Method | Path | Body | Returns |
|---|---|---|---|
| `GET` | `/health` | — | `{status: "ok"}` |
| `POST` | `/navigate` | `{url, wait_for?}` | `{title, url, text}` |
| `POST` | `/screenshot` | `{url, full_page?}` | `{image_base64}` |
| `POST` | `/scrape` | `{url, selector?}` | `{url, content}` |
| `POST` | `/click` | `{url, selector}` | `{ok, result_url, text}` |
| `POST` | `/fill_and_submit` | `{url, form, submit}` | `{ok, result_url, text}` |

## Setup

```bash
cd browser_service
npm install
npx playwright install chromium
```

## Run

```bash
npm start
# 🎭 Clawixir Browser Service running on http://localhost:4001
# ✅ Playwright browser ready
```

During dev, use `npm run dev` for auto-restart on file changes.

## Configuration

| Env var | Default | Description |
|---|---|---|
| `PORT` | `4001` | HTTP port |

Set `BROWSER_SERVICE_URL=http://localhost:4001` in the main `clawixir/.env`
(the Elixir side reads this to know where to call the service).
