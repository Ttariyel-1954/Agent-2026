# =============================================
# İnstitut Strukturu: Unit Testlər
# =============================================

library(testthat)

# Sabitləri yüklə (layihə kökünə nisbətən)
project_root <- normalizePath(file.path(dirname(sys.frame(1)$ofile %||% "."), ".."), mustWork = FALSE)
if (!file.exists(file.path(project_root, "R", "constants.R"))) {
  project_root <- normalizePath(file.path(getwd(), ".."), mustWork = FALSE)
}
source(file.path(project_root, "R", "constants.R"))
source(file.path(project_root, "modules", "institute", "institute_helpers.R"))

# =============================================
# 1. validate_unit_data() testləri
# =============================================

test_that("validate_unit_data: düzgün data keçir", {
  result <- validate_unit_data(list(name = "Test Mərkəz", unit_type = "merkez"))
  expect_true(result$valid)
  expect_length(result$errors, 0)
})

test_that("validate_unit_data: boş ad rədd olunur", {
  result <- validate_unit_data(list(name = "", unit_type = "merkez"))
  expect_false(result$valid)
  expect_true(any(grepl("boş", result$errors)))
})

test_that("validate_unit_data: NULL ad rədd olunur", {
  result <- validate_unit_data(list(name = NULL, unit_type = "merkez"))
  expect_false(result$valid)
})

test_that("validate_unit_data: yanlış unit_type rədd olunur", {
  result <- validate_unit_data(list(name = "Test", unit_type = "yanlis_tip"))
  expect_false(result$valid)
  expect_true(any(grepl("vahid növü", result$errors)))
})

test_that("validate_unit_data: boşluqlu ad rədd olunur", {
  result <- validate_unit_data(list(name = "   ", unit_type = "shobe"))
  expect_false(result$valid)
})

# =============================================
# 2. validate_resource_data() testləri
# =============================================

test_that("validate_resource_data: düzgün data keçir", {
  result <- validate_resource_data(list(
    name = "Kompüter", resource_type = "avadanliq",
    unit_id = "abc-123", budget_amount = 5000
  ))
  expect_true(result$valid)
})

test_that("validate_resource_data: boş ad rədd olunur", {
  result <- validate_resource_data(list(
    name = "", resource_type = "avadanliq", unit_id = "abc-123"
  ))
  expect_false(result$valid)
})

test_that("validate_resource_data: yanlış resurs növü rədd olunur", {
  result <- validate_resource_data(list(
    name = "Test", resource_type = "yanlis", unit_id = "abc-123"
  ))
  expect_false(result$valid)
})

test_that("validate_resource_data: boş unit_id rədd olunur", {
  result <- validate_resource_data(list(
    name = "Test", resource_type = "budce", unit_id = ""
  ))
  expect_false(result$valid)
})

test_that("validate_resource_data: mənfi büdcə rədd olunur", {
  result <- validate_resource_data(list(
    name = "Test", resource_type = "budce", unit_id = "abc", budget_amount = -100
  ))
  expect_false(result$valid)
  expect_true(any(grepl("mənfi", result$errors)))
})

test_that("validate_resource_data: NULL büdcə icazə verilir", {
  result <- validate_resource_data(list(
    name = "Test", resource_type = "budce", unit_id = "abc", budget_amount = NULL
  ))
  expect_true(result$valid)
})

# =============================================
# 3. validate_personnel_data() testləri
# =============================================

test_that("validate_personnel_data: düzgün data keçir", {
  result <- validate_personnel_data(list(
    full_name = "Əli Əliyev", personnel_type = "emedkas", unit_id = "abc-123"
  ))
  expect_true(result$valid)
})

test_that("validate_personnel_data: boş ad rədd olunur", {
  result <- validate_personnel_data(list(
    full_name = "", personnel_type = "emedkas", unit_id = "abc-123"
  ))
  expect_false(result$valid)
})

test_that("validate_personnel_data: yanlış tip rədd olunur", {
  result <- validate_personnel_data(list(
    full_name = "Test", personnel_type = "yanlis", unit_id = "abc-123"
  ))
  expect_false(result$valid)
})

