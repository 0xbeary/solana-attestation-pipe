-- Most Complex Schemas
-- Schemas ranked by field count and layout size
SELECT 
  name,
  length(field_names) as field_count,
  length(layout_buffer) / 2 as layout_size_bytes,
  arrayStringConcat(field_names, ', ') as fields,
  timestamp as created_at
FROM schemas_raw 
WHERE instruction_type = 'createSchema'
ORDER BY field_count DESC, layout_size_bytes DESC
LIMIT 10;
