-- Overall Data Summary
-- Basic overview of total instructions and time range
SELECT 
  COUNT(*) as total_instructions,
  COUNT(DISTINCT instruction_type) as unique_instruction_types,
  MIN(timestamp) as earliest_data,
  MAX(timestamp) as latest_data
FROM (
  SELECT instruction_type, timestamp FROM credentials_raw
  UNION ALL
  SELECT instruction_type, timestamp FROM schemas_raw
  UNION ALL
  SELECT instruction_type, timestamp FROM attestations_raw
  UNION ALL
  SELECT instruction_type, timestamp FROM tokenization_raw
  UNION ALL
  SELECT instruction_type, timestamp FROM events_raw
) all_instructions;
