-- Table Editor and SQL as postgres often BYPASS Row Level Security.
-- The Flutter app uses the anon key + logged-in JWT (role "authenticated").
-- If SELECT was never granted, or RLS is on without a policy, the API returns
-- no rows even though you see data in the dashboard.

GRANT SELECT ON public.book_categories TO authenticated;
GRANT SELECT ON public.books TO authenticated;
GRANT SELECT ON public.categories TO authenticated;

-- Idempotent: ensure junction table is readable when logged in.
ALTER TABLE public.book_categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "book_categories_select_authenticated" ON public.book_categories;
CREATE POLICY "book_categories_select_authenticated"
  ON public.book_categories
  FOR SELECT
  TO authenticated
  USING (true);
