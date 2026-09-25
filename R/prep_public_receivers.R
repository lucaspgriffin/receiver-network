#==========================================================
# PREP PUBLIC RECEIVER DATA
#
# Reads the source receiver lists (kept out of git in data-raw/)
# and writes app/receivers_public.csv:
#   - receiver names and institutions dropped
#   - coordinates kept at their true positions (4 decimals, ~10 m);
#     the app limits how far the map can zoom in
#
# Partners are credited as a list in app/partners.csv, never tied
# to locations.
#
# Run from the repo root:  Rscript R/prep_public_receivers.R
#==========================================================

library(dplyr)
library(stringr)


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
# 3. ST. JOE BAY ARRAY (replaces older entries inside the bay)
#----------------------------------------------------------

# Current deployed stations, copied from
# SJB-Receiver-Map-App/data/SJB_deployed_stations.csv
sjb <- read.csv("data-raw/SJB_deployed_stations.csv", stringsAsFactors = FALSE)

sjb_rx <- sjb %>%
  distinct(name, .keep_all = TRUE) %>%
  transmute(Institution = "SJB", Lat = lat, Lon = lon, Status = "Active")

# Footprint of the new array plus ~1 km; older receivers inside it
# are superseded by this deployment sheet
SJB_BUFFER <- 0.01
in_sjb <- with(
  partner_rx,
  Lat >= min(sjb_rx$Lat) - SJB_BUFFER & Lat <= max(sjb_rx$Lat) + SJB_BUFFER &
    Lon >= min(sjb_rx$Lon) - SJB_BUFFER & Lon <= max(sjb_rx$Lon) + SJB_BUFFER
)
message(
  "St. Joe Bay: replaced ", sum(in_sjb), " existing receivers with ",
  nrow(sjb_rx), " from the deployment sheet"
)
partner_rx <- partner_rx[!in_sjb, ]

#----------------------------------------------------------
# 4. UPDATED PANHANDLE / ALABAMA LIST (Sep 2026)
#----------------------------------------------------------

hav_m <- function(lat1, lon1, lat2, lon2) {
  r <- pi / 180
  a <- sin((lat2 - lat1) * r / 2)^2 +
    cos(lat1 * r) * cos(lat2 * r) * sin((lon2 - lon1) * r / 2)^2
  2 * 6371000 * asin(sqrt(a))
}

upd <- read.csv("data-raw/updated_receivers_2026-09-25.csv", stringsAsFactors = FALSE)

upd_rx <- upd %>%
  filter(toupper(Present) == "YES") %>%
  transmute(Institution = "USGS", Lat = Lat, Lon = Lon, Status = "Active")

# Older partner-list entries within UPD_REPLACE_M of an updated receiver are
# the same site (or its previous position) and would sit on top of it
UPD_REPLACE_M <- 1000
near_upd <- vapply(
  seq_len(nrow(partner_rx)),
  function(i) any(hav_m(partner_rx$Lat[i], partner_rx$Lon[i], upd_rx$Lat, upd_rx$Lon) <= UPD_REPLACE_M),
  logical(1)
)
message(
  "Updated list: replaced ", sum(near_upd), " existing receivers with ",
  nrow(upd_rx), " updated entries"
)
partner_rx <- partner_rx[!near_upd, ]

#----------------------------------------------------------
# 5. COMBINE + QA BOUNDS + DE-DUPLICATE
#----------------------------------------------------------

# Most authoritative sources first, so they win the de-duplication
receivers <- bind_rows(sjb_rx, upd_rx, btt_rx, partner_rx) %>%
  filter(
    !is.na(Lat), !is.na(Lon),
    Lat >= 15, Lat <= 35,
    Lon >= -100, Lon <= -78
  )

# Drop stacked duplicates (same receiver listed twice). The SJB
# positioning array is intentionally ~45-50 m apart, so stay well below that
DUP_M <- 25
keep <- rep(TRUE, nrow(receivers))
for (i in seq_len(nrow(receivers))[-1]) {
  prev <- which(keep[seq_len(i - 1)])
  if (any(hav_m(receivers$Lat[i], receivers$Lon[i], receivers$Lat[prev], receivers$Lon[prev]) <= DUP_M)) {
    keep[i] <- FALSE
  }
}
message("Removed ", sum(!keep), " duplicate receivers (within ", DUP_M, " m of another)")
receivers <- receivers[keep, ]

message("Receivers kept: ", nrow(receivers))

#----------------------------------------------------------
# 6. PUBLIC OUTPUT
#----------------------------------------------------------

public <- receivers %>%
  transmute(lat = round(Lat, 4), lon = round(Lon, 4), status = Status) %>%
  arrange(lat, lon) # sorted so row order carries no institution information

write.csv(public, "app/receivers_public.csv", row.names = FALSE)

message("Wrote app/receivers_public.csv: ", nrow(public), " receivers")
print(table(public$status))

# Institutions in the source data, for checking app/partners.csv is current
message("Institutions in source data: ", paste(sort(unique(receivers$Institution)), collapse = ", "))
