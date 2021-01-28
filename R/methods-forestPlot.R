setClassUnion("PCOSP_or_ClinicalModel", c('PCOSP', 'ClinicalModel'))
#' Generate a forest plot from an `S4` object
#'
#' @param object An `S4` object to create a forest plot of.
#' @param ... Allow new parameters to this generic.
#'
#' @return None, draws a forest plot.
#'
#' @export
setGeneric('forestPlot', function(object, ...)
    standardGeneric('forestPlot'))
#'
#' Render a forest plot from the `validationStats` slot of a `PCOSP` model object.
#'
#' @param object A `PCOSP` model which has been validated with `validateModel`
#'   and therefore has data in the `validationStats` slot.
#' @param stat A `character` vector specifying a statistic to plot.
#' @param groupBy A `character` vector with one or more columns in `validationStats`
#'   to group by. These will be the facets in your
#' @param colourBy A `character` vector specifying the columns in
#'   `validationStats` to colour by.
#' @param ... Force subsequent parameters to be named, not used.
#' @param xlab A `character` vector specifying the desired x label.
#'   Automatically guesses based on the `stat` argument.
#' @param ylab A `character` vector specifyuing the desired y label.
#'   Defaults to 'Cohort (P-value)'.
#' @param colours A `character` vector of colours to pass into
#'   ``ggplot2::scale_fill_manual``, which modify the colourBy argument.
#' @param title A `characer` vector with a title to add to the plot.
#'
#' @return A `ggplot2` object
#'
#' @md
#' @import data.table
#' @importFrom ggplot2 ggplot geom_pointrange theme_bw facet_grid theme
#'   geom_vline vars xlab ylab scale_colour_manual ggtitle
#' @importFrom stats reformulate
#' @importFrom scales scientific
#' @export
setMethod('forestPlot', signature('PCOSP_or_ClinicalModel'),
    function(object, stat, groupBy='mDataType', colourBy='isSummary',
        vline, ..., xlab, ylab, transform, colours, title)
{
    if (!is.character(stat)) stop(.erroMsg(.context(), 'The stat parameter',
        'must be a character vector present in the statistics column of the ',
        'PCOSP models validationStats slot!'))

    stats <- copy(validationStats(object))[statistic == stat
        ][order(-mDataType, isSummary)]
    # Add p-value to the cohort labels
    stats[, cohort := paste0(cohort, ' (', scientific(p_value,  2), ')')]

    if (missing(vline)) {
        vline <- switch(stat,
            'D_index' = 1,
            'concordance_index' = 0.5,
            stop(.errorMsg(.context(), 'Unkown statistic specified, please ',
                'manually set the vline location with the vline argument!')))
    }

    if (missing(xlab)) {
        xlab <- switch(stat,
            'D_index' = 'Hazard Ratio',
            'concordance_index' = 'Concordance Index',
            stop(.errorMsg(.context(), 'Unkown statistic specified, please ',
                'manually set the x label with the xlab argument!')))
    }

    if (missing(ylab)) ylab <- 'Cohort (P-value)'

    if (!missing(transform)) {
        stats[, `:=`(estimate=get(transform)(estimate),
            lower=get(transform)(lower), upper=get(transform)(upper))]
        xlab <- paste(transform, xlab)
        vline <- get(transform)(vline)
    }

    plot <- ggplot(stats, aes(y=reorder(cohort, -isSummary), x=estimate,
                xmin=lower, xmax=upper, shape=isSummary)) +
        geom_pointrange(aes_string(colour=colourBy, group=groupBy)) +
        theme_bw() +
        facet_grid(reformulate('.', groupBy), scales='free_y',
            space='free', switch='x') +
        theme(strip.text.y = element_text(angle = 0),
            plot.title=element_text(hjust = 0.5),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            panel.background = element_blank()) +
        geom_vline(xintercept=vline, linetype=3) +
        xlab(xlab) +
        ylab(ylab)

    if (!missing(colours))
        plot <- plot + scale_colour_manual(values=colours)

    if (!missing(title))
        plot <- plot + ggtitle(title)

    return(plot)
})

## TODO:: Refactor to use hook for minimal difference in behavoir
#' @inherit forestPlot,PCOSP_or_ClinicalModel-method
#' @param object A `ModelComparison` object
#'
#' @md
#' @export
setMethod('forestPlot', signature(object='ModelComparison'),
    function(object, stat, groupBy='cohort', colourBy='model',
        vline, ..., xlab, ylab, transform, colours, title)
{
    if (!is.character(stat)) stop(.erroMsg(.context(), 'The stat parameter',
        'must be a character vector present in the statistics column of the ',
        'PCOSP models validationStats slot!'))

    statsDT <- as.data.table(object)[statistic == stat, ]
    statsDT[, model_pvalue :=
        paste0(model, ' (', scientific(p_value,  2), ')')]

    if (missing(vline)) {
        vline <- switch(stat,
            'D_index' = 1,
            'concordance_index' = 0.5,
            stop(.errorMsg(.context(), 'Unkown statistic specified, please ',
                'manually set the vline location with the vline argument!')))
    }

    if (missing(xlab)) {
        xlab <- switch(stat,
            'D_index' = 'Hazard Ratio',
            'concordance_index' = 'Concordance Index',
            stop(.errorMsg(.context(), 'Unknown statistic specified, please ',
                'manually set the x label with the xlab argument!')))
    }

    if (missing(ylab)) ylab <- 'Model (P-value)'

    if (!missing(transform)) {
        statsDT[, `:=`(estimate=get(transform)(estimate),
            lower=get(transform)(lower), upper=get(transform)(upper))]
        xlab <- paste(transform, xlab)
        vline <- get(transform)(vline)
    }

    plot <-
        ggplot(statsDT[order(-isSummary)],
            aes(y=reorder(model_pvalue, -isSummary), x=estimate,
            xmin=lower, xmax=upper, shape=isSummary)) +
        geom_pointrange(aes_string(colour=colourBy,
            group=paste0('reorder(', groupBy, ', -isSummary)'))) +
        theme_bw() +
        facet_grid(reformulate('.', groupBy),
            scales='free_y', space='free', switch='y') +
        theme(strip.text.y = element_text(angle = 0),
            plot.title=element_text(hjust = 0.5),
            panel.grid.major = element_blank(),
            panel.grid.minor = element_blank(),
            panel.background = element_blank()) +
        geom_vline(xintercept=vline, linetype=3) +
        xlab(xlab) +
        ylab(ylab)

    if (!missing(colours))
        plot <- plot + scale_colour_manual(values=colours)

    if (!missing(title))
        plot <- plot + ggtitle(title)

    plot

})