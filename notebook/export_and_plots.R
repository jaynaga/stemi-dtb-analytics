# =====================================================================
# export_and_plots.R
# R snippets from the Quarto notebook (stemi_qi_report.qmd) that:
#   1) export SQL query results to CSV for the Tableau dashboard, and
#   2) visualize DTB time and mortality distributions with ggplot2.
#
# Run inside the notebook after establishing the `con` database
# connection and running the SQL in ../sql/.
# =====================================================================

library(tidyverse)
library(RPostgres)
library(connections)

# ---------------------------------------------------------------------
# Export the pre-intervention STEMI timeline (DTB dataset) for Tableau
# ---------------------------------------------------------------------
query1 <- "SELECT * FROM stemi_timeline"
stemi_timeline_pre_intervention <- dbGetQuery(con, query1)

timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
filename <- paste0("stemi_timeline_pre_intervention_", timestamp, ".csv")
write.csv(stemi_timeline_pre_intervention, filename, row.names = FALSE)

# ---------------------------------------------------------------------
# Plot: distribution of DTB times for STEMI patients
# (dtb_dist_df is produced by the SQL chunk with output.var = "dtb_dist_df")
# ---------------------------------------------------------------------
ggplot(dtb_dist_df, aes(x = dtb_bin, y = patient_count)) +
  geom_col(fill = "#041E42", color = "black") +
  labs(title = "Distribution of DTB Times for STEMI Patients",
       x = "DTB Time",
       y = "Patient Count") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# ---------------------------------------------------------------------
# Export the pre-intervention STEMI deaths table for Tableau
# ---------------------------------------------------------------------
query2 <- "SELECT * FROM stemi_deaths"
stemi_deaths_pre_intervention <- dbGetQuery(con, query2)

timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
filename <- paste0("stemi_deaths_pre_intervention_", timestamp, ".csv")
write.csv(stemi_deaths_pre_intervention, filename, row.names = FALSE)

# ---------------------------------------------------------------------
# Plot: distribution of STEMI patient deaths by time-to-death
# (death_dist_df is produced by the SQL chunk with output.var = "death_dist_df")
# ---------------------------------------------------------------------
ggplot(death_dist_df, aes(x = time_stemi_to_death, y = patient_count)) +
  geom_col(fill = "#041E42", color = "black") +
  labs(title = "Distribution of STEMI Patient Deaths",
       x = "Time from STEMI Encounter to Death",
       y = "Patient Count") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
