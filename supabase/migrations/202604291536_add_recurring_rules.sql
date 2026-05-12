-- Add recurring rules table for recurring transactions feature.
-- Safe to run multiple times.

CREATE TABLE IF NOT EXISTS public.recurring_rules (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL DEFAULT auth.uid() REFERENCES auth.users(id) ON DELETE CASCADE,
  frequency TEXT NOT NULL CHECK (frequency IN ('weekly','monthly','yearly')),
  next_date DATE NOT NULL,
  type TEXT NOT NULL CHECK (type IN ('income','expense')),
  category_id BIGINT NOT NULL REFERENCES public.categories(id),
  amount DOUBLE PRECISION NOT NULL,
  source_or_payee TEXT,
  account TEXT,
  notes TEXT,
  active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_recurring_rules_user_next_date
  ON public.recurring_rules(user_id, next_date)
  WHERE active = true;

ALTER TABLE public.recurring_rules ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own recurring rules" ON public.recurring_rules;
CREATE POLICY "Users can manage own recurring rules"
  ON public.recurring_rules FOR ALL USING (auth.uid() = user_id);
