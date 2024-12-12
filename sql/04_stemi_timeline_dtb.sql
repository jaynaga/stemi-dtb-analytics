-- =====================================================================
-- 04_stemi_timeline_dtb.sql
-- Build a per-patient event timeline (EKG -> cardiology consult -> PCI)
-- and calculate door-to-balloon (DTB) time: the interval between EKG
-- start and PCI start. This table is the source of truth for the
-- primary DTB quality metric and feeds the Tableau dashboard.
--
-- Filters applied:
--   - only the most recent EKG / consult / PCI procedure per patient
--   - drop internally inconsistent (negative-duration) records
--   - require all three steps to fall in the same calendar year
--   - require total DTB time under 24 hours (86,400 seconds)
-- =====================================================================

DROP TABLE IF EXISTS stemi_timeline;

CREATE TEMPORARY TABLE stemi_timeline AS

WITH ekg_patients AS (
  SELECT
    patient,
    encounter AS ekg_encounter,
    start AS ekg_start,
    stop AS ekg_stop,
    code AS ekg_code,
    description AS ekg_desc,
    EXTRACT(YEAR FROM start) AS ekg_year,
    ROW_NUMBER() OVER (PARTITION BY patient ORDER BY start DESC) AS ekg_rank
  FROM procedures
  WHERE code = '29303009'
     OR code = '268400002'
)

, cardio_consult_patients AS (
  SELECT
    patient,
    encounter AS consult_encounter,
    start AS consult_start,
    stop AS consult_stop,
    code AS consult_code,
    description AS consult_desc,
    EXTRACT(YEAR FROM start) AS consult_year,
    ROW_NUMBER() OVER (PARTITION BY patient ORDER BY start DESC) AS consult_rank
  FROM procedures
  WHERE code = '698314001'
)

, pci_patients AS (
  SELECT
    patient,
    encounter AS pci_encounter,
    start AS pci_start,
    stop AS pci_stop,
    EXTRACT(YEAR FROM start) AS pci_year,
    ROW_NUMBER() OVER (PARTITION BY patient ORDER BY start DESC) AS pci_rank
  FROM procedures
  WHERE code = '415070008'
)

SELECT
  s.patient,
  e.ekg_encounter,
  c.consult_encounter,
  p.pci_encounter,
  e.ekg_start,
  e.ekg_stop,
  c.consult_start,
  c.consult_stop,
  p.pci_start,
  p.pci_stop,
  ROUND(EXTRACT(EPOCH FROM (e.ekg_stop - e.ekg_start)) / 60, 2) AS ekg_duration_minutes,
  ROUND(EXTRACT(EPOCH FROM (c.consult_start - e.ekg_stop)) / 60, 2) AS ekg_to_consult_minutes,
  ROUND(EXTRACT(EPOCH FROM (c.consult_stop - c.consult_start)) / 60, 2) AS consult_duration_minutes,
  ROUND(EXTRACT(EPOCH FROM (p.pci_start - c.consult_stop)) / 60, 2) AS consult_to_pci_minutes,
  ROUND(EXTRACT(EPOCH FROM (p.pci_stop - p.pci_start)) / 60, 2) AS pci_duration_minutes,
  ROUND(EXTRACT(EPOCH FROM (p.pci_start - e.ekg_start)) / 60, 2) AS dtb_minutes
FROM stemi_cohort s
JOIN ekg_patients e ON s.patient = e.patient
JOIN cardio_consult_patients c ON s.patient = c.patient
JOIN pci_patients p ON s.patient = p.patient
WHERE p.pci_rank = 1
  AND e.ekg_rank = 1
  AND c.consult_rank = 1
  AND EXTRACT(EPOCH FROM (e.ekg_stop - e.ekg_start)) >= 0
  AND EXTRACT(EPOCH FROM (c.consult_stop - c.consult_start)) >= 0
  AND EXTRACT(EPOCH FROM (p.pci_stop - p.pci_start)) >= 0
  AND EXTRACT(EPOCH FROM (p.pci_start - e.ekg_start)) >= 0
  AND e.ekg_year = c.consult_year
  AND c.consult_year = p.pci_year
  AND EXTRACT(EPOCH FROM (p.pci_start - e.ekg_start)) <= 86400
ORDER BY p.patient;
-- Result: 214-215 patients with a complete, internally consistent timeline

-- Sanity check: one row per patient
SELECT COUNT(DISTINCT patient) AS distinct_count,
       COUNT(patient) AS all_patients
FROM stemi_timeline;

-- Confirm timeline patients were admitted via the Emergency Department
SELECT
  COUNT(DISTINCT s.patient) AS patient_count,
  e.encounterclass,
  e.description
FROM stemi_timeline s
JOIN encounters e ON s.patient = e.patient AND s.ekg_encounter = e.id
WHERE encounterclass = 'emergency'
GROUP BY e.encounterclass, e.description;

-- DTB time distribution (primary quality metric)
SELECT
  CASE
    WHEN dtb_minutes < 30 THEN '<30 minutes'
    WHEN dtb_minutes BETWEEN 31 AND 60 THEN '31-60 minutes'
    WHEN dtb_minutes BETWEEN 61 AND 90 THEN '61-90 minutes'
    WHEN dtb_minutes > 90 THEN '>90 minutes'
    ELSE 'Unknown'
  END AS dtb_bin,
  COUNT(patient) AS patient_count,
  ROUND((COUNT(patient) * 100.0 / SUM(COUNT(patient)) OVER ()), 2) AS proportion_percent
FROM stemi_timeline
GROUP BY dtb_bin
ORDER BY dtb_bin;
-- Result: 95% of patients under 30 minutes; ~4% (8 of 214) exceed the 90-minute guideline

-- Outcomes for the 8 patients who exceeded the 90-minute DTB guideline
SELECT
  patient,
  ekg_start,
  dtb_minutes,
  deathdate,
  CASE
    WHEN (deathdate - ekg_start) <= INTERVAL '3 months' THEN 1
    ELSE 0
  END AS stemi_death
FROM stemi_timeline
JOIN patients ON stemi_timeline.patient = patients.id
WHERE dtb_minutes >= 90;
-- Result: 1 of 8 delayed patients had a reported death within 3 months
-- (sample too small to establish a DTB-to-mortality relationship on its own)
