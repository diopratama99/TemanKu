-- ============================================================
-- TemanKu — Supabase PostgreSQL Schema (idempotent)
-- Safe to run on existing Supabase instances.
-- ============================================================

-- 1. PROFILES (extends auth.users)
-- Jika tabel profiles sudah ada dari app lain, tambahkan kolom yg kurang saja
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL DEFAULT '',
  picture TEXT,
  currency TEXT DEFAULT 'IDR',
  created_at TIMESTAMPTZ DEFAULT now()
);
-- Tambah kolom jika belum ada (safe, diabaikan kalau sudah ada)
DO $$ BEGIN
  ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS picture TEXT;
  ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS currency TEXT DEFAULT 'IDR';
END $$;

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE USING (auth.uid() = id);
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
  ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);

-- 2. CATEGORIES
CREATE TABLE IF NOT EXISTS public.categories (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT CHECK(type IN ('income','expense')) NOT NULL,
  name TEXT NOT NULL,
  emoji TEXT,
  UNIQUE(user_id, type, name)
);

ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own categories" ON public.categories;
CREATE POLICY "Users can manage own categories"
  ON public.categories FOR ALL USING (auth.uid() = user_id);

-- 3. TRANSACTIONS
CREATE TABLE IF NOT EXISTS public.transactions (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  type TEXT CHECK(type IN ('income','expense')) NOT NULL,
  category_id BIGINT NOT NULL REFERENCES public.categories(id),
  amount DOUBLE PRECISION NOT NULL,
  source_or_payee TEXT,
  account TEXT,
  notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_trx_user_date ON public.transactions(user_id, date);
CREATE INDEX IF NOT EXISTS idx_trx_user_type ON public.transactions(user_id, type);

ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own transactions" ON public.transactions;
CREATE POLICY "Users can manage own transactions"
  ON public.transactions FOR ALL USING (auth.uid() = user_id);

-- 4. BUDGETS
CREATE TABLE IF NOT EXISTS public.budgets (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id BIGINT NOT NULL REFERENCES public.categories(id),
  month TEXT NOT NULL,
  amount DOUBLE PRECISION NOT NULL,
  UNIQUE(user_id, category_id, month)
);

ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own budgets" ON public.budgets;
CREATE POLICY "Users can manage own budgets"
  ON public.budgets FOR ALL USING (auth.uid() = user_id);

-- 5. SAVINGS AUTO TRANSFERS
CREATE TABLE IF NOT EXISTS public.savings_auto_transfers (
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  month TEXT NOT NULL,
  amount DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (user_id, month)
);

ALTER TABLE public.savings_auto_transfers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own auto transfers" ON public.savings_auto_transfers;
CREATE POLICY "Users can manage own auto transfers"
  ON public.savings_auto_transfers FOR ALL USING (auth.uid() = user_id);

-- 6. SAVINGS GOALS
CREATE TABLE IF NOT EXISTS public.savings_goals (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  target_amount DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  achieved_at TIMESTAMPTZ,
  archived_at TIMESTAMPTZ
);

ALTER TABLE public.savings_goals ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own goals" ON public.savings_goals;
CREATE POLICY "Users can manage own goals"
  ON public.savings_goals FOR ALL USING (auth.uid() = user_id);

-- 7. SAVINGS ALLOCATIONS
CREATE TABLE IF NOT EXISTS public.savings_allocations (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  goal_id BIGINT NOT NULL REFERENCES public.savings_goals(id) ON DELETE CASCADE,
  amount DOUBLE PRECISION NOT NULL,
  date DATE NOT NULL,
  note TEXT
);

ALTER TABLE public.savings_allocations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own allocations" ON public.savings_allocations;
CREATE POLICY "Users can manage own allocations"
  ON public.savings_allocations FOR ALL USING (auth.uid() = user_id);

-- 8. SAVINGS MANUAL TOPUPS
CREATE TABLE IF NOT EXISTS public.savings_manual_topups (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  month TEXT NOT NULL,
  date DATE NOT NULL,
  amount DOUBLE PRECISION NOT NULL,
  note TEXT,
  transaction_id BIGINT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.savings_manual_topups ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own topups" ON public.savings_manual_topups;
CREATE POLICY "Users can manage own topups"
  ON public.savings_manual_topups FOR ALL USING (auth.uid() = user_id);

-- 9. SAVINGS CONSUMED
CREATE TABLE IF NOT EXISTS public.savings_consumed (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  amount DOUBLE PRECISION NOT NULL,
  note TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.savings_consumed ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own consumed" ON public.savings_consumed;
CREATE POLICY "Users can manage own consumed"
  ON public.savings_consumed FOR ALL USING (auth.uid() = user_id);

-- 10. FAVORITES
CREATE TABLE IF NOT EXISTS public.favorites (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  type TEXT NOT NULL CHECK(type IN ('income','expense')),
  category_id BIGINT NOT NULL,
  amount DOUBLE PRECISION,
  account TEXT,
  source_or_payee TEXT,
  notes TEXT,
  UNIQUE(user_id, name)
);

ALTER TABLE public.favorites ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own favorites" ON public.favorites;
CREATE POLICY "Users can manage own favorites"
  ON public.favorites FOR ALL USING (auth.uid() = user_id);

-- 11. ACCOUNT TRANSFERS
CREATE TABLE IF NOT EXISTS public.account_transfers (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  date DATE NOT NULL,
  from_account TEXT NOT NULL CHECK(from_account IN ('Transfer','Tunai','E-Wallet')),
  to_account TEXT NOT NULL CHECK(to_account IN ('Transfer','Tunai','E-Wallet')),
  amount DOUBLE PRECISION NOT NULL,
  note TEXT,
  fee_transaction_id BIGINT,
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.account_transfers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own transfers" ON public.account_transfers;
CREATE POLICY "Users can manage own transfers"
  ON public.account_transfers FOR ALL USING (auth.uid() = user_id);

-- ============================================================
-- TRIGGER: Auto-create profile + seed categories on signup
-- ============================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  -- Create profile (wrapped in exception block for shared DB compatibility)
  BEGIN
    INSERT INTO public.profiles (id, name)
    VALUES (
      NEW.id,
      COALESCE(NEW.raw_user_meta_data->>'name', split_part(NEW.email, '@', 1))
    )
    ON CONFLICT (id) DO UPDATE SET
      name = COALESCE(EXCLUDED.name, public.profiles.name);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: profiles insert skipped: %', SQLERRM;
  END;

  -- Seed default categories (wrapped in exception block)
  BEGIN
    INSERT INTO public.categories (user_id, type, name, emoji) VALUES
      (NEW.id, 'income',  'Gaji',       '💼'),
      (NEW.id, 'income',  'Bonus',      '🎁'),
      (NEW.id, 'income',  'Investasi',  '📈'),
      (NEW.id, 'income',  'Freelance',  '🧑‍💻'),
      (NEW.id, 'expense', 'Makan',      '🍽️'),
      (NEW.id, 'expense', 'Transport',  '🚌'),
      (NEW.id, 'expense', 'Belanja',    '🛍️'),
      (NEW.id, 'expense', 'Hiburan',    '🎬'),
      (NEW.id, 'expense', 'Kesehatan',  '🩺'),
      (NEW.id, 'expense', 'Tagihan',    '🧾'),
      (NEW.id, 'expense', 'Lainnya',    '📦')
    ON CONFLICT DO NOTHING;
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'handle_new_user: categories seed skipped: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if any, then recreate
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- RPC: Atomic account transfer with fee
-- ============================================================
CREATE OR REPLACE FUNCTION public.insert_transfer_with_fee(
  p_date DATE,
  p_from_account TEXT,
  p_to_account TEXT,
  p_amount DOUBLE PRECISION,
  p_note TEXT DEFAULT NULL,
  p_admin_fee DOUBLE PRECISION DEFAULT 0
)
RETURNS void AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_fee_trx_id BIGINT;
  v_cat_id BIGINT;
BEGIN
  IF p_admin_fee > 0 THEN
    SELECT id INTO v_cat_id
    FROM public.categories
    WHERE user_id = v_uid AND type = 'expense' AND name = 'Lainnya'
    LIMIT 1;

    IF v_cat_id IS NULL THEN
      INSERT INTO public.categories (user_id, type, name, emoji)
      VALUES (v_uid, 'expense', 'Lainnya', '📦')
      RETURNING id INTO v_cat_id;
    END IF;

    INSERT INTO public.transactions (user_id, date, type, category_id, amount, source_or_payee, account, notes)
    VALUES (v_uid, p_date, 'expense', v_cat_id, p_admin_fee, 'Admin Fee', p_from_account, p_note)
    RETURNING id INTO v_fee_trx_id;
  END IF;

  INSERT INTO public.account_transfers (user_id, date, from_account, to_account, amount, note, fee_transaction_id)
  VALUES (v_uid, p_date, p_from_account, p_to_account, p_amount, p_note, v_fee_trx_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
