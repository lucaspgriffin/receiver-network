#==========================================================
# RECEIVER NETWORK
# Public Shiny app (runs on shinyapps.io, and in the browser
# via shinylive on GitHub Pages)
#
# Receivers are shown at their true positions, but the map will
# not zoom in past MAX_ZOOM. Receivers are not labelled by
# institution; partners are credited as a list in the sidebar.
#==========================================================

library(shiny)
library(bslib)
library(leaflet)

MAX_ZOOM <- 10
MIN_ZOOM <- 4

#----------------------------------------------------------
# DATA
#----------------------------------------------------------

rx <- read.csv("receivers_public.csv", stringsAsFactors = FALSE)
partners <- read.csv("partners.csv", stringsAsFactors = FALSE, na.strings = "")

DOT_COL <- "#0072B2"

partner_label <- ifelse(
  is.na(partners$name),
  partners$acronym,
  paste0(partners$name, " (", partners$acronym, ")")
)

#----------------------------------------------------------
# UI
#----------------------------------------------------------

ui <- page_sidebar(
  title = "Receiver Network",
  window_title = "Receiver Network",
  theme = bs_theme(version = 5, primary = "#0072B2"),
  fillable_mobile = TRUE,

  sidebar = sidebar(
    width = 300,
    open = list(desktop = "open", mobile = "closed"),
    p(
      class = "small text-muted",
      "Active and planned acoustic telemetry receivers operated by",
      "partner institutions across the Gulf and western Caribbean.",
      "This is a partial collection, shown to the best of our",
      "knowledge; other arrays exist, and receivers may be relocated",
      "over time."
    ),
    p(
      class = "small text-muted",
      sprintf("%s receivers shown", format(nrow(rx), big.mark = ","))
    ),
    hr(),
    h6("Partner institutions"),
    tags$ul(
      class = "small ps-3 mb-0",
      lapply(sort(partner_label), tags$li)
    )
  ),

  card(
    full_screen = TRUE,
    card_body(padding = 0, leafletOutput("map", height = "100%"))
  )
)

#----------------------------------------------------------
# SERVER
#----------------------------------------------------------

server <- function(input, output, session) {

  output$map <- renderLeaflet({

    leaflet(options = leafletOptions(minZoom = MIN_ZOOM, maxZoom = MAX_ZOOM)) |>
      addProviderTiles(
        providers$Esri.OceanBasemap, group = "Ocean",
        options = providerTileOptions(maxZoom = MAX_ZOOM)
      ) |>
      addProviderTiles(
        providers$Esri.WorldImagery, group = "Satellite",
        options = providerTileOptions(maxZoom = MAX_ZOOM)
      ) |>
      addLayersControl(
        baseGroups = c("Ocean", "Satellite"),
        options = layersControlOptions(collapsed = TRUE)
      ) |>
      setMaxBounds(-105, 10, -70, 40) |>
      fitBounds(-98, 16.5, -79, 31) |>
      addCircleMarkers(
        data = rx, lng = ~lon, lat = ~lat,
        radius = 3.5,
        color = "white", weight = 0.7, opacity = 0.9,
        fillColor = DOT_COL, fillOpacity = 0.85
      )
  })
}

shinyApp(ui, server)
