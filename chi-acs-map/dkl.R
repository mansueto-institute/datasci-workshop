
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

acs5_vars_selected <- c('B23025_004','B23025_005','B23025_006','B23025_007',
                        'B06001_002','B06001_003','B06001_004','B06001_005','B06001_006','B06001_007','B06001_008','B06001_009','B06001_010','B06001_011','B06001_012',
                        'B19001_002','B19001_003','B19001_004','B19001_005','B19001_006','B19001_007','B19001_008','B19001_009','B19001_010','B19001_011','B19001_012','B19001_013','B19001_014','B19001_015','B19001_016','B19001_017',
                        'B19001A_002','B19001A_003','B19001A_004','B19001A_005','B19001A_006','B19001A_007','B19001A_008','B19001A_009','B19001A_010','B19001A_011','B19001A_012','B19001A_013','B19001A_014','B19001A_015','B19001A_016','B19001A_017',
                        'B19001B_002','B19001B_003','B19001B_004','B19001B_005','B19001B_006','B19001B_007','B19001B_008','B19001B_009','B19001B_010','B19001B_011','B19001B_012','B19001B_013','B19001B_014','B19001B_015','B19001B_016','B19001B_017',
                        'B19001C_002','B19001C_003','B19001C_004','B19001C_005','B19001C_006','B19001C_007','B19001C_008','B19001C_009','B19001C_010','B19001C_011','B19001C_012','B19001C_013','B19001C_014','B19001C_015','B19001C_016','B19001C_017',
                        'B19001C_002','B19001C_003','B19001C_004','B19001C_005','B19001C_006','B19001C_007','B19001C_008','B19001C_009','B19001C_010','B19001C_011','B19001C_012','B19001C_013','B19001C_014','B19001C_015','B19001C_016','B19001C_017',
                        'B19001D_002','B19001D_003','B19001D_004','B19001D_005','B19001D_006','B19001D_007','B19001D_008','B19001D_009','B19001D_010','B19001D_011','B19001D_012','B19001D_013','B19001D_014','B19001D_015','B19001D_016','B19001D_017',
                        'B19001E_002','B19001E_003','B19001E_004','B19001E_005','B19001E_006','B19001E_007','B19001E_008','B19001E_009','B19001E_010','B19001E_011','B19001E_012','B19001E_013','B19001E_014','B19001E_015','B19001E_016','B19001E_017',
                        'B19001F_002','B19001F_003','B19001F_004','B19001F_005','B19001F_006','B19001F_007','B19001F_008','B19001F_009','B19001F_010','B19001F_011','B19001F_012','B19001F_013','B19001F_014','B19001F_015','B19001F_016','B19001F_017',
                        'B19001G_002','B19001G_003','B19001G_004','B19001G_005','B19001G_006','B19001G_007','B19001G_008','B19001G_009','B19001G_010','B19001G_011','B19001G_012','B19001G_013','B19001G_014','B19001G_015','B19001G_016','B19001G_017',
                        'B19001H_002','B19001H_003','B19001H_004','B19001H_005','B19001H_006','B19001H_007','B19001H_008','B19001H_009','B19001H_010','B19001H_011','B19001H_012','B19001H_013','B19001H_014','B19001H_015','B19001H_016','B19001H_017',
                        'B19001I_002','B19001I_003','B19001I_004','B19001I_005','B19001I_006','B19001I_007','B19001I_008','B19001I_009','B19001I_010','B19001I_011','B19001I_012','B19001I_013','B19001I_014','B19001I_015','B19001I_016','B19001I_017',
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

explore_acs_vars()
options(scipen=999)

df <- acs_tract_all_us_data %>%
  rename_all(list(tolower)) %>%
  left_join(., acs5_vars %>% select(name, label), by = c('variable' = 'name')) %>%
  mutate(label = gsub("Estimate!!Total:", "", label), 
         label = gsub("With income:", "", label),
         label = gsub("In labor force", "", label),
         label = gsub("Civilian labor force", "", label),
         label = gsub("Household income the past 12 months \\(in 2019 inflation-adjusted dollars\\) --", "", label),
         label = gsub("", "", label),
         label = gsub("!!|:", "", label)) %>%
  separate(col = 'variable',  
           into = c('variable_group','variable_item'),
           sep = c('_'),
           remove = FALSE,
           extra = "merge") %>%
  mutate(label = case_when(variable_group == 'B19001A' ~ paste0('White alone',' - ',label),
                           variable_group == 'B19001B' ~ paste0('Black or African American alone',' - ',label),
                           variable_group == 'B19001C' ~ paste0('Native American alone',' - ',label),
                           variable_group == 'B19001D' ~ paste0('Asian alone',' - ',label),
                           variable_group == 'B19001E' ~ paste0('Pacific Islander alone',' - ',label),
                           variable_group == 'B19001F' ~ paste0('Some other race alone',' - ',label),
                           variable_group == 'B19001G' ~ paste0('Two or more races',' - ',label),
                           variable_group == 'B19001H' ~ paste0('White alone, not Latino',' - ',label),
                           variable_group == 'B19001I' ~ paste0('Hispanic or Latino',' - ',label),
                           TRUE ~ as.character(label))) %>%
  mutate(group_label = case_when(variable_group == "B02001" ~ 'Race',
                                 variable_group == "B03001" ~ 'Hispanic or Latino',
                                 variable_group == "B08124" ~ 'Occupation',
                                 variable_group == "B08126" ~ 'Industry',
                                 variable_group == "B15003" ~ 'Education attainment',
                                 variable_group == 'B23025' ~ 'Employment status',
                                 variable_group == 'B06001' ~ 'Age',
                                 variable_group == 'B19001' ~ 'Household income',
                                 variable_group == 'B19001A' ~ 'Household income - White alone',
                                 variable_group == 'B19001B' ~ 'Household income - Black or African American alone',
                                 variable_group == 'B19001C' ~ 'Household income - Native American alone',
                                 variable_group == 'B19001D' ~ 'Household income - Asian alone',
                                 variable_group == 'B19001E' ~ 'Household income - Pacific Islander alone',
                                 variable_group == 'B19001F' ~ 'Household income - Some other race alone',
                                 variable_group == 'B19001G' ~ 'Household income - Two or more races',
                                 variable_group == 'B19001H' ~ 'Household income - White alone, not Latino',
                                 variable_group == 'B19001I' ~ 'Household income - Hispanic or Latino'),
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
  arrange(county_fips, tract_fips, variable) %>%
  mutate_at(vars(tract_pct,county_pct,cbsa_pct), ~replace(., is.nan(.), 0)) %>%
  filter(cbsa_title %in% c("Chicago-Naperville-Elgin, IL-IN-WI",
                           "Madison, WI",
                           "Minneapolis-St. Paul-Bloomington, MN-WI",
                           "Indianapolis-Carmel-Anderson, IN",
                           "Milwaukee-Waukesha, WI"))

write_csv(df, '/Users/nm/Desktop/dkl_input_data.csv')

write_csv(df %>% filter(tract_fips == '17031010100'), '/Users/nm/Desktop/dkl_test.csv')

