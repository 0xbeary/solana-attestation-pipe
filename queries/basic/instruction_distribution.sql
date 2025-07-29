-- Instruction Type Distribution
-- Breakdown of all instruction types and their frequency
SELECT 
  instruction_type,
  COUNT(*) as count,
  COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() as percentage
FROM (
  SELECT instruction_type FROM credentials_raw
  UNION ALL
  SELECT instruction_type FROM schemas_raw
  UNION ALL
  SELECT instruction_type FROM attestations_raw
  UNION ALL
  SELECT instruction_type FROM tokenization_raw
  UNION ALL
  SELECT instruction_type FROM events_raw
) all_instructions
GROUP BY instruction_type
ORDER BY count DESC;
