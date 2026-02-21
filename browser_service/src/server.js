/**
 * Clawixir Browser Service
 *
 * A lightweight HTTP microservice that exposes Playwright browser automation
 * to the Elixir Gateway via JSON API calls.
 *
 * The Elixir Gateway NEVER runs a browser itself — it delegates all browser
 * tasks here. This keeps BEAM processes clean and lets Node/Playwright do
 * what it does best.
 *
 * API:
 *   POST /navigate      { url }                → { title, url, text }
 *   POST /screenshot    { url }                → { image_base64 }
 *   POST /click         { url, selector }      → { ok, text }
 *   POST /scrape        { url, selector? }     → { content }
 *   POST /fill_and_submit { url, form: [{selector, value}], submit }  → { ok, result_url }
 *   GET  /health                               → { status: "ok" }
 */

import express from "express";
import { chromium } from "playwright";

const app = express();
app.use(express.json());

const PORT = process.env.PORT || 4001;

// ─── Browser pool (single shared browser instance) ──────────────────────────

let browser = null;

async function getBrowser() {
  if (!browser || !browser.isConnected()) {
    browser = await chromium.launch({
      headless: true,
      args: ["--no-sandbox", "--disable-setuid-sandbox"],
    });
  }
  return browser;
}

async function withPage(fn) {
  const b = await getBrowser();
  const ctx = await b.newContext({
    userAgent:
      "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120 Safari/537.36",
  });
  const page = await ctx.newPage();
  try {
    return await fn(page);
  } finally {
    await ctx.close();
  }
}

// ─── Routes ─────────────────────────────────────────────────────────────────

// Health check — called by Elixir on startup and periodically
app.get("/health", (_req, res) => {
  res.json({ status: "ok", service: "claw-browser-service" });
});

/**
 * Navigate to a URL and return page title + visible text.
 * Body: { url: string, wait_for?: "load" | "networkidle" }
 */
app.post("/navigate", async (req, res) => {
  const { url, wait_for = "load" } = req.body;
  if (!url) return res.status(400).json({ error: "url is required" });

  try {
    const result = await withPage(async (page) => {
      await page.goto(url, { waitUntil: wait_for, timeout: 30_000 });
      const title = await page.title();
      const text = await page.evaluate(() => document.body.innerText);
      return { title, url: page.url(), text: text.slice(0, 8000) };
    });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * Take a screenshot of a URL.
 * Body: { url: string, full_page?: boolean }
 * Returns: { image_base64: string }
 */
app.post("/screenshot", async (req, res) => {
  const { url, full_page = false } = req.body;
  if (!url) return res.status(400).json({ error: "url is required" });

  try {
    const result = await withPage(async (page) => {
      await page.goto(url, { waitUntil: "load", timeout: 30_000 });
      const buffer = await page.screenshot({ fullPage: full_page, type: "png" });
      return { image_base64: buffer.toString("base64") };
    });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * Click an element on a page.
 * Body: { url: string, selector: string }
 */
app.post("/click", async (req, res) => {
  const { url, selector } = req.body;
  if (!url || !selector)
    return res.status(400).json({ error: "url and selector are required" });

  try {
    const result = await withPage(async (page) => {
      await page.goto(url, { waitUntil: "load", timeout: 30_000 });
      await page.click(selector, { timeout: 10_000 });
      await page.waitForLoadState("load");
      const text = await page.evaluate(() => document.body.innerText);
      return { ok: true, result_url: page.url(), text: text.slice(0, 4000) };
    });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * Scrape content from a URL, optionally filtered by a CSS selector.
 * Body: { url: string, selector?: string }
 */
app.post("/scrape", async (req, res) => {
  const { url, selector } = req.body;
  if (!url) return res.status(400).json({ error: "url is required" });

  try {
    const result = await withPage(async (page) => {
      await page.goto(url, { waitUntil: "networkidle", timeout: 30_000 });
      let content;
      if (selector) {
        content = await page.$eval(selector, (el) => el.innerText);
      } else {
        content = await page.evaluate(() => document.body.innerText);
      }
      return { url: page.url(), content: content.slice(0, 10_000) };
    });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

/**
 * Fill form fields and submit.
 * Body: {
 *   url: string,
 *   form: [{ selector: string, value: string }],
 *   submit: string   (CSS selector for submit button)
 * }
 */
app.post("/fill_and_submit", async (req, res) => {
  const { url, form = [], submit } = req.body;
  if (!url) return res.status(400).json({ error: "url is required" });

  try {
    const result = await withPage(async (page) => {
      await page.goto(url, { waitUntil: "load", timeout: 30_000 });

      for (const field of form) {
        await page.fill(field.selector, field.value, { timeout: 5_000 });
      }

      if (submit) {
        await Promise.all([
          page.waitForNavigation({ waitUntil: "load", timeout: 30_000 }),
          page.click(submit),
        ]);
      }

      const text = await page.evaluate(() => document.body.innerText);
      return { ok: true, result_url: page.url(), text: text.slice(0, 4000) };
    });
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ─── Start ───────────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`🎭 Clawixir Browser Service running on http://localhost:${PORT}`);
  // Pre-warm browser
  getBrowser().then(() => console.log("✅ Playwright browser ready"));
});

// Graceful shutdown
process.on("SIGTERM", async () => {
  if (browser) await browser.close();
  process.exit(0);
});
