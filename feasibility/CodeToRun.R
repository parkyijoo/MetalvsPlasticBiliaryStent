# =============================================================================
# Biliary Stent PLE — Feasibility Check
# T/C 코호트 전후 30일 이내 measurement concept 매핑 확인
# =============================================================================
#
# 목적:
#   본 분석 실행 전, 참여기관의 CDM에서 Cholangitis TK 결과 정의에 필요한
#   measurement concept(체온, WBC, CRP, Bilirubin)이 올바르게 매핑되어 있는지 확인.
#
# 산출물 (집계 데이터만, 환자 단위 데이터 없음):
#   1) measurement_coverage.csv  — 전체 measurement concept 목록 + 건수/값 범위
#   2) measurement_value_dist.csv — 핵심 4개 concept의 사분위 값 분포
#
# 필요 패키지:
#   DatabaseConnector, SqlRender, CohortGenerator, CirceR
# =============================================================================

library(DatabaseConnector)
library(SqlRender)
library(CohortGenerator)

# -----------------------------------------------------------------------------
# 1. 기관별 설정 — 아래 값을 참여기관 환경에 맞게 수정
# -----------------------------------------------------------------------------
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms     = "sql server",       # "postgresql", "redshift", "oracle" 등
  server   = "your_server",
  user     = "your_user",
  password = "your_password",
  pathToDriver = "path/to/jdbc/driver"
)

cdmDatabaseSchema     <- "CDM54.dbo"          # CDM 스키마
cohortDatabaseSchema  <- "scratch.dbo"        # 코호트 테이블을 생성할 스키마
cohortTable           <- "feasibility_bs"     # 코호트 테이블 이름
vocabularyDatabaseSchema <- cdmDatabaseSchema # vocabulary가 CDM과 같은 스키마인 경우

databaseId   <- "SITE_NAME"                   # 기관 식별자
outputFolder <- file.path(getwd(), "output", databaseId)

targetId     <- 851   # Metal stent with Pancreatic cancer
comparatorId <- 852   # Plastic stent with Pancreatic cancer
minCellCount <- 0     # 소규모 셀 억제 기준

# -----------------------------------------------------------------------------
# 2. 출력 폴더 생성
# -----------------------------------------------------------------------------
if (!dir.exists(outputFolder)) {
  dir.create(outputFolder, recursive = TRUE)
}

# -----------------------------------------------------------------------------
# 3. T/C 코호트 생성
# -----------------------------------------------------------------------------
message("== Step 1: T/C 코호트 생성 ==")

cohortJsonFiles <- list(
  list(cohortId = 851L, path = file.path("cohorts", "851.json")),
  list(cohortId = 852L, path = file.path("cohorts", "852.json"))
)

cohortDefinitionSet <- do.call(rbind, lapply(cohortJsonFiles, function(x) {
  json <- paste(readLines(x$path, warn = FALSE), collapse = "\n")
  expr <- CirceR::cohortExpressionFromJson(json)
  sql  <- CirceR::buildCohortQuery(
    expr,
    options = CirceR::createGenerateOptions(generateStats = FALSE)
  )
  data.frame(
    cohortId   = x$cohortId,
    cohortName = paste0("cohort_", x$cohortId),
    json       = json,
    sql        = sql,
    stringsAsFactors = FALSE
  )
}))

cohortTableNames <- CohortGenerator::getCohortTableNames(cohortTable = cohortTable)

# 코호트 테이블 생성
CohortGenerator::createCohortTables(
  connectionDetails    = connectionDetails,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTableNames     = cohortTableNames
)

# 코호트 instantiation
cohortsGenerated <- CohortGenerator::generateCohortSet(
  connectionDetails    = connectionDetails,
  cdmDatabaseSchema    = cdmDatabaseSchema,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTableNames     = cohortTableNames,
  cohortDefinitionSet  = cohortDefinitionSet
)
message("코호트 생성 완료:")
print(cohortsGenerated)

