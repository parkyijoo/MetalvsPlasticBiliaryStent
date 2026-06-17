-- Codesets 정의
CREATE TABLE #Codesets (
  codeset_id int NOT NULL,
  concept_id bigint NOT NULL
);

INSERT INTO #Codesets (codeset_id, concept_id)
SELECT 3 as codeset_id, c.concept_id FROM (select distinct I.concept_id FROM
( 
  select concept_id from @vocabulary_database_schema.CONCEPT where concept_id in (3024128)
) I) C UNION ALL 
SELECT 5 as codeset_id, c.concept_id FROM (select distinct I.concept_id FROM
( 
  select concept_id from @vocabulary_database_schema.CONCEPT where concept_id in (3000905)
) I) C UNION ALL 
SELECT 6 as codeset_id, c.concept_id FROM (select distinct I.concept_id FROM
( 
  select concept_id from @vocabulary_database_schema.CONCEPT where concept_id in (3020891)
) I) C UNION ALL 
SELECT 7 as codeset_id, c.concept_id FROM (select distinct I.concept_id FROM
( 
  select concept_id from @vocabulary_database_schema.CONCEPT where concept_id in (3010156)
) I) C;

-- 메인 쿼리 시작
WITH 
-- 기본 측정값들을 CTE로 미리 정의
base_measurements_codeset6 AS (
  select m.person_id, m.measurement_id, m.measurement_date, m.value_as_number, m.visit_occurrence_id
  FROM @cdm_database_schema.MEASUREMENT m
  JOIN #Codesets codesets on m.measurement_concept_id = codesets.concept_id and codesets.codeset_id = 6
  WHERE m.value_as_number > 38.0000
),
base_measurements_codeset3 AS (
  select m.person_id, m.measurement_id, m.measurement_date, m.value_as_number, m.visit_occurrence_id
  FROM @cdm_database_schema.MEASUREMENT m
  JOIN #Codesets codesets on m.measurement_concept_id = codesets.concept_id and codesets.codeset_id = 3
  WHERE m.value_as_number > 2.0000
),
base_measurements_codeset5 AS (
  select m.person_id, m.measurement_id, m.measurement_date, m.value_as_number, m.visit_occurrence_id
  FROM @cdm_database_schema.MEASUREMENT m
  JOIN #Codesets codesets on m.measurement_concept_id = codesets.concept_id and codesets.codeset_id = 5
  WHERE m.value_as_number > 10.0000
),
base_measurements_codeset7 AS (
  select m.person_id, m.measurement_id, m.measurement_date, m.value_as_number, m.visit_occurrence_id
  FROM @cdm_database_schema.MEASUREMENT m
  JOIN #Codesets codesets on m.measurement_concept_id = codesets.concept_id and codesets.codeset_id = 7
  WHERE m.value_as_number >= 1.0000
),
-- Observation period와 조인된 기본 이벤트
events_with_op_codeset6 AS (
  SELECT 
    m.person_id, 
    m.measurement_id as event_id, 
    m.measurement_date as start_date, 
    DATEADD(d,1,m.measurement_date) as end_date,
    m.visit_occurrence_id,
    OP.observation_period_start_date as op_start_date, 
    OP.observation_period_end_date as op_end_date
  FROM base_measurements_codeset6 m
  JOIN @cdm_database_schema.OBSERVATION_PERIOD OP 
    on m.person_id = OP.person_id 
    and OP.observation_period_start_date <= m.measurement_date 
    and OP.observation_period_end_date >= m.measurement_date
),
events_with_op_codeset5 AS (
  SELECT 
    m.person_id, 
    m.measurement_id as event_id, 
    m.measurement_date as start_date, 
    DATEADD(d,1,m.measurement_date) as end_date,
    m.visit_occurrence_id,
    OP.observation_period_start_date as op_start_date, 
    OP.observation_period_end_date as op_end_date
  FROM base_measurements_codeset5 m
  JOIN @cdm_database_schema.OBSERVATION_PERIOD OP 
    on m.person_id = OP.person_id 
    and OP.observation_period_start_date <= m.measurement_date 
    and OP.observation_period_end_date >= m.measurement_date
),
-- 첫 번째 primary event 그룹 (codeset 6 + 3)
primary_events_group1 AS (
  SELECT DISTINCT
    P.person_id,
    P.event_id,
    P.start_date,
    P.end_date,
    P.op_start_date,
    P.op_end_date,
    P.visit_occurrence_id
  FROM events_with_op_codeset6 P
  WHERE EXISTS (
    SELECT 1
    FROM base_measurements_codeset3 A
    WHERE A.person_id = P.person_id
      AND A.measurement_date >= P.op_start_date 
      AND A.measurement_date <= P.op_end_date
      AND A.measurement_date >= P.start_date 
      AND A.measurement_date <= P.start_date
  )
),
-- 두 번째 primary event 그룹 (codeset 5 + 7 AND codeset 5 + 3)
primary_events_group2 AS (
  SELECT DISTINCT
    P.person_id,
    P.event_id,
    P.start_date,
    P.end_date,
    P.op_start_date,
    P.op_end_date,
    P.visit_occurrence_id
  FROM events_with_op_codeset5 P
  WHERE EXISTS (
    SELECT 1
    FROM base_measurements_codeset7 A
    WHERE A.person_id = P.person_id
      AND A.measurement_date >= P.op_start_date 
      AND A.measurement_date <= P.op_end_date
      AND A.measurement_date >= P.start_date 
      AND A.measurement_date <= P.start_date
  )
  AND EXISTS (
    SELECT 1
    FROM base_measurements_codeset3 A
    WHERE A.person_id = P.person_id
      AND A.measurement_date >= P.op_start_date 
      AND A.measurement_date <= P.op_end_date
      AND A.measurement_date >= P.start_date 
      AND A.measurement_date <= P.start_date
  )
),
-- Primary events 통합
all_primary_events AS (
  SELECT person_id, event_id, start_date, end_date, op_start_date, op_end_date, visit_occurrence_id
  FROM primary_events_group1
  UNION ALL
  SELECT person_id, event_id, start_date, end_date, op_start_date, op_end_date, visit_occurrence_id
  FROM primary_events_group2
),
primary_events AS (
  SELECT 
    row_number() OVER (PARTITION BY person_id ORDER BY start_date ASC) as event_id,
    person_id, 
    start_date, 
    end_date, 
    op_start_date, 
    op_end_date,
    cast(visit_occurrence_id as bigint) as visit_occurrence_id
  FROM all_primary_events
),
-- Qualified events
qualified_events AS (
  SELECT 
    event_id, 
    person_id, 
    start_date, 
    end_date, 
    op_start_date, 
    op_end_date,
    visit_occurrence_id,
    row_number() over (partition by person_id order by start_date ASC) as ordinal
  FROM primary_events
),
-- Included events (inclusion rules가 없으므로 모든 qualified events)
included_events AS (
  SELECT event_id, person_id, start_date, end_date, op_start_date, op_end_date
  FROM qualified_events
),
-- Cohort ends
cohort_ends AS (
  SELECT event_id, person_id, op_end_date as end_date 
  FROM included_events
),
-- First ends
first_ends AS (
  SELECT 
    I.person_id, 
    I.start_date, 
    MIN(E.end_date) as end_date
  FROM included_events I
  JOIN cohort_ends E 
    ON I.event_id = E.event_id 
    AND I.person_id = E.person_id 
    AND E.end_date >= I.start_date
  GROUP BY I.person_id, I.start_date
),
-- Cohort rows
cohort_rows AS (
  SELECT person_id, start_date, end_date
  FROM first_ends
),
-- End dates calculation
raw_events AS (
  SELECT
    person_id,
    start_date AS event_date,
    -1 AS event_type,
    ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY start_date) AS start_ordinal
  FROM cohort_rows
  UNION ALL
  SELECT
    person_id,
    DATEADD(day,0,end_date) as event_date,
    1 AS event_type,
    NULL as start_ordinal
  FROM cohort_rows
),
ranked_events AS (
  SELECT
    person_id,
    event_date,
    event_type,
    MAX(start_ordinal) OVER (PARTITION BY person_id ORDER BY event_date, event_type ROWS UNBOUNDED PRECEDING) AS start_ordinal,
    ROW_NUMBER() OVER (PARTITION BY person_id ORDER BY event_date, event_type) AS overall_ord
  FROM raw_events
),
end_dates AS (
  SELECT
    person_id,
    DATEADD(day,-1 * 0, event_date) as end_date
  FROM ranked_events
  WHERE (2 * start_ordinal) - overall_ord = 0
),
cohort_ends_final AS (
  SELECT
    c.person_id,
    c.start_date,
    MIN(e.end_date) AS end_date
  FROM cohort_rows c
  JOIN end_dates e ON c.person_id = e.person_id AND e.end_date >= c.start_date
  GROUP BY c.person_id, c.start_date
),
final_cohort AS (
  SELECT 
    person_id, 
    min(start_date) as start_date, 
    end_date
  FROM cohort_ends_final
  GROUP BY person_id, end_date
)
-- 최종 결과 삽입
SELECT 
  @target_cohort_id as cohort_definition_id, 
  person_id as subject_id, 
  start_date as cohort_start_date, 
  end_date as cohort_end_date
INTO #final_cohort_result
FROM final_cohort;

-- 기존 데이터 삭제 및 삽입
DELETE FROM @target_database_schema.@target_cohort_table 
WHERE cohort_definition_id = @target_cohort_id;

INSERT INTO @target_database_schema.@target_cohort_table 
  (cohort_definition_id, subject_id, cohort_start_date, cohort_end_date)
SELECT cohort_definition_id, subject_id, cohort_start_date, cohort_end_date
FROM #final_cohort_result;

-- 임시 테이블 정리
DROP TABLE #final_cohort_result;
DROP TABLE #Codesets;