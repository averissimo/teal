#' Get Client Timezone
#'
#' Local timezone in the browser may differ from the system timezone from the server.
#'   This script can be run to register a shiny input which contains information about
#'   the timezone in the browser.
#'
#' @param ns (`function`) namespace function passed from the `session` object in the
#'   Shiny server. For Shiny modules this will allow for proper name spacing of the
#'   registered input.
#'
#' @return (`Shiny`) input variable accessible with `input$tz` which is a (`character`)
#'  string containing the timezone of the browser/client.
#' @keywords internal
get_client_timezone <- function(ns) {
  script <- sprintf(
    "Shiny.setInputValue(`%s`, Intl.DateTimeFormat().resolvedOptions().timeZone)",
    ns("timezone")
  )
  shinyjs::runjs(script) # function does not return anything
  return(invisible(NULL))
}

#' Resolve the expected bootstrap theme
#' @keywords internal
get_teal_bs_theme <- function() {
  bs_theme <- getOption("teal.bs_theme")
  if (is.null(bs_theme)) {
    NULL
  } else if (!inherits(bs_theme, "bs_theme")) {
    warning("teal.bs_theme has to be of a bslib::bs_theme class, the default shiny bootstrap is used.")
    NULL
  } else {
    bs_theme
  }
}

include_parent_datanames <- function(dataname, join_keys) {
  parents <- character(0)
  for (i in dataname) {
    while (length(i) > 0) {
      parent_i <- teal.data::parent(join_keys, i)
      parents <- c(parent_i, parents)
      i <- parent_i
    }
  }

  return(unique(c(parents, dataname)))
}



#' Create a `FilteredData`
#'
#' Create a `FilteredData` object from a `teal_data` object
#' @param x (`teal_data`) object
#' @param datanames (`character`) vector of data set names to include; must be subset of `datanames(x)`
#' @return (`FilteredData`) object
#' @keywords internal
teal_data_to_filtered_data <- function(x, datanames = teal.data::datanames(x)) {
  checkmate::assert_class(x, "teal_data")
  checkmate::assert_character(datanames, min.len = 1L, any.missing = FALSE)
  checkmate::assert_subset(datanames, teal.data::datanames(x))

  ans <- teal.slice::init_filtered_data(
    x = sapply(datanames, function(dn) x[[dn]], simplify = FALSE),
    join_keys = teal.data::join_keys(x)
  )
  # Piggy-back entire pre-processing code so that filtering code can be appended later.
  attr(ans, "preprocessing_code") <- teal.code::get_code(x)
  ans
}

#' Template Function for `TealReportCard` Creation and Customization
#'
#' This function generates a report card with a title,
#' an optional description, and the option to append the filter state list.
#'
#' @param title (`character(1)`) title of the card (unless overwritten by label)
#' @param label (`character(1)`) label provided by the user when adding the card
#' @param description (`character(1)`) optional additional description
#' @param with_filter (`logical(1)`) flag indicating to add filter state
#' @param filter_panel_api (`FilterPanelAPI`) object with API that allows the generation
#' of the filter state in the report
#'
#' @return (`TealReportCard`) populated with a title, description and filter state
#'
#' @export
report_card_template <- function(title, label, description = NULL, with_filter, filter_panel_api) {
  checkmate::assert_string(title)
  checkmate::assert_string(label)
  checkmate::assert_string(description, null.ok = TRUE)
  checkmate::assert_flag(with_filter)
  checkmate::assert_class(filter_panel_api, classes = "FilterPanelAPI")

  card <- teal::TealReportCard$new()
  title <- if (label == "") title else label
  card$set_name(title)
  card$append_text(title, "header2")
  if (!is.null(description)) card$append_text(description, "header3")
  if (with_filter) card$append_fs(filter_panel_api$get_filter_state())
  card
}
#' Resolve `datanames` for the modules
#'
#' Modifies `module$datanames` to include names of the parent dataset (taken from `join_keys`).
#' When `datanames` is set to `"all"` it is replaced with all available datasets names.
#' @param modules (`teal_modules`) object
#' @param datanames (`character`) names of datasets available in the `data` object
#' @param join_keys (`join_keys`) object
#' @return `teal_modules` with resolved `datanames`
#' @keywords internal
resolve_modules_datanames <- function(modules, datanames, join_keys) {
  if (inherits(modules, "teal_modules")) {
    modules$children <- sapply(
      modules$children,
      resolve_modules_datanames,
      simplify = FALSE,
      datanames = datanames,
      join_keys = join_keys
    )
    modules
  } else {
    modules$datanames <- if (identical(modules$datanames, "all")) {
      datanames
    } else if (is.character(modules$datanames)) {
      extra_datanames <- setdiff(modules$datanames, datanames)
      if (length(extra_datanames)) {
        stop(
          sprintf(
            "Module %s has datanames that are not available in a 'data':\n %s not in %s",
            modules$label,
            toString(extra_datanames),
            toString(datanames)
          )
        )
      }
      datanames_adjusted <- intersect(modules$datanames, datanames)
      include_parent_datanames(dataname = datanames_adjusted, join_keys = join_keys)
    }
    modules
  }
}

#' Check `datanames` in modules
#'
#' This function ensures specified `datanames` in modules match those in the data object,
#' returning error messages or `TRUE` for successful validation.
#'
#' @param modules (`teal_modules`) object
#' @param datanames (`character`) names of datasets available in the `data` object
#'
#' @return A `character(1)` containing error message or `TRUE` if validation passes.
#' @keywords internal
check_modules_datanames <- function(modules, datanames) {
  checkmate::assert_class(modules, "teal_modules")
  checkmate::assert_character(datanames)

  recursive_check_datanames <- function(modules, datanames) {
    # check teal_modules against datanames
    if (inherits(modules, "teal_modules")) {
      sapply(modules$children, function(module) recursive_check_datanames(module, datanames = datanames))
    } else {
      extra_datanames <- setdiff(modules$datanames, c("all", datanames))
      if (length(extra_datanames)) {
        sprintf(
          "- Module '%s' uses datanames not available in 'data': (%s) not in (%s)",
          modules$label,
          toString(dQuote(extra_datanames, q = FALSE)),
          toString(dQuote(datanames, q = FALSE))
        )
      }
    }
  }
  check_datanames <- unlist(recursive_check_datanames(modules, datanames))
  if (length(check_datanames)) {
    paste(check_datanames, collapse = "\n")
  } else {
    TRUE
  }
}

#' Check `datanames` in filters
#'
#' This function checks whether `datanames` in filters correspond to those in `data`,
#' returning character vector with error messages or TRUE if all checks pass.
#'
#' @param filters (`teal_slices`) object
#' @param datanames (`character`) names of datasets available in the `data` object
#'
#' @return A `character(1)` containing error message or TRUE if validation passes.
#' @keywords internal
check_filter_datanames <- function(filters, datanames) {
  checkmate::assert_class(filters, "teal_slices")
  checkmate::assert_character(datanames)

  # check teal_slices against datanames
  out <- unlist(sapply(
    filters, function(filter) {
      dataname <- shiny::isolate(filter$dataname)
      if (!dataname %in% datanames) {
        sprintf(
          "- Filter '%s' refers to dataname not available in 'data':\n %s not in (%s)",
          shiny::isolate(filter$id),
          dQuote(dataname, q = FALSE),
          toString(dQuote(datanames, q = FALSE))
        )
      }
    }
  ))


  if (length(out)) {
    paste(out, collapse = "\n")
  } else {
    TRUE
  }
}
