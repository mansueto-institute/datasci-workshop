
# Author: Nicholas Marchio, nmarchio@uchicago.edu
# Date: 10/26/2020
# Source: https://github.com/mansueto-institute/datasci-workshop/blob/master/chi-data-portal/urban-design-with-nature.R


library(sf)
library(dplyr)
library(ggplot2)
library(reshape2)
library(tidyverse)
library(stringr)
library(scales)
#library(purrr)
#library(tigris)
#library(tidycensus)
#library(readxl)
#library(viridis)
#library(lubridate)
#library(ggrepel)
#library(patchwork)
#library(ggforce)
#library(nngeo)


# Why does this matter? 
# E-bikes present a radical solution to urban mobility challenges that is sustainable, affordable,
# and allow for point-to-point transit in a timely manner. However, current bike infrastructure
# is already limited and unsafe. To achieve more sustainable transit outcomes urban policy
# makers need to identify and prioritize areas of the city most in need of better infrastructure. 

# Set file path of parent directory
path_wd <- '/Users/nm/Desktop/projects/work/mansueto/workshops/chi-data-portal'

# Obtain Census API Key here: https://api.census.gov/data/key_signup.html
#census_api_key('API_KEY', install = TRUE) 
readRenviron("~/.Renviron")


# Import data -------------------------------------------------------------

# Import Chicago community areas
# https://data.cityofchicago.org/Facilities-Geographic-Boundaries/Boundaries-Community-Areas-current-/cauq-8yn6
community_areas_url <- 'https://data.cityofchicago.org/api/geospatial/cauq-8yn6?method=export&format=GeoJSON'
community_areas <- sf::st_read(community_areas_url) %>% st_as_sf() %>% select(community)

# Import Chicago tracts
chicago_tracts_url <- 'https://data.cityofchicago.org/api/geospatial/5jrd-6zik?method=export&format=GeoJSON'
chicago_tracts <- sf::st_read(chicago_tracts_url) %>% st_as_sf() %>%
  mutate_at(vars(geoid10),list(as.character)) %>%
  mutate(geoid10 = str_pad(geoid10, width=11, side="left", pad="0")) %>%
  select(geoid10) %>%
  rename(geoid = geoid10)

# Import Chicago blocks
# chicago_blocks_url <- 'https://data.cityofchicago.org/api/geospatial/mfzt-js4n?method=export&format=GeoJSON'
# chicago_blocks <- sf::st_read(chicago_blocks_url) %>% st_as_sf() %>%
#   mutate_at(vars(geoid10),list(as.character)) %>%
#   mutate(geoid10 = str_pad(geoid10, width=15, side="left", pad="0")) %>%
#   select(geoid10) %>%
#   rename(geoid = geoid10)

# Import bike routes
bike_routes_url <- 'https://data.cityofchicago.org/api/geospatial/3w5d-sru8?method=export&format=GeoJSON'
bike_routes <- sf::st_read(bike_routes_url) %>% st_as_sf() %>%
  st_join(., community_areas, largest = TRUE)

# Import street routes
# street_routes_url <- 'https://data.cityofchicago.org/api/geospatial/6imu-meau?method=export&format=GeoJSON'
# street_routes <- sf::st_read(street_routes_url) %>% 
#   st_as_sf() %>%
#   filter(!st_is_empty(geometry))

# Import traffic crashes
traffic_crashes_url <- 'https://data.cityofchicago.org/api/views/85ca-t3if/rows.csv'
traffic_crashes <- read_csv(traffic_crashes_url) %>%
  rename_all(list(tolower)) %>%
  filter(first_crash_type == 'PEDALCYCLIST',
         most_severe_injury %in% c("NONINCAPACITATING INJURY","REPORTED, NOT EVIDENT","INCAPACITATING INJURY","FATAL")) %>%
  filter(!is.na(longitude)) %>%
  st_as_sf(coords = c("longitude", "latitude"), 
           crs = 4326, agr = "constant") %>% 
  mutate(injuries_dooring = case_when(dooring_i == 'Y' ~ 1, TRUE ~ as.numeric(0)))

# Process data ------------------------------------------------------------

# block_traffic_crashes <- traffic_crashes %>%
#   st_join(., chicago_blocks) %>%
#   st_drop_geometry() %>%  
#   group_by(geoid) %>% 
#   summarize_at(vars(injuries_total, injuries_dooring, injuries_fatal, injuries_incapacitating), list(sum), na.rm=TRUE)  %>%
#   ungroup() 
# 
# block_traffic_crashes <- left_join(chicago_blocks, block_traffic_crashes, by = c('geoid' = 'geoid')) %>%
#   mutate_at(vars(injuries_total, injuries_fatal, injuries_incapacitating), ~replace_na(., 0)) %>%
#   st_as_sf()

tract_traffic_crashes <- traffic_crashes %>%
  st_join(., chicago_tracts) %>%
  st_drop_geometry() %>%  
  group_by(geoid) %>% 
  summarize_at(vars(injuries_total, injuries_dooring, injuries_fatal, injuries_incapacitating), list(sum), na.rm=TRUE)  %>%
  ungroup() 

tract_traffic_crashes <- left_join(chicago_tracts, tract_traffic_crashes, by = c('geoid' = 'geoid')) %>%
  mutate_at(vars(injuries_total, injuries_fatal, injuries_incapacitating), ~replace_na(., 0)) %>%
  st_as_sf()

tract_traffic_crashes <- st_join(tract_traffic_crashes, community_areas, largest=TRUE)

