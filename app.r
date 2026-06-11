library(shiny)
library(leaflet)
library(ggplot2)
library(plotly)
library(lubridate)
library(dplyr)
library(readr)
library(leaflet.extras)
library(sf)
library(tidycensus)
library(patchwork)


# abbey's reference commands:
# library(rsconnect)
# deployApp()
# shiny::runApp()

# clean out the data
assault_clean <- readr::read_csv("assault_clean.csv")

assault_clean <- assault_clean %>%
  mutate(
    Date = lubridate::mdy_hms(Date),
    hour = lubridate::hour(Date),
    Year = lubridate::year(Date),
    time_group = ifelse(hour >= 20 | hour < 6, "Night", "Day"),
    category = ifelse(grepl("AGGRAVATED", Description, ignore.case = TRUE),
                      "Aggravated", "Other"),
    Arrest = as.factor(Arrest)
  ) %>%
  filter(!is.na(Latitude), !is.na(Longitude))





# trends
yearly_counts <- assault_clean %>%
  count(Year)

p_trend <- ggplot(yearly_counts, aes(
  x = Year,
  y = n,
  group = 1,
  text = paste0("Year: ", Year, "<br>Count: ", n)
)) +
  geom_line() +
  geom_point() +
  theme_minimal() +
  labs(
    x = "Year",
    y = "Number of Cases"
  )

p_trend_plotly <- ggplotly(p_trend, tooltip = "text")



