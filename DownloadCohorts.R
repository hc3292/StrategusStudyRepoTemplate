################################################################################
# INSTRUCTIONS: This script assumes you have cohorts you would like to use in an
# ATLAS instance. Please note you will need to update the baseUrl to match
# the settings for your enviroment. You will also want to change the 
# CohortGenerator::saveCohortDefinitionSet() function call arguments to identify
# a folder to store your cohorts. This code will store the cohorts in 
# "inst/sampleStudy" as part of the template for reference. You should store
# your settings in the root of the "inst" folder and consider removing the 
# "inst/sampleStudy" resources when you are ready to release your study.
# 
# See the Download cohorts section
# of the UsingThisTemplate.md for more details.
# ##############################################################################

library(dplyr)
baseUrl <- "https://nypdevops1.sis.nyp.org/api/WebAPI/"
# Use this if your WebAPI instance has security enables
#ROhdsiWebApi::authorizeWebApi(
#   baseUrl = baseUrl,
#   authMethod = "windows"
# )
cohortDefinitionSet <- ROhdsiWebApi::exportCohortDefinitionSet(
  baseUrl = baseUrl,
  cohortIds = c(
    11721, # sglt2i
    11722, # sulfonylurea
    11708, # T2DM
    11869 #UTI
  ),
  generateStats = TRUE
)

# Rename cohorts
cohortDefinitionSet[cohortDefinitionSet$cohortId == 11721,]$cohortName <- "SGLT2i"
cohortDefinitionSet[cohortDefinitionSet$cohortId == 11722,]$cohortName <- "SU"
cohortDefinitionSet[cohortDefinitionSet$cohortId == 11708,]$cohortName <- "T2DM"
cohortDefinitionSet[cohortDefinitionSet$cohortId == 11869,]$cohortName <- "UTI"

# Re-number cohorts
#cohortDefinitionSet[cohortDefinitionSet$cohortId == 11721,]$cohortId <- 1
#cohortDefinitionSet[cohortDefinitionSet$cohortId == 11722,]$cohortId <- 2
#cohortDefinitionSet[cohortDefinitionSet$cohortId == 11708,]$cohortId <- 3
#cohortDefinitionSet[cohortDefinitionSet$cohortId == 11869,]$cohortId <- 4


# Save the cohort definition set
# NOTE: Update settingsFileName, jsonFolder and sqlFolder
# for your study.
CohortGenerator::saveCohortDefinitionSet(
  cohortDefinitionSet = cohortDefinitionSet,
  settingsFileName = "inst/UTI_Study/Cohorts.csv",
  jsonFolder = "inst/UTI_Study/cohorts",
  sqlFolder = "inst/UTI_Study/sql/sql_server",
)

# switch it back to get this
baseUrl = "https://atlas-demo.ohdsi.org/WebAPI"
# Download and save the negative control outcomes
negativeControlOutcomeCohortSet <- ROhdsiWebApi::getConceptSetDefinition(
  conceptSetId = 1885090,
  baseUrl = baseUrl
) %>%
  ROhdsiWebApi::resolveConceptSet(
    baseUrl = baseUrl
  ) %>%
  ROhdsiWebApi::getConcepts(
    baseUrl = baseUrl
  ) %>%
  rename(outcomeConceptId = "conceptId",
         cohortName = "conceptName") %>%
  mutate(cohortId = row_number() + 100) %>%
  select(cohortId, cohortName, outcomeConceptId)

# NOTE: Update file location for your study.
CohortGenerator::writeCsv(
  x = negativeControlOutcomeCohortSet,
  file = "inst/UTI_Study/negativeControlOutcomes.csv",
  warnOnFileNameCaseMismatch = F
)
