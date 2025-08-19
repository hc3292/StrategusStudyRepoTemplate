-- This script is used as an example when creating cohorts outside
-- of CohortGenerator & Strategus. This simple example creates 2 cohorts
-- of 100 patients with an odd & even person_id.
DELETE FROM @target_database_schema.@target_cohort_table 
where cohort_definition_id = 7001;

INSERT INTO @target_database_schema.@target_cohort_table (
  cohort_definition_id, 
  subject_id, 
  cohort_start_date, 
  cohort_end_date
)
SELECT TOP 100
  7001 as cohort_definition_id, 
  person_id, 
  observation_period_start_date, 
  observation_period_end_date 
FROM @cdm_database_schema.observation_period 
WHERE person_id % 2 = 1
;

DELETE FROM @target_database_schema.@target_cohort_table 
where cohort_definition_id = 7002;

INSERT INTO @target_database_schema.@target_cohort_table (
  cohort_definition_id, 
  subject_id, 
  cohort_start_date, 
  cohort_end_date
)
SELECT TOP 100
  7002 as cohort_definition_id, 
  person_id, 
  observation_period_start_date, 
  observation_period_end_date 
FROM @cdm_database_schema.observation_period 
WHERE person_id % 2 = 0
;