-- Indexes for common query patterns (plan §5)

CREATE INDEX IF NOT EXISTS idx_user_book_status_user_id
  ON public.user_book_status (user_id);

CREATE INDEX IF NOT EXISTS idx_book_categories_category_id
  ON public.book_categories (category_id);
