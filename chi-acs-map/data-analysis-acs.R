
# Author: Nicholas Marchio nmarchio at uchicago dot edu
# Date: March 2021
# This script works through several vignettes of using the Census API, processing the data, and building choropleth maps
# Developed in R version 4.0.4 (2021-02-15)
# Google Slide Deck: https://docs.google.com/presentation/d/1crLM8qvvuLrAIxXrrUurge5213OlSOR7o_e425_f25o/edit?usp=sharing

library(tidyverse)
library(sf)
library(lwgeom)
library(tidycensus)
library(scales)
library(viridis)
library(DT)
library(shiny)
library(ggplot2)
library(readxl)
library(patchwork)

# Setup -------------------------------------------------------------------

# Set file path of parent directory
path_wd <- '/Users/nm/Desktop/projects/work/mansueto/workshops/acs-data-analysis/'

# 1. Obtain Census API Key here: https://api.census.gov/data/key_signup.html
# 2. Run census_api_key function to add API_KEY to .Renviron
# census_api_key('API_KEY', install = TRUE) 
# 3. Restart RStudio

# Another option is to simply run:
# Sys.getenv("API_KEY") 

# Read the .Renviron file (only necessary fi you ran census_api_key()
readRenviron("~/.Renviron")

# Function to launch a mini Shiny app to look up Census variables
explore_acs_vars <- function () { 
  ui <- basicPage(h2("ACS Variable Search"), 
                  tags$style('#display {height:100px; white-space: pre-wrap;}'),
                  verbatimTextOutput('display', placeholder = TRUE),
                  mainPanel(DT::dataTableOutput(outputId = "acs_table", width = '800px'))
  )
  server <- function(input, output, session) {
    output$acs_table= DT::renderDataTable({ 
      acs5_vars <- acs5_vars 
    }, filter = "top", selection = 'multiple', options = list(columnDefs = list( list(className = "nowrap",width = '100px', targets = c(1,2))), pageLength = 20), server = TRUE) 
    selected_index <- reactive({
      acs5_vars %>% slice(input$acs_table_rows_selected) %>% pull(name)
    })
    output$display = renderPrint({
      s = unique(input$acs_table_rows_selected)
      if (length(s)) {cat(paste0("'",selected_index(),"'",collapse = ","))}
    })
  }
  shinyApp(ui, server)
}

# Vignette 1: -------------------------------------------------------------
# Download population from Census for all counties
# Prepare the data for analysis
# Make a county choropleth map

# API request of population for 2019 for all counties with spatial geometries (and shift AK and HI to bottom left)
acs_county <- get_acs(year = 2019, geography = "county", variables = 'B01003_001', 
                     geometry = TRUE, keep_geo_vars = TRUE, shift_geo = TRUE)

# Example of "piping" with a %>%
acs_county <- acs_county %>%
  # Reformat columns to lowercase
  rename_all(list(tolower)) %>%
  # Rename columns to better descriptions
  rename(county_fips = geoid,
         county_population = estimate) %>%
  # Select most useful columns
  select(county_fips,name,variable,county_population)


# Create a county choropleth using base log 10 scaling and custom labels / clean aesthetics
(p <- ggplot(acs_county, aes(fill = log10(county_population), color = log10(county_population))) +
    geom_sf() + 
    scale_fill_viridis(breaks= c(2,3,4,5,6,7), labels = c("100","1K","10K","100K","1M","10M") ) + 
    scale_color_viridis(breaks= c(2,3,4,5,6,7), labels = c("100","1K","10K","100K","1M","10M")) + 
    labs(title = "", subtitle = "U.S. County Population", caption = 'Source: U.S. Census Bureau. 2015-2019 American Community Survey 5-year estimates.') +
    theme_minimal() + theme(legend.title = element_blank())) 

# Write plot to PNG
ggsave(plot = p, filename = paste0(path_wd,'counties.png'), device = 'png') 

# Vignette 2 --------------------------------------------------------------
# Download multiple fields from Census for one county 
# Prepare the data for analysis
# Make a tract choropleth map within a city

