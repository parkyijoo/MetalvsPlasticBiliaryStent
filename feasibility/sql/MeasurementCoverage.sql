-- MeasurementCoverage.sql
-- T/C 코호트(851, 852) index date 전후 30일 이내 모든 measurement concept 집계
-- SqlRender 파라미터: @cdm_database_schema, @cohort_database_schema, @cohort_table,
--                     @target_id, @comparator_id, @min_cell_count

SELECT
  m.measurement_concept_id,
  c.concept_name                              AS measurement_name,
  c.vocabulary_id,
  c.concept_code,
  COALESCE(m.unit_concept_id, 0)              AS unit_concept_id,
  COALESCE(u.concept_name, 'No unit')         AS unit_name,
  COUNT(DISTINCT m.person_id)                 AS n_persons,
  COUNT(*)                                    AS n_records,
  SUM(CASE WHEN m.value_as_number IS NOT NULL THEN 1 ELSE 0 END) AS n_with_value,
  MIN(m.value_as_number)                      AS min_value,
  AVG(m.value_as_number * 1.0)                AS mean_value,
  MAX(m.value_as_number)                      AS max_value
FROM @cohort_database_schema.@cohort_table co
INNER JOIN @cdm_database_schema.measurement m
  ON co.subject_id = m.person_id
  AND m.measurement_date >= DATEADD(day, -30, co.cohort_start_date)
  AND m.measurement_date <= DATEADD(day,  30, co.cohort_start_date)
INNER JOIN @cdm_database_schema.concept c
  ON m.measurement_concept_id = c.concept_id
LEFT JOIN @cdm_database_schema.concept u
  ON m.unit_concept_id = u.concept_id
WHERE co.cohort_definition_id IN (@target_id, @comparator_id)
GROUP BY
  m.measurement_concept_id,
  c.concept_name,
  c.vocabulary_id,
  c.concept_code,
  COALESCE(m.unit_concept_id, 0),
  COALESCE(u.concept_name, 'No unit')
HAVING COUNT(DISTINCT m.person_id) >= @min_cell_count
ORDER BY n_persons DESC;
