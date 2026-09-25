#==========================================================
# COBIA & TRIPLETAIL ACOUSTIC RECEIVER NETWORK
# Public Shiny app (runs in the browser via shinylive)
#
# Locations are generalized to ~5 km grid cells and the map
# will not zoom in past MAX_ZOOM, so exact receiver positions
# are never shown. Receivers are not labelled by institution;
# partners are credited as a list in the sidebar.
#==========================================================

library(shiny)
library(bslib)
library(leaflet)

MAX_ZOOM <- 10 # ~150 m/pixel; a 5 km cell is still a blob, not a spot
MIN_ZOOM <- 4

#----------------------------------------------------------
# DATA
#----------------------------------------------------------

rx <- read.csv("receivers_public.csv", stringsAsFactors = FALSE)
partners <- read.csv("partners.csv", stringsAsFactors = FALSE, na.strings = "")

# Status order doubles as priority: a cell with any active
# receiver is drawn as active, and so on
status_cols <- c(
  "Active"        = "#0072B2",
  "Not specified" = "#56B4E9",
  "Planned"       = "#E69F00",
  "Proposed"      = "#CC79A7"
)
status_cols <- status_cols[names(status_cols) %in% rx$Status]
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
  title = "Cobia & Tripletail Receiver Network",
  theme = bs_theme(version = 5, primary = "#0072B2"),
  fillable_mobile = TRUE,

  sidebar = sidebar(
    width = 300,
    open = list(desktop = "open", mobile = "closed"),
    p(
      class = "small text-muted",
      "Acoustic receivers used to track tagged cobia and tripletail",
      "across the Gulf. Locations are generalized to ~5 km areas;",
      "circle size shows the number of receivers in each area."
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
    rx[rx$Status %in% input$status, ]
  })

  # One marker per grid cell, coloured by its highest-priority status
  cells <- reactive({
    d <- filtered()
    if (nrow(d) == 0) return(NULL)
    key <- paste(d$cell_lat, d$cell_lon)
    do.call(rbind, lapply(split(d, key), function(g) {
      g <- g[order(match(g$Status, statuses)), ]
      n <- sum(g$n_receivers)
      data.frame(
        lat = g$cell_lat[1],
        lon = g$cell_lon[1],
        n = n,
        col = status_cols[[g$Status[1]]],
        popup = paste0(
          "<b>", n, " receiver", ifelse(n > 1, "s", ""),
          " in this ~5 km area</b><br>",
          paste0(g$n_receivers, " ", tolower(g$Status), collapse = "<br>")
        ),
        stringsAsFactors = FALSE
      )
    }))
  })

  # Markers are drawn inside renderLeaflet (not via leafletProxy) so
  # they reliably appear under shinylive. The current view is kept
  # when filters change.
  output$map <- renderLeaflet({
    cl <- cells()
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
      setMaxBounds(-105, 12, -70, 40)

    m <- if (is.null(ctr)) {
      fitBounds(m, -98, 18.5, -79, 31)
    } else {
      setView(m, ctr$lng, ctr$lat, zm)
    }

    if (is.null(cl)) return(m)

    m |>
      addCircleMarkers(
        data = cl, lng = ~lon, lat = ~lat,
        radius = ~pmin(4 + 2.5 * sqrt(n), 16),
        color = "white", weight = 1, opacity = 0.9,
        fillColor = ~col, fillOpacity = 0.85,
        popup = ~popup
      )
  })

  output$summary <- renderUI({
    d <- filtered()
    p(
      class = "small text-muted",
      sprintf(
        "%s receivers in %d areas shown",
        format(sum(d$n_receivers), big.mark = ","),
        length(unique(paste(d$cell_lat, d$cell_lon)))
      )
    )
  })
}

shinyApp(ui, server)
