#' ModelComparison Class Definition
#'
#' @md
#' @importClassesFrom S4Vectors DataFrame
#' @export
.ModelComparison <- setClass('ModelComparison', contains='DFrame')

#' ModelComparison Constructor
#'
#' @param model1 An object with a `validationStats` method which returns a
#'   `data.table`. Probably this object should inherit from `SurvivalModel`.
#' @param model2 An object with a `validationStats` method which returns a
#'   `data.table`. Probably this object should inherit from `SurvivalModel`.
#' @param ... Not used.
#'
#' @return A `ModelComparison` object, which is a wrapper for `DataFrame`
#'   which is used for method dispatch.
#'
#' @examples
#' data(sampleValPCOSPmodel)
#' data(sampleClinicalModel)
#' data(sampleCohortList)
#'
#' # Set parallelization settings
#' BiocParallel::register(BiocParallel::SerialParam())
#'
#' # Train the models
#' trainedClinicalModel <- trainModel(sampleClinicalModel)
#'
#' # Predict risk/risk-class
#' clinicalPredCohortL <- predictClasses(sampleCohortList[c('PCSI', 'TCGA')],
#'   model=trainedClinicalModel)
#'
#' # Validate the models
#' validatedClinicalModel <- validateModel(trainedClinicalModel,
#'   valData=clinicalPredCohortL)
#'
#' # Compare the models
#' modelComp <- ModelComparison(sampleValPCOSPmodel, validatedClinicalModel)
#' head(modelComp)
#'
#' @md
#' @importFrom methods is
#' @importFrom S4Vectors DataFrame
#' @importFrom data.table data.table as.data.table merge.data.table rbindlist
#'   `:=` copy .N .SD fifelse merge.data.table transpose setcolorder
#' @export
ModelComparison <- function(model1, model2, ...) {

    ## TODO:: Is it better to define a validationStats method for a
    ##   ModelComparsion? Then can't do class for model column.
    if (is(model1, 'ModelComparison')) {
        model1StatsDT <- as.data.table(model1)
    } else {
        model1StatsDT <- as.data.table(validationStats(model1))
        model1StatsDT[, model := class(model1)]
    }

    if (is(model2, 'ModelComparison')) {
        model2StatsDT <- as.data.table(model2)
    } else {
        model2StatsDT <- as.data.table(validationStats(model2))
        model2StatsDT[, model := class(model2)]
    }

    sharedCohorts <- intersect(model1StatsDT$cohort, model2StatsDT$cohort)
    modelComparisonDT <- rbind(model1StatsDT, model2StatsDT)
    modelComparisonDT <- modelComparisonDT[cohort %in% sharedCohorts, ]

    .ModelComparison(DataFrame(modelComparisonDT))
}
