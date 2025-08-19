# -------------------------------------------------------
#                     PLEASE READ
# -------------------------------------------------------
#
# You must call "renv::restore()" and follow the prompts
# to install all of the necessary R libraries to run this
# project. This is a one-time operation that you must do
# before running any code.
#
# !!! PLEASE RESTART R AFTER RUNNING renv::restore() !!!
#
# -------------------------------------------------------
#renv::restore()

# ENVIRONMENT SETTINGS NEEDED FOR RUNNING Strategus ------------
Sys.setenv("_JAVA_OPTIONS"="-Xmx4g") # Sets the Java maximum heap space to 4GB
Sys.setenv("VROOM_THREADS"=1) # Sets the number of threads to 1 to avoid deadlocks on file system

##=========== START OF INPUTS ==========
cdmDatabaseSchema <- "main"
workDatabaseSchema <- "main"
outputLocation <- file.path(getwd(), "results")
databaseName <- "Eunomia" # Only used as a folder name for results from the study
minCellCount <- 5
cohortTableName <- "sample_study"

# Create the connection details for your CDM
# More details on how to do this are found here:
# https://ohdsi.github.io/DatabaseConnector/reference/createConnectionDetails.html
# connectionDetails <- DatabaseConnector::createConnectionDetails(
#   dbms = Sys.getenv("DBMS_TYPE"),
#   connectionString = Sys.getenv("CONNECTION_STRING"),
#   user = Sys.getenv("DBMS_USERNAME"),
#   password = Sys.getenv("DBMS_PASSWORD")
# )

# For this example we will use the Eunomia sample data 
# set. This library is not installed by default so you
# can install this by running:
#
# install.packages("Eunomia")
connectionDetails <- Eunomia::getEunomiaConnectionDetails()

# You can use this snippet to test your connection
#conn <- DatabaseConnector::connect(connectionDetails)
#DatabaseConnector::disconnect(conn)

##=========== END OF INPUTS ==========
analysisSpecifications <- ParallelLogger::loadSettingsFromJson(
  fileName = "inst/Eunomia/sampleStudy/sampleStudyAnalysisSpecification.json"
)

executionSettings <- Strategus::createCdmExecutionSettings(
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortTableNames = CohortGenerator::getCohortTableNames(cohortTable = cohortTableName),
  workFolder = file.path(outputLocation, databaseName, "strategusWork"),
  resultsFolder = file.path(outputLocation, databaseName, "strategusOutput"),
  minCellCount = minCellCount
)

if (!dir.exists(file.path(outputLocation, databaseName))) {
  dir.create(file.path(outputLocation, databaseName), recursive = T)
}
ParallelLogger::saveSettingsToJson(
  object = executionSettings,
  fileName = file.path(outputLocation, databaseName, "executionSettings.json")
)


# Custom Execution --------------------
# Step 1: Generate cohorts using Strategus - do not execute other analytical modules
executionSettings$modulesToExecute <- c("CohortGeneratorModule")
Strategus::execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  connectionDetails = connectionDetails
)

# Step 2: Create custom cohorts and append custom cohorts to results from Step 1
createCustomCohorts <- function(executionSettings, connectionDetails) {
  cli::cli_alert_info("Creating custom cohorts & writing results")
  sql <- SqlRender::readSql(
    sourceFile = "inst/Eunomia/sampleStudy/customCohorts.sql"
  )
  sql <- SqlRender::render(
    sql = sql,
    warnOnMissingParameters = TRUE,
    target_database_schema = executionSettings$workDatabaseSchema,
    target_cohort_table = executionSettings$cohortTableNames$cohortTable,
    cdm_database_schema = executionSettings$cdmDatabaseSchema
  )
  sql <- SqlRender::translate(
    sql = sql,
    targetDialect = connectionDetails$dbms
  )
  
  connection <- DatabaseConnector::connect(
    connectionDetails = connectionDetails
  )
  on.exit(DatabaseConnector::disconnect(connection))
  DatabaseConnector::executeSql(
    connection = connection,
    sql = sql
  )
  
  # Append the custom cohorts to existing cohort definition results
  customCohorts <- CohortGenerator::readCsv(
    file = "inst/Eunomia/sampleStudy/customCohorts.csv"
  )
    
  exportedCohorts <- CohortGenerator::readCsv(
    file = file.path(executionSettings$resultsFolder, "CohortGeneratorModule", "cg_cohort_definition.csv")
  ) |>
    dplyr::bind_rows(customCohorts)
  
  CohortGenerator::writeCsv(
    x = exportedCohorts,
    file = file.path(executionSettings$resultsFolder, "CohortGeneratorModule", "cg_cohort_definition.csv")
  )
  
  # Append the custom cohort counts
  cohortCounts <- CohortGenerator::readCsv(
    file = file.path(executionSettings$resultsFolder, "CohortGeneratorModule", "cg_cohort_count.csv")
  )
  customCohortCounts <- CohortGenerator::getCohortCounts(
    connection = connection,
    cohortDatabaseSchema = executionSettings$workDatabaseSchema,
    cohortTable = executionSettings$cohortTableNames$cohortTable,
    cohortIds = customCohorts$cohortDefinitionId,
    databaseId = unique(cohortCounts$databaseId)
  ) |>
    dplyr::bind_rows(cohortCounts)
  
  CohortGenerator::writeCsv(
    x = customCohortCounts,
    file = file.path(executionSettings$resultsFolder, "CohortGeneratorModule", "cg_cohort_count.csv")
  )
}
createCustomCohorts(
  executionSettings = executionSettings,
  connectionDetails = connectionDetails
)

# Step 3: Execute the full analysis specification, excluding CohortGenerator
allModules <- unlist(lapply(analysisSpecifications$moduleSpecifications, function(x) { x$module }))
modulesOtherThanCg <- allModules[allModules != "CohortGeneratorModule"]
executionSettings$modulesToExecute <- modulesOtherThanCg
Strategus::execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  connectionDetails = connectionDetails
)
