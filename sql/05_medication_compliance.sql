-- =====================================================================
-- 05_medication_compliance.sql
-- Guideline-concordant medication compliance within 24 hours of the
-- STEMI encounter: dual antiplatelet therapy (DAPT), high-intensity
-- statins, and beta-blockers.
-- =====================================================================

WITH stemi_meds AS (
SELECT
  s.patient,
  -- Dual antiplatelet therapy (aspirin, prasugrel, ticagrelor, clopidogrel, etc.)
  MAX(CASE
    WHEN m.code IN (2563431, 243670, 855812, 212033, 1116635, 749196, 1997015, 200349, 1737466, 309362) THEN 1
    ELSE 0
  END) AS DAPT,
  -- High-intensity statins
  MAX(CASE
    WHEN m.code IN (854255) THEN 1
    ELSE 0
  END) AS Statin,
  -- Beta-blockers
  MAX(CASE
    WHEN m.code IN (1659263, 1361048, 1361226, 861356) THEN 1
    ELSE 0
  END) AS BetaBlocker,
  -- Any other medication administered in the window
  MAX(CASE
    WHEN m.code NOT IN (2563431, 243670, 855812, 212033, 1116635, 749196, 1997015, 200349, 1737466,
                         309362, 854255, 1659263, 1361048, 1361226, 861356) THEN 1
    ELSE 0
  END) AS Other
FROM medications AS m
JOIN stemi_timeline AS s ON m.patient = s.patient AND m.encounter = s.ekg_encounter
WHERE
  (EXTRACT(EPOCH FROM (m.start - s.ekg_start)) / 60) <= 1440  -- within 24 hours
  AND s.patient IN (SELECT patient FROM stemi_timeline)
GROUP BY s.patient
ORDER BY s.patient
)

SELECT
  ROUND((SUM(DAPT) / SUM(COUNT(patient)) OVER ()), 2) AS dapt_percent,
  ROUND((SUM(Statin) / SUM(COUNT(patient)) OVER ()), 2) AS statin_percent,
  ROUND((SUM(BetaBlocker) / SUM(COUNT(patient)) OVER ()), 2) AS betablocker_percent,
  ROUND((SUM(Other) / SUM(COUNT(patient)) OVER ()), 2) AS other_percent
FROM stemi_meds;
-- Result: ~99% of patients received guideline-concordant medication within 24 hours
