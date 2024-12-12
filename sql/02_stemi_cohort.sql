-- =====================================================================
-- 02_stemi_cohort.sql
-- Narrow the MI cohort (see 01_mi_cohort.sql) down to a STEMI cohort:
-- patients with a documented EKG, a cardiology consultation, and a PCI
-- procedure, all tied back to the MI diagnosis.
-- =====================================================================

DROP TABLE IF EXISTS stemi_cohort;

CREATE TEMPORARY TABLE stemi_cohort AS

WITH ekg_patients AS (
  SELECT patient
  FROM procedures
  WHERE code = '29303009'   -- Electrocardiographic procedure (procedure)
     OR code = '268400002'  -- 12 lead electrocardiogram (procedure)
)

, cardio_consult_patients AS (
  SELECT patient
  FROM procedures
  WHERE code = '698314001'  -- Consultation for treatment (procedure)
)

, pci_patients AS (
  SELECT patient
  FROM procedures
  WHERE code = '415070008'  -- Percutaneous coronary intervention (procedure)
)

SELECT
  DISTINCT pci.patient,
  p.birthdate,
  p.deathdate,
  p.race,
  p.ethnicity,
  p.gender,
  p.city,
  p.state,
  p.zip
FROM pci_patients pci
JOIN patients p ON pci.patient = p.id
JOIN ekg_patients ekg ON pci.patient = ekg.patient
JOIN cardio_consult_patients cons ON pci.patient = cons.patient
WHERE pci.patient IN (SELECT patient FROM mi_cohort);

-- Referential sanity check: every STEMI patient must also be an MI patient (expect 0)
SELECT COUNT(*)
FROM stemi_cohort s
WHERE s.patient NOT IN (SELECT patient FROM mi_cohort);

-- Uniqueness check: one row per patient (both counts should match)
SELECT COUNT(patient) AS all_patients,
       COUNT(DISTINCT patient) AS distinct_patients
FROM stemi_cohort;

-- Cohort funnel: STEMI cohort as a share of the broader MI cohort
SELECT
  (SELECT COUNT(DISTINCT patient) FROM mi_cohort) AS mi_cohort_count,
  (SELECT COUNT(DISTINCT patient) FROM stemi_cohort) AS stemi_cohort_count,
  ROUND((COUNT(DISTINCT stemi_cohort.patient) * 100.0 /
        (SELECT COUNT(DISTINCT mi_cohort.patient) FROM mi_cohort)), 2) AS percent_stemi_from_mi
FROM stemi_cohort;
-- Result: 441 patients, ~26% of the MI cohort
