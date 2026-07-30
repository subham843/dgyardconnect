-- Atomic reorder for calculator question groups (avoids sort_order race / stale UI).

CREATE OR REPLACE FUNCTION reorder_calculator_question_groups(
  p_family_id UUID,
  p_group_ids UUID[]
) RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT auth_is_superadmin() THEN
    RAISE EXCEPTION 'not allowed';
  END IF;

  IF p_group_ids IS NULL OR cardinality(p_group_ids) = 0 THEN
    RETURN;
  END IF;

  -- Reject ids that do not belong to this family.
  IF EXISTS (
    SELECT 1
    FROM unnest(p_group_ids) AS x(id)
    WHERE NOT EXISTS (
      SELECT 1
      FROM calculator_question_groups g
      WHERE g.id = x.id AND g.family_id = p_family_id
    )
  ) THEN
    RAISE EXCEPTION 'group id not in family';
  END IF;

  -- Phase 1: unique temporary ranks (never collide with 0..n finals).
  UPDATE calculator_question_groups g
  SET sort_order = -100000 - s.ord::INT,
      updated_at = now()
  FROM unnest(p_group_ids) WITH ORDINALITY AS s(id, ord)
  WHERE g.id = s.id
    AND g.family_id = p_family_id;

  -- Phase 2: final 0-based order matching array position.
  UPDATE calculator_question_groups g
  SET sort_order = (s.ord - 1)::INT,
      updated_at = now()
  FROM unnest(p_group_ids) WITH ORDINALITY AS s(id, ord)
  WHERE g.id = s.id
    AND g.family_id = p_family_id;
END;
$$;

REVOKE ALL ON FUNCTION reorder_calculator_question_groups(UUID, UUID[]) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION reorder_calculator_question_groups(UUID, UUID[]) TO authenticated;
GRANT EXECUTE ON FUNCTION reorder_calculator_question_groups(UUID, UUID[]) TO service_role;

COMMENT ON FUNCTION reorder_calculator_question_groups(UUID, UUID[]) IS
  'Superadmin-only: set calculator_question_groups.sort_order to match p_group_ids order.';
