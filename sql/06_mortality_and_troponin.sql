-- =====================================================================
-- 06_mortality_and_troponin.sql
-- 3-month mortality rate and troponin testing compliance for the
-- STEMI timeline cohort.
-- =====================================================================

DROP TABLE IF EXISTS stemi_deaths;

CREATE TEMPORARY TABLE stemi_deaths AS
  SELECT
  s.patient,
  s.ekg_encounter,
  s.ekg_start,
  p.deathdate,
  CASE
  WHEN p.deathdate IS NOT NULL
    AND p.deathdate <= s.ekg_start + INTERVAL '3 months'
  THEN 1
  ELSE 0
END AS stemi_death
FROM stemi_timeline s
JOIN patients p ON s.patient = p.id;

-- 3-month mortality summary
SELECT
  COUNT(DISTINCT patient) AS total_stemi_patients,
  COUNT(p.deathdate) AS total_deaths,
  ROUND(COUNT(p.deathdate) * 100.0 / COUNT(DISTINCT s.patient), 2) AS percent_total_deaths,
  SUM(CASE
        WHEN p.deathdate IS NOT NULL
          AND p.deathdate <= s.ekg_start + INTERVAL '3 months'
        THEN 1
        ELSE 0
      END) AS deaths_within_3_months,
  ROUND(SUM(CASE
        WHEN p.deathdate IS NOT NULL
          AND p.deathdate <= s.ekg_start + INTERVAL '3 months'
        THEN 1
        ELSE 0
      END) * 100.0 / COUNT(DISTINCT patient), 2) AS percent_deaths_within_3_months
FROM stemi_timeline s
JOIN patients p ON s.patient = p.id;
-- Result: 13% of the timeline cohort has a reported death date;
-- 7% of all timeline patients died within 3 months of their STEMI encounter

-- Distribution of time-to-death, for patients with a reported death date
SELECT
  CASE
    WHEN deathdate - ekg_start <= INTERVAL '3 months' THEN '1. < 3 months'
    WHEN deathdate - ekg_start > INTERVAL '3 months' AND deathdate - ekg_start <= INTERVAL '6 months' THEN '2. 3-6 months'
    WHEN deathdate - ekg_start > INTERVAL '6 months' AND deathdate - ekg_start <= INTERVAL '1 year' THEN '3. 6 months-1 year'
    WHEN deathdate - ekg_start > INTERVAL '1 year' AND deathdate - ekg_start <= INTERVAL '3 years' THEN '4. 1-3 years'
    WHEN deathdate - ekg_start > INTERVAL '3 years' AND deathdate - ekg_start <= INTERVAL '5 years' THEN '5. 3-5 years'
    ELSE '6. > 5 years'
  END AS time_stemi_to_death,
  COUNT(*) AS patient_count
FROM stemi_deaths
WHERE deathdate IS NOT NULL
GROUP BY time_stemi_to_death;

-- Troponin testing compliance (LOINC 89579-7, high-sensitivity cardiac troponin I)
WITH trop_labs AS (
  SELECT patient, encounter, code, description
  FROM observations
  WHERE code = '89579-7'
)
SELECT
  COUNT(s.patient) AS troponin_patient_count,
  ROUND((COUNT(s.patient) * 100.0 / SUM(COUNT(s.patient)) OVER ()), 2) AS troponin_percent
FROM stemi_timeline s
JOIN trop_labs t ON s.patient = t.patient AND s.ekg_encounter = t.encounter;
-- Result: 100% of STEMI patients received a troponin test during their STEMI encounter
