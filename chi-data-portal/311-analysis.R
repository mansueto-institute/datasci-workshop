
library(lubridate)
library(tidyverse)
library(sf)

# Ingest 311 data
d311 <- read_csv('https://data.cityofchicago.org/api/views/v6vf-nfxy/rows.csv')      

# Clean up 311 data
d311 <- d311 %>% 
  rename_all(tolower) %>%
  mutate(created_date = as.Date(created_date , format = "%m/%d/%Y %I:%M:%S %p"),
        year = format(created_date ,"%Y")) %>%
  filter(year > 2019) %>% 
  filter(!is.na(longitude)) %>%
  st_as_sf(coords = c("longitude", "latitude"), 
           crs = 4326, agr = "constant") 

# Ingest community area geometries
community_areas <- sf::st_read('https://data.cityofchicago.org/api/geospatial/cauq-8yn6?method=export&format=GeoJSON') %>% 
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf() %>% 
  select(community)

# Ingest block geometries
filedir <- paste0(tempdir(), '/blocks/')
unlink(filedir, recursive = TRUE)
dir.create(filedir)
state_shp <- paste0('https://www2.census.gov/geo/tiger/TIGER2019/BG/tl_2019_17_bg.zip')
download.file(url = state_shp, destfile = paste0(filedir, basename(state_shp)))
unzip(paste0(filedir,basename(state_shp)), exdir= filedir)

list.files(path = filedir)
cook_blocks <- st_read(fs::dir_ls(filedir, regexp = "\\.shp$")[1]) %>%
  st_transform(crs = st_crs(4326)) %>% 
  select(GEOID) %>%
  rename(block_fips = GEOID)

# Geocode by block and community area
d311<-d311 %>% 
  filter(duplicate == FALSE) %>%
  st_join(., cook_blocks) %>%
  st_join(., community_areas) 

# Aggregate and collapse 311 data
d311_collapsed <- d311 %>% 
  mutate(request_count = 1) %>%
  st_drop_geometry() %>%
  group_by(year,
                created_date,
                block_fips,
                zip_code,
                precinct,
                ward,
                community,
                sr_type,
                sr_short_code,
                owner_department,
                status) %>%
  summarise_at(vars(request_count), list(sum), na.rm = TRUE) %>% 
  ungroup()

write_csv(d311_collapsed, '/Users/nm/Desktop/microdata_311.csv')

# Aggregate and collapse by 311 categories
d311_categories <- d311 %>% 
  mutate(request_count = 1) %>%
  st_drop_geometry() %>%
  group_by(sr_type,
           sr_short_code,
           owner_department) %>%
  summarise_at(vars(request_count), list(sum), na.rm = TRUE) %>% 
  ungroup()

write_csv(d311_categories, '/Users/nm/Desktop/311_categories.csv')

# Select point data columns that are relevant
d311 <- d311 %>% select(year,
                    created_date,
                    block_fips,
                    street_number,
                    street_direction,
                    street_name,
                    street_type,
                    city,
                    state,
                    zip_code,
                    precinct,
                    ward,
                    community,
                    sr_number,
                    sr_type,
                    sr_short_code,
                    owner_department,
                    status)

st_write(d311, '/Users/nm/Desktop/point_data_311.geojson')

# all of 2020 to end of April
# microdata_311.csv is aggregates of service requests types grouped by block FIPS, ZIP codes, community areas 780K rows   
# 311_categories.csv is the aggregates of the different categories
# underlying point data, 2.4 million rows

