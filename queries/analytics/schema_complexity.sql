-- Schema Complexity vs Usage Analysis
-- Correlates schema field complexity with actual usage patterns to identify optimal schema designs.
SELECT 
  s.name as schema_name,
  length(s.field_names) as field_count,
  length(s.layout_buffer) / 2 as layout_size_bytes,
  COUNT(a.attestation_pda) as total_attestations,
  COUNT(CASE WHEN a.is_tokenized = 1 THEN 1 END) as tokenized_attestations,
  ROUND(COUNT(a.attestation_pda) * 1.0 / length(s.field_names), 2) as attestations_per_field,
  arrayStringConcat(s.field_names, ', ') as field_structure
FROM schemas_raw s
LEFT JOIN attestations_raw a ON s.schema_pda = a.schema_pda 
  AND a.instruction_type IN ('createAttestation', 'createTokenizedAttestation')
WHERE s.instruction_type = 'createSchema'
GROUP BY s.name, s.schema_pda, length(s.field_names), length(s.layout_buffer), arrayStringConcat(s.field_names, ', ')
ORDER BY total_attestations DESC;
