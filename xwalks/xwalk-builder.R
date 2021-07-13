
library(sf)
library(dplyr)
library(ggplot2)
library(purrr)
library(tigris)
library(tidycensus)
library(stringr)
library(readxl)
library(viridis)
library(scales)

# Create directory and load Census API key --------------------------------
# Obtain Census API Key here: https://api.census.gov/data/key_signup.html

wd_dev <- '/Users/nm/Desktop/projects/work/mansueto/xwalks'
dir.create(paste0(wd_dev,'/intermediary'))
dir.create(paste0(wd_dev,'/delineations'))
# census_api_key('API KEY', install = TRUE) 
readRenviron("~/.Renviron")

# States ------------------------------------------------------------------

state_xwalk <- as.data.frame(fips_codes) %>%
  rename(state_fips = state_code,
         state_codes = state,
         county_name = county) %>%
  mutate(county_fips = paste0(state_fips,county_code))
state_fips <- unique(state_xwalk$state_fips)[1:51]
state_codes <- unique(state_xwalk$state_codes)[1:51]

us_states <- get_acs(year = 2018, geography = "state", variables = "B01003_001", geometry = TRUE, keep_geo_vars = TRUE, shift_geo = TRUE)

us_states <- us_states %>%
  rename_all(tolower) %>%
  rename(population = estimate,
         state_fips = geoid)%>%
  mutate_at(vars(state_fips),list(as.character)) %>%
  mutate(state_fips = str_pad(state_fips, width=2, side="left", pad="0")) %>%
  select(state_fips, population) %>%
  rename(state_population = population)

us_states <- left_join(us_states, 
                       state_xwalk %>% 
                         select(state_codes, state_fips, state_name) %>%
                         distinct() %>%
                         filter(!(state_fips %in% c('60','66','69','72','74','78'))),
                       by = c('state_fips'='state_fips')) %>%
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf()

# Counties ----------------------------------------------------------------

xwalk_url <- 'https://www2.census.gov/programs-surveys/metro-micro/geographies/reference-files/2020/delineation-files/list1_2020.xls'
tmp_filepath <- paste0(tempdir(), '/', basename(xwalk_url))
download.file(url = paste0(xwalk_url), destfile = tmp_filepath)
unzip(tmp_filepath, exdir=tempdir())
cbsa_xwalk <- read_excel(tmp_filepath, sheet = 1, range = cell_rows(3:1919))
cbsa_xwalk <- cbsa_xwalk %>% 
  select_all(~gsub("\\s+|\\.|\\/", "_", .)) %>%
  rename_all(list(tolower)) %>%
  mutate(county_fips = paste0(fips_state_code,fips_county_code)) %>%
  rename(cbsa_fips = cbsa_code,
         area_type = metropolitan_micropolitan_statistical_area) %>%
  select(county_fips,cbsa_fips,cbsa_title,area_type,central_outlying_county) 

us_county <- get_acs(year = 2018, geography = "county", variables = "B01003_001", geometry = TRUE, keep_geo_vars = TRUE, shift_geo = TRUE)
us_county <- us_county %>%
  rename_all(list(tolower)) %>%
  rename(county_fips = geoid,
         county_population = estimate) %>%
  select(county_fips,county_population)

# ggplot(us_county, aes(fill = log(county_population), color = log(county_population))) +
#   geom_sf() + scale_fill_viridis() + scale_color_viridis() 

us_county <- us_county %>% 
  left_join(., cbsa_xwalk, by = c('county_fips'='county_fips') ) %>%
  left_join(., state_xwalk, by = c('county_fips'='county_fips') ) %>%
  mutate(area_type = case_when(is.na(area_type) ~ 'Rural',
                               area_type == 'Metropolitan Statistical Area' ~ 'Metro',
                               area_type == 'Micropolitan Statistical Area' ~ 'Micro'),
         central_outlying_county = ifelse(is.na(central_outlying_county), 'Rural', central_outlying_county)) %>%
  select(county_fips,county_code,county_name,county_population,
         cbsa_fips,cbsa_title,area_type,central_outlying_county,
         state_codes,state_fips,state_name) %>%
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf()

# CBSAs -------------------------------------------------------------------

