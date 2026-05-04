-- ============================================================
-- TemanKu — Move all app objects from `public` to `temanku`
-- Forward-only, idempotent. Safe to run multiple times.
--
-- Rationale:
--   Self-hosted Supabase is shared across several apps (TemanKu,
--   IngatanKu, BensinKu, DungeonKu, …). Keeping them all in `public`
--   causes name clashes and makes backup/restore + RLS audit harder.
--   We isolate TemanKu into its own Postgres schema `temanku`.
--
-- What this migration does:
--   1. Create schema `temanku`.
--   2. Drop the trigger on `auth.users` that references the old
--      `public.handle_new_user()` (we cannot MOVE a function whose
--      trigger still references it without temporarily removing the
--      dependency on auth.users — ALTER FUNCTION ... SET SCHEMA is
--      allowed even with the trigger, but we drop it to recreate it
--      later pointing at the new schema explicitly).
--   3. Move all 13 app tables (RLS policies, indexes, constraints
--      follow the table automatically).
--   4. Move the 2 app functions into `temanku`.
--   5. Recreate function bodies so internal `public.<table>` refs
--      become `temanku.<table>`.
--   6. Recreate the `on_auth_user_created` trigger on `auth.users`
--      pointing at `temanku.handle_new_user()`.
--   7. Grant schema usage + default privileges for anon /
--      authenticated / service_role so PostgREST + API work.
--
-- NOT touched:
--   - `auth.*`, `storage.*`, `realtime.*` (Supabase-owned).
--   - Any table that belongs to other apps (only the explicitly
--     listed tables are moved).
--   - No DROP TABLE, TRUNCATE, or DELETE of user data anywhere.
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- 1. Schema
-- ──────────────────────────────────────────────────────────────
create schema if not exists temanku;

-- ──────────────────────────────────────────────────────────────
-- 2. Drop the auth.users trigger (we'll recreate it in step 6
--    pointing at the moved function).
-- ──────────────────────────────────────────────────────────────
drop trigger if exists on_auth_user_created on auth.users;

-- ──────────────────────────────────────────────────────────────
-- 3. Move tables. RLS policies, indexes, constraints follow the
--    table when SET SCHEMA is used, so they do not need manual
--    reattachment. `if exists` makes re-runs a no-op.
-- ──────────────────────────────────────────────────────────────
alter table if exists public.profiles                set schema temanku;
alter table if exists public.categories              set schema temanku;
alter table if exists public.transactions            set schema temanku;
alter table if exists public.budgets                 set schema temanku;
alter table if exists public.savings_auto_transfers  set schema temanku;
alter table if exists public.savings_goals           set schema temanku;
alter table if exists public.savings_allocations     set schema temanku;
alter table if exists public.savings_manual_topups   set schema temanku;
alter table if exists public.savings_consumed        set schema temanku;
alter table if exists public.favorites               set schema temanku;
alter table if exists public.account_transfers       set schema temanku;
alter table if exists public.debts                   set schema temanku;
alter table if exists public.debt_payments           set schema temanku;

-- ──────────────────────────────────────────────────────────────
-- 4. Move functions. `ALTER FUNCTION` has no IF EXISTS, so wrap
--    each call in a BEGIN/EXCEPTION block. We swallow the two
--    expected errors on re-run:
--      - undefined_function  → already moved (or never existed)
--      - duplicate_function  → a function with the same signature
--                              already exists in temanku
-- ──────────────────────────────────────────────────────────────
do $mig$
declare
  fns text[] := array[
    'public.handle_new_user()',
    'public.insert_transfer_with_fee(date, text, text, double precision, text, double precision)'
  ];
  fn text;
begin
  foreach fn in array fns loop
    begin
      execute format('alter function %s set schema temanku', fn);
    exception
      when undefined_function then null;
      when duplicate_function then null;
      when invalid_schema_name then null;
    end;
  end loop;
end
$mig$;

-- ──────────────────────────────────────────────────────────────
-- 5. Recreate function bodies in `temanku` so internal table
--    references use the new schema. CREATE OR REPLACE keeps the
--    same OID → trigger dependency (re-created in step 6) stays
--    stable.
-- ──────────────────────────────────────────────────────────────

