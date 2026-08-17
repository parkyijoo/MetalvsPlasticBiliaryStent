# Biliary Stent PLE — Feasibility Check

본 분석 실행 전, 참여기관의 CDM에서 Cholangitis TK 결과 코호트에 필요한
measurement concept 매핑 상태를 확인하는 스크립트입니다.

## 확인 항목

T/C 코호트(Metal/Plastic stent with Pancreatic cancer) 환자의 index date
전후 30일 이내에 존재하는 **모든 measurement concept**을 집계합니다.

특히 아래 4개 concept이 기관 CDM에 존재하는지, 단위와 값 범위가 올바른지 확인합니다:

| Concept ID | LOINC | 이름 | 기대 단위 | 기대 범위 |
|---|---|---|---|---|
| 3024128 | 1975-2 | Total Bilirubin | mg/dL | 0.1 ~ 30 |
| 3000905 | 6690-2 | WBC count | 10*3/uL | 1 ~ 30 |
| 3020891 | 8310-5 | Body temperature | Cel | 35 ~ 42 |
| 3010156 | 30522-7 | CRP (high sensitivity) | mg/dL | 0.01 ~ 30 |

## 필요 패키지

```r
install.packages("DatabaseConnector")
install.packages("SqlRender")
install.packages("CohortGenerator")
install.packages("CirceR")
```

## 실행 방법

1. `CodeToRun.R`을 열고 **1. 기관별 설정** 섹션의 값을 수정합니다:
   - `connectionDetails`: DB 접속 정보
   - `cdmDatabaseSchema`: CDM 스키마
   - `cohortDatabaseSchema`: 코호트 테이블을 생성할 수 있는 스키마
   - `databaseId`: 기관 식별자 (예: "AMC", "SNUH")

2. 작업 디렉터리를 `feasibility/` 폴더로 설정합니다:
   ```r
   setwd("path/to/BiliaryStent260817/feasibility")
   ```

3. 스크립트를 실행합니다:
   ```r
   source("CodeToRun.R")
   ```

## 산출물

`feasibility_output/<databaseId>/` 폴더에 아래 CSV 파일이 생성됩니다:

- **measurement_coverage.csv**: 전체 measurement concept 목록
  - `MEASUREMENT_CONCEPT_ID`, `MEASUREMENT_NAME`, `VOCABULARY_ID`, `CONCEPT_CODE`
  - `UNIT_CONCEPT_ID`, `UNIT_NAME`
  - `N_PERSONS`, `N_RECORDS`, `N_WITH_VALUE`
  - `MIN_VALUE`, `MEAN_VALUE`, `MAX_VALUE`

- **measurement_value_dist.csv**: 핵심 4개 concept의 값 분포
  - `MIN_VALUE`, `P25`, `MEDIAN_VALUE`, `P75`, `MAX_VALUE`

모든 산출물은 **집계 데이터**이며 환자 단위 데이터를 포함하지 않습니다.
`min_cell_count = 5` 이하인 concept은 제외됩니다.

## 결과 전달

`feasibility_output/<databaseId>/` 폴더의 CSV 파일 2개를 중앙 연구팀에 전달해 주세요.

담당: Yiju Park (yijoo0320@yuhs.ac)
