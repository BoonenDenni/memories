-- book_read_status enum for user_book_status.status
-- Idempotent: safe to re-run.

DO $$
BEGIN
  CREATE TYPE public.book_read_status AS ENUM (
    'wants_to_read',
    'reading',
    'finished',
    'dropped'
  );
EXCEPTION
  WHEN duplicate_object THEN NULL;
END;
$$;

-- Ensure default matches enum (column must already use this type in your schema)
ALTER TABLE public.user_book_status
  ALTER COLUMN status SET DEFAULT 'wants_to_read'::public.book_read_status;
