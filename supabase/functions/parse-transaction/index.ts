// supabase/functions/parse-transaction/index.ts
//
// Parses a free-form Indonesian transcript (e.g. "Beli batagor 20rb pakai cash")
// into one or more structured transaction drafts using GPT-4o.
//
// A single utterance may describe up to MAX_TRANSACTIONS distinct transactions
// (e.g. "Beli batagor 20rb cash terus bayar parkir 5rb"). To keep cost bounded,
// we hard-cap both the prompt instruction and the post-processing slice.
//
// Input  (POST JSON):
//   { transcript: string }
//
// Output (200 JSON):
//   {
//     transactions: [
//       {
//         type: "expense" | "income",
//         amount: number,
//         category_id: number,
//         category_name: string,
//         category_emoji: string | null,
//         account: "Tunai" | "Transfer" | "E-Wallet",
//         source_or_payee: string,
//         notes: string,
//         date: "YYYY-MM-DD",
//         confidence: "high" | "medium" | "low",
//         reasoning: string
//       }, ...up to 3
//     ],
//     transcript: string
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
const MAX_TRANSACTIONS = 3;

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

  return `Kamu adalah parser transaksi keuangan untuk aplikasi TemanKu (Bahasa Indonesia).
Tugasmu: ubah ucapan bebas pengguna menjadi JSON terstruktur.

Satu ucapan bisa berisi 1-${MAX_TRANSACTIONS} transaksi terpisah. Pisahkan jika user
jelas menyebut beberapa kejadian (mis. dipisah dengan "terus", "lalu", "sama",
"dan", atau menyebut item+harga berurutan). Maksimal ${MAX_TRANSACTIONS} transaksi;
kalau user menyebut lebih, ambil ${MAX_TRANSACTIONS} yang paling jelas.

KONTEKS TANGGAL HARI INI: ${today} (Asia/Jakarta).

KATEGORI YANG TERSEDIA (pilih id yang paling cocok, JANGAN buat baru):

PENGELUARAN (expense):
${expense || "  (kosong)"}

PEMASUKAN (income):
${income || "  (kosong)"}

AKUN YANG DIIZINKAN: Tunai, Transfer, E-Wallet

ATURAN AKUN (WAJIB DIIKUTI — jangan abaikan kata kunci akun!):
1. Jika user menyebut salah satu kata kunci di bawah, WAJIB gunakan akun yang sesuai:
   - "cash", "tunai", "uang tunai", "uang cash" -> "Tunai"
   - "bca", "bri", "mandiri", "bni", "bank", "transfer", "rekening", "atm", "m-banking", "mobile banking" -> "Transfer"
   - "gopay", "ovo", "dana", "shopeepay", "linkaja", "e-wallet", "ewallet", "qris" -> "E-Wallet"
2. Perhatikan konteks: "pakai dana", "via dana", "bayar pake dana", "lewat dana" = E-Wallet (DANA adalah aplikasi e-wallet).
   Tapi "dana darurat", "dana tabungan" = bukan nama akun, abaikan.
3. "via transfer", "lewat transfer", "pakai transfer", "bayar transfer" = Transfer (bukan Tunai!).
4. HANYA jika user TIDAK menyebut metode pembayaran sama sekali, default ke "Tunai".

PARSING JUMLAH:
- "20rb" / "20 ribu" / "20k" -> 20000
- "1jt" / "1 juta" -> 1000000
- "150rb" -> 150000
- "6 juta" / "6jt" -> 6000000
- Hilangkan titik/koma format ribuan: "20.000" -> 20000

JENIS TRANSAKSI (PENTING — baca baik-baik!):
- PEMASUKAN (type="income"): gaji, gajian, dapat gaji, terima gaji, bonus, THR, dapat uang, terima uang, transfer masuk, untung, laba, hadiah, refund, cashback, jual, hasil jualan, dividen, komisi, honor, honorarium, freelance
- PENGELUARAN (type="expense"): beli, bayar, jajan, belanja, makan, minum, top up, isi, ngopi, bensin, parkir, transfer keluar, kirim uang, sewa, cicilan, tagihan

ATURAN TYPE (WAJIB DIIKUTI):
- Jika ucapan mengandung kata kunci PEMASUKAN di atas, type HARUS "income". Jangan pernah set "expense" untuk gaji/bonus/refund/dll.
- "baru dapat gaji" / "gaji masuk" / "terima gaji" / "gajian bulan X" = SELALU income.
- "dapat uang dari X" / "terima transfer dari X" = income.
- Hanya set "expense" jika ucapan jelas tentang pengeluaran (beli, bayar, dsb).
- Jika ambigu, lihat konteksnya: jumlah besar + "gaji"/"bonus" = income.

ATURAN JSON OUTPUT:
1. category_id WAJIB dari list di atas. Jika tidak ada yang cocok, pilih kategori paling general (misal "Lainnya").
2. category_name HARUS sama persis dengan name di list.
3. amount HARUS angka rupiah utuh (bukan string, tanpa pemisah).
4. date default ke ${today} kecuali user sebut tanggal lain.
   - "bulan april" / "april" tanpa tanggal spesifik -> tanggal 1 bulan tersebut tahun ini.
   - "kemarin" -> ${today} minus 1 hari.
   - "minggu lalu" -> ${today} minus 7 hari.

5. source_or_payee = KETERANGAN UTAMA transaksi. Isi field ini dengan:
   - Nama item / barang yang dibeli (contoh: "batagor", "bakso", "kopi susu", "bensin pertamax", "tiket bioskop").
   - ATAU nama tempat / pihak (contoh: "Warung Bu Ani", "Indomaret", "Gojek", "Andi") jika user menyebutnya.
   - ATAU sumber pemasukan (contoh: "Gaji November", "Gaji April", "Bonus", "Refund Tokopedia").
   - Kalau user menyebut keduanya (item + tempat), gabungkan singkat: "batagor di Warung Bu Ani".
   - Kosong "" hanya jika benar-benar tidak ada petunjuk.

6. notes = CATATAN TAMBAHAN / KONTEKS, BUKAN nama item.
   Field ini WAJIB KOSONG "" kecuali user secara eksplisit menyebut konteks tambahan seperti:
   - Utang / pinjam: "utang dulu ke temen", "pinjam dulu sama Andi"
   - Split bill: "nanti di-split bill", "patungan sama X", "buat 3 orang"
   - Reimburse: "nanti diganti kantor", "buat tagihan kantor"
   - Cicilan / bertahap: "sisa bayar bulan depan"
   - Untuk orang lain: "buat anak", "buat istri"
   Selain konteks seperti di atas, biarkan notes kosong "".

7. confidence: "high" jika semua field jelas; "medium" jika ada tebakan; "low" jika ucapan ambigu.
8. reasoning: 1 kalimat singkat dalam Bahasa Indonesia yang menjelaskan keputusanmu.

CONTOH SATU TRANSAKSI:
- "Beli batagor 20rb pakai cash"
  -> type="expense", account="Tunai", source_or_payee="batagor", notes=""
- "Bayar bensin 50rb di pertamina transfer bca"
  -> type="expense", account="Transfer", source_or_payee="bensin di pertamina", notes=""
- "Bayar makan 80rb via dana"
  -> type="expense", account="E-Wallet", source_or_payee="makan", notes=""
- "Bayar parkir pakai transfer"
  -> type="expense", account="Transfer", source_or_payee="parkir", notes=""
- "Makan siang 100rb tapi nanti di-split sama Andi"
  -> type="expense", source_or_payee="makan siang", notes="split bill sama Andi"
- "Beli kopi 30rb pakai gopay, utang dulu ke Budi"
  -> type="expense", account="E-Wallet", source_or_payee="kopi", notes="utang dulu ke Budi"
- "Dapat gaji 5jt masuk rekening"
  -> type="income", account="Transfer", source_or_payee="gaji", notes=""
- "Baru dapat gaji bulan april 6 juta"
  -> type="income", account="Transfer", source_or_payee="Gaji April", notes=""
- "Terima bonus 2jt via transfer"
  -> type="income", account="Transfer", source_or_payee="bonus", notes=""

CONTOH MULTI TRANSAKSI:
- "Beli batagor 20rb cash terus bayar parkir 5rb"
  -> 2 transaksi: [batagor 20000 Tunai expense, parkir 5000 Tunai expense]
- "Top up gopay 100rb sama beli pulsa 50rb"
  -> 2 transaksi: [top up gopay 100000 E-Wallet expense, pulsa 50000 ...]
- "Bayar listrik 300rb, internet 400rb, sama air 100rb pakai transfer"
  -> 3 transaksi (semua Transfer expense)

FORMAT OUTPUT (WAJIB):
Balas HANYA dengan satu objek JSON valid berbentuk:
{ "transactions": [ { ...field di atas... }, ... ] }
Array berisi 1 sampai ${MAX_TRANSACTIONS} elemen. Tanpa markdown, tanpa backticks.`;
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

  let payload: { transcript?: string };
  try {
    payload = await req.json();
  } catch {
    return jsonResponse({ error: "invalid_json" }, 400);
  }

  const transcript = (payload.transcript ?? "").trim();
  if (!transcript) {
    return jsonResponse({ error: "empty_transcript" }, 400);
  }
  if (transcript.length > 600) {
    return jsonResponse({ error: "transcript_too_long" }, 400);
  }

  // 1. Fetch caller's categories using their JWT so RLS scopes by user.
  // `db: { schema: "temanku" }` routes every .from()/.rpc() call to our
  // dedicated Postgres schema on the shared self-hosted Supabase.
  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    db: { schema: "temanku" },
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

  // 2. Call GPT-4o with structured output.
  const today = todayJakarta();
  const systemPrompt = buildSystemPrompt(categories, today);

  const openaiRes = await fetch(`${OPENAI_BASE_URL}/chat/completions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${OPENAI_API_KEY}`,
    },
    body: JSON.stringify({
      model: OPENAI_MODEL,
      temperature: 0.1,
      response_format: { type: "json_object" },
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: transcript },
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
  // Accept either { transactions: [...] }, a bare array, or a single object
  // (older single-transaction shape) so we never break callers if the model
  // drifts back to the legacy form.
  let rawList: any[] = [];
  if (Array.isArray(parsed)) {
    rawList = parsed;
  } else if (parsed && Array.isArray(parsed.transactions)) {
    rawList = parsed.transactions;
  } else if (parsed && typeof parsed === "object" && "amount" in parsed) {
    rawList = [parsed];
  }

  if (rawList.length === 0) {
    return jsonResponse({ error: "no_transactions_parsed", raw }, 502);
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

  return jsonResponse({ transactions, transcript }, 200);
});
