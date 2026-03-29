-- Define public.user_book_status (was only referenced in earlier migrations).
-- Idempotent for partial existing tables.

CREATE TABLE IF NOT EXISTS public.user_book_status (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  book_id uuid NOT NULL REFERENCES public.books (id) ON DELETE CASCADE,
  status public.book_read_status NOT NULL DEFAULT 'wants_to_read',
  user_rating smallint,
  note text,
  finished_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_book_status_user_rating_chk
  CHECK (user_rating IS NULL OR (user_rating BETWEEN 1 AND 5))
);

ALTER TABLE public.user_book_status
  ADD COLUMN IF NOT EXISTS user_rating smallint;

ALTER TABLE public.user_book_status
  ADD COLUMN IF NOT EXISTS note text;

ALTER TABLE public.user_book_status
  ADD COLUMN IF NOT EXISTS finished_at timestamptz;

ALTER TABLE public.user_book_status
  ADD COLUMN IF NOT EXISTS created_at timestamptz DEFAULT now();

ALTER TABLE public.user_book_status
  ADD COLUMN IF NOT EXISTS updated_at timestamptz DEFAULT now();

DO $$
BEGIN
  ALTER TABLE public.user_book_status
    ADD CONSTRAINT user_book_status_user_rating_chk
    CHECK (user_rating IS NULL OR (user_rating BETWEEN 1 AND 5));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END;
$$;

CREATE UNIQUE INDEX IF NOT EXISTS user_book_status_user_id_book_id_key
  ON public.user_book_status (user_id, book_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_book_status TO authenticated;
