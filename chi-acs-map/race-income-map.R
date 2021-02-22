

library(sf)
library(dplyr)
library(ggplot2)
library(purrr)
library(tigris)
library(tidyverse)
library(tidycensus)
library(stringr)
library(readxl)
library(viridis)
library(scales)
library(lubridate)
library(reshape2)
library(ggrepel)
library(patchwork)
library(ggforce)

# Set file path of parent directory
path_wd <- '/Users/nm/Desktop/'

# Obtain Census API Key here: https://api.census.gov/data/key_signup.html
#census_api_key('API_KEY', install = TRUE) 

readRenviron("~/.Renviron")

# Spatial GIS Files --------------------------------------------------------------

# Community Areas GeoJSON
community_areas <- 'https://data.cityofchicago.org/api/geospatial/cauq-8yn6?method=export&format=GeoJSON'
tmp_filepath <- paste0(tempdir(), '/', basename(community_areas))
download.file(url = paste0(community_areas), destfile = tmp_filepath)
community_geo <- sf::st_read(tmp_filepath) %>% st_as_sf() %>% select(community)

# State and Tract shapefiles
state_xwalk <- as.data.frame(fips_codes) %>%
  rename(state_fips = state_code,
         state_codes = state,
         county_name = county) %>%
  mutate(county_fips = paste0(state_fips,county_code))

state_fips <- unique(state_xwalk$state_fips)[1:51]
state_codes <- unique(state_xwalk$state_codes)[1:51]

# Chicago Tracts
chicago_tracts_url <- 'https://data.cityofchicago.org/api/geospatial/5jrd-6zik?method=export&format=GeoJSON'
tmp_filepath <- paste0(tempdir(), '/', basename(chicago_tracts_url))
download.file(url = paste0(chicago_tracts_url), destfile = tmp_filepath)
chicago_tracts <- sf::st_read(tmp_filepath) %>% st_as_sf() %>%
  mutate_at(vars(geoid10),list(as.character)) %>%
  mutate(geoid10 = str_pad(geoid10, width=11, side="left", pad="0")) %>%
  select(geoid10) %>%
  rename(geoid = geoid10)



# Final Plots -------------------------------------------------------------

map_ggplot <- function(data, fill_var, scale_label = percent,
                       lab_t = '', lab_s = '', lab_c = '') {
  plot <- ggplot(data) +
    geom_sf( aes_string(fill = fill_var), color = 'white', size = .55) +
    scale_fill_viridis("", option = "magma", direction = -1, labels = scale_label) +
    labs(title = lab_t,subtitle = lab_s,caption = lab_c) +
    coord_sf(clip = "on") + theme_minimal() +  
    theme(axis.line = element_blank(),
          axis.text = element_blank(),
          axis.text.x = element_blank(),
          axis.text.y = element_blank(),
          axis.ticks = element_blank(),
          axis.title.x = element_blank(),
          axis.title.y = element_blank(),
          panel.spacing.x=unit(0, "lines"),
          panel.spacing.y=unit(0, "lines"),
          panel.grid.major = element_line(color = "#ebebe5", size = 0.2),
          panel.grid.minor = element_blank(),
          plot.background = element_rect(fill = "#f5f5f2", color = NA),
          #plot.title = element_text(face = 'bold',size=10),
          plot.title = element_blank(),
          legend.text = element_text(size= 9),
          plot.subtitle=element_text(size=9, hjust = .5, face = 'bold'),
          plot.caption=element_text(size=9, hjust = 0, face = 'italic'),
          panel.background = element_rect(fill = "#f5f5f2", color = NA), 
          legend.background = element_rect(fill = "#f5f5f2", color = NA),
          plot.margin=unit(c(t=3,r=0,b=-10,l=0), "mm"),
          panel.border = element_blank())  
  print(plot)
  return(plot)
}

# ACS Data ----------------------------------------------------------------

# Census Planning Database at Tract level
data_url <- 'https://www2.census.gov/adrm/PDB/2020/pdb2020trv2_us.zip'
download.file(url = paste0(data_url), destfile = paste(tempdir(), basename(data_url), sep = "/")) 
df_acs_raw <- read.csv(unzip(zipfile = paste(tempdir(), basename(data_url), sep = "/")))