# go/no-go: T/C 코호트 수 확인
cohortCounts <- CohortGenerator::getCohortCounts(
  connectionDetails    = connectionDetails,
  cohortDatabaseSchema = cohortDatabaseSchema,
  cohortTable          = cohortTable,
  cohortIds            = c(targetId, comparatorId)
)
message("코호트 건수:")
print(cohortCounts)

if (all(cohortCounts$cohortSubjects == 0)) {
  stop("T/C 코호트 모두 0명입니다. CDM 스키마와 코호트 정의를 확인하세요.")
}

# -----------------------------------------------------------------------------
# 4. Measurement Coverage — 전체 measurement concept 탐색
# -----------------------------------------------------------------------------
message("== Step 2: Measurement coverage 조회 ==")

connection <- DatabaseConnector::connect(connectionDetails)
on.exit(DatabaseConnector::disconnect(connection), add = TRUE)

sqlCoverage <- SqlRender::readSql(file.path("sql", "MeasurementCoverage.sql"))
sqlCoverage <- SqlRender::render(
  sql                     = sqlCoverage,
  cdm_database_schema     = cdmDatabaseSchema,
  cohort_database_schema  = cohortDatabaseSchema,
  cohort_table            = cohortTable,
  target_id               = targetId,
  comparator_id           = comparatorId,
  min_cell_count          = minCellCount
)
sqlCoverage <- SqlRender::translate(sqlCoverage, targetDialect = connectionDetails$dbms)

coverage <- DatabaseConnector::querySql(connection, sqlCoverage)

write.csv(coverage, file.path(outputFolder, "measurement_coverage.csv"), row.names = FALSE)
message(sprintf("measurement_coverage.csv 저장 완료 (%d rows)", nrow(coverage)))

# -----------------------------------------------------------------------------
# 5. Measurement Value Distribution — 핵심 4개 concept 사분위
# -----------------------------------------------------------------------------
message("== Step 3: 핵심 measurement 값 분포 조회 ==")

sqlDist <- SqlRender::readSql(file.path("sql", "MeasurementValueDistribution.sql"))
sqlDist <- SqlRender::render(
  sql                     = sqlDist,
  cdm_database_schema     = cdmDatabaseSchema,
  cohort_database_schema  = cohortDatabaseSchema,
  cohort_table            = cohortTable,
  target_id               = targetId,
  comparator_id           = comparatorId
)
sqlDist <- SqlRender::translate(sqlDist, targetDialect = connectionDetails$dbms)

valueDist <- DatabaseConnector::querySql(connection, sqlDist)

write.csv(valueDist, file.path(outputFolder, "measurement_value_dist.csv"), row.names = FALSE)
message(sprintf("measurement_value_dist.csv 저장 완료 (%d rows)", nrow(valueDist)))

# -----------------------------------------------------------------------------
# 6. 핵심 concept 매핑 확인 요약
# -----------------------------------------------------------------------------
message("\n== 핵심 Measurement Concept 매핑 확인 ==")

keyConcepts <- data.frame(
  concept_id   = c(3024128, 3000905, 3020891, 3010156),
  concept_name = c("Total Bilirubin", "WBC count", "Body temperature", "CRP (hs)"),
  loinc_code   = c("1975-2", "6690-2", "8310-5", "30522-7"),
  stringsAsFactors = FALSE
)

for (i in seq_len(nrow(keyConcepts))) {
  cid <- keyConcepts$concept_id[i]
  matched <- coverage[coverage$MEASUREMENT_CONCEPT_ID == cid, ]
  if (nrow(matched) > 0) {
    message(sprintf("  [OK] %s (concept %d): %d persons, %d records",
                    keyConcepts$concept_name[i], cid,
                    sum(matched$N_PERSONS), sum(matched$N_RECORDS)))
  } else {
    message(sprintf("  [!!] %s (concept %d): NOT FOUND — 이 기관에서 다른 LOINC에 매핑되었을 수 있음",
                    keyConcepts$concept_name[i], cid))
  }
}

message(sprintf(
  "\n산출물 경로: %s\n이 폴더의 CSV 파일을 연구팀에 전달해 주세요.",
  normalizePath(outputFolder)
))
