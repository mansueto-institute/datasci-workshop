

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

# Metro crosswalk
xwalk_url <- 'https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2020/delineation-files/list1_2020.xls'
tmp_filepath <- paste0(tempdir(), '/', basename(xwalk_url))
download.file(url = paste0(xwalk_url), destfile = tmp_filepath)
cbsa_xwalk <- read_excel(tmp_filepath, sheet = 1, range = cell_rows(3:1919))
cbsa_xwalk <- cbsa_xwalk %>% 
  select_all(~gsub("\\s+|\\.|\\/", "_", .)) %>%
  rename_all(list(tolower)) %>%
  mutate(fips_state_code = str_pad(fips_state_code, width=2, side="left", pad="0"),
         fips_county_code = str_pad(fips_county_code, width=3, side="left", pad="0"),
         county_fips = paste0(fips_state_code,fips_county_code)) %>%
  rename(cbsa_fips = cbsa_code,
         area_type = metropolitan_micropolitan_statistical_area) %>%
  select(county_fips,cbsa_fips,cbsa_title,area_type,central_outlying_county) 

# Investigate Census Variables
acs5_vars <- load_variables(year = 2019, dataset = c('acs5'), cache = FALSE) 
# Separate concept column so its easier to sort through
acs5_vars <- acs5_vars %>% separate(col = 'concept',  
                                    into = c('concept_main','concept_part'),
                                    sep = c(' BY '),
                                    remove = FALSE,
                                    extra = "merge") %>%
  mutate(concept_part = case_when(is.na(concept_part) ~ 'TOTAL',
                                  TRUE ~ as.character(concept_part)))

# Create HTML Search Window to find variables
explore_acs_vars()

acs5_vars_selected <- c('B06010_002','B06010_004','B06010_005','B06010_006','B06010_007','B06010_008','B06010_009','B06010_010','B06010_011',
                        'B25121_002','B25121_017','B25121_032','B25121_047','B25121_062','B25121_077','B25121_092',
                        'B08126_002','B08126_003','B08126_004','B08126_005','B08126_006','B08126_007','B08126_008','B08126_009','B08126_010','B08126_011','B08126_012','B08126_013','B08126_014','B08126_015',        
                        'B08124_002','B08124_003','B08124_004','B08124_005','B08124_006','B08124_007',
                        'B15003_002','B15003_003','B15003_004','B15003_005','B15003_006','B15003_007','B15003_008','B15003_009','B15003_010','B15003_011','B15003_012','B15003_013','B15003_014','B15003_015','B15003_016',
                        'B15003_017','B15003_018','B15003_019','B15003_020','B15003_021','B15003_022','B15003_023','B15003_024','B15003_025',
                        'B02001_002','B02001_003','B02001_004','B02001_005','B02001_006','B02001_007','B02001_008',
                        'B03001_002','B03001_003')

# 'B06010_001','B06010_003','B25121_001','B08126_001','B08124_001','B15003_001','B02001_001','B03001_001'

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
          variables = acs5_vars_selected, 
          state = x)
})

options(scipen=999)
df <- acs_tract_all_us_data %>%
  rename_all(list(tolower)) %>%
  left_join(., acs5_vars %>% select(name, label), by = c('variable' = 'name')) %>%
  mutate(label = gsub("Estimate!!Total:", "", label), 
         label = gsub("With income:", "", label),
         label = gsub("Household income the past 12 months \\(in 2019 inflation-adjusted dollars\\) --", "", label),
         label = gsub("", "", label),
         label = gsub("!!|:", "", label)) %>%
  separate(col = 'variable',  
           into = c('variable_group','variable_item'),
           sep = c('_'),
           remove = FALSE,
           extra = "merge") %>%
  mutate(group_label = case_when(variable_group == "B02001" ~ 'Race',
                                 variable_group == "B03001" ~ 'Latino',
                                 variable_group == "B06010" ~ 'Individual Income',
                                 variable_group == "B08124" ~ 'Occupation',
                                 variable_group == "B08126" ~ 'Industry',
                                 variable_group == "B15003" ~ 'Education',
                                 variable_group == "B25121" ~ 'Household Income'),
         county_fips = str_sub(geoid,1,5)) %>%
  left_join(., state_xwalk, by = c('county_fips'='county_fips')) %>%
  left_join(.,cbsa_xwalk, by = c('county_fips'='county_fips')) %>%
  group_by(geoid, variable_group) %>% mutate(tract_total = sum(estimate)) %>% ungroup() %>%
  group_by(county_fips, variable) %>% mutate(county_estimate = sum(estimate)) %>% ungroup() %>%
  group_by(county_fips, variable_group) %>% mutate(county_total = sum(estimate)) %>% ungroup() %>%
  group_by(cbsa_fips, variable) %>% mutate(cbsa_estimate = sum(estimate)) %>% ungroup() %>%
  group_by(cbsa_fips, variable_group) %>% mutate(cbsa_total = sum(estimate)) %>% ungroup() %>%
  mutate(tract_pct = estimate / tract_total,
         county_pct = county_estimate / county_total,
         cbsa_pct = cbsa_estimate / cbsa_total) %>%
  rename(tract_estimate = estimate,
         tract_fips = geoid) %>%
  select(tract_fips,county_fips,county_name,cbsa_fips,cbsa_title,area_type,central_outlying_county,state_codes,state_fips,state_name,variable,variable_group,variable_item,group_label,label,tract_pct,tract_estimate,moe,tract_total,county_pct,county_estimate,county_total,cbsa_pct,cbsa_estimate,cbsa_total) %>%
  filter(cbsa_title %in% c("Chicago-Naperville-Elgin, IL-IN-WI",
                           "Champaign-Urbana, IL",
                           "Madison, WI",
                           "Minneapolis-St. Paul-Bloomington, MN-WI",
                           "Indianapolis-Carmel-Anderson, IN",
                           "Milwaukee-Waukesha, WI"))
  
write_csv(df, '/Users/nm/Desktop/dkl_input_data.csv')