df_acs_raw <- df_acs_raw %>% 
  rename_all(tolower) %>%
  mutate_at(vars(gidtr, state),list(as.character)) %>%
  mutate(gidtr = str_pad(gidtr, width=11, side="left", pad="0"),
         state = str_pad(state, width=2, side="left", pad="0"),
         county = str_pad(county, width=3, side="left", pad="0"),
         county_fips = str_sub(gidtr, 1, 5)) %>%
  filter(state %in% state_fips) %>% 
  filter(!is.na(tot_population_acs_14_18))

df_acs_raw %>% 
  group_by(gidtr) %>% 
  mutate(dupes = n()) %>%
  ungroup() %>%
  filter(dupes >= 2)

df_acs_raw <- inner_join(df_acs_raw, chicago_tracts, by = c('gidtr'='geoid') ) %>% 
  st_as_sf() %>% 
  st_join(., community_geo, left= TRUE, largest = TRUE) %>%
  st_drop_geometry() %>% 
  as.data.frame() 

vars_sum <- c('nh_white_alone_acs_14_18','nh_blk_alone_acs_14_18','nh_aian_alone_acs_14_18','nh_asian_alone_acs_14_18','hispanic_acs_14_18',
              'college_acs_14_18','prs_blw_pov_lev_acs_14_18','children_in_pov_acs_14_18','female_no_hb_acs_14_18','tot_vacant_units_acs_14_18',
              'owner_occp_hu_acs_14_18','single_unit_acs_14_18','recent_built_hu_acs_14_18','aggr_house_value_acs_14_18','aggregate_hh_inc_acs_14_18',
              'tot_population_acs_14_18','pop_25yrs_over_acs_14_18','pov_univ_acs_14_18',
              'children_povdet_acs_14_18','tot_occp_units_acs_14_18','tot_housing_units_acs_14_18' )

df_acs_raw_sum <- df_acs_raw %>%
  mutate_at(vars('aggr_house_value_acs_14_18','aggregate_hh_inc_acs_14_18'),funs(as.numeric(gsub('\\$|,', '', .)))  ) %>%
  mutate_at(vars(vars_sum),list(as.numeric), na.rm = TRUE) %>%
  group_by(community) %>%
  summarise_at(vars(vars_sum), list(sum)) %>%
  ungroup() 

df_acs_processed <- df_acs_raw_sum %>%
  mutate(pct_white = nh_white_alone_acs_14_18/tot_population_acs_14_18,
         pct_black = nh_blk_alone_acs_14_18/tot_population_acs_14_18,
         pct_aian = nh_aian_alone_acs_14_18/tot_population_acs_14_18,
         pct_asian = nh_asian_alone_acs_14_18/tot_population_acs_14_18,
         pct_latino = hispanic_acs_14_18/tot_population_acs_14_18,
         pct_college = college_acs_14_18/pop_25yrs_over_acs_14_18,
         pct_blw_pov = prs_blw_pov_lev_acs_14_18 /pov_univ_acs_14_18,
         pct_children_blw_pov = children_in_pov_acs_14_18/children_povdet_acs_14_18,
         pct_female_no_hb = female_no_hb_acs_14_18/tot_occp_units_acs_14_18,
         pct_vacant = tot_vacant_units_acs_14_18/tot_housing_units_acs_14_18,
         pct_owner_occ = owner_occp_hu_acs_14_18/tot_occp_units_acs_14_18,
         pct_single_detached = single_unit_acs_14_18/tot_housing_units_acs_14_18,
         pct_recent_built = recent_built_hu_acs_14_18/tot_housing_units_acs_14_18,
         avg_hh_inc_acs_14_18 = aggregate_hh_inc_acs_14_18/tot_occp_units_acs_14_18, 
         avg_house_value_acs_14_18 = aggr_house_value_acs_14_18/tot_housing_units_acs_14_18) %>%
  select(community, tot_population_acs_14_18, tot_occp_units_acs_14_18, tot_housing_units_acs_14_18,
         pct_white,pct_black,pct_aian,pct_asian,pct_latino,
         pct_college,pct_blw_pov,pct_children_blw_pov,pct_female_no_hb,pct_vacant,
         pct_owner_occ,pct_single_detached,pct_recent_built,
         avg_hh_inc_acs_14_18, avg_house_value_acs_14_18 )

