-- MeasurementValueDistribution.sql
-- Cholangitis TK 정의에 사용되는 핵심 measurement concept의 값 분포 (사분위)
-- PERCENTILE_CONT 대신 NTILE 사용 (SqlRender 이식성)
-- SqlRender 파라미터: @cdm_database_schema, @cohort_database_schema, @cohort_table,
--                     @target_id, @comparator_id

WITH measurements AS (
  SELECT
    m.measurement_concept_id,
    m.value_as_number,
    COALESCE(m.unit_concept_id, 0) AS unit_concept_id,
    NTILE(4) OVER (
      PARTITION BY m.measurement_concept_id, COALESCE(m.unit_concept_id, 0)
      ORDER BY m.value_as_number
    ) AS quartile
  FROM @cohort_database_schema.@cohort_table co
  INNER JOIN @cdm_database_schema.measurement m
    ON co.subject_id = m.person_id
    AND m.measurement_date >= DATEADD(day, -30, co.cohort_start_date)
    AND m.measurement_date <= DATEADD(day,  30, co.cohort_start_date)
  WHERE co.cohort_definition_id IN (@target_id, @comparator_id)
    AND m.value_as_number IS NOT NULL
    AND m.measurement_concept_id IN (
      3024128,  -- Total Bilirubin  (LOINC 1975-2)
      3000905,  -- WBC count         (LOINC 6690-2)
      3020891,  -- Body temperature  (LOINC 8310-5)
      3010156   -- CRP hs            (LOINC 30522-7)
    )
)
SELECT
  q.measurement_concept_id,
  c.concept_name                        AS measurement_name,
  c.concept_code,
  q.unit_concept_id,
  COALESCE(u.concept_name, 'No unit')   AS unit_name,
  COUNT(*)                              AS n_records,
  MIN(q.value_as_number)                AS min_value,
  MAX(CASE WHEN q.quartile = 1 THEN q.value_as_number END) AS p25,
  MAX(CASE WHEN q.quartile = 2 THEN q.value_as_number END) AS median_value,
  MAX(CASE WHEN q.quartile = 3 THEN q.value_as_number END) AS p75,
  MAX(q.value_as_number)                AS max_value
FROM measurements q
INNER JOIN @cdm_database_schema.concept c
  ON q.measurement_concept_id = c.concept_id
LEFT JOIN @cdm_database_schema.concept u
  ON q.unit_concept_id = u.concept_id
GROUP BY
  q.measurement_concept_id,
  c.concept_name,
  c.concept_code,
  q.unit_concept_id,
  COALESCE(u.concept_name, 'No unit')
ORDER BY q.measurement_concept_id;
