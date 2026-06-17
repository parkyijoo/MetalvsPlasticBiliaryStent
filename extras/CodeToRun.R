.libPaths("/home/yuhsuser/root_library")

renv::deactivate()
.libPaths()

library(DatabaseConnector)
library(BS260205)

# Optional: specify where the temporary files (used by the Andromeda package) will be created:
options(andromedaTempFolder = "s:/andromedaTemp")

# Maximum number of cores to be used:
maxCores <- parallel::detectCores()

# The folder where the study intermediate and result files will be written:
outputFolder <- "/home/yuhsuser/Desktop/yjpark/BS260205/output/BS_db26_260611"
options(andromedaTempFolder = file.path(outputFolder, "andromedaTemp"))

# Details for connecting to the server:
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "sql server",
                                                                server = "10.8.10.76",
                                                                user = "cdm_sel_user",
                                                                password = "cdmtkdydwk@#",
                                                                pathToDriver = "/home/yuhsuser/jdbcDriver")

connection <- DatabaseConnector::connect(connectionDetails)

# The name of the database schema where the CDM data can be found:
cdmDatabaseSchema <- "CDM54_2601.CDM"
vocabularyDatabaseSchema <- "CDM54_2601.CDM"

# The name of the database schema and table where the study-specific cohorts will be instantiated:
cohortDatabaseSchema <- "CohortDB.dbo"
cohortTable <- "C20261231_yjpark_BiliaryStent_PS_260611"

# Some meta-information that will be used by the export function:
databaseId <- "YUHS"
databaseName <- "YUHS"

databaseDescription <- "YUHS"
Sys.setlocale(category = "LC_ALL", locale = "english")

# For Oracle: define a schema that can be used to emulate temp tables:
oracleTempSchema <- NULL

execute(connectionDetails = connectionDetails,
        cdmDatabaseSchema = cdmDatabaseSchema,
        cohortDatabaseSchema = cohortDatabaseSchema,
        cohortTable = cohortTable,
        oracleTempSchema = oracleTempSchema,
        outputFolder = outputFolder,
        databaseId = databaseId,
        databaseName = databaseName,
        databaseDescription = databaseDescription,
        createCohorts = TRUE,
        synthesizePositiveControls = FALSE,
        runAnalyses = TRUE,
        packageResults = TRUE,
        maxCores = maxCores)

resultsZipFile <- file.path(outputFolder, "export", paste0("Results_", databaseId, ".zip"))
dataFolder <- file.path(outputFolder, "shinyData")

# You can inspect the results if you want:
prepareForEvidenceExplorer(resultsZipFile = resultsZipFile, dataFolder = dataFolder)
launchEvidenceExplorer(dataFolder = dataFolder, blind = FALSE, launch.browser = FALSE)