tract_traffic_crashes_summary <- tract_traffic_crashes %>%
  st_drop_geometry() %>%  
  group_by(community) %>% 
  summarize_at(vars(injuries_total, injuries_dooring, injuries_fatal, injuries_incapacitating), list(sum), na.rm=TRUE)  %>%
  ungroup() %>%
  mutate(injuries_other = injuries_total - (injuries_dooring + injuries_fatal + injuries_incapacitating)) %>%
  select(community, injuries_other, injuries_dooring, injuries_fatal, injuries_incapacitating) %>%
  melt(id.vars = c('community')) %>%
  mutate(variable = case_when(variable == 'injuries_other' ~ 'Other', 
                              variable == 'injuries_dooring' ~ 'Dooring', 
                              variable == 'injuries_fatal' ~ 'Fatal', 
                              variable == 'injuries_incapacitating' ~ 'Incapacitating', 
                              TRUE ~ as.character('Other'))) %>%
  arrange(community, variable)%>%
  group_by(community) %>%
  mutate(total = sum(value)) %>%
  ungroup() %>%
  mutate(share = value / total) %>%
  arrange(community, desc(variable)) %>%
  group_by(community) %>%
  mutate(pos_id_share =  (cumsum(share) - 0.5*share ),
         pos_id_value =  (cumsum(value) - 0.5*value)) %>%
  ungroup() %>%
  mutate(rank = dense_rank(desc(total))) 
          
# Visualize ---------------------------------------------------------------

# Crop out O'Hare (not analytically useful)
chi_bbox <- st_bbox(tract_traffic_crashes) 
chi_bbox_crop <- st_bbox(c(xmin = -87.862226, 
                           xmax = chi_bbox[[3]], 
                           ymax = chi_bbox[[4]], 
                           ymin = chi_bbox[[2]]), crs = st_crs(4326))
tract_traffic_crashes <- st_crop(tract_traffic_crashes, y = chi_bbox_crop) %>%
  mutate(lon = map_dbl(geometry, ~st_point_on_surface(.x)[[1]]),
         lat = map_dbl(geometry, ~st_point_on_surface(.x)[[2]])) 

# Choropleth of Bike Routes
(pchoro <- ggplot() + 
  geom_sf(data = st_union(tract_traffic_crashes)) +
  geom_sf(data = tract_traffic_crashes, aes(fill = injuries_total, color = injuries_total),  size = .01 ) + #
  scale_fill_gradient2(low =  "#ffffff", high = "#F77552", labels = comma, name = "Reported\nInjuries") +
  scale_color_gradient2(low =  "#ffffff", high = "#F77552", labels = comma, name = "Reported\nInjuries") +
  geom_sf(data = bike_routes, color = alpha("#0194D3", .5), size = .7) + 
  labs(title = "Reported Bike Crashes (2015-2020) and Bike Lanes", caption = "Source: Chicago Data Portal") +
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
        text = ggplot2::element_text(family = "Lato"),
        plot.title = element_text(face = 'bold',size=14),
        legend.title = element_text(size= 12),
        legend.text = element_text(size= 10),
        plot.subtitle=element_text(size=9, hjust = .5, face = 'bold'),
        plot.caption=element_text(size=12, hjust = 0, face = 'italic'),
        panel.background = element_rect(fill = "#f5f5f2", color = NA), 
        legend.background = element_rect(fill = "#f5f5f2", color = NA),
        panel.border = element_blank()))

ggsave(paste0(path_wd,'/bike_choropleth.png'), pchoro, dpi = 400, height =8, width=6) #

# Bar Chart Ranking Crash Areas
tract_summary <- tract_traffic_crashes_summary %>% filter(rank <= 30) %>%
  arrange(desc(total))
tract_summary_order <- unique(tract_summary$community)
tract_summary$community <- factor(tract_summary$community, levels = rev(tract_summary_order))

colorhexes <- c("#0194D3","#D1D3D4","#ffc425","#49DEA4")
(pbar <- ggplot(data = tract_summary,
       aes(x = community,
           y = value,
           fill = variable), 
       alpha=0.8) +
  coord_flip() +
  geom_bar(stat = "identity", color = "white") +
  geom_text(aes(label=ifelse(share >= 0.075, paste0(round(value,0)),""), 
                y=pos_id_value),
                size = 4, fontface = "bold", family = 'Lato') +
  ggplot2::scale_color_manual(values = c('white',"grey20")) + 
  ggplot2::scale_fill_manual(values = colorhexes ) + 
  scale_y_continuous(expand = c(0, 0)) +
  ggplot2::labs(y= "Reported Injuries", 
                x = 'Community', 
                fill = '',
                title = 'Top 30 Community Areas by Reported Bike Crashes (2015-2020)',
                caption = "Source: Chicago Data Portal") +
  ggplot2::theme(legend.position ="bottom",
                 panel.border = ggplot2::element_blank(),
                 legend.title = ggplot2::element_blank(),
                 axis.title= ggplot2::element_text(size=12),
                 axis.text.y = ggplot2::element_text(size=12),
                 plot.subtitle = ggplot2::element_text(size=12, face = 'bold'),
                 plot.caption=element_text(size=12, hjust = 0, face = 'italic'),
                 text = ggplot2::element_text(family = "Lato", size = 13, color = "#161616")))

ggsave(paste0(path_wd,'/bike_stackedbar.png'), pbar , dpi = 400, height =8, width=9) #


