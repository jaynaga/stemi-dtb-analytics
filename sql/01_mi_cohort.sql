-- =====================================================================
-- 01_mi_cohort.sql
-- Build the base Myocardial Infarction (MI) cohort from a synthetic
-- Synthea-derived hospital database (PostgreSQL).
--
-- A patient enters the MI cohort if they have any of the following,
-- keyed on SNOMED-CT codes:
--   22298006   Myocardial infarction
--   401303003  Acute ST segment elevation myocardial infarction (disorder)
--   401314000  Acute non-ST segment elevation myocardial infarction (disorder)
-- across the encounters, conditions, and procedures tables.
--
-- Patients with only a *history* of MI (399211009) are excluded so the
-- cohort reflects a new diagnosis at this hospital, not a past event
-- carried in the record.
-- =====================================================================

DROP TABLE IF EXISTS mi_cohort;

CREATE TEMPORARY TABLE mi_cohort AS
WITH all_mi_patients AS (
    -- MI encounter
    SELECT
        patient,
        reasoncode AS diagnosis_code,
        reasondescription AS diagnosis_desc,
        start
    FROM encounters
    WHERE reasoncode IN ('22298006', '401303003', '401314000')

    UNION

    -- MI condition
    SELECT
        patient,
        code AS diagnosis_code,
        description AS diagnosis_desc,
        start
    FROM conditions
    WHERE code IN ('22298006', '401303003', '401314000')

    UNION

    -- MI procedure
    SELECT
        patient,
        reasoncode AS diagnosis_code,
        reasondescription AS diagnosis_desc,
        start
    FROM procedures
    WHERE reasoncode IN ('22298006', '401303003', '401314000')
),
-- If a patient has multiple diagnoses, keep only the most recent one
recent_diagnosis AS (
    SELECT
        patient,
        diagnosis_code,
        diagnosis_desc,
        MAX(start) AS most_recent_date
    FROM all_mi_patients
    GROUP BY patient, diagnosis_code, diagnosis_desc
),
most_recent_per_patient AS (
    SELECT DISTINCT ON (patient)
        patient,
        diagnosis_code,
        diagnosis_desc,
        most_recent_date
    FROM recent_diagnosis
    ORDER BY patient, most_recent_date DESC
)
SELECT
    m.patient,
    m.diagnosis_code,
    m.diagnosis_desc,
    m.most_recent_date,
    p.birthdate,
    p.deathdate,
    p.race,
    p.ethnicity,
    p.gender,
    p.city,
    p.state,
    p.zip
FROM most_recent_per_patient m
JOIN patients p
    ON p.id = m.patient;

-- Cohort size check
SELECT COUNT(DISTINCT patient) AS total_mi_patients
FROM mi_cohort;
-- Result: 1,680 patients