# Investigate Census Variables
acs5_vars <- load_variables(year = 2019, dataset = c('acs5'), cache = FALSE) 
# Separate concept column so its easier to sort through
acs5_vars <- acs5_vars %>% separate(col = 'concept',  
                                    into = c('concept_main','concept_part'),
                                    sep = c(' BY '),
                                    remove = FALSE,
                                    extra = "merge") %>%
  # Recode values
  mutate(concept_part = case_when(is.na(concept_part) ~ 'TOTAL',
                                  TRUE ~ as.character(concept_part)))

# Create HTML Search Window to find variables
explore_acs_vars()

# Variables for Population by Race/Ethnicity and Median Household Income 
acs5_vars_selected <- c('B02001_001', 'B03002_003', 'B03002_012', 'B02009_001', 'B02011_001', 'B19013_001', 'B25001_001')

# Download Census data by tract for Cook County, IL
acs_tract <- get_acs(year = 2019, geography = "tract", survey = 'acs5', 
                     variables = acs5_vars_selected, 
                     state = '17', county = '031') 

# Reshape the table from long to wide
acs_tract <- acs_tract %>%
  rename_all(list(tolower)) %>%
  pivot_wider(id_cols = geoid,
              names_from = c(variable), 
              values_from = c(estimate)) %>%
  rename(total_population = B02001_001, # TOTAL POPULATION
         black_population = B02009_001, # POPULATION OF BLACK OR AFRICAN AMERICAN ALONE OR IN COMBINATION WITH ONE OR MORE OTHER RACES
         white_population = B03002_003, # POPULATION WHITE ALONE NOT HISPANIC OR LATINO ORIGIN
         latino_population = B03002_012, # POPULATION HISPANIC OR LATINO ORIGIN
         asian_population = B02011_001, # POPULATION ASIAN ALONE OR IN COMBINATION WITH ONE OR MORE OTHER RACES
         median_household_income = B19013_001, # MEDIAN HOUSEHOLD INCOME IN THE PAST 12 MONTHS (IN 2019 INFLATION-ADJUSTED DOLLARS
         total_housing_units = B25001_001 # TOTAL HOUSING UNITS
         ) 

# Download geometries
geom_tract <- get_acs(year = 2019, geography = "tract", survey = 'acs5', 
                     variables = 'B02001_001', 
                     state = '17', county = '031', 
                     geometry = TRUE) %>%
  select(GEOID) %>%
  # Transform to WGS84
  st_transform(crs = st_crs(4326)) 

# Join tract data to geometries
acs_tract <- left_join(geom_tract, acs_tract, by = c('GEOID' = 'geoid'))

# Read in Community Areas from Chicago Data Portal
community_areas <- sf::st_read('https://data.cityofchicago.org/api/geospatial/cauq-8yn6?method=export&format=GeoJSON') %>% 
  # Set to WGS 84
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf() %>% 
  select(community)

# Build Chicago tract spatial data frame
chicago_acs_tract <- acs_tract %>%
  # Join in Community Areas with spatial join
  st_join(., community_areas, left= TRUE, largest = TRUE) %>%
  # Filter where community is missing
  filter(!is.na(community)) %>% 
  # Create population shares for each race/ethnicity
  mutate(black_population_share = black_population/total_population,
         white_population_share = white_population/total_population,
         latino_population_share = latino_population/total_population,
         asian_population_share = asian_population/total_population)
        
# Create tract choropleth maps
(p_b <- ggplot(chicago_acs_tract, aes(fill = black_population_share, color = black_population_share)) +
  geom_sf() + scale_fill_viridis(labels = percent_format()) + scale_color_viridis(labels = percent_format()) +
  labs(title = "", subtitle = "Black share of population", caption = '') +
  theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank()))

(p_l <- ggplot(chicago_acs_tract, aes(fill = latino_population_share, color = latino_population_share)) +
  geom_sf() + scale_fill_viridis(labels = percent_format()) + scale_color_viridis(labels = percent_format()) +
  labs(title = "", subtitle = "Latino share of population", caption = '') +
  theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank()))

(p_w <- ggplot(chicago_acs_tract, aes(fill = white_population_share, color = white_population_share)) +
  geom_sf() + scale_fill_viridis(labels = percent_format()) + scale_color_viridis(labels = percent_format()) +
  labs(title = "", subtitle = "White share of population", caption = '') +
  theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank()))

