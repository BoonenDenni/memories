-- Adds finished_at for the “finished books per month” chart when your table
-- already uses rating + notes (see public.user_book_status in production).

ALTER TABLE public.user_book_status
  ADD COLUMN IF NOT EXISTS finished_at timestamptz;

NOTIFY pgrst, 'reload schema';
