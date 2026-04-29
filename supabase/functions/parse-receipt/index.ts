// supabase/functions/parse-receipt/index.ts
//
// Reads a photo of a paper/digital receipt and converts it into one or more
// structured transaction drafts using GPT-4o vision.
//
// A single receipt usually maps to ONE transaction (the grand total). When a
// receipt clearly bundles separate transactions — e.g. a transfer slip listing
// multiple recipients — we still cap the output at MAX_TRANSACTIONS to keep
// the preview UI bounded.
//
// Input  (POST JSON):
//   {
//     image_base64: string,   // raw base64, no data: prefix
//     mime: "image/jpeg" | "image/png" | "image/webp"
//   }
//
// Output (200 JSON): same shape as `parse-transaction` so the Flutter client
// can reuse the `ParsedTransaction` model verbatim.
//
//   {
//     transactions: [ { type, amount, category_id, ... } ],
//     transcript: string  // short natural-language summary of the receipt
//   }
//
// Auth: requires the caller's JWT (forwarded via Authorization header so
// Supabase RLS can scope category lookups to the calling user).

// deno-lint-ignore-file no-explicit-any
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const OPENAI_API_KEY = Deno.env.get("OPENAI_API_KEY");
const OPENAI_BASE_URL =
  Deno.env.get("OPENAI_BASE_URL") ?? "https://api.openai.com/v1";
// Vision needs the full model; mini is too unreliable for thermal receipts.
const OPENAI_VISION_MODEL =
  Deno.env.get("OPENAI_VISION_MODEL") ?? "gpt-4o";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const ACCOUNTS = ["Tunai", "Transfer", "E-Wallet"] as const;
const ALLOWED_MIMES = new Set([
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
]);
const MAX_TRANSACTIONS = 3;
// Hard cap on the *base64* payload size. ~6.5 MB base64 ≈ ~5 MB raw image.
// Anything bigger usually means the client forgot to compress.
const MAX_BASE64_BYTES = 6_500_000;

interface CategoryRow {
  id: number;
  name: string;
  emoji: string | null;
  type: "income" | "expense";
}

function todayJakarta(): string {
  // Asia/Jakarta is UTC+7. Anchor "today" to the user's local civil date.
  const now = new Date();
  const jakarta = new Date(now.getTime() + 7 * 60 * 60 * 1000);
  return jakarta.toISOString().slice(0, 10);
}

