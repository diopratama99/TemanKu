-- ============================================================
-- TemanKu — Restore IngatanKu signup trigger + add TemanKu's own
-- `profiles` table.
--
-- Context:
--   The previous migration (20260504211300_move_to_temanku_schema)
--   replaced the trigger `on_auth_user_created` on `auth.users` so
--   it now calls `temanku.handle_new_user()`. That trigger name was
--   ALSO used by IngatanKu's own migration, which means IngatanKu's
--   signup hook (profile + username generator) no longer fires for
--   new users. We need both apps' seed logic to run.
--
--   Additionally, IngatanKu's `profiles` table has a different shape
--   (username, xp, level, streak_days, …) than TemanKu's
--   (name, picture, currency). They are effectively different
--   tables, so TemanKu needs its own `temanku.profiles` instead of
--   reusing `ingatanku.profiles`.
--
-- This migration is forward-only and idempotent.
-- ============================================================

-- ──────────────────────────────────────────────────────────────
-- 1. Create temanku.profiles (TemanKu's own per-user profile).
--    Structure matches what `lib/data/app_database.dart` expects
--    in getProfile() / updateProfile() and what the trigger
--    `temanku.handle_new_user()` inserts into.
-- ──────────────────────────────────────────────────────────────
create table if not exists temanku.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  name        text not null default '',
  picture     text,
  currency    text default 'IDR',
  created_at  timestamptz default now()
);

-- Ensure columns exist even if the table was created earlier with
-- a smaller set (safe on fresh installs too).
do $cols$ begin
  alter table temanku.profiles add column if not exists picture  text;
  alter table temanku.profiles add column if not exists currency text default 'IDR';
end $cols$;

alter table temanku.profiles enable row level security;

drop policy if exists "Users can view own profile"   on temanku.profiles;
drop policy if exists "Users can update own profile" on temanku.profiles;
drop policy if exists "Users can insert own profile" on temanku.profiles;

create policy "Users can view own profile"
  on temanku.profiles for select using (auth.uid() = id);
create policy "Users can update own profile"
  on temanku.profiles for update using (auth.uid() = id);
create policy "Users can insert own profile"
  on temanku.profiles for insert with check (auth.uid() = id);

grant all on temanku.profiles to anon, authenticated, service_role;

-- Backfill: every existing auth user who doesn't have a TemanKu
-- profile yet gets one seeded from their email local-part. This
-- covers users who signed up via IngatanKu before TemanKu existed.
insert into temanku.profiles (id, name)
select u.id,
       coalesce(u.raw_user_meta_data->>'name', split_part(u.email, '@', 1))
from auth.users u
left join temanku.profiles p on p.id = u.id
where p.id is null;

-- ──────────────────────────────────────────────────────────────
-- 2. Split the shared `on_auth_user_created` trigger into two
--    app-specific triggers so BOTH apps' handle_new_user fire on
--    every signup. Postgres allows multiple triggers per event
--    (they fire alphabetically by trigger name — order is
--    irrelevant here since the two functions touch different
--    schemas).
--
--    We drop the old shared name to avoid double-firing TemanKu.
-- ──────────────────────────────────────────────────────────────
drop trigger if exists on_auth_user_created             on auth.users;
drop trigger if exists on_auth_user_created_temanku     on auth.users;
drop trigger if exists on_auth_user_created_ingatanku   on auth.users;

-- TemanKu trigger (always created — this migration ships with TemanKu)
create trigger on_auth_user_created_temanku
  after insert on auth.users
  for each row execute function temanku.handle_new_user();

-- IngatanKu trigger — only create if IngatanKu's function still
-- exists on this Postgres (it does, per the IngatanKu migration
-- that already ran). Guarded so running this on a Postgres that
-- does NOT host IngatanKu doesn't fail.
do $trg$
begin
  if exists (
    select 1
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'ingatanku' and p.proname = 'handle_new_user'
  ) then
    execute $sql$
      create trigger on_auth_user_created_ingatanku
        after insert on auth.users
        for each row execute function ingatanku.handle_new_user()
    $sql$;
  end if;
end
$trg$;