(p_i <- ggplot(chicago_acs_tract, aes(fill = median_household_income, color = median_household_income)) +
  geom_sf() + scale_fill_viridis(option = "magma", labels = dollar_format()) + scale_color_viridis(option = "magma", labels = dollar_format())  +
  labs(title = "", subtitle = "Median household income", caption = '') +
  theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank()))

(panel <- p_b + p_l + p_w + p_i +
  plot_annotation(title = '',#subtitle = 'Demographic and Socioeconomic Tract Patterns in Chicago',
                  caption = "U.S. Census Bureau. Analysis of 2015-2019 American Community Survey 5-year estimates.") & 
  theme(plot.caption = element_text(hjust = 0, face= "italic"), 
        plot.tag.position = "bottom") + theme(text = element_text(family = "Lato")))

# Write plot to PNG
ggsave(plot = panel, filename = paste0(path_wd,'chi_tract.png'), device = 'png') 


# Vignette 3 --------------------------------------------------------------
# Aggregate tract data to community areas
# Make a community area choropleth map 

# Aggregate from tract to community area
chicago_acs_community_areas <- chicago_acs_tract %>%
  st_drop_geometry() %>%
  # Weight median household income
  mutate(median_household_income_weighted = total_housing_units*median_household_income) %>%
  # Group by community and aggregate
  group_by(community) %>%  
  summarise_at(vars(total_population,
                    black_population,
                    white_population,
                    latino_population,
                    asian_population,
                    median_household_income_weighted,
                    total_housing_units), list(sum), na.rm = TRUE) %>% 
  ungroup() %>%
  # Divide weighted sum by total housing units
  mutate(median_household_income = median_household_income_weighted / total_housing_units) %>%
  # Select columns
  select(community, 
         total_population,
         median_household_income,
         black_population,
         white_population,
         latino_population,
         asian_population) %>%
  # Calculate population shares
  mutate(black_population_share = black_population/total_population,
         white_population_share = white_population/total_population,
         latino_population_share = latino_population/total_population,
         asian_population_share = asian_population/total_population)
  
# Join community data to community area geometries
chicago_acs_community_areas <- left_join(community_areas, 
                                         chicago_acs_community_areas, 
                                         by = c('community'='community')) %>%
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf()

# Create community area choropleth maps
(c_b <- ggplot(chicago_acs_community_areas, aes(fill = black_population_share, color = black_population_share)) +
  geom_sf() + scale_fill_viridis(labels = percent_format()) + scale_color_viridis(labels = percent_format()) +
  labs(title = "", subtitle = "Black share of population", caption = '') +
  theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank()))

(c_w <- ggplot(chicago_acs_community_areas, aes(fill = white_population_share, color = white_population_share)) +
  geom_sf() + scale_fill_viridis(labels = percent_format()) + scale_color_viridis(labels = percent_format()) +
  labs(title = "", subtitle = "White share of population", caption = '') +
  theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank()))

(c_l <- ggplot(chicago_acs_community_areas, aes(fill = latino_population_share, color = latino_population_share)) +
  geom_sf() + scale_fill_viridis(labels = percent_format()) + scale_color_viridis(labels = percent_format()) +
  labs(title = "", subtitle = "Latino share of population", caption = '') +
  theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank()))

(c_i <- ggplot(chicago_acs_community_areas, aes(fill = median_household_income, color = median_household_income)) +
  geom_sf() + scale_fill_viridis(option = "magma", labels = dollar_format()) + scale_color_viridis(option = "magma", labels = dollar_format()) +
  labs(title = "", subtitle = "Median Household Income", caption = '') +
  theme_minimal() + theme(legend.title = element_blank(), axis.text = element_blank()))

(panel_areas <- c_b + c_l + c_w + c_i +
    plot_annotation(title = '',#subtitle = 'Demographic and Socioeconomic Community Area Patterns in Chicago',
                    caption = "U.S. Census Bureau. Analysis of 2015-2019 American Community Survey 5-year estimates.") & 
    theme(plot.caption = element_text(hjust = 0, face= "italic"), 
          plot.tag.position = "bottom") + theme(text = element_text(family = "Lato")))

