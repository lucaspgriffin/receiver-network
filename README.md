# Receiver Network

Public, interactive map of a partner acoustic telemetry receiver network across
the Gulf and western Caribbean, built as an R Shiny app.

The same app is published two ways:

| Where | URL | QR code | Notes |
|---|---|---|---|
| shinyapps.io | https://lucaspgriffin.shinyapps.io/receiver-network/ | [`qr/qr-shinyapps.png`](qr/qr-shinyapps.png) · [svg](qr/qr-shinyapps.svg) | Loads fast; free tier has monthly active-hour limits |
| GitHub Pages | https://lucaspgriffin.github.io/receiver-network/ | [`qr/qr-github-pages.png`](qr/qr-github-pages.png) · [svg](qr/qr-github-pages.svg) | Runs in the browser via [shinylive](https://posit-dev.github.io/r-shinylive/); no usage limits, ~20-30 s first load |

## Location privacy

Exact receiver coordinates are **not** in this repository.

- `R/prep_public_receivers.R` reads the exact lists from `data-raw/` (git-ignored),
  drops receiver names and institutions, and places each receiver at a random
  point inside its 0.05° (~5 km) grid cell. Row order is shuffled.
- The map clusters receivers when zoomed out, shows individuals from zoom 9,
  and is capped at zoom 10.
- Receivers are not labelled by institution. Partners are credited as a list in
  the sidebar, from `app/partners.csv` (edit by hand).

To change the level of generalization, edit `GRID_DEG` in the prep script and
`MAX_ZOOM` / `UNCLUSTER_ZOOM` in `app/app.R`.

## Data sources (local only, in `data-raw/`)

- `Cobia_TTT_Receiver_List.csv`: partner receiver list
  (`Receiver, Lat, Lon, Institution, notes`). Blank `notes` are treated as Active.
- `BTT_BZ_MX_deployments.csv`: Bonefish & Tarpon Trust Belize/Mexico array,
  copied from `BTT_AcTelem_BZ_MX/data/processed/deployments_clean.csv`.

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
