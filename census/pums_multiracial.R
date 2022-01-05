# Household categorization & statistics by race and ethnicity

# Functions -------------------------------------
using<-function(...) {
  libs<-unlist(list(...))
  req<-unlist(lapply(libs,require,character.only=TRUE))
  need<-libs[req==FALSE]
  if(length(need)>0){ 
    install.packages(need)
    lapply(need,require,character.only=TRUE)
  }
}

pums_recode_na <-function(dt){
  for(col in names(dt)) set(dt, i=grep("b+",dt[[col]]), j=col, value=NA)
  return(dt)
}

pums_stat <- function(df, stat_type, target_var=NULL, group_var=NULL){
  result_name <- sym(stat_type)                                                                    # i.e. total, tally, median or mean
  srvyrf_name <- as.name(paste0("survey_",stat_type))                                              # specific srvyr function name
  se_name     <- paste0(stat_type,"_se")                                                           # specific srvyr standard error field
  moe_name    <- paste0(stat_type,"_moe")                                                          # margin of error
  if(!is.null(group_var)){df %<>% group_by(!!as.name(group_var))}
  if(stat_type=="count"){
    rs <- survey_tally(df, name="count", vartype="se")
  }else{
    rs <- summarise(df, !!result_name:=(as.function(!!srvyrf_name)(!!as.name(target_var), na.rm=TRUE, vartype="se", level=0.95)))
  }
  rs %<>% mutate(!!rlang::sym(moe_name):=!!rlang::sym(se_name) * 1.645) %>% select(-se_name) 
  if(!is.null(group_var)){
    rs %<>% arrange(!!as.name(group_var))
    df %<>% ungroup()
  }
  return(rs)
}

stuff <- function(x){unique(x) %>% paste(collapse=",")}                                            # Aggregation for strings (spec. race/ethnicity codes/descriptions)

using("rlang","dplyr","tidyselect","magrittr","data.table","tidycensus","stringr","srvyr")         # Attach libraries

dyear <- 2019
#pv <- pums_variables %>% setDT() %>% .[year==dyear & survey=="acs1"] %>% .[, 1:6, by=.(1:6)] %>% unique() # Relevant variable list

# API calls & data handling ---------------------
p1 <- get_pums(variables=c("RAC1P","HISP"),                            
               state="WA",
               puma = c(11501:11520,11601:11630,11701:11720,11801:11810),                          # Faster when filtered--futureproofed for additional PUMAs
               year=dyear, survey="acs1",
               recode=TRUE) %>% setDT() %>%                                                        # Recode option only available after 2017
  .[, HISP:=fcase((HISP)=="01", "No", default="Yes")] %>%                                          # Recode Hispanic to binary
  .[, HISP_label:=fcase(HISP=="Yes", "Hispanic or Latino", default="Not Hispanic or Latino")] %>%
  .[, RAC1P_label:=as.character(RAC1P_label)]

p1[RAC1P %in% c(3:5),`:=`(RAC1P=3,RAC1P_label="American Indian and/or Alaska Native alone")]       # Collapse 3 Native categories

hhs <- p1[, .(RAC1P=stuff(RAC1P), 
              HISP=stuff(HISP), 
              RAC1P_label=stuff(RAC1P_label), 
              HISP_label=stuff(HISP_label), 
              HHSIZE=.N), 
          by=.(SERIALNO)]                                                                          # Summarize households by race/ethnic composition
hhs[(RAC1P %like% ","|HISP %like% ","), c("RAC1P_label","HISP_label"):="Multiple races"]           # Households either heterogeously Hispanic or racially heterogenous labeled "Multiple races" (why?)                                        

h1 <- get_pums(variables=c("WGTP","HINCP","ADJINC"),                            
               state="WA",
               puma = c(11501:11520,11601:11630,11701:11720,11801:11810),           
               year=dyear, survey="acs1",
               variables_filter=list(TYPE=1, SPORDER=1),
               recode=FALSE,                                                          
               rep_weights="housing") %>% setDT() %>%
  .[, HINCP:=round(as.numeric(gsub(",", "", HINCP)) * as.numeric(ADJINC),0)] %>%                   # Adjust for intra-dataset inflation
  .[hhs,`:=`(RACE_label=i.RAC1P_label, HISPANIC_label=i.HISP_label, 
             HHSIZE=i.HHSIZE), on =.(SERIALNO)]                                                    # Carry hh race/ethnicity attributes to hh dataset

fcols <- c("RACE_label","HISPANIC_label")
h1[ , (fcols):=lapply(.SD, factor), .SDcols=fcols]                                                 # Switch to factors in prep for Srvyr
  
rw <- colnames(h1) %>% .[grep(paste0("WGTP","\\d+"),.)]                                            # Define replicate weights

h1 %<>% pums_recode_na() %>% setDF() %>%
  srvyr::as_survey_rep(variables=c(SERIALNO, RACE_label, HISPANIC_label, HINCP, HHSIZE),           # Create srvyr object with replication weights for MOE
                       weights= WGTP,
                       repweights=all_of(rw),
                       combined_weights=TRUE,
                       mse=TRUE,
                       type="other",
                       scale=4/80,
                       rscale=length(all_of(rw)))

# Run statistical functions ---------------------
r_med_hhinc1 <- pums_stat(h1, "median", "HINCP","RACE_label")
h_med_hhinc1 <- pums_stat(h1, "median", "HINCP","HISPANIC_label")
r_counts1 <- pums_stat(h1, "count", NA, "RACE_label")
h_counts1 <- pums_stat(h1, "count", NA, "HISPANIC_label")