test_that("validate_personnel_data: bütün personal tipləri qəbul olunur", {
  for (ptype in names(PERSONNEL_TYPES)) {
    result <- validate_personnel_data(list(
      full_name = "Test Ad", personnel_type = ptype, unit_id = "abc-123"
    ))
    expect_true(result$valid, info = paste("Tip:", ptype))
  }
})

# =============================================
# 4. validate_kpi_data() testləri
# =============================================

test_that("validate_kpi_data: düzgün data keçir", {
  result <- validate_kpi_data(list(
    name = "Tamamlanma faizi", target_value = 100, activity_id = "abc-123"
  ))
  expect_true(result$valid)
})

test_that("validate_kpi_data: sıfır hədəf rədd olunur", {
  result <- validate_kpi_data(list(
    name = "Test", target_value = 0, activity_id = "abc-123"
  ))
  expect_false(result$valid)
})

test_that("validate_kpi_data: mənfi hədəf rədd olunur", {
  result <- validate_kpi_data(list(
    name = "Test", target_value = -50, activity_id = "abc-123"
  ))
  expect_false(result$valid)
})

test_that("validate_kpi_data: boş activity_id rədd olunur", {
  result <- validate_kpi_data(list(
    name = "Test", target_value = 100, activity_id = ""
  ))
  expect_false(result$valid)
})

# =============================================
# 5. validate_project_data() testləri
# =============================================

test_that("validate_project_data: düzgün data keçir", {
  result <- validate_project_data(list(
    name = "Test Layihə", unit_id = "abc-123", budget = 50000
  ))
  expect_true(result$valid)
})

test_that("validate_project_data: mənfi büdcə rədd olunur", {
  result <- validate_project_data(list(
    name = "Test", unit_id = "abc-123", budget = -1000
  ))
  expect_false(result$valid)
})

test_that("validate_project_data: sıfır büdcə icazə verilir", {
  result <- validate_project_data(list(
    name = "Test", unit_id = "abc-123", budget = 0
  ))
  expect_true(result$valid)
})

# =============================================
# 6. format_budget_azn() testləri
# =============================================

test_that("format_budget_azn: ədədi formatlaşdırır", {
  result <- format_budget_azn(1234.56)
  expect_true(grepl("1", result))
  expect_true(grepl("\\u20BC", result) || grepl("\u20BC", result))
})

test_that("format_budget_azn: NULL halı", {
  result <- format_budget_azn(NULL)
  expect_equal(result, "0,00 \u20BC")
})

test_that("format_budget_azn: NA halı", {
  result <- format_budget_azn(NA)
  expect_equal(result, "0,00 \u20BC")
})

test_that("format_budget_azn: sıfır", {
  result <- format_budget_azn(0)
  expect_true(grepl("0,00", result))
})

test_that("format_budget_azn: böyük ədəd", {
  result <- format_budget_azn(1000000)
  expect_true(grepl("\\.", result))
})

# =============================================
# 7. Sabit dəyərlərin testləri
# =============================================

test_that("UNIT_TYPES bütün tipləri ehtiva edir", {
  expect_true("rehberlik" %in% names(UNIT_TYPES))
  expect_true("merkez" %in% names(UNIT_TYPES))
  expect_true("shobe" %in% names(UNIT_TYPES))
  expect_length(UNIT_TYPES, 5)
})

test_that("PERSONNEL_TYPES bütün tipləri ehtiva edir", {
  expect_true("emedkas" %in% names(PERSONNEL_TYPES))
  expect_true("tedqiqatci" %in% names(PERSONNEL_TYPES))
  expect_true("doktorant" %in% names(PERSONNEL_TYPES))
  expect_length(PERSONNEL_TYPES, 5)
})

test_that("INST_RESOURCE_TYPES düzgün sayda", {
  expect_length(INST_RESOURCE_TYPES, 5)
})

test_that("ACTIVITY_CATEGORIES düzgün sayda", {
  expect_length(ACTIVITY_CATEGORIES, 6)
})

test_that("PROJECT_PRIORITY düzgün sayda", {
  expect_length(PROJECT_PRIORITY, 4)
})

test_that("INST_PROJECT_STATUS düzgün sayda", {
  expect_length(INST_PROJECT_STATUS, 5)
})

test_that("KPI_FREQUENCY düzgün sayda", {
  expect_length(KPI_FREQUENCY, 5)
})
