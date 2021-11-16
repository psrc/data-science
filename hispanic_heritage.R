library(devtools)
library(sf)
library(dplyr)
library(psrccensus)

Sys.getenv("CENSUS_API_KEY")

tract.big.tbl <- psrccensus::get_acs_recs(geography='tract',table.names=c('B03001'),years=c(2019), acs.type='acs-5')


tract.tbl <- tract.big.tbl %>%
filter(label=='Estimate!!Total:!!Hispanic or Latino:')

gdb.nm <- paste0("MSSQL:server=",
"AWS-PROD-SQL\\Sockeye",
";database=",
"ElmerGeo",
";trusted_connection=yes")

spn <-  2285

tract_layer_name <- "dbo.tract2010_nowater"

tract.lyr <- st_read(gdb.nm, tract_layer_name, crs = spn)
?create_tract_map
m<-create_tract_map(tract.tbl=tract.tbl, tract.lyr=tract.lyr,  
                 legend.title='Hispanic Population', legend.subtitle='by Census Tract')


county.big.tbl <- psrccensus::get_acs_recs(geography='county',table.names=c('B03001'),years=c(2019), acs.type='acs-5')