cbsa_url <- 'https://www2.census.gov/geo/tiger/TIGER2019/CBSA/tl_2019_us_cbsa.zip'
tmp_filepath <- paste0(tempdir(), '/', basename(cbsa_url))
download.file(url = paste0(cbsa_url), destfile = tmp_filepath)
unzip(tmp_filepath, exdir=tempdir())
us_cbsa <- sf::st_read(gsub(".zip", ".shp", tmp_filepath))

cbsa_pop_url <- 'https://www2.census.gov/programs-surveys/popest/datasets/2010-2019/metro/totals/cbsa-est2019-alldata.csv'
tmp_filepath <- paste0(tempdir(), '/', basename(cbsa_pop_url))
download.file(url = paste0(cbsa_pop_url), destfile = tmp_filepath)
cbsa_pop <- read_csv(tmp_filepath)

cbsa_pop <- cbsa_pop %>%
  rename_all(tolower) %>% 
  filter(lsad %in% c('Metropolitan Statistical Area','Micropolitan Statistical Area')) %>%
  select(cbsa,popestimate2019) %>%
  mutate(cbsa = str_pad(cbsa, width=5, side="left", pad="0"))

us_cbsa <- us_cbsa %>% 
  rename_all(tolower) %>%
  mutate_at(vars(csafp, cbsafp, geoid),list(as.character)) %>%
  mutate(csafp = str_pad(csafp, width=3, side="left", pad="0"),
         cbsafp = str_pad(cbsafp, width=5, side="left", pad="0"),
         geoid = str_pad(geoid, width=5, side="left", pad="0")) %>%
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf()

us_cbsa <- inner_join(us_cbsa,
                     cbsa_pop,
                     by = c('geoid'='cbsa')) %>%
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf()

# Tracts ------------------------------------------------------------------

if (!file.exists(paste0(wd_dev,'/delineations/us_tracts.geojson'))) {
  filedir <- paste0(tempdir(), '/tracts/')
  unlink(filedir, recursive = TRUE)
  dir.create(filedir)
  for (s in state_fips) {
    state_shp <- paste0('https://www2.census.gov/geo/tiger/TIGER2019/TRACT/tl_2019_',s,'_tract.zip')
    download.file(url = state_shp, destfile = paste0(filedir, basename(state_shp)))
    unzip(paste0(filedir,basename(state_shp)), exdir= filedir)
  }
  list.files(path = filedir)
  us_tracts <- st_read(fs::dir_ls(filedir, regexp = "\\.shp$")[1])
  for (f in fs::dir_ls(filedir, regexp = "\\.shp$")[-1] ) {
    state_sf <- st_read(f)
    us_tracts <- rbind(us_tracts, state_sf)
  }
  st_write(us_tracts, paste0(wd_dev,'/delineations/','us_tracts.geojson'))
} else {us_tracts <- st_read(paste0(wd_dev,'/delineations/','us_tracts.geojson'))}

us_tracts <- us_tracts %>% 
  rename_all(tolower) %>%
  mutate_at(vars(statefp, countyfp, tractce, geoid),list(as.character)) %>%
  mutate(geoid = str_pad(geoid, width=11, side="left", pad="0"),
         statefp = str_pad(statefp, width=2, side="left", pad="0"),
         countyfp = str_pad(countyfp, width=3, side="left", pad="0"),
         tractce = str_pad(tractce, width=6, side="left", pad="0")) %>%
  filter(statefp %in% state_fips) %>% 
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf()

# Block Groups ------------------------------------------------------------

if (!file.exists(paste0(wd_dev,'/delineations/','us_blockgroups.geojson'))) {
  filedir <- paste0(tempdir(), '/blocks/')
  unlink(filedir, recursive = TRUE)
  dir.create(filedir)
  for (s in state_fips) {
    state_shp <- paste0('https://www2.census.gov/geo/tiger/TIGER2019/BG/tl_2019_',s,'_bg.zip')
    download.file(url = state_shp, destfile = paste0(filedir, basename(state_shp)))
    unzip(paste0(filedir,basename(state_shp)), exdir= filedir)
  }
  list.files(path = filedir)
  us_blocks <- st_read(fs::dir_ls(filedir, regexp = "\\.shp$")[1])
  for (f in fs::dir_ls(filedir, regexp = "\\.shp$")[-1] ) {
    state_sf <- st_read(f)
    us_blocks <- rbind(us_blocks, state_sf)
  }
  st_write(us_blocks, paste0(wd_dev,'/delineations/','us_blockgroups.geojson'))
} else {us_blocks <- st_read(paste0(wd_dev,'/delineations/','us_blockgroups.geojson'))}

