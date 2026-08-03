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