vars_median <- c('med_hhd_inc_acs_14_18','med_house_value_acs_14_18')

df_acs_raw_median <- df_acs_raw %>%
  mutate_at(vars(vars_median),funs(as.numeric(gsub('\\$|,', '', .)))  ) %>%
  mutate(med_house_value_acs_14_18_weighted = tot_occp_units_acs_14_18*med_house_value_acs_14_18,
         med_hhd_inc_acs_14_18_weighted = tot_housing_units_acs_14_18*med_hhd_inc_acs_14_18) %>%
  #select(community,med_house_value_acs_14_18, med_hhd_inc_acs_14_18)
  group_by(community) %>%
  summarise_at(vars(med_house_value_acs_14_18,med_hhd_inc_acs_14_18,
                    med_house_value_acs_14_18_weighted,med_hhd_inc_acs_14_18_weighted,
                    tot_occp_units_acs_14_18,tot_housing_units_acs_14_18), list(sum), na.rm = TRUE) %>% 
  ungroup() %>%
  mutate(med_house_value_acs_14_18 = (med_house_value_acs_14_18_weighted/tot_occp_units_acs_14_18),
         med_hhd_inc_acs_14_18 = (med_hhd_inc_acs_14_18_weighted/tot_housing_units_acs_14_18)) %>%
  select(community, med_house_value_acs_14_18,med_hhd_inc_acs_14_18)

df_acs_processed = left_join(df_acs_processed, df_acs_raw_median, by = c('community'='community'))

rm(df_acs_raw_median, df_acs_raw_sum)

# Consolidated analysis dataframe -----------------------------------------

df_analysis <- left_join(community_geo,  df_acs_processed, by = c('community'='community')) %>%
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf()

# Crop out O'Hare
chi_bbox <- st_bbox(df_analysis) 
chi_bbox_crop <- st_bbox(c(xmin = -87.862226, 
                           xmax = chi_bbox[[3]], 
                           ymax = chi_bbox[[4]], 
                           ymin = chi_bbox[[2]]), crs = st_crs(4326))
df_analysis <- st_crop(df_analysis, y = chi_bbox_crop) %>%
  mutate(lon = map_dbl(geometry, ~st_point_on_surface(.x)[[1]]),
         lat = map_dbl(geometry, ~st_point_on_surface(.x)[[2]])) 

df_analysis <- df_analysis %>%
  mutate(race_label = case_when((pct_white <= .6 & pct_white >= .2) & (pct_latino <= .6 & pct_latino >= .2) & (pct_black <= .6 & pct_black >= .2) ~ 'White, Black & Latino',
                                (pct_white <= .6 & pct_white >= .2) & (pct_asian <= .6 & pct_asian >= .2) ~ 'Asian & white',
                                (pct_white <= .6 & pct_white >= .2) & (pct_black <= .6 & pct_black >= .2) ~ 'Black & white',
                                (pct_white <= .6 & pct_white >= .2) & (pct_latino <= .6 & pct_latino >= .2) ~ 'Latino & white',
                                (pct_black <= .6 & pct_black >= .2) & (pct_latino <= .6 & pct_latino >= .2) ~ 'Black & Latino',
                                #(pct_asian <= .6 & pct_asian >= .2) & (pct_latino <= .6 & pct_latino >= .2) ~ 'Asian & Latino',
                                #(pct_asian <= .6 & pct_asian >= .2) & (pct_black <= .6 & pct_black >= .2) ~ 'Asian & Black',
                                pct_black >= .5 ~ 'Black',
                                pct_latino >= .5 ~ 'Latino',
                                pct_asian >= .5 ~ 'Asian',
                                pct_white >= .5 ~ 'White',
                                TRUE ~ as.character('Other')),
         income_label = case_when(med_hhd_inc_acs_14_18 <= 50000 ~ '$20-50K',
                                  med_hhd_inc_acs_14_18 > 50000 & med_hhd_inc_acs_14_18 <= 75000 ~ '$50-75K',
                                  med_hhd_inc_acs_14_18 > 75000 ~ '$75-120K',
                                  TRUE ~ as.character('Other'))) %>%
  mutate(race_income_label = paste0(race_label,' (',income_label,')'))