ggsave(plot = panel_areas, filename = paste0(path_wd,'chi_community_area.png'), device = 'png') 

# Vignette 4 --------------------------------------------------------------
# Download ACS data for all tracts in US (or a subset of states)
# Download and build county to metro crosswalk from non-machine friendly format
# Make a tract choropleth map for one metro area
# Make a tract choropleth map for one city within metro area

# Download state codes via tidycensus' "fips_codes" data set
state_xwalk <- as.data.frame(fips_codes) %>%
  rename(state_fips = state_code,
         state_codes = state,
         county_name = county) %>%
  mutate(county_fips = paste0(state_fips,county_code))
# Make lists for FIPS and codes
state_fips <- unique(state_xwalk$state_fips)[1:51]
state_codes <- unique(state_xwalk$state_codes)[1:51]

# Subset to states of interest (use state_codes list to get all states)
state_list <- c('IL','WI','IN')

# Use purrr function map_df to run a get_acs call that loops over all states
acs_tract_all_us_data <- map_df(state_list, function(x) {
  get_acs(year = 2019, geography = "tract", survey = 'acs5', 
          variables = c("B19013_001",'B15003_001','B15003_022','B15003_023','B15003_024','B15003_025',
                        'B08301_003','B08301_018','B08301_019','B08301_010','B08301_001',
                        'B08303_001','B08303_013','B08303_012','B08303_011','B08303_010'), 
          state = x)
})

# B08303_001 # Travel Time To Work Denominator
# B08303_013 # 40 to 44 minutes
# B08303_012 # 45 to 59 minutes
# B08303_011 # 60 to 89 minutes
# B08303_010 # 90 or more minutes
# B15003_022 # Bachelor' Degree
# B15003_023 # Master's Degree
# B15003_024 # Professional School Degree
# B15003_025 # Doctorate Degree
# B08301_018 # Bicycle
# B08301_019 # Walked
# B08301_010 # Public transportation (excluding taxicab)

acs_tract_all_us_data <- acs_tract_all_us_data %>%
  rename_all(list(tolower)) %>%
  pivot_wider(id_cols = geoid,
              names_from = c(variable), 
              values_from = c(estimate)) %>%
  mutate(median_household_income = B19013_001, # Median household income in the past 12 months (in 2019 inflation-adjusted dollars)
         population_25plus = B15003_001, # Population 25 years and over
         bachelors_plus_population = B15003_022+B15003_023+B15003_024+B15003_025,
         bachelors_plus_share = bachelors_plus_population/population_25plus,
         total_commuting_population = B08301_001, # Total Means of Transportation to Work
         drove_alone_population = B08301_003, # Drove alone
         bike_walk_transit_population = B08301_018+B08301_019+B08301_010,
         bike_walk_transit_share = bike_walk_transit_population/total_commuting_population,
         drove_alone_share = drove_alone_population/total_commuting_population,
         travel_over_40min_share = (B08303_013 + B08303_012 + B08303_011 + B08303_010) / B08303_001 ) %>%
  select(geoid, 
         median_household_income, bachelors_plus_share, 
         bike_walk_transit_share, drove_alone_share, travel_over_40min_share)

# Pull down geometries and population separately
acs_tract_all_us_geometries <- map_df(state_list, function(x) {
  get_acs(year = 2019, geography = "tract", survey = 'acs5', 
          variables = c("B01003_001"), 
          state = x,
          geometry = TRUE)
})

acs_tract_all_us <- left_join(acs_tract_all_us_geometries, acs_tract_all_us_data, by = c('GEOID'='geoid'))

# Download county-metro crosswalk from excel file on Census website, clean up columns
xwalk_url <- 'https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2020/delineation-files/list1_2020.xls'
tmp_filepath <- paste0(tempdir(), '/', basename(xwalk_url))
# Download file to temporary file
download.file(url = paste0(xwalk_url), destfile = tmp_filepath)
# Read sheet 1 rows 3 to 1919 from excel file (there is a space below the header)
cbsa_xwalk <- read_excel(tmp_filepath, sheet = 1, range = cell_rows(3:1919))
cbsa_xwalk <- cbsa_xwalk %>% 
  # Remove spaces, periods and slashes with underscores from columns
  select_all(~gsub("\\s+|\\.|\\/", "_", .)) %>%
  # Rename to lower
  rename_all(list(tolower)) %>%
  # Ensure state and county FIPS have leading zeroes
  mutate(fips_state_code = str_pad(fips_state_code, width=2, side="left", pad="0"),
         fips_county_code = str_pad(fips_county_code, width=3, side="left", pad="0"),
         county_fips = paste0(fips_state_code,fips_county_code)) %>%
  rename(cbsa_fips = cbsa_code,
         area_type = metropolitan_micropolitan_statistical_area) %>%
  select(county_fips,cbsa_fips,cbsa_title,area_type,central_outlying_county) 

