-- Calculator quotations: customer contact for "Prepared for" on PDF
ALTER TABLE quotations
  ADD COLUMN IF NOT EXISTS customer_address TEXT,
  ADD COLUMN IF NOT EXISTS customer_phone TEXT;