race_income_levels <- c("White, Black & Latino ($20-50K)","White ($50-75K)","White ($75-120K)","Black & white ($50-75K)","Black & white ($75-120K)","Black ($20-50K)","Black ($50-75K)","Black & Latino ($20-50K)","Black & Latino ($50-75K)","Latino ($20-50K)","Latino ($50-75K)","Latino & white ($50-75K)","Latino & white ($75-120K)","Asian ($20-50K)","Asian & white ($50-75K)","Asian & white ($75-120K)")

df_analysis$race_income_label<- factor(df_analysis$race_income_label, levels = race_income_levels)

df_analysis <- df_analysis %>%
  mutate(community_label = str_to_title(community)) %>%
  mutate(community_label = gsub("North ","N. ", community_label ),
         community_label = gsub("South ", "S. ",community_label ),
         community_label = gsub("West ", "W. ", community_label ),
         community_label = gsub("East ", "E. ", community_label ))

df_outlines_all <- df_analysis %>%
  select(race_income_label) %>%
  group_by(race_income_label) %>% 
  summarize(geometry = st_union(geometry)) %>%
  ungroup() %>%
  mutate(lon = map_dbl(geometry, ~st_point_on_surface(.x)[[1]]),
         lat = map_dbl(geometry, ~st_point_on_surface(.x)[[2]])) 


df_analysis <- df_analysis %>%
  mutate(lat_mod = case_when(community == 'WEST ENGLEWOOD' ~ .$lat - .01, # South
                             community == 'GREATER GRAND CROSSING' ~ .$lat - .0055,
                             community == 'JEFFERSON PARK' ~ .$lat - .007,
                             community == 'ALBANY PARK' ~ .$lat - .002,
                             community == 'BEVERLY' ~ .$lat - .01,
                             community == 'BRIGHTON PARK' ~ .$lat - .007,
                             community == 'BRIDGEPORT' ~ .$lat - .009,
                             community == 'WASHINGTON PARK' ~ .$lat - .004,
                             community == 'AVALON PARK' ~ .$lat - .004,
                             community == 'MCKINLEY PARK' ~ .$lat - .002,
                             community == 'WEST ELSDON' ~ .$lat - .004,
                             community == 'GARFIELD RIDGE'~ .$lat - .01,
                             community == 'ROSELAND' ~ .$lat - .015,
                             community == 'HEGEWISCH' ~ .$lat - .015,
                             community == 'RIVERDALE' ~ .$lat - .01,
                             community == 'FULLER PARK'~ .$lat - .008,
                             community == 'KENWOOD' ~ .$lat - .004,
                             community == 'ENGLEWOOD' ~ .$lat + .003, # North
                             community == 'NORTH LAWNDALE' ~ .$lat + .004,
                             community == 'WOODLAWN' ~ .$lat + .003,
                             community == 'GRAND BOULEVARD' ~ .$lat + .003,
                             community == 'ARMOUR SQUARE' ~ .$lat + .002,
                             community == 'WEST PULLMAN' ~ .$lat + .003,
                             community == 'SOUTH CHICAGO' ~ .$lat + .003,
                             community == 'CHATHAM' ~ .$lat + .003,
                             TRUE ~ as.numeric(.$lat)),
         lon_mod = case_when(community == 'LOWER WEST SIDE'~ .$lon - .003, # West
                             community == 'MCKINLEY PARK' ~ .$lon - .003,
                             community == 'GARFIELD RIDGE'~ .$lon - .02,
                             community == 'WASHINGTON PARK' ~ .$lon - .004,
                             community == 'GRAND BOULEVARD' ~ .$lon - .003,
                             community == 'ENGLEWOOD' ~ .$lon - .004,
                             community == 'ROSELAND' ~ .$lon - .007,
                             community == 'HEGEWISCH' ~ .$lon - .009,
                             community == 'ARMOUR SQUARE' ~ .$lon - .007,
                             community == 'EAST GARFIELD PARK' ~ .$lon + .003, # East
                             community == 'OAKLAND' ~ .$lon + .01,
                             community == 'NEAR NORTH SIDE' ~ .$lon + .002,
                             community == 'WEST PULLMAN' ~ .$lon + .007,
                             community == 'WEST ENGLEWOOD' ~ .$lon + .006,
                             community == 'KENWOOD' ~ .$lon + .005,
                             community == 'MCKINLEY PARK' ~ .$lon + .005,
                             community == 'EDGEWATER' ~ .$lon + .006,
                             community == 'IRVING PARK' ~ .$lon + .005,
                             community == 'BRIDGEPORT' ~ .$lon + .0065,
                             community == 'CALUMET HEIGHTS' ~ .$lon + .003,
                             community == 'DOUGLAS' ~ .$lon + .003,
                             TRUE ~ as.numeric(.$lon)))      

