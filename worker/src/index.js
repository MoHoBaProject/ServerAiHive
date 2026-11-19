// AiHive notify Worker
// POST /notify  با هدر  Authorization: Bearer <NOTIFY_SECRET>  و بدنه‌ی JSON: {"text":"..."}
// پیام رو به تلگرام می‌فرسته. بقیه‌ی مسیرها 404.

const MAX_TEXT = 3500;

function json(obj, status = 200) {
  return new Response(JSON.stringify(obj), {
    status,
    headers: { "content-type": "application/json; charset=utf-8" },
  });
}

// مقایسه‌ی ثابت‌زمان دو رشته (از راه هش SHA-256 تا طول‌ها یکسان بشن)
async function safeEqual(a, b) {
  const enc = new TextEncoder();
  const [ha, hb] = await Promise.all([
    crypto.subtle.digest("SHA-256", enc.encode(a)),
    crypto.subtle.digest("SHA-256", enc.encode(b)),
  ]);
  const x = new Uint8Array(ha);
  const y = new Uint8Array(hb);
  let diff = 0;
  for (let i = 0; i < x.length; i++) diff |= x[i] ^ y[i];
  return diff === 0;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    if (url.pathname !== "/notify") return json({ ok: false, error: "not_found" }, 404);
    if (request.method !== "POST") return json({ ok: false, error: "method_not_allowed" }, 405);

    if (!env.NOTIFY_SECRET || !env.TELEGRAM_BOT_TOKEN || !env.TELEGRAM_CHAT_ID) {
      return json({ ok: false, error: "worker_not_configured" }, 500);
    }

    const auth = request.headers.get("authorization") || "";
    const token = auth.startsWith("Bearer ") ? auth.slice(7) : "";
    if (!token || !(await safeEqual(token, env.NOTIFY_SECRET))) {
      return json({ ok: false, error: "unauthorized" }, 401);
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json({ ok: false, error: "bad_json" }, 400);
    }

    let text = typeof body.text === "string" ? body.text.trim() : "";
    if (!text) return json({ ok: false, error: "empty_text" }, 400);
    if (text.length > MAX_TEXT) text = text.slice(0, MAX_TEXT) + "…";

    let tg;
    try {
      tg = await fetch(
        `https://api.telegram.org/bot${env.TELEGRAM_BOT_TOKEN}/sendMessage`,
        {
          method: "POST",
          headers: { "content-type": "application/json" },
          body: JSON.stringify({
            chat_id: env.TELEGRAM_CHAT_ID,
            text,
            disable_web_page_preview: true,
          }),
        }
      );
    } catch {
      return json({ ok: false, error: "telegram_unreachable" }, 502);
    }

    if (!tg.ok) return json({ ok: false, error: "telegram_error", status: tg.status }, 502);
    return json({ ok: true });
  },
};
