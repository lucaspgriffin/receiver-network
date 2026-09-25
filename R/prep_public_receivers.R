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
# 4. COMBINE + QA BOUNDS
#----------------------------------------------------------

receivers <- bind_rows(partner_rx, btt_rx, sjb_rx) %>%
  filter(
    !is.na(Lat), !is.na(Lon),
    Lat >= 15, Lat <= 35,
    Lon >= -100, Lon <= -78
  )

message("Receivers kept: ", nrow(receivers))

#----------------------------------------------------------
# 5. PUBLIC OUTPUT
#----------------------------------------------------------

public <- receivers %>%
  transmute(lat = round(Lat, 4), lon = round(Lon, 4), status = Status) %>%
  arrange(lat, lon) # sorted so row order carries no institution information

write.csv(public, "app/receivers_public.csv", row.names = FALSE)

message("Wrote app/receivers_public.csv: ", nrow(public), " receivers")
print(table(public$status))

# Institutions in the source data, for checking app/partners.csv is current
message("Institutions in source data: ", paste(sort(unique(receivers$Institution)), collapse = ", "))
