# Cobia & Tripletail Receiver Network Map

Public, interactive map of the acoustic receiver network used for cobia and
tripletail tracking across the Gulf. It is an R Shiny app compiled with
[shinylive](https://posit-dev.github.io/r-shinylive/), so it runs entirely in the
visitor's browser and is hosted free on GitHub Pages (no Shiny server needed).

**Live app:** https://lucaspgriffin.github.io/cobia-tripletail-receiver-map/

QR code (links to the app): [`qr/receiver-map-qr.png`](qr/receiver-map-qr.png) ·
[`qr/receiver-map-qr.svg`](qr/receiver-map-qr.svg) (vector, best for print)

## Location privacy

Exact receiver coordinates are **not** in this repository.

- `R/prep_public_receivers.R` reads the exact list from `data-raw/` (git-ignored),
  drops receiver names and institutions, snaps coordinates to a 0.05° grid
  (~5 km), and writes counts per grid cell × status to `app/receivers_public.csv`.
- Receivers are not labelled by institution. Partners are credited as a list
  in the sidebar, from `app/partners.csv` (edit it by hand; a blank `name`
  shows the acronym alone).
- The map is capped at zoom level 10, so it cannot be zoomed to fine scale.

To change the level of generalization, edit `GRID_DEG` in the prep script and
`MAX_ZOOM` in `app/app.R`.

## Updating the receiver list

1. Save the updated receiver CSV to `data-raw/Cobia_TTT_Receiver_List.csv`
   (columns: `Receiver, Lat, Lon, Institution, notes`).
2. Run `Rscript R/prep_public_receivers.R` from the repo root.
3. If a new institution appears, add it to `app/partners.csv`.
4. Commit and push `app/receivers_public.csv`. GitHub Actions rebuilds and
   redeploys the site in a few minutes; the QR code URL stays the same.

## Running locally

```r
shiny::runApp("app")
```

## Data notes

- Two TAMUG platform longitudes were entered without the minus sign
  (`Mobile Platform`, `Sargent Platform`); the prep script flips them.
- Bounds were widened from the original Gulf box (lat 20–32, lon −100 to −80)
  to keep the Veracruz, Atlantic Florida, and inland Louisiana/Arkansas river
  receivers.
- Blank `notes` are shown as status "Not specified".