function buildSystemPrompt(
  categories: CategoryRow[],
  today: string,
): string {
  const expense = categories
    .filter((c) => c.type === "expense")
    .map((c) => `  - id=${c.id} name="${c.name}"`)
    .join("\n");
  const income = categories
    .filter((c) => c.type === "income")
    .map((c) => `  - id=${c.id} name="${c.name}"`)
    .join("\n");

  return `Kamu adalah parser STRUK / RECEIPT untuk aplikasi TemanKu (Bahasa Indonesia).
Tugasmu: lihat foto struk yang dikirim user, lalu ubah jadi JSON transaksi terstruktur.

Satu struk biasanya = 1 transaksi (total akhir). Jika struk JELAS berisi beberapa
transaksi terpisah (mis. bukti transfer ke beberapa orang, atau struk multi-bill),
boleh keluarkan sampai ${MAX_TRANSACTIONS} transaksi.

KONTEKS TANGGAL HARI INI: ${today} (Asia/Jakarta).

KATEGORI YANG TERSEDIA (pilih id yang paling cocok, JANGAN buat baru):

PENGELUARAN (expense):
${expense || "  (kosong)"}

PEMASUKAN (income):
${income || "  (kosong)"}

AKUN YANG DIIZINKAN: Tunai, Transfer, E-Wallet
- "CASH" / "TUNAI" / "BAYAR TUNAI" -> "Tunai"
- "DEBIT" / "BCA" / "MANDIRI" / "BRI" / "BANK" / "TRANSFER" / "VA" / "ATM" -> "Transfer"
- "QRIS" / "GOPAY" / "OVO" / "DANA" / "SHOPEEPAY" / "LINKAJA" / "E-WALLET" -> "E-Wallet"
- Default "Tunai" jika tidak terlihat metode pembayaran.

CARA BACA STRUK:
1. amount = TOTAL AKHIR yang dibayar (bukan subtotal, bukan harga per item, sudah termasuk pajak/diskon).
   - Cari label "TOTAL", "GRAND TOTAL", "JUMLAH BAYAR", "BAYAR", atau angka paling besar di bagian bawah.
   - Hilangkan pemisah ribuan: "20.000" / "20,000" -> 20000.
   - Untuk struk transfer/QRIS: ambil nominal yang ditransfer.
2. date = tanggal di struk dalam format YYYY-MM-DD.
   - Format umum: "12/03/2024", "12-03-2024", "12 Mar 2024", "12 Maret 2024".
   - Jika tidak terbaca / tidak ada, pakai ${today}.
3. type = "expense" untuk struk pembelian/pembayaran (default).
   - "income" hanya jika struk JELAS bukti penerimaan uang (mis. slip transfer MASUK, bukti gaji).
4. account = metode pembayaran sesuai mapping di atas.

5. source_or_payee = NAMA TOKO / MERCHANT dari header struk.
   - Contoh: "Indomaret Sudirman", "Warmindo Kakzul", "Starbucks", "Pertamina", "Gojek".
   - Kalau merchant tidak terlihat, tulis nama item utama yang dibeli.
   - Untuk struk transfer, isi nama penerima.
   - Singkat saja, jangan masukkan alamat panjang.

6. notes = info tambahan yang relevan TAPI BUKAN nama merchant.
   WAJIB KOSONG "" kecuali ada konteks khusus seperti:
   - Daftar item utama (mis. "Indomie x2, Aqua x1") jika user perlu rekap.
   - Nomor struk / nomor referensi jika menonjol.
   - Catatan promo / diskon ("diskon 20%", "voucher cashback").
   Jangan mengulang merchant atau total di sini.

7. confidence:
   - "high" jika total + tanggal + merchant terbaca jelas
   - "medium" jika ada 1 field yang ditebak
   - "low" jika foto buram / sebagian terpotong / banyak tebakan
8. reasoning: 1 kalimat singkat Bahasa Indonesia menjelaskan apa yang kamu baca dari struk.

ATURAN JSON OUTPUT:
1. category_id WAJIB dari list di atas. Pilih kategori paling cocok:
   - Struk supermarket / minimarket -> kategori belanja / kebutuhan harian
   - Struk makanan -> kategori makan / kuliner
   - Struk SPBU / parkir -> kategori transportasi
   - Struk tagihan listrik/air/internet -> kategori tagihan
   - Jika ragu, pilih kategori paling general (mis. "Lainnya").
2. category_name HARUS sama persis dengan name di list.
3. amount HARUS angka rupiah utuh (integer, tanpa desimal/pemisah).

CONTOH:
- Struk Indomaret total Rp 47.500 tunai, tanggal 15 Mar 2024:
  -> source_or_payee="Indomaret", amount=47500, account="Tunai",
     date="2024-03-15", notes="", type="expense"
- Bukti transfer BCA ke "Andi" Rp 250.000 tanggal 20 Maret 2024:
  -> source_or_payee="Andi", amount=250000, account="Transfer",
     date="2024-03-20", notes="", type="expense"
- Struk QRIS Starbucks Rp 65.000 dengan diskon promo 30%:
  -> source_or_payee="Starbucks", amount=65000, account="E-Wallet",
     notes="diskon promo 30%"

Selain "transactions", balas juga field "transcript" berisi 1 kalimat ringkas
(maks 100 karakter) yang menggambarkan struk, mis: "Struk Indomaret 15 Mar 2024,
total Rp 47.500 tunai".

FORMAT OUTPUT (WAJIB):
Balas HANYA dengan satu objek JSON valid berbentuk:
{ "transactions": [ { ...field di atas... }, ... ], "transcript": "..." }
Array berisi 1 sampai ${MAX_TRANSACTIONS} elemen. Tanpa markdown, tanpa backticks.

Jika foto BUKAN struk / tidak bisa dibaca sama sekali / kosong, balas:
{ "transactions": [], "transcript": "Foto tidak terbaca sebagai struk." }`;
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

  let payload: { image_base64?: string; mime?: string };
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const imageBase64 = (payload.image_base64 ?? "").trim();
  const mime = (payload.mime ?? "image/jpeg").toLowerCase();

  if (!imageBase64) {
    return jsonResponse({ error: "empty_image" }, 400);
  }
  if (imageBase64.length > MAX_BASE64_BYTES) {
    return jsonResponse({ error: "image_too_large" }, 413);
  }
  if (!ALLOWED_MIMES.has(mime)) {
    return jsonResponse({ error: "unsupported_mime", detail: mime }, 400);
  }

  // 1. Fetch caller's categories using their JWT so RLS scopes by user.
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
  if (categories.length === 0) {
    return jsonResponse(
      { error: "no_categories", detail: "User has no categories yet." },
      400,
    );
  }

  // 2. Call GPT-4o vision with structured output.
  const today = todayJakarta();
  const systemPrompt = buildSystemPrompt(categories, today);
  const dataUrl = `data:${mime};base64,${imageBase64}`;

  const openaiRes = await fetch(`${OPENAI_BASE_URL}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: OPENAI_VISION_MODEL,
      temperature: 0.1,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        {
          role: "user",
          content: [
            {
              type: "text",
              text:
                "Baca struk berikut dan ubah jadi JSON sesuai instruksi sistem.",
            },
            {
              type: "image_url",
              image_url: { url: dataUrl, detail: "high" },
            },
          ],
        },
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

  // 3. Sanity-validate the LLM output and force it onto a known shape.
  let rawList: any[] = [];
  if (Array.isArray(parsed)) {
    rawList = parsed;
  } else if (parsed && Array.isArray(parsed.transactions)) {
    rawList = parsed.transactions;
  } else if (parsed && typeof parsed === "object" && "amount" in parsed) {
    rawList = [parsed];
  }

  const sharedTranscript =
    typeof parsed?.transcript === "string"
      ? parsed.transcript.trim().slice(0, 200)
      : "";

  if (rawList.length === 0) {
    return jsonResponse(
      {
        error: "no_transactions_parsed",
        detail: sharedTranscript || "Struk tidak terbaca.",
        raw,
      },
      422,
    );
  }

  // Hard cap to keep API + UI cost bounded.
  rawList = rawList.slice(0, MAX_TRANSACTIONS);

  const transactions = rawList.map((item: any) => {
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

    const account = ACCOUNTS.find((a) => a === item.account) ?? "Tunai";

    const date = /^\d{4}-\d{2}-\d{2}$/.test(item.date ?? "")
      ? item.date
      : today;

    return {
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
      notes:
        typeof item.notes === "string" ? item.notes.trim() : "",
      date,
      confidence:
        item.confidence === "high" ||
        item.confidence === "medium" ||
        item.confidence === "low"
          ? item.confidence
          : "medium",
      reasoning:
        typeof item.reasoning === "string" ? item.reasoning.trim() : "",
    };
  });

  return jsonResponse(
    { transactions, transcript: sharedTranscript },
    200,
  );
});
