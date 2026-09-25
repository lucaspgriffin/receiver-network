# Receiver Network

Public, interactive map of a partner acoustic telemetry receiver network across
the Gulf and western Caribbean, built as an R Shiny app.

The same app is published two ways:

| Where | URL | QR code | Notes |
|---|---|---|---|
| shinyapps.io | https://lucaspgriffin.shinyapps.io/receiver-network/ | [`qr/qr-shinyapps.png`](qr/qr-shinyapps.png) · [svg](qr/qr-shinyapps.svg) | Loads fast; free tier has monthly active-hour limits |
| GitHub Pages | https://lucaspgriffin.github.io/receiver-network/ | [`qr/qr-github-pages.png`](qr/qr-github-pages.png) · [svg](qr/qr-github-pages.svg) | Runs in the browser via [shinylive](https://posit-dev.github.io/r-shinylive/); no usage limits, ~20-30 s first load |

## Location detail

- `R/prep_public_receivers.R` reads the source lists from `data-raw/`
  (git-ignored), drops receiver names and institutions, and writes true
  positions (rounded to 4 decimals, ~10 m) to `app/receivers_public.csv`.
- The map is capped at zoom 10 (`MAX_ZOOM` in `app/app.R`) so it can't be
  zoomed to fine scale. Note that the public CSV itself has the coordinates.
- Receivers are not labelled by institution. Partners are credited as a list in
  the sidebar, from `app/partners.csv` (edit by hand).

## Data sources (local only, in `data-raw/`)

- `Cobia_TTT_Receiver_List.csv`: partner receiver list
  (`Receiver, Lat, Lon, Institution, notes`). Blank `notes` are treated as Active;
  `Proposed` is folded into `Planned`.
- `BTT_BZ_MX_deployments.csv`: Bonefish & Tarpon Trust Belize/Mexico array,
  copied from `BTT_AcTelem_BZ_MX/data/processed/deployments_clean.csv`.
- `SJB_deployed_stations.csv`: current St. Joe Bay stations, copied from
  `SJB-Receiver-Map-App/data/SJB_deployed_stations.csv`. These replace any
  partner-list receivers inside the array's footprint (+0.01°).

The prep script also:

- flips two TAMUG platform longitudes entered without the minus sign;
- drops the inland LSU FAMEL river array (north of 30.1°N, west of 90.5°W);
- drops the retired BTT Cayo_Mosquito station (replaced by Boca_Chica).

## Updating

1. Update the files in `data-raw/`.
2. `Rscript R/prep_public_receivers.R` from the repo root.
3. If a new institution appears, add it to `app/partners.csv`.
4. Commit and push: GitHub Actions rebuilds GitHub Pages in a few minutes.
5. Redeploy shinyapps.io:
   ```r
   rsconnect::deployApp("app", appName = "receiver-network", account = "lucaspgriffin")
   ```

QR code URLs stay the same across updates.

## Running locally

```r
shiny::runApp("app")
```