-- 5a. handle_new_user — fires on auth.users INSERT, seeds profile
--     and default categories for the new user.
create or replace function temanku.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = temanku, public, pg_temp
as $$
begin
  -- Create profile (wrapped in exception block for shared DB compatibility)
  begin
    insert into temanku.profiles (id, name)
    values (
      new.id,
      coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1))
    )
    on conflict (id) do update set
      name = coalesce(excluded.name, temanku.profiles.name);
  exception when others then
    raise warning 'handle_new_user: profiles insert skipped: %', SQLERRM;
  end;

  -- Seed default categories (wrapped in exception block)
  begin
    insert into temanku.categories (user_id, type, name, emoji) values
      (new.id, 'income',  'Gaji',       '💼'),
      (new.id, 'income',  'Bonus',      '🎁'),
      (new.id, 'income',  'Investasi',  '📈'),
      (new.id, 'income',  'Freelance',  '🧑‍💻'),
      (new.id, 'expense', 'Makan',      '🍽️'),
      (new.id, 'expense', 'Transport',  '🚌'),
      (new.id, 'expense', 'Belanja',    '🛍️'),
      (new.id, 'expense', 'Hiburan',    '🎬'),
      (new.id, 'expense', 'Kesehatan',  '🩺'),
      (new.id, 'expense', 'Tagihan',    '🧾'),
      (new.id, 'expense', 'Lainnya',    '📦')
    on conflict do nothing;
  exception when others then
    raise warning 'handle_new_user: categories seed skipped: %', SQLERRM;
  end;

  return new;
end;
$$;

-- 5b. insert_transfer_with_fee — atomic account transfer with optional fee.
create or replace function temanku.insert_transfer_with_fee(
  p_date        date,
  p_from_account text,
  p_to_account  text,
  p_amount      double precision,
  p_note        text default null,
  p_admin_fee   double precision default 0
)
returns void
language plpgsql
security definer
set search_path = temanku, public, pg_temp
as $$
declare
  v_uid        uuid   := auth.uid();
  v_fee_trx_id bigint;
  v_cat_id     bigint;
begin
  if p_admin_fee > 0 then
    select id into v_cat_id
    from temanku.categories
    where user_id = v_uid and type = 'expense' and name = 'Lainnya'
    limit 1;

    if v_cat_id is null then
      insert into temanku.categories (user_id, type, name, emoji)
      values (v_uid, 'expense', 'Lainnya', '📦')
      returning id into v_cat_id;
    end if;

    insert into temanku.transactions (
      user_id, date, type, category_id, amount,
      source_or_payee, account, notes
    )
    values (
      v_uid, p_date, 'expense', v_cat_id, p_admin_fee,
      'Admin Fee', p_from_account, p_note
    )
    returning id into v_fee_trx_id;
  end if;

  insert into temanku.account_transfers (
    user_id, date, from_account, to_account, amount, note, fee_transaction_id
  )
  values (
    v_uid, p_date, p_from_account, p_to_account, p_amount, p_note, v_fee_trx_id
  );
end;
$$;

-- ──────────────────────────────────────────────────────────────
-- 6. Recreate the auth.users trigger pointing at the moved
--    function. DROP TRIGGER IF EXISTS already ran in step 2, so
--    this is a fresh CREATE every time.
-- ──────────────────────────────────────────────────────────────
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function temanku.handle_new_user();

-- ──────────────────────────────────────────────────────────────
-- 7. Grants + default privileges. Required for:
--      - PostgREST (exposes schema via PGRST_DB_SCHEMAS env).
--      - anon / authenticated roles used by supabase-js /
--        supabase-flutter with the anon & user JWTs.
--      - service_role used by Edge Functions for admin ops.
--    Default privileges apply to future tables/sequences/
--    functions created inside `temanku` (useful for follow-up
--    migrations).
-- ──────────────────────────────────────────────────────────────
grant usage on schema temanku to anon, authenticated, service_role;

grant all on all tables    in schema temanku to anon, authenticated, service_role;
grant all on all sequences in schema temanku to anon, authenticated, service_role;
grant all on all functions in schema temanku to anon, authenticated, service_role;

alter default privileges in schema temanku
  grant all on tables    to anon, authenticated, service_role;
alter default privileges in schema temanku
  grant all on sequences to anon, authenticated, service_role;
alter default privileges in schema temanku
  grant all on functions to anon, authenticated, service_role;
