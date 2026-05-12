---
description: Deploy Supabase Edge Functions ke home server (leykopin@serverdio) via scp + restart container
---

# Deploy Edge Function ke Self-Hosted Supabase

Server: `leykopin@serverdio`
Path edge functions di server: `~/supabase/docker/volumes/functions/`
Container yang harus di-restart setelah update: `functions` (di compose stack `~/supabase/docker`).

## 1. Push function ke server (pilih salah satu)

### Push satu function tertentu (paling umum)

Ganti `<function-name>` dengan nama function (mis. `parse-receipt`, `parse-transaction`).

// turbo
```powershell
scp -r supabase/functions/<function-name> leykopin@serverdio:~/supabase/docker/volumes/functions/
```

### Push semua functions sekaligus

// turbo
```powershell
scp -r supabase/functions/* leykopin@serverdio:~/supabase/docker/volumes/functions/
```

> Catatan: `scp -r` selalu menyalin ulang semua file (tidak diff seperti rsync). Untuk function kecil ini cepat.

## 2. Restart container `functions` supaya Deno reload module cache

// turbo
```powershell
ssh leykopin@serverdio "cd ~/supabase/docker && docker compose restart functions"
```

## 3. Verifikasi function aktif (logs)

```powershell
ssh leykopin@serverdio "docker logs supabase-edge-functions --tail 50"
```

Ctrl+C untuk berhenti kalau pakai `--follow`.

## 4. Smoke test endpoint (opsional)

Ganti `<function-name>` dan domain Supabase-mu. JWT bisa diambil dari sesi login user di app.

```powershell
curl -X POST https://<your-supabase-domain>/functions/v1/<function-name> `
  -H "Authorization: Bearer <JWT>" `
  -H "Content-Type: application/json" `
  -d '{}'
```

Function yang aktif akan return error code spesifik (mis. `{"error":"empty_image"}` untuk `parse-receipt`), bukan 404 atau timeout.

## Catatan Tambahan

- **Secrets**: Edge function butuh env var seperti `OPENAI_API_KEY` dan `OPENAI_VISION_MODEL`. Pasang di `~/supabase/docker/.env` di server, lalu `docker compose up -d` ulang.
- **Alternatif rsync**: Kalau punya WSL atau install scoop, `rsync -avz supabase/functions/<name>/ leykopin@serverdio:~/supabase/docker/volumes/functions/<name>/` lebih efisien karena diff-only.
- **Trailing slash di scp**: Untuk `scp -r supabase/functions/parse-receipt destination/`, folder `parse-receipt` akan dibuat di destination. Jangan tambahkan `/` di belakang source path saat pakai scp.
