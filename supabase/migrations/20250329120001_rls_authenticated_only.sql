-- RLS: authenticated users only (no anon access to app data)
-- Idempotent policies.

ALTER TABLE public.books ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.book_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_book_status ENABLE ROW LEVEL SECURITY;

-- books
DROP POLICY IF EXISTS "books_select_authenticated" ON public.books;
CREATE POLICY "books_select_authenticated"
  ON public.books
  FOR SELECT
  TO authenticated
  USING (true);

-- categories
DROP POLICY IF EXISTS "categories_select_authenticated" ON public.categories;
CREATE POLICY "categories_select_authenticated"
  ON public.categories
  FOR SELECT
  TO authenticated
  USING (true);

-- book_categories (junction)
DROP POLICY IF EXISTS "book_categories_select_authenticated" ON public.book_categories;
CREATE POLICY "book_categories_select_authenticated"
  ON public.book_categories
  FOR SELECT
  TO authenticated
  USING (true);

-- user_book_status: own rows only
DROP POLICY IF EXISTS "user_book_status_select_own" ON public.user_book_status;
DROP POLICY IF EXISTS "user_book_status_insert_own" ON public.user_book_status;
DROP POLICY IF EXISTS "user_book_status_update_own" ON public.user_book_status;
DROP POLICY IF EXISTS "user_book_status_delete_own" ON public.user_book_status;

CREATE POLICY "user_book_status_select_own"
  ON public.user_book_status
  FOR SELECT
  TO authenticated
  USING (user_id = auth.uid());

CREATE POLICY "user_book_status_insert_own"
  ON public.user_book_status
  FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_book_status_update_own"
  ON public.user_book_status
  FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "user_book_status_delete_own"
  ON public.user_book_status
  FOR DELETE
  TO authenticated
  USING (user_id = auth.uid());
