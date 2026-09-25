#==========================================================
# PREP PUBLIC (GENERALIZED) RECEIVER DATA
#
# Reads the exact receiver lists (kept out of git in data-raw/)
# and writes app/receivers_public.csv, which is safe to publish:
#   - receiver names and institutions dropped
#   - each receiver placed at a random point inside its GRID_DEG
#     grid cell, so the map shows individual receivers without
#     revealing where in the cell they actually sit
#
# Partners are credited as a list in app/partners.csv, never tied
# to locations.
#
# Run from the repo root:  Rscript R/prep_public_receivers.R
#==========================================================

library(dplyr)
library(stringr)

GRID_DEG <- 0.05 # ~5.5 km N-S; true positions are never finer than this
SEED <- 20260925 # fixed so points don't jump around between rebuilds

#----------------------------------------------------------
# 1. PARTNER RECEIVER LIST
#----------------------------------------------------------

raw <- read.csv("data-raw/Cobia_TTT_Receiver_List.csv", stringsAsFactors = FALSE)

partner_rx <- raw %>%
  mutate(
    Lat = as.numeric(Lat),
    Lon = as.numeric(Lon),
    Institution = str_squish(Institution),

    # Blank notes are established, deployed arrays;
    # "proposed" and "planned" mean the same thing here
    Status = case_when(
      is.na(notes) | str_squish(notes) == "" ~ "Active",
      str_to_lower(str_squish(notes)) %in% c("planned", "proposed") ~ "Planned",
      TRUE ~ str_to_title(str_squish(notes))
    ),

    # Western Gulf longitudes entered without the minus sign
    # (e.g., TAMUG "Mobile Platform" at +96.09)
    lon_sign_fixed = !is.na(Lon) & Lon > 80 & Lon < 100,
    Lon = ifelse(lon_sign_fixed, -Lon, Lon)
  )

if (any(partner_rx$lon_sign_fixed)) {
  message("Flipped sign on ", sum(partner_rx$lon_sign_fixed), " longitude(s):")
  print(partner_rx %>% filter(lon_sign_fixed) %>% select(Receiver, Institution, Lat, Lon))
}

# Drop the inland freshwater river array (LSU FAMEL receivers up the
# Atchafalaya / Red / Ouachita drainages); the map is coastal/marine
inland_river <- with(
  partner_rx,
  Institution == "LSU_FAMEL" & Lat > 30.1 & Lon < -90.5
)
message("Dropped ", sum(inland_river, na.rm = TRUE), " inland river receivers")

partner_rx <- partner_rx[!inland_river, ] %>%
  select(Institution, Lat, Lon, Status)

#----------------------------------------------------------
# 2. BTT BELIZE / MEXICO ARRAY
#----------------------------------------------------------

btt <- read.csv("data-raw/BTT_BZ_MX_deployments.csv", stringsAsFactors = FALSE)

# Current stations only: Cayo_Mosquito was pulled Aug 2025 and
# replaced by Boca_Chica
btt_rx <- btt %>%
  filter(station != "Cayo_Mosquito") %>%
  distinct(station, .keep_all = TRUE) %>%
  transmute(Institution = "BTT", Lat = lat, Lon = lon, Status = "Active")

message("BTT receivers added: ", nrow(btt_rx))

#----------------------------------------------------------
# 3. COMBINE + QA BOUNDS
#----------------------------------------------------------

receivers <- bind_rows(partner_rx, btt_rx) %>%
  filter(
    !is.na(Lat), !is.na(Lon),
    Lat >= 15, Lat <= 35,
    Lon >= -100, Lon <= -78
  )

message("Receivers kept: ", nrow(receivers))

#----------------------------------------------------------
# 4. GENERALIZE: RANDOM POINT WITHIN EACH RECEIVER'S GRID CELL
#----------------------------------------------------------

set.seed(SEED)

cell_origin <- function(x) floor(x / GRID_DEG) * GRID_DEG

public <- receivers %>%
  mutate(
    lat = round(cell_origin(Lat) + runif(n(), 0.1, 0.9) * GRID_DEG, 4),
    lon = round(cell_origin(Lon) + runif(n(), 0.1, 0.9) * GRID_DEG, 4)
  ) %>%
  select(lat, lon, status = Status) %>%
  slice_sample(prop = 1) # shuffle so row order carries no information

write.csv(public, "app/receivers_public.csv", row.names = FALSE)

message("Wrote app/receivers_public.csv: ", nrow(public), " receivers")
print(table(public$status))

# Institutions in the source data, for checking app/partners.csv is current
message("Institutions in source data: ", paste(sort(unique(receivers$Institution)), collapse = ", "))
