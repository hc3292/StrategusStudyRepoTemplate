customCohorts <- tibble::tibble(
  cohortDefinitionId = c(7001, 7002),
  cohortName = c("Custom cohort - odd numbered patients", "Custom cohort - odd numbered patients"),
  description = c("", ""),
  json = c("{}", "{}"),
  sqlCommand = c("", ""),
  subsetParent = c(7001, 7002),
  isSubset = c(FALSE, FALSE),
  subsetDefinitionId = c(NA, NA)
)
CohortGenerator::writeCsv(
  x = customCohorts,
  file = "inst/Eunomia/sampleStudy/customCohorts.csv"
)