acs_tract_all_us <- acs_tract_all_us %>%
  rename_all(list(tolower)) %>%
  # Clip first 5 numbers of tract geoid to get county FIPS
  mutate(county_fips = str_sub(geoid,1,5)) %>% 
  # Join in the county metro crosswalk to tract data
  left_join(., cbsa_xwalk, by = c('county_fips'='county_fips'))

# Limit to Chicago MSA
acs_tract_chicago_metro <- acs_tract_all_us %>%
  filter(cbsa_fips == '16980')

theme_maps <- theme(legend.title = element_blank(), axis.text = element_blank(),
                    panel.spacing.x=unit(0, "lines"),
                    panel.spacing.y=unit(0, "lines"),
                    plot.margin=unit(c(t=0,r=0,b=0,l=0), "mm"),
                    panel.border = element_blank(), 
                    plot.caption=element_text(vjust = -15, face = 'bold')) 

# Metro Commuting and Economic Maps
(m_p <- ggplot() +
    geom_sf(data = acs_tract_chicago_metro, aes(fill = log10(estimate), color = log10(estimate) )) +
    scale_fill_viridis(option = 'inferno', breaks= c(3,3.69897,4,4.3), labels = c("1K","5K","10K","20K") ) + 
    scale_color_viridis(option = 'inferno', breaks= c(3,3.69897,4,4.3), labels = c("1K","5K","10K","20K")) + 
    labs(title = "", subtitle = "Population", caption = '') +
    theme_minimal() + theme_maps )

(m_i <- ggplot() +
  geom_sf(data = acs_tract_chicago_metro, aes(fill = median_household_income, color = median_household_income)) +
  scale_fill_viridis(option = "magma", labels = dollar_format()) + scale_color_viridis(option = "magma", labels = dollar_format()) +
  labs(title = "", subtitle = "Median household income", caption = '') +
  theme_minimal() + theme_maps )

(m_ba <- ggplot() +
  geom_sf(data = acs_tract_chicago_metro, aes(fill = bachelors_plus_share, color = bachelors_plus_share )) +
  scale_fill_viridis(labels = percent_format()) + scale_color_viridis( labels = percent_format()) +
  labs(title = "", subtitle = "Share of population 25+ years\nwith Bachelor's or higher", caption = '') +
    theme_minimal() + theme_maps )

(m_car <- ggplot() +
  geom_sf(data = acs_tract_chicago_metro, aes(fill = drove_alone_share, color = drove_alone_share )) +
  scale_fill_viridis(option = "plasma", labels = percent_format()) + scale_color_viridis(option = "plasma", labels = percent_format()) +
  labs(title = "", subtitle = "Share of commuters who\ndrove alone", caption = '') +
    theme_minimal() + theme_maps )

(m_bwt <- ggplot() +
  geom_sf(data = acs_tract_chicago_metro, aes(fill = bike_walk_transit_share , color = bike_walk_transit_share )) +
  scale_fill_viridis(option = "plasma", labels = percent_format()) + scale_color_viridis(option = "plasma", labels = percent_format()) +
  labs(title = "", subtitle = "Share of commuters who travel\nby bike, foot, public transit", caption = '') +
    theme_minimal() + theme_maps)

(m_40 <- ggplot() +
    geom_sf(data = acs_tract_chicago_metro, aes(fill =travel_over_40min_share, color = travel_over_40min_share )) +
    scale_fill_viridis(option = "plasma", labels = percent_format()) + scale_color_viridis(option = "plasma", labels = percent_format()) +
    labs(title = "", subtitle = "Share of commuters who travel\nover 40 min to work", caption = '') +
    theme_minimal() + theme_maps)

