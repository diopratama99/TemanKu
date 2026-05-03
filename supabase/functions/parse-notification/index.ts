// supabase/functions/parse-notification/index.ts
//
// Parses a financial notification text (e.g. from GoPay, DANA, BCA)
// into a structured transaction or account transfer using GPT-4o.
//
// Input  (POST JSON):
//   { notification_text: string, package_name: string }
//
// Output (200 JSON):
//   {
//     action: "transaction" | "transfer" | "ignore",
//     transaction?: { type, amount, category_id, category_name, category_emoji, account, source_or_payee, notes, date, confidence, reasoning },
//     transfer?: { from_account, to_account, amount, note, date },
//     notification_text: string
//   }

// deno-lint-ignore-file no-explicit-any
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const OPENAI_BASE_URL =
  Deno.env.get("OPENAI_BASE_URL") ?? "https://api.openai.com/v1";
const OPENAI_MODEL = Deno.env.get("OPENAI_MODEL") ?? "gpt-4o-mini";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ACCOUNTS = ["Tunai", "Transfer", "E-Wallet"] as const;

interface CategoryRow {
  id: number;
  name: string;
  emoji: string | null;
  type: "income" | "expense";
}

function todayJakarta(): string {
  const now = new Date();
  const jakarta = new Date(now.getTime() + 7 * 60 * 60 * 1000);
  return jakarta.toISOString().slice(0, 10);
}

// Map package name to app label for better AI context
function appLabel(pkg: string): string {
  const map: Record<string, string> = {
    // E-Wallets
    "id.dana": "DANA (E-Wallet)",
    "com.gojek.app": "GoPay (E-Wallet)",
    "com.gojek.gopay": "GoPay (E-Wallet)",
    "com.ovo.fif": "OVO (E-Wallet)",
    "com.shopee.id": "ShopeePay (E-Wallet)",
    "com.telkom.mwallet": "LinkAja (E-Wallet)",
    // Banking — Konvensional
    "com.bca": "BCA (Bank/Transfer)",
    "com.bca.mBCA": "BCA (Bank/Transfer)",
    "com.bca.mybca": "BCA (Bank/Transfer)",
    "id.co.bri.brimobile": "BRI (Bank/Transfer)",
    "id.bmri.livin": "Mandiri Livin (Bank/Transfer)",
    "com.bni.mobilebanking": "BNI (Bank/Transfer)",
    "id.bni.wondr": "Wondr by BNI (Bank/Transfer)",
    "net.id.permatabank.permatamobile": "PermataMobile X (Bank/Transfer)",
    "id.co.cimbniaga.mobile.android": "Octo Mobile CIMB Niaga (Bank/Transfer)",
    // Banking — Digital
    "com.jago.retailApp": "Bank Jago (Bank/Transfer)",
    "com.bke.seabank": "SeaBank (Bank/Transfer)",
    "com.btpn.dc.jeniusapp": "Jenius BTPN (Bank/Transfer)",
    "com.bcadigital.blu": "blu BCA Digital (Bank/Transfer)",
    "co.id.ncb": "Neobank BNC (Bank/Transfer)",
    "id.koala.app": "Allo Bank (Bank/Transfer)",
    "id.co.superbank": "Superbank (Bank/Transfer)",
  };
  return map[pkg] ?? pkg;
}

// Detect account type from package name
function accountFromPackage(pkg: string): string {
  const ewallets = [
    "id.dana",
    "com.gojek.app",
    "com.gojek.gopay",
    "com.ovo.fif",
    "com.shopee.id",
    "com.telkom.mwallet",
  ];
  if (ewallets.includes(pkg)) return "E-Wallet";
  return "Transfer"; // banking apps default to Transfer
}

