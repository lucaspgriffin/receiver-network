#==========================================================
# PREP PUBLIC (COARSENED) RECEIVER DATA
#
# Reads the exact receiver list (kept out of git in data-raw/)
# and writes app/receivers_public.csv, which is safe to publish:
#   - receiver names dropped (many are fishing-spot names)
#   - coordinates snapped to a GRID_DEG grid (cell centres)
#   - receivers aggregated to counts per cell x institution x status
#
# Run from the repo root:  Rscript R/prep_public_receivers.R
#==========================================================

library(dplyr)
library(stringr)

GRID_DEG <- 0.05 # ~5.5 km N-S; the public map never shows finer than this

#----------------------------------------------------------
# 1. READ + CLEAN
#----------------------------------------------------------

raw <- read.csv("data-raw/Cobia_TTT_Receiver_List.csv", stringsAsFactors = FALSE)

receivers <- raw %>%
  mutate(
    Lat = as.numeric(Lat),
    Lon = as.numeric(Lon),
    Institution = str_squish(Institution),
    Status = case_when(
      is.na(notes) | str_squish(notes) == "" ~ "Not specified",
      TRUE ~ str_to_title(str_squish(notes))
    ),

    # Western Gulf longitudes entered without the minus sign
    # (e.g., TAMUG "Mobile Platform" at +96.09)
    lon_sign_fixed = !is.na(Lon) & Lon > 80 & Lon < 100,
    Lon = ifelse(lon_sign_fixed, -Lon, Lon)
  )

if (any(receivers$lon_sign_fixed)) {
  message("Flipped sign on ", sum(receivers$lon_sign_fixed), " longitude(s):")
  print(receivers %>% filter(lon_sign_fixed) %>% select(Receiver, Institution, Lat, Lon))
}

# Wider bounds than the original Gulf box so we keep the Veracruz,
# Atlantic Florida, and inland Louisiana/Arkansas river receivers
receivers <- receivers %>%
  filter(
    !is.na(Lat), !is.na(Lon),
    Lat >= 18, Lat <= 35,
    Lon >= -100, Lon <= -78
  )

message("Receivers kept: ", nrow(receivers), " of ", nrow(raw))

#----------------------------------------------------------
# 2. COARSEN + AGGREGATE
#----------------------------------------------------------

snap <- function(x) round((floor(x / GRID_DEG) + 0.5) * GRID_DEG, 4)

public <- receivers %>%
  mutate(cell_lat = snap(Lat), cell_lon = snap(Lon)) %>%
  count(cell_lat, cell_lon, Institution, Status, name = "n_receivers") %>%
  arrange(Institution, cell_lat, cell_lon)

write.csv(public, "app/receivers_public.csv", row.names = FALSE)

message(
  "Wrote app/receivers_public.csv: ", nrow(public), " rows, ",
  n_distinct(paste(public$cell_lat, public$cell_lon)), " grid cells, ",
  sum(public$n_receivers), " receivers"
)
