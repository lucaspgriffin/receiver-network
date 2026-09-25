#==========================================================
# RECEIVER NETWORK
# Public Shiny app (runs on shinyapps.io, and in the browser
# via shinylive on GitHub Pages)
#
# Receiver positions in receivers_public.csv are already
# generalized (see R/prep_public_receivers.R), and the map will
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

status_cols <- c(
  "Active"  = "#0072B2",
  "Planned" = "#E69F00"
)
status_cols <- status_cols[names(status_cols) %in% rx$status]
statuses <- names(status_cols)

# Checkbox labels double as the colour key
swatch <- function(col, label) {
  tags$span(
    tags$span(style = sprintf(
      "display:inline-block;width:12px;height:12px;border-radius:50%%;background:%s;margin-right:6px;vertical-align:-1px;",
      col
    )),
    label
  )
}

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
      "Acoustic telemetry receivers operated by partner institutions",
      "across the Gulf and western Caribbean. This is a partial",
      "collection, shown to the best of our knowledge; other arrays",
      "exist, and active receivers may be relocated over time."
    ),
    checkboxGroupInput(
      "status", "Receiver status",
      choiceNames = unname(Map(swatch, status_cols, statuses)),
      choiceValues = statuses,
      selected = statuses
    ),
    uiOutput("summary"),
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

  filtered <- reactive({
    rx[rx$status %in% input$status, ]
  })

  # Markers are drawn inside renderLeaflet (not via leafletProxy) so
  # they reliably appear under shinylive. The current view is kept
  # when filters change.
  output$map <- renderLeaflet({
    d <- filtered()
    ctr <- isolate(input$map_center)
    zm <- isolate(input$map_zoom)

    m <- leaflet(options = leafletOptions(minZoom = MIN_ZOOM, maxZoom = MAX_ZOOM)) |>
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
      setMaxBounds(-105, 10, -70, 40)

    m <- if (is.null(ctr)) {
      fitBounds(m, -98, 16.5, -79, 31)
    } else {
      setView(m, ctr$lng, ctr$lat, zm)
    }

    if (nrow(d) == 0) return(m)

    m |>
      addCircleMarkers(
        data = d, lng = ~lon, lat = ~lat,
        radius = 4,
        color = "white", weight = 0.7, opacity = 0.9,
        fillColor = ~unname(status_cols[status]), fillOpacity = 0.85,
        popup = ~paste0("<b>Receiver</b><br>Status: ", tolower(status))
      )
  })

  output$summary <- renderUI({
    p(
      class = "small text-muted",
      sprintf("%s receivers shown", format(nrow(filtered()), big.mark = ","))
    )
  })
}

shinyApp(ui, server)