#colorhexes <-  colorRampPalette(c('#e41a1c','#f781bf','#ff7f00','#ffff33','#4daf4a','#377eb8','#984ea3','#999999'))(16)
#colorhexes <-  colorRampPalette(c('#543005','#8c510a','#bf812d','#35978f','#01665e','#003c30','#40004b','#762a83','#9970ab','#5aae61','#1b7837','#00441b'))(16)
#,'#67001f','#b2182b','#d6604d','#4393c3','#2166ac','#053061'))(16)

colorhexes <-  colorRampPalette(c('#f44336','#E91E63','#9C27B0','#673AB7','#3F51B5','#2196F3','#00BCD4','#009688','#4CAF50','#CDDC39','#FFEB3B','#FFC107','#FF9800','#795548','#9E9E9E','#607D8B'))(16)

(panel0 <- ggplot(df_analysis) +
    geom_sf(fill = 'white', color = '#242629', size = .45, alpha= .6) +
    geom_sf(data = df_outlines_all, aes(fill =  race_income_label), color = 'white', size = .45, alpha= .6) +
    #geom_sf(data = df_outlines_cops, color = '#242629', size = .3, alpha= 0) +
    geom_text(mapping = aes(x = lon_mod,y =lat_mod, label = str_wrap(community_label, width = 4)), 
              fontface = 'bold', size = 2.85) +
    scale_fill_manual(values=colorhexes)+
    labs(title = "",
         subtitle = "Race and Income in Chicago Community Areas",
         caption = '  Source: U.S. Census Bureau. Analysis of 2014-2018 American Community Survey 5-year estimates.') +
    coord_sf(clip = "on") +
    theme_minimal() +
    theme(axis.line = element_blank(),
          axis.text = element_blank(),
          axis.text.x = element_blank(),
          axis.text.y = element_blank(),
          axis.ticks = element_blank(),
          axis.title.x = element_blank(),
          axis.title.y = element_blank(),
          text = element_text(family = "Lato", size = 13, color = "#333333"),
          panel.spacing.x=unit(0, "lines"),
          panel.spacing.y=unit(0, "lines"),
          panel.grid.major = element_line(color = "#ebebe5", size = 0.2),
          panel.grid.minor = element_blank(),
          plot.background = element_rect(fill = "white", color = NA),
          plot.title = element_text(face = 'bold',size=10),
          #plot.title = element_blank(),
          legend.text = element_text(size= 13),
          legend.title = element_blank(),
          #legend.position= "bottom",
          plot.subtitle=element_text(size=15, hjust = 1, vjust= -3, face = 'bold'),
          plot.caption=element_text(size=13, vjust =5,  hjust = -1, face = 'italic'),
          panel.background = element_rect(fill = "white", color = NA), 
          legend.background = element_rect(fill = "white", color = NA),
          plot.margin=unit(c(t=-5,r=0,b=0,l=0), "mm"),
          panel.border = element_blank()) )

ggsave(paste0(path_wd,'panel0.png'), panel0, dpi = 400, height =11, width=10)
