-- Table Status Check
-- Health check to verify all tables exist and have data
SELECT 
  table_name,
  MAX(slot) as latest_slot,
  MAX(timestamp) as latest_timestamp,
  COUNT(*) as total_records
FROM (
  SELECT 'credentials' as table_name, slot, timestamp FROM credentials_raw
  UNION ALL
  SELECT 'schemas' as table_name, slot, timestamp FROM schemas_raw
  UNION ALL
  SELECT 'attestations' as table_name, slot, timestamp FROM attestations_raw
  UNION ALL
  SELECT 'tokenization' as table_name, slot, timestamp FROM tokenization_raw
  UNION ALL
  SELECT 'events' as table_name, slot, timestamp FROM events_raw
) all_data
GROUP BY table_name
ORDER BY latest_slot DESC;