# ui
ui <- fluidPage(

  navbarPage(
  "Chicago Sexual Assault Analysis Dashboard",
  header = tags$p("M. Prue & A. Kratman, 2026.")
),

  tabsetPanel(
    tabPanel("Cluster Map",
             leafletOutput("map_points"),
             p("This graph shows clusters of data. Clicking on each cluster allows you to zoom in, and see the individual data points-- specifically what crimes they pull from.")
             ),

    tabPanel("Heat Map",
             leafletOutput("map_heat"),
              p("This graph maps heat to the quantity of assaults commited. Zoom in to interact with it.")
    ),
    tabPanel("Population vs. Crime Rate Analysis",
             leafletOutput("map_census"),
              p("This graph compares each census tract to the rate of crime it experiences.
              \n If no data shows, please check https://api.census.gov/status/.")
    ),

            tabPanel("Basic Analysis",
        p("These graphs were built to understand the basic trends of the data before the team applied further visualizations."),
             plotlyOutput("trend_plot"),
              p("This graph is a simple trend tracker with hoverable data points. Click on them to see their year and quantity."),
              plotlyOutput("circadian_plot"),
                       p("This graph studies the time during which crimes are commited most often in basis to the data.")
                        
    ),
    tabPanel("Severity by Populace Heatmap",
         leafletOutput("map_severity_pop"),
         p("This heatmap weights crimes by severity in terms of population weight, with more severe crimes weighed higher"),
         p("Aggravated crimes count for five points, while non-aggravated count for one.
         \n If no data shows, please check https://api.census.gov/status/.")
            )
          )
)



# server stuff 

server <- function(input, output, session) {


# graph buildin' 


output$map_points <- renderLeaflet({
    leaflet(assault_clean) %>%
      addTiles() %>%
      addCircleMarkers(
        lng = ~Longitude,
        lat = ~Latitude,
        radius = 5,
        color = "red",
        popup = ~Description,
            fillOpacity = 1,
        clusterOptions = markerClusterOptions(
        showCoverageOnHover = TRUE,
        zoomToBoundsOnClick = TRUE
        )
      )
  })

  
  output$map_heat <- renderLeaflet({
  leaflet(assault_clean) %>%
    addTiles() %>%
    leaflet.extras::addHeatmap(
      lng = ~Longitude,
      lat = ~Latitude,
      radius = 8,
      blur = 10,
      max = 0.05
    )
})

  output$map_severity <- renderLeaflet({
    leaflet(assault_clean) %>%
      addTiles() %>%
      addCircleMarkers(
        lng = ~Longitude,
        lat = ~Latitude,
        radius = 3,
        stroke = FALSE,
        fillOpacity = 0.4,
        color = ~ifelse(category == "Aggravated", "red", "orange"),
        popup = ~category
      )
  })

  output$trend_plot <- renderPlotly({
    p_trend_plotly
  })



# ------------------------ BARRIER SO ABBEY DOESN'T LOSE IT ------------------------ 
# census census census this is the census section 

output$map_census <- renderLeaflet({



  assault_sf <- sf::st_as_sf(
    assault_clean,
    coords = c("Longitude", "Latitude"),
    crs = 4326
  )
  pop_data <- tidycensus::get_acs(
    geography = "tract",
    variables = "B01003_001",
    state = "IL",
    county = "Cook",
    year = 2022,
    geometry = TRUE
  )
  pop_data <- sf::st_transform(pop_data, 4326)
  assault_with_tract <- sf::st_join(assault_sf, pop_data)

  assault_counts <- assault_with_tract %>%
    sf::st_drop_geometry() %>%
    dplyr::group_by(GEOID) %>%
    dplyr::summarise(n_assaults = n(), .groups = "drop")

  final_data <- pop_data %>%
    dplyr::left_join(assault_counts, by = "GEOID") %>%
    dplyr::mutate(
      n_assaults = ifelse(is.na(n_assaults), 0, n_assaults),
      rate_per_100 = (n_assaults / estimate) * 100
    )

  final_data$rate_per_100[is.na(final_data$rate_per_100)] <- 0
  final_data$rate_per_100[is.infinite(final_data$rate_per_100)] <- 0
  assault_pts <- sf::st_coordinates(assault_sf)
  assault_pts <- data.frame(x = assault_pts[,1], y = assault_pts[,2])

  pal <- colorNumeric(
    palette = "viridis",
    domain = final_data$rate_per_100
  )


  leaflet() %>%
    addTiles() %>%
    addPolygons(
      data = final_data,
      fillColor = ~ifelse(rate_per_100 == 0, NA, pal(rate_per_100)),
      color = "white",
      weight = 1,
      fillOpacity = ~ifelse(rate_per_100 == 0, 0, .8),
      group = "Choropleth",
      popup = ~paste(
        "<strong>Census Tract:</strong>", NAME,
        "<br><strong>Assaults:</strong>", n_assaults,
        "<br><strong>Rate per 100:</strong>", round(rate_per_100, 2)
      )
    ) %>%
 addLegend(
      pal = pal,
      values = final_data$rate_per_100,
      title = "Rate per 100 people",
      position = "bottomright"
    )
})




# ------------------------ BARRIER SO ABBEY DOESN'T LOSE IT ------------------------ 

# time of day evolution -- just make a trend tracker for when crimes happen
# we're calling it circadian rhythm

assault_clean <- assault_clean %>%
  dplyr::filter(!is.na(Longitude), !is.na(Latitude)) %>%
  dplyr::mutate(
    Date = as.POSIXct(Date, tz = "UTC"),
    hour = lubridate::hour(Date),

    time_group = ifelse(hour >= 6 & hour < 20,
                        "Daytime Crimes",
                        "Nighttime Crimes"),

    category = ifelse(grepl("AGGRAVATED", Description, ignore.case = TRUE),
                      "Aggravated",
                      "Other")
  )


# ------------------------ BARRIER SO ABBEY DOESN'T LOSE IT ------------------------ 
# circadian data
circ_data <- assault_clean %>%
  dplyr::group_by(hour) %>%
  dplyr::summarise(crimes = n(), .groups = "drop")

p_circadian <- ggplot(circ_data, aes(
  x = hour,
  y = crimes,
  text = paste0("Hour: ", hour, "<br>Crimes: ", crimes)
)) +
  geom_smooth(se = FALSE, color = "blue", linewidth = 1.2, span = 0.4) +
  geom_point(alpha = 0.6) +
  scale_x_continuous(breaks = 0:23) +
  labs(
    title = "24-Hour Circadian Rhythm of Assault Incidents",
    x = "Hour of Day (Military Time)",
    y = "Number of Crimes"
  ) +
  theme_minimal()

p_circadian_plotly <- ggplotly(p_circadian, tooltip = "text")


output$circadian_plot <- renderPlotly({
  plot_ly(circ_data, x = ~hour, y = ~crimes, type = "scatter", mode = "lines+markers",
          text = ~paste0("Hour: ", hour, "<br>Crimes: ", crimes),
          hoverinfo = "text")
})





# severity of crimes by population density

output$map_severity_pop <- renderLeaflet({

  pop_data <- tidycensus::get_acs(
    geography = "tract",
    variables = "B01003_001",
    state = "IL",
    county = "Cook",
    year = 2022,
    geometry = TRUE
  ) %>%
    sf::st_transform(4326)


  assault_sf <- sf::st_as_sf(
    assault_clean,
    coords = c("Longitude", "Latitude"),
    crs = 4326
  )


  assault_with_tract <- sf::st_join(assault_sf, pop_data)

  tract_severity <- assault_with_tract %>%
    sf::st_drop_geometry() %>%  
    dplyr::filter(!is.na(GEOID)) %>%
    dplyr::mutate(
      severity_weight = ifelse(category == "Aggravated", 5, 1)
    ) %>%
    dplyr::group_by(GEOID) %>%
    dplyr::summarise(
      severity_score = sum(severity_weight),
      .groups = "drop"
    )


 final_data <- pop_data %>%
  dplyr::left_join(tract_severity, by = "GEOID") %>%
  dplyr::mutate(
    severity_score = ifelse(is.na(severity_score), 0, severity_score),
    estimate = ifelse(is.na(estimate), NA_real_, estimate),

    severity_per_1000 = ifelse(
      is.na(estimate) | estimate == 0,
      0,
      (severity_score / estimate) * 1000
    )
  )

  final_data$severity_per_1000[is.na(final_data$severity_per_1000)] <- 0


domain_vals <- final_data$severity_per_1000

domain_vals <- domain_vals[is.finite(domain_vals)]

if (length(domain_vals) == 0) {
  domain_vals <- c(0, 1) #error fix
}

pal <- colorNumeric(
  palette = "magma",
  domain = domain_vals
)
  leaflet(final_data) %>%
    addTiles() %>%

    addPolygons(
      fillColor = ~ifelse(severity_per_1000 == 0, NA, pal(severity_per_1000)),
      color = "white",
      weight = 1,
      fillOpacity = ~ifelse(severity_per_1000 == 0, 0, 0.8),
      layerId = ~GEOID,
      popup = ~paste0(
        "<b>Tract:</b> ", NAME,
        "<br><b>Severity:</b> ", round(severity_score, 2),
        "<br><b>Per 1000:</b> ", round(severity_per_1000, 2)
      )
    ) %>%

    addLegend(
      pal = pal,
      values = ~severity_per_1000,
      title = "Severity per 1000",
      position = "bottomright"
    )
})


}

shinyApp(ui, server)