us_blocks <- us_blocks %>% 
  rename_all(tolower) %>%
  mutate_at(vars(geoid, statefp),list(as.character)) %>%
  mutate(geoid = str_pad(geoid, width=12, side="left", pad="0"),
         statefp = str_pad(statefp, width=2, side="left", pad="0"),
         countyfp = str_pad(countyfp, width=3, side="left", pad="0"),
         tractce = str_pad(tractce, width=6, side="left", pad="0"),
         blkgrpce = str_pad(blkgrpce, width=1, side="left", pad="0")) %>%
  filter(statefp %in% state_fips) %>% 
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf()

# Places ------------------------------------------------------------------

if (!file.exists(paste0(wd_dev,'/delineations/','us_places.geojson'))) {
  filedir <- paste0(tempdir(), '/places/')
  unlink(filedir, recursive = TRUE)
  dir.create(filedir)
  for (s in state_fips) {
    state_shp <- paste0('https://www2.census.gov/geo/tiger/TIGER2019/PLACE/tl_2019_',s,'_place.zip')
    download.file(url = state_shp, destfile = paste0(filedir, basename(state_shp)))
    unzip(paste0(filedir,basename(state_shp)), exdir= filedir)
  }
  list.files(path = filedir)
  us_places <- st_read(fs::dir_ls(filedir, regexp = "\\.shp$")[1])
  for (f in fs::dir_ls(filedir, regexp = "\\.shp$")[-1] ) {
    state_sf <- st_read(f)
    us_places <- rbind(us_places, state_sf)
  }
  st_write(us_places, paste0(wd_dev,'/delineations/','us_places.geojson'))
} else {us_places <- st_read(paste0(wd_dev,'/delineations/','us_places.geojson'))}

us_places <- us_places %>% 
  rename_all(tolower) %>%
  mutate_at(vars(geoid, statefp, placefp, placens),list(as.character)) %>%
  mutate(geoid = str_pad(geoid, width=7, side="left", pad="0"),
         statefp = str_pad(statefp, width=2, side="left", pad="0"),
         placefp = str_pad(placefp, width=5, side="left", pad="0"),
         placens = str_pad(placens, width=8, side="left", pad="0")) %>%
  filter(statefp %in% state_fips) %>%
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf()

places_url <- 'https://www2.census.gov/programs-surveys/popest/datasets/2010-2018/cities/totals/sub-est2018_all.csv'
tmp_filepath <- paste0(tempdir(), '/', basename(places_url))
download.file(url = paste0(places_url), destfile = tmp_filepath)
places_pop <- read_csv(tmp_filepath)

places_pop <- places_pop %>%
  rename_all(tolower) %>% 
  filter(sumlev %in% c('061','162','171')) %>%
  select(state, place, name, stname, popestimate2018) %>%
  mutate(state = str_pad(state, width=2, side="left", pad="0"),
         place = str_pad(place, width=5, side="left", pad="0"),
         placeid = paste0(state,place)) %>%
  rename(cityname = name)

us_places <- inner_join(us_places, 
                       places_pop,
                       by = c('geoid'='placeid')) %>%
  st_transform(crs = st_crs(4326)) %>% 
  st_as_sf()

# Write GeoJSONs ----------------------------------------------------------

rm(cbsa_pop)
rm(places_pop)
rm(cbsa_xwalk)
rm(full_xwalk)
rm(state_sf)
rm(state_xwalk)

st_write(us_blocks, paste0(wd_dev,'/delineations/','blockgroup_delineations.geojson'), delete_dsn = FALSE)
st_write(us_tracts, paste0(wd_dev,'/delineations/','tract_delineations.geojson'), delete_dsn = TRUE)
st_write(us_county, paste0(wd_dev,'/delineations/','county_delineations.geojson'), delete_dsn = TRUE)
st_write(us_states, paste0(wd_dev,'/delineations/','state_delineations.geojson'), delete_dsn = TRUE)
st_write(us_cbsa, paste0(wd_dev,'/delineations/','cbsa_delineations.geojson'), delete_dsn = TRUE)
st_write(us_places, paste0(wd_dev,'/delineations/','place_delineations.geojson'), delete_dsn = TRUE)
