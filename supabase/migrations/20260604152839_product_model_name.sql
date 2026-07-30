-- Rename product_type to model_name (admin product form)

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'product_type'
  ) AND NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'products' AND column_name = 'model_name'
  ) THEN
    ALTER TABLE products RENAME COLUMN product_type TO model_name;
  END IF;
END $$;

COMMENT ON COLUMN products.model_name IS 'Manufacturer model number / name (e.g. DS-2CD1023G0-I)';
