# Session state that is not configuration: what has already been said once,
# and which hosts verified only with the shipped intermediates
# (perform_supplemented()).
the <- new.env(parent = emptyenv())

.onLoad <- function(libname, pkgname) {
  # Register defaults only for options the user has not already set, so that
  # options() reflects the effective configuration in every session.
  defaults <- compact_list(knbs_option_defaults())
  names(defaults) <- paste0("knbsdata.", names(defaults))
  unset <- setdiff(names(defaults), names(options()))
  if (length(unset) > 0L) {
    options(defaults[unset])
  }
  invisible()
}
