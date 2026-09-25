#==========================================================
# COBIA & TRIPLETAIL ACOUSTIC RECEIVER NETWORK
# Public Shiny app (runs in the browser via shinylive)
#
# Locations are generalized to ~5 km grid cells and the map
# will not zoom in past MAX_ZOOM, so exact receiver positions
# are never shown.
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

institutions <- sort(unique(rx$Institution))
statuses <- intersect(
  c("Active", "Planned", "Proposed", "Not specified"),
  unique(rx$Status)
)

# One distinct colour per institution (Tableau-style, grey reserved)
inst_cols <- c(
  "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd", "#8c564b",
  "#e377c2", "#bcbd22", "#17becf", "#aec7e8", "#ffbb78", "#98df8a",
  "#ff9896", "#c5b0d5"
)[seq_along(institutions)]
names(inst_cols) <- institutions
MULTI_COL <- "#333333"

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

#----------------------------------------------------------
# UI
#----------------------------------------------------------

ui <- page_sidebar(
  title = "Cobia & Tripletail Receiver Network",
  theme = bs_theme(version = 5, primary = "#0072B2"),
  fillable_mobile = TRUE,

  sidebar = sidebar(
    width = 290,
    open = list(desktop = "open", mobile = "closed"),
    p(
      class = "small text-muted",
      "Acoustic receivers from partner institutions across the Gulf.",
      "Locations are generalized to ~5 km areas; circle size shows",
      "the number of receivers in each area."
    ),
    checkboxGroupInput(
      "inst", "Institution",
      choiceNames = unname(Map(swatch, inst_cols, institutions)),
      choiceValues = institutions,
      selected = institutions
    ),
    p(class = "small text-muted mt-n2", swatch(MULTI_COL, "Multiple institutions in one area")),
    div(
      class = "d-flex gap-2 mb-3",
      actionButton("inst_all", "All", class = "btn-sm"),
      actionButton("inst_none", "None", class = "btn-sm")
    ),
    checkboxGroupInput(
      "status", "Status",
      choices = statuses, selected = statuses
    ),
    hr(),
    uiOutput("summary")
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

  observeEvent(input$inst_all, {
    updateCheckboxGroupInput(session, "inst", selected = institutions)
  })
  observeEvent(input$inst_none, {
    updateCheckboxGroupInput(session, "inst", selected = character(0))
  })

  filtered <- reactive({
    rx[rx$Institution %in% input$inst & rx$Status %in% input$status, ]
  })

  # One marker per grid cell; popup lists who has what there
  cells <- reactive({
    d <- filtered()
    if (nrow(d) == 0) return(NULL)
    key <- paste(d$cell_lat, d$cell_lon)
    do.call(rbind, lapply(split(d, key), function(g) {
      by_inst <- tapply(g$n_receivers, g$Institution, sum)
      data.frame(
        lat = g$cell_lat[1],
        lon = g$cell_lon[1],
        n = sum(g$n_receivers),
        col = if (length(by_inst) == 1) inst_cols[[names(by_inst)]] else MULTI_COL,
        popup = paste0(
          "<b>", sum(g$n_receivers), " receiver",
          ifelse(sum(g$n_receivers) > 1, "s", ""), " in this ~5 km area</b><br>",
          paste0(
            g$Institution, ": ", g$n_receivers, " (", tolower(g$Status), ")",
            collapse = "<br>"
          )
        ),
        stringsAsFactors = FALSE
      )
    }))
  })

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
      setMaxBounds(-105, 12, -70, 40) |>
      fitBounds(-98, 18.5, -79, 31)
  })

  observe({
    cl <- cells()
    proxy <- leafletProxy("map") |> clearMarkers()
    if (is.null(cl)) return()

    proxy |>
      addCircleMarkers(
        data = cl, lng = ~lon, lat = ~lat,
        radius = ~pmin(4 + 2.5 * sqrt(n), 16),
        color = "white", weight = 1, opacity = 0.9,
        fillColor = ~col, fillOpacity = 0.8,
        popup = ~popup
      )
  })

  output$summary <- renderUI({
    d <- filtered()
    tagList(
      h6(sprintf("%s receivers shown", format(sum(d$n_receivers), big.mark = ","))),
      p(
        class = "small text-muted mb-0",
        sprintf(
          "%d institutions, %d areas",
          length(unique(d$Institution)),
          length(unique(paste(d$cell_lat, d$cell_lon)))
        )
      )
    )
  })
}

shinyApp(ui, server)