(panel_msa <- m_p + m_i + m_ba +  m_car + m_bwt + m_40 +
    plot_annotation(title = '',#subtitle = 'Social Characteristics and Commuting Patterns in Chicago MSA',
                    caption = "U.S. Census Bureau. Analysis of 2015-2019 American Community Survey 5-year estimates.") & 
    theme(plot.caption = element_text(hjust = 0, face= "italic"), 
          plot.tag.position = "bottom",
          text = element_text(family = "Lato", size = 11) ))

ggsave(plot = panel_msa, filename = paste0(path_wd,'chimsa_tract.png'), device = 'png') 

# Zoom in on Chicago City
acs_tract_chicago_city <- acs_tract_chicago_metro %>% 
  st_transform(crs = st_crs(4326)) %>%
  st_join(., community_areas) %>%
  filter(!is.na(community))

(m_p <- ggplot() +
    geom_sf(data = acs_tract_chicago_city, aes(fill = log10(estimate), color = log10(estimate) )) +
    scale_fill_viridis(option = 'inferno', breaks= c(3,3.69897,4,4.3), labels = c("1K","5K","10K","20K") ) + 
    scale_color_viridis(option = 'inferno', breaks= c(3,3.69897,4,4.3), labels = c("1K","5K","10K","20K")) + 
    labs(title = "", subtitle = "Population", caption = '') +
    theme_minimal() + theme_maps )

(m_i <- ggplot() +
    geom_sf(data = acs_tract_chicago_city, aes(fill = median_household_income, color = median_household_income)) +
    scale_fill_viridis(option = "magma", labels = dollar_format()) + scale_color_viridis(option = "magma", labels = dollar_format()) +
    labs(title = "", subtitle = "Median household income", caption = '') +
    theme_minimal() + theme_maps )

(m_ba <- ggplot() +
    geom_sf(data = acs_tract_chicago_city, aes(fill = bachelors_plus_share, color = bachelors_plus_share )) +
    scale_fill_viridis(labels = percent_format()) + scale_color_viridis( labels = percent_format()) +
    labs(title = "", subtitle = "Share of population 25+ years\nwith Bachelor's or higher", caption = '') +
    theme_minimal() + theme_maps )

(m_car <- ggplot() +
    geom_sf(data = acs_tract_chicago_city, aes(fill = drove_alone_share, color = drove_alone_share )) +
    scale_fill_viridis(option = "plasma", labels = percent_format()) + scale_color_viridis(option = "plasma", labels = percent_format()) +
    labs(title = "", subtitle = "Share of commuters who\ndrove alone", caption = '') +
    theme_minimal() + theme_maps )

(m_bwt <- ggplot() +
    geom_sf(data = acs_tract_chicago_city, aes(fill = bike_walk_transit_share , color = bike_walk_transit_share )) +
    scale_fill_viridis(option = "plasma", labels = percent_format()) + scale_color_viridis(option = "plasma", labels = percent_format()) +
    labs(title = "", subtitle = "Share of commuters who travel\nby bike, foot, public transit", caption = '') +
    theme_minimal() + theme_maps)

(m_40 <- ggplot() +
    geom_sf(data = acs_tract_chicago_city, aes(fill =travel_over_40min_share, color = travel_over_40min_share )) +
    scale_fill_viridis(option = "plasma", labels = percent_format()) + scale_color_viridis(option = "plasma", labels = percent_format()) +
    labs(title = "", subtitle = "Share of commuters who travel\nover 40 min to work", caption = '') +
    theme_minimal() + theme_maps)

(panel_city <- m_p + m_i + m_ba +  m_car + m_bwt + m_40 +
    plot_annotation(title = '',#subtitle = 'Social Characteristics and Commuting Patterns in Chicago MSA',
                    caption = "U.S. Census Bureau. Analysis of 2015-2019 American Community Survey 5-year estimates.") & 
    theme(plot.caption = element_text(hjust = 0, face= "italic"), 
          plot.tag.position = "bottom",
          text = element_text(family = "Lato", size = 11) ))

ggsave(plot = panel_city, filename = paste0(path_wd,'chicity_tract.png'), device = 'png') 

