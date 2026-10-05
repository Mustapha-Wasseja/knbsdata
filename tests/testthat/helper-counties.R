# The 2019 census frame's 47 counties as the census API names them (read
# live 2026-10-06), for tests that match county names without the network.

census_counties <- function() {
  tibble::tibble(
    geo_code = sprintf("%02d", 1:47),
    geo_name = c(
      "Mombasa", "Kwale", "Kilifi", "Tana River", "Lamu", "Taita/Taveta",
      "Garissa", "Wajir", "Mandera", "Marsabit", "Isiolo", "Meru",
      "Tharaka-Nithi", "Embu", "Kitui", "Machakos", "Makueni", "Nyandarua",
      "Nyeri", "Kirinyaga", "Murang'a", "Kiambu", "Turkana", "West Pokot",
      "Samburu", "Trans Nzoia", "Uasin Gishu", "Elgeyo/Marakwet", "Nandi",
      "Baringo", "Laikipia", "Nakuru", "Narok", "Kajiado", "Kericho", "Bomet",
      "Kakamega", "Vihiga", "Bungoma", "Busia", "Siaya", "Kisumu", "Homa Bay",
      "Migori", "Kisii", "Nyamira", "Nairobi City"
    )
  )
}

local_counties <- function(env = parent.frame()) {
  testthat::local_mocked_bindings(
    county_reference = function(vintage, cache, refresh) census_counties(),
    .package = "knbsdata",
    .env = env
  )
}