function buildSystemPrompt(
  categories: CategoryRow[],
  today: string,
  appSource: string,
  sourceAccount: string,
): string {
  const expense = categories
    .filter((c) => c.type === "expense")
    .map((c) => `  - id=${c.id} name="${c.name}"`)
    .join("\n");
  const income = categories
    .filter((c) => c.type === "income")
    .map((c) => `  - id=${c.id} name="${c.name}"`)
    .join("\n");

  return `Kamu adalah parser notifikasi keuangan untuk aplikasi TemanKu (Bahasa Indonesia).
Tugasmu: baca teks notifikasi dari aplikasi keuangan dan tentukan apakah ini:
1. TRANSAKSI (pembayaran/pembelian/pemasukan) → action="transaction"
2. MUTASI ANTAR AKUN (top-up e-wallet, tarik tunai, transfer antar bank) → action="transfer"
3. TIDAK RELEVAN (promo, OTP, info saldo, iklan, reminder) → action="ignore"

SUMBER NOTIFIKASI: ${appSource}
AKUN SUMBER DEFAULT: ${sourceAccount}
TANGGAL HARI INI: ${today}

KATEGORI TERSEDIA:

PENGELUARAN (expense):
${expense || "  (kosong)"}

PEMASUKAN (income):
${income || "  (kosong)"}

AKUN: Tunai, Transfer, E-Wallet
- E-Wallet = GoPay, OVO, DANA, ShopeePay, LinkAja
- Transfer = BCA, BRI, Mandiri, BNI, rekening bank
- Tunai = uang cash

ATURAN KLASIFIKASI:

1. PEMBAYARAN / PEMBELIAN (action="transaction"):
   - "Pembayaran Rp15.000 ke WARUNG via QRIS" → expense
   - "Bayar tagihan listrik Rp300.000" → expense
   - "Kamu menerima Rp500.000 dari Andi" → income
   - Notif berisi: "pembayaran berhasil", "bayar", "pembelian", "pembelanjaan", "transaksi berhasil"

2. MUTASI ANTAR AKUN (action="transfer"):
   - "Top Up GoPay Rp100.000 dari BCA" → from=Transfer, to=E-Wallet
   - "Tarik Tunai Rp500.000 berhasil" → from=Transfer, to=Tunai
   - "Transfer ke rekening BRI berhasil Rp1.000.000" → from=Transfer/E-Wallet, to=Transfer
   - "Top up saldo Rp200.000" → from=Transfer, to=${sourceAccount}
   - Notif berisi: "top up", "tarik tunai", "transfer ke", "isi saldo"

3. ABAIKAN (action="ignore"):
   - Promo, cashback notif, OTP, info saldo tanpa transaksi, iklan, reminder bayar
   - "Saldo GoPay kamu Rp50.000"
   - "Kode OTP: 123456"
   - "Promo! Diskon 50%"
   - "Jangan lupa bayar tagihan"

ATURAN AKUN UNTUK TRANSFER:
- Jika notif dari app E-Wallet dan bilang "top up" → from_account="Transfer", to_account="E-Wallet"
- Jika notif dari app bank dan bilang "tarik tunai" → from_account="Transfer", to_account="Tunai"
- Jika notif dari app bank dan bilang "transfer ke [e-wallet]" → from_account="Transfer", to_account="E-Wallet"
- Jika notif dari app E-Wallet dan bilang "transfer ke bank" → from_account="E-Wallet", to_account="Transfer"

FORMAT OUTPUT (WAJIB — hanya JSON, tanpa backticks/markdown):

Untuk action="transaction":
{
  "action": "transaction",
  "transaction": {
    "type": "expense" | "income",
    "amount": number,
    "category_id": number,
    "category_name": "string",
    "account": "${sourceAccount}",
    "source_or_payee": "nama toko/merchant/orang",
    "notes": "",
    "date": "${today}",
    "confidence": "high" | "medium" | "low",
    "reasoning": "penjelasan singkat"
  }
}

Untuk action="transfer":
{
  "action": "transfer",
  "transfer": {
    "from_account": "Tunai" | "Transfer" | "E-Wallet",
    "to_account": "Tunai" | "Transfer" | "E-Wallet",
    "amount": number,
    "note": "keterangan singkat",
    "date": "${today}"
  }
}

Untuk action="ignore":
{ "action": "ignore", "reasoning": "alasan singkat" }`;
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS_HEADERS, "Content-Type": "application/json" },
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: CORS_HEADERS });
  }
  if (req.method !== "POST") {
    return jsonResponse({ error: "method_not_allowed" }, 405);
  }
  if (!OPENAI_API_KEY) {
    return jsonResponse({ error: "missing_openai_api_key" }, 500);
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) {
    return jsonResponse({ error: "unauthorized" }, 401);
  }

  let payload: { notification_text?: string; package_name?: string };
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const notifText = (payload.notification_text ?? "").trim();
  if (!notifText) {
    return jsonResponse({ error: "empty_notification" }, 400);
  }
  if (notifText.length > 1000) {
    return jsonResponse({ error: "notification_too_long" }, 400);
  }

  const packageName = (payload.package_name ?? "").trim();

  // 1. Fetch user categories
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
    auth: { persistSession: false },
  });

  const { data: catRows, error: catErr } = await supabase
    .from("categories")
    .select("id, name, emoji, type")
    .order("type")
    .order("name");

  if (catErr) {
    return jsonResponse(
      { error: "categories_query_failed", detail: catErr.message },
      500,
    );
  }
  const categories = (catRows ?? []) as CategoryRow[];

  // 2. Call AI
  const today = todayJakarta();
  const appSource = appLabel(packageName);
  const sourceAccount = accountFromPackage(packageName);
  const systemPrompt = buildSystemPrompt(
    categories,
    today,
    appSource,
    sourceAccount,
  );

  const openaiRes = await fetch(`${OPENAI_BASE_URL}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      temperature: 0.05,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: notifText },
      ],
    }),
  });

  if (!openaiRes.ok) {
    const detail = await openaiRes.text();
    return jsonResponse(
      { error: "openai_call_failed", status: openaiRes.status, detail },
      502,
    );
  }

  const openaiBody: any = await openaiRes.json();
  const raw = openaiBody?.choices?.[0]?.message?.content;
  if (typeof raw !== "string") {
    return jsonResponse({ error: "empty_llm_response" }, 502);
  }

  let parsed: any;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return jsonResponse({ error: "invalid_llm_json", raw }, 502);
  }

  // 3. Validate and normalize
  const action = parsed.action;

  if (action === "ignore") {
    return jsonResponse({
      action: "ignore",
      reasoning: parsed.reasoning ?? "",
      notification_text: notifText,
    });
  }

  if (action === "transaction" && parsed.transaction) {
    const item = parsed.transaction;
    const type =
      item.type === "income" || item.type === "expense"
        ? item.type
        : "expense";
    const amount = Math.max(0, Math.round(Number(item.amount) || 0));

    let category: CategoryRow | undefined;
    if (item.category_id != null) {
      category = categories.find(
        (c) => c.id === Number(item.category_id) && c.type === type,
      );
    }
    if (!category && typeof item.category_name === "string") {
      const target = item.category_name.toLowerCase().trim();
      category = categories.find(
        (c) => c.type === type && c.name.toLowerCase() === target,
      );
    }
    if (!category) {
      category = categories.find((c) => c.type === type) ?? categories[0];
    }

    const account = ACCOUNTS.find((a) => a === item.account) ?? sourceAccount;
    const date = /^\d{4}-\d{2}-\d{2}$/.test(item.date ?? "")
      ? item.date
      : today;

    return jsonResponse({
      action: "transaction",
      transaction: {
        type,
        amount,
        category_id: category.id,
        category_name: category.name,
        category_emoji: category.emoji,
        account,
        source_or_payee:
          typeof item.source_or_payee === "string"
            ? item.source_or_payee.trim()
            : "",
        notes: typeof item.notes === "string" ? item.notes.trim() : "",
        date,
        confidence:
          item.confidence === "high" ||
          item.confidence === "medium" ||
          item.confidence === "low"
            ? item.confidence
            : "medium",
        reasoning:
          typeof item.reasoning === "string" ? item.reasoning.trim() : "",
      },
      notification_text: notifText,
    });
  }

  if (action === "transfer" && parsed.transfer) {
    const t = parsed.transfer;
    const fromAccount =
      ACCOUNTS.find((a) => a === t.from_account) ?? "Transfer";
    const toAccount =
      ACCOUNTS.find((a) => a === t.to_account) ?? sourceAccount;
    const amount = Math.max(0, Math.round(Number(t.amount) || 0));
    const date = /^\d{4}-\d{2}-\d{2}$/.test(t.date ?? "") ? t.date : today;

    return jsonResponse({
      action: "transfer",
      transfer: {
        from_account: fromAccount,
        to_account: toAccount,
        amount,
        note: typeof t.note === "string" ? t.note.trim() : "",
        date,
      },
      notification_text: notifText,
    });
  }

  // Fallback: couldn't classify
  return jsonResponse({
    action: "ignore",
    reasoning: "Could not classify notification",
    notification_text: notifText,
  });
});
