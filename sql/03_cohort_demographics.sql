-- =====================================================================
-- 03_cohort_demographics.sql
-- Demographic and risk-factor profiling of the STEMI cohort:
-- age, gender, race/ethnicity, smoking status, hypertension.
-- =====================================================================

-- Age: summary statistics (as of 2023-12-31)
SELECT
  AVG(date_part('year', age('2023-12-31', birthdate))) AS avg_age,
  MIN(date_part('year', age('2023-12-31', birthdate))) AS min_age,
  MAX(date_part('year', age('2023-12-31', birthdate))) AS max_age
FROM stemi_cohort;

-- Age: distribution by bin
SELECT
    CASE
      WHEN date_part('year', age('2023-12-31', birthdate)) < 18 THEN '< 18'
      WHEN date_part('year', age('2023-12-31', birthdate)) BETWEEN 18 AND 35 THEN '18-35'
      WHEN date_part('year', age('2023-12-31', birthdate)) BETWEEN 36 AND 55 THEN '35-55'
      WHEN date_part('year', age('2023-12-31', birthdate)) BETWEEN 56 AND 65 THEN '56-65'
      WHEN date_part('year', age('2023-12-31', birthdate)) BETWEEN 66 AND 89 THEN '66-89'
      WHEN date_part('year', age('2023-12-31', birthdate)) > 89 THEN '> 89'
      ELSE 'Unknown Age Group'
    END AS age_group,
    COUNT(*) AS patient_count,
    ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()), 2) AS proportion_percent
FROM stemi_cohort
GROUP BY age_group
ORDER BY age_group ASC;
-- Result: 58% of patients fall between 66 and 89

-- Gender distribution
SELECT gender,
  COUNT(*) AS num_patients,
  ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()), 2) AS proportion_percent
FROM stemi_cohort
GROUP BY gender;
-- Result: 60% male

-- Race distribution
SELECT race,
  COUNT(*) AS num_patients,
  ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()), 2) AS proportion_percent
FROM stemi_cohort
GROUP BY race
ORDER BY num_patients DESC;
-- Result: 50% Black, 41% White

-- Ethnicity distribution
SELECT ethnicity,
  COUNT(*) AS num_patients,
  ROUND((COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()), 2) AS proportion_percent
FROM stemi_cohort
GROUP BY ethnicity
ORDER BY num_patients DESC;
-- Result: 80% non-Hispanic

-- Smoking status: most recent observation per patient (LOINC 72166-2)
WITH smokers AS (
  SELECT
      patient,
      CASE
        WHEN code = '72166-2' AND value = 'Smokes tobacco daily (finding)' THEN 'Current smoker'
        WHEN code = '72166-2' AND value = 'Ex-smoker (finding)' THEN 'Former smoker'
        WHEN code = '72166-2' AND value = 'Never smoked tobacco (finding)' THEN 'Never smoked'
      END AS smoking_status,
      ROW_NUMBER() OVER (PARTITION BY patient ORDER BY date DESC) AS rn
  FROM observations
  WHERE code = '72166-2'
)
SELECT
  smoking_status,
  COUNT(DISTINCT sm.patient) AS patient_count,
  ROUND((COUNT(DISTINCT sm.patient) * 100.0 /
        (SELECT COUNT(DISTINCT patient) FROM stemi_cohort)), 2) AS proportion_percent
FROM smokers sm
RIGHT JOIN stemi_cohort st ON sm.patient = st.patient
WHERE sm.rn = 1
GROUP BY smoking_status;
-- Result: 33% former smokers

-- Hypertension prevalence (SNOMED 59621000, essential hypertension)
WITH htn_patients AS (
  SELECT patient
  FROM conditions
  WHERE code = '59621000'
)
SELECT
  COUNT(DISTINCT s.patient) AS htn_patient_count,
  (SELECT COUNT(DISTINCT patient) FROM stemi_cohort) AS total_patient_count,
  ROUND((COUNT(DISTINCT s.patient) * 100.0 /
        (SELECT COUNT(DISTINCT patient) FROM stemi_cohort)), 2) AS htn_percent
FROM stemi_cohort s
JOIN htn_patients h ON s.patient = h.patient;
-- Result: 77% have a hypertension diagnosis
