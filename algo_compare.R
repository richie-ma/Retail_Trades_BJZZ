#########################################
## Comparison between BJZZ algorithm and its competative algotithm
## Richie R. Ma, ruchuan2@illinois.edu
#########################################

rm(list=ls())

library(data.table)

setwd("C:/Users/ruchuan2/Box/STAT 480/final project")

results <- list.files("C:/Users/ruchuan2/Box/STAT 480/final project/results")

summary_stat <- list()

summary.function <- function(x){
  summary <- list(N=length(x),mean=round(mean(x, na.rm=T),4), std=round(sd(x, na.rm=T),4),
                  min=round(min(x, na.rm=T),4), p25=round(quantile(x,0.25, na.rm=T),4), median=round(median(x, na.rm=T),4), 
                  p75=round(quantile(x,0.75, na.rm=T),4), max=round(max(x, na.rm=T),4))
  return(summary)
  
}


load("C:/Users/ruchuan2/Box/STAT 480/final project/sampled.stocks.rda")

#### In terms of trading symbol, or generally trading tickers, they are not necessarily 
#### the same. In TAQ data, there is suffix for the same root to indicate they are not the
#### same stocks.



for(i in 1:length(results)){
  print(results[i])
  
  
  load(paste0("C:/Users/ruchuan2/Box/STAT 480/final project/results/", results[i]))
  
  retail.trades[substr(sym_root, nchar(sym_root)-1, nchar(sym_root))=="NA", sym_root:=substr(sym_root, 1, nchar(sym_root)-2)] 
  retail.trades <- merge(retail.trades, sample[, .(SYM_ROOT, DATE, EXCHCD, PRC, SHROUT)], by.x=c("sym_root", "date"), by.y=c("SYM_ROOT", "DATE"))
  
  ### some trades might be outside of NBBO, we delete these retail trades.
  retail.trades[, trd_location:=(price-best_bid)/(best_ask-best_bid)]
  
  delete.rate <- retail.trades[, {
    total=.N
    .SD[trd_location %between% c(0,1), .(rate=1-.N/total)]
  }]
  

  ## subpenny group
  
  retail.trades <- retail.trades[trd_location %between% c(0,1)]
  
  retail.trades[retail.dire!="non", subpenny.group:=fifelse(subpenny > 0 & subpenny <= 0.1, 1,
                                                              fifelse(subpenny > 0.1 & subpenny <= 0.2, 2,
                                                                      fifelse(subpenny > 0.2 & subpenny <= 0.3, 3,
                                                                              fifelse(subpenny > 0.3 & subpenny <= 0.4, 4,
                                                                                      fifelse(subpenny>0.6 & subpenny <= 0.7, 5,
                                                                                              fifelse(subpenny > 0.7 & subpenny <= 0.8, 6,
                                                                                                      fifelse(subpenny > 0.8 & subpenny <= 0.9, 7,8)))))))]
  
  subpenny <- retail.trades[retail.dire!="non"]
  subpenny <- subpenny[, .N, by=.(subpenny.group)]
  setkey(subpenny, subpenny.group)
  
  ## trade_location 
  
  retail.trades[, trd.loc.group:=fifelse(trd_location > 0 & trd_location <= 0.1, 1,
                                                                        fifelse(trd_location > 0.1 & trd_location <= 0.2, 2,
                                                                                fifelse(trd_location > 0.2 & trd_location <= 0.3, 3,
                                                                                        fifelse(trd_location > 0.3 & trd_location <= 0.4, 4,
                                                                                                fifelse(trd_location > 0.4 & trd_location <= 0.5, 5,
                                                                                                        fifelse(trd_location > 0.5 & trd_location <= 0.6, 6,
                                                                                                                fifelse(trd_location > 0.6 & trd_location <= 0.7, 7,
                                                                                                                        fifelse(trd_location > 0.7 & trd_location <= 0.8, 8,
                                                                                                                                fifelse(trd_location > 0.8 & trd_location <= 0.9, 9, 10)))))))))]
  location <- retail.trades[retail.dire!="non"]
 location <- location[, .N, by=.(trd.loc.group, retail.dire)]
 setkey(location, trd.loc.group)
  
  ### comparison
  ### We first look at retail trades-identified sample
 
  
  rate_function <- function(x){
    total=length(x) 
    rate=length(which(x!="non"))/total
    return(rate)
    }
  
  identification_rate_bjzz <- retail.trades[, lapply(.SD, rate_function), .SDcols = c("retail.dire", "retail.dire.nbbo"), by=.(sym_root)]
  
  ############### Let's first look at the identification rate #############################
  # We first compare whether the BJZZ algorithm could provide the same identification as NBBO
  # Specifically, whether retail trades identified by BJZZ can still be identifed as retail trades by NBBO
  
  NBBOmisidentify <- function(data, location,...){
    
    if(location==0){
      
      identificationN <- data[ retail.dire!="non", .(total=.N), by=.(sym_root)]
      misidentification <- data[retail.dire!="non" & retail.dire.nbbo=="non",.(misidentify=.N), by=.(sym_root)]
      
      misidentification <- merge(misidentification, identificationN, by="sym_root", all = TRUE)
      misidentification[is.na(misidentify), misidentify:=0]
      misidentification <- misidentification[, .(rate=misidentify/total), by=.(sym_root)]
      
      return(misidentification)
      
      
    }else{
      
      identificationN <- data[ retail.dire!="non", .(total=.N), by=.(trd.loc.group)]
      misidentification <- data[retail.dire!="non" & retail.dire.nbbo=="non",.(misidentify=.N), by=.(trd.loc.group)]
      
      misidentification <- merge(misidentification, identificationN, by="trd.loc.group", all = TRUE)
      misidentification[is.na(misidentify), misidentify:=0]
      misidentification <- misidentification[, .(rate=misidentify/total), by=.(trd.loc.group)]
      
      return(misidentification)
      
    }
    
  }
  
  NBBO_mis <- NBBOmisidentify(retail.trades, location=0)
  NBBO_mis.loc <- NBBOmisidentify(retail.trades, location=1)
  
  BJZZmisidentify <- function(data,location, ...){
    
    if(location==0){
      
      
      identificationN <- data[ retail.dire.nbbo!="non", .(total=.N), by=.(sym_root)]
      misidentification <- data[retail.dire.nbbo!="non" & retail.dire=="non",.(misidentify=.N), by=.(sym_root)]
      
      misidentification <- merge(misidentification, identificationN, by="sym_root", all = TRUE)
      misidentification[is.na(misidentify), misidentify:=0]
      misidentification <- misidentification[, .(rate=misidentify/total), by=.(sym_root)]
      
      return(misidentification)
      
    }else{
      
      identificationN <- data[ retail.dire.nbbo!="non", .(total=.N), by=.(trd.loc.group)]
      misidentification <- data[retail.dire.nbbo!="non" & retail.dire=="non",.(misidentify=.N), by=.(trd.loc.group)]
      
      misidentification <- merge(misidentification, identificationN, by="trd.loc.group", all = TRUE)
      misidentification[is.na(misidentify), misidentify:=0]
      misidentification <- misidentification[, .(rate=misidentify/total), by=.(trd.loc.group)]
      
      return(misidentification)
      
    }
    
    
  }
  
  BJZZ_mis <- BJZZmisidentify(retail.trades, location = 0)
  BJZZ_mis_loc <- BJZZmisidentify(retail.trades, location = 1)

  #### Now, we check the identification accuracy
  ### Retail trade direction identified by the BJZZ (2021) algorithm may not be the same as that identified by the NBBO
  ### Specifically, whether a retail buy trade from BJZZ (2021) is identified as a retail sell trade from the NBBO

  same_accuracy <- function(data, location,...){
    
    if(location==0){
    
  identificationN <- data[ retail.dire!="non" & retail.dire.nbbo!="non", .(total=.N), by=.(sym_root)]
  same_identification <- data[ retail.dire!="non"  & retail.dire.nbbo!="non" & retail.dire==retail.dire.nbbo,.(same_identify=.N), by=.(sym_root)]
  
  same_identification <- merge(same_identification, identificationN, by="sym_root", all = TRUE)
  same_identification[is.na(same_identify), same_identify:=0]
  same_identification <- same_identification[, .(rate=same_identify/total), by=.(sym_root)]
  return(same_identification)
    }else{
  
  
    identificationN <- data[ retail.dire!="non" & retail.dire.nbbo!="non", .(total=.N), by=.(trd.loc.group)]
    same_identification <- data[ retail.dire!="non"  & retail.dire.nbbo!="non" & retail.dire==retail.dire.nbbo,.(same_identify=.N), by=.(trd.loc.group)]
    
    same_identification <- merge(same_identification, identificationN, by="trd.loc.group", all = TRUE)
    same_identification[is.na(same_identify), same_identify:=0]
    same_identification <- same_identification[, .(rate=same_identify/total), by=.(trd.loc.group)] 
    return(same_identification)
  
  

 
  
}
  
  }
 
  same_identify <- same_accuracy(retail.trades,location=0)  
  same_identify_loc <- same_accuracy(retail.trades,location=1) 
  
  #### We could look at the following scenarios
  
  #### Some trades identified by BJZZ will not be able to be identified by Lee and Ready (NBBO method)
  ### Some trades identified by Lee and Ready will not be able to be identified by BJZZ
  

  
  algo_results <- list(delete.rate=delete.rate, subpenny=subpenny, location=location, identification_rate_bjzz=identification_rate_bjzz, same_accuracy=same_identify, same_accuracy_loc=same_identify_loc,
                  NBBO_mis=NBBO_mis, NBBO_mis.loc=NBBO_mis.loc, BJZZ_mis=BJZZ_mis, BJZZ_mis_loc=BJZZ_mis_loc)
  
  saveRDS(algo_results, file=paste0("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list/", substr(results[i], 1, 10), ".rds"))
  
}



# ####################################

algo  <- list.files("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list")

delete.rate <- list()
subpenny <- list()
location <- list()
identification_rate_bjzz <- list()
same_accuracy <- list()
same_accuracy_loc <- list()
NBBO_mis <- list()
NBBO_mis.loc <- list()
BJZZ_mis <- list()
BJZZ_mis_loc <- list()

for (i in 1:length(algo)){

  delete.rate[[i]] <- readRDS(paste0("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list/", algo[i]))[[1]]
  subpenny[[i]]<- readRDS(paste0("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list/", algo[i]))[[2]]
  location[[i]] <- readRDS(paste0("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list/", algo[i]))[[3]]
  identification_rate_bjzz[[i]] <- readRDS(paste0("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list/", algo[i]))[[4]]
  same_accuracy[[i]] <- readRDS(paste0("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list/", algo[i]))[[5]]
  same_accuracy_loc[[i]] <- readRDS(paste0("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list/", algo[i]))[[6]]
  NBBO_mis[[i]] <- readRDS(paste0("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list/", algo[i]))[[7]]
  NBBO_mis.loc[[i]] <- readRDS(paste0("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list/", algo[i]))[[8]]
  BJZZ_mis[[i]] <-  readRDS(paste0("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list/", algo[i]))[[9]]
  BJZZ_mis_loc[[i]] <- readRDS(paste0("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list/", algo[i]))[[10]]

}

delete.rate <- rbindlist(delete.rate)
subpenny <- rbindlist(subpenny)
location <- rbindlist(location)
identification_rate_bjzz <- rbindlist(identification_rate_bjzz)
same_accuracy <- rbindlist(same_accuracy)
same_accuracy_loc <- rbindlist(same_accuracy_loc)
NBBO_mis <- rbindlist(NBBO_mis)
NBBO_mis.loc <- rbindlist(NBBO_mis.loc)
BJZZ_mis <- rbindlist(BJZZ_mis)
BJZZ_mis_loc <- rbindlist(BJZZ_mis_loc)

#### Retail trades that are not within the inside spread

summary(delete.rate)

##### subpenny group plot

subpenny_plot <- subpenny[, {
  total=sum(N)
  .SD[, .(proportion=sum(N)/total), by=.(subpenny.group)]
}]

fwrite(subpenny_plot, "C:/Users/ruchuan2/Box/STAT 480/final project/Figures/subpenny.csv")


#### location plot

location_plot <- location[,.(total=sum(N)), by=.(retail.dire)]
location_sum <- location[,.(subtotal=sum(N)), by=.(retail.dire, trd.loc.group)]

location_plot <- merge(location_plot, location_sum, by=c("retail.dire"))
location_plot <- location_plot[, .(retail.dire, trd.loc.group, proportion=subtotal/total)]

fwrite(location_plot, "C:/Users/ruchuan2/Box/STAT 480/final project/Figures/location_plot.csv")

#### BJZZ identification rate
load("C:/Users/ruchuan2/Box/STAT 480/final project/sampled.stocks.rda")


identification_rate_bjzz <- merge(identification_rate_bjzz, sample[, .SD[.N, .(mkt_quantile)], by=.(SYM_ROOT)], by.x="sym_root", by.y="SYM_ROOT")
BJZZ_identify <- identification_rate_bjzz[, lapply(.SD, summary.function), .SDcols=c("retail.dire", "retail.dire.nbbo")]

### by market cap
BJZZ_identify_quantile <- identification_rate_bjzz[, lapply(.SD, summary.function), .SDcols=c("retail.dire", "retail.dire.nbbo"), by=.(mkt_quantile)]
setkey(BJZZ_identify_quantile, mkt_quantile)

##### BJZZ and NBBO--same accuracy


same_accuracy <- merge(same_accuracy, sample[, .SD[.N, .(mkt_quantile)], by=.(SYM_ROOT)], by.x="sym_root", by.y="SYM_ROOT")
same_accuracy_summary <- same_accuracy[, lapply(.SD, summary.function), .SDcols=c("rate")]

### by market cap
same_accuracy_quantile <- same_accuracy[, lapply(.SD, summary.function), .SDcols=c("rate"), by=.(mkt_quantile)]
setkey(same_accuracy_quantile, mkt_quantile)

### by location
### plot median 

same_accuracy_loc_mean <- same_accuracy_loc[, lapply(.SD, mean), .SDcols = c("rate"), by=.(trd.loc.group)]
setkey(same_accuracy_loc_mean)

fwrite(same_accuracy_loc_mean, "C:/Users/ruchuan2/Box/STAT 480/final project/Figures/same_accuracy_loc_mean.csv")

#### NBBO misclassification

NBBO_mis <- merge(NBBO_mis, sample[, .SD[.N, .(mkt_quantile)], by=.(SYM_ROOT)], by.x="sym_root", by.y="SYM_ROOT")
NBBO_mis_sum <- NBBO_mis[, lapply(.SD, summary.function), .SDcols=c("rate")]

### by market cap
NBBO_mis_quantile <- NBBO_mis[, lapply(.SD, summary.function), .SDcols=c("rate"), by=.(mkt_quantile)]
setkey(NBBO_mis_quantile, mkt_quantile)

### BJZZ misclassification

BJZZ_mis <- merge(BJZZ_mis, sample[, .SD[.N, .(mkt_quantile)], by=.(SYM_ROOT)], by.x="sym_root", by.y="SYM_ROOT")
BJZZ_mis_sum <- BJZZ_mis[, lapply(.SD, summary.function), .SDcols=c("rate")]

### by market cap
BJZZ_mis_quantile <- BJZZ_mis[, lapply(.SD, summary.function), .SDcols=c("rate"), by=.(mkt_quantile)]
setkey(BJZZ_mis_quantile, mkt_quantile)


#### subpenny by market cap

files <- list.files("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list/subpenny")

subpenny_cap <- list()

for(i in 1:length(files)){
  
  load(paste0("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list/subpenny/", files[i]))
  subpenny_cap[[i]] <- subpenny
  
  
}

subpenny_cap <- rbindlist(subpenny_cap)

subpenny_cap_sum <- subpenny_cap[, .(total=sum(N)), by=.(mkt_quantile)]
subpenny_cap_group <- subpenny_cap[, .(subpenny=sum(N)), by=.(mkt_quantile, subpenny.group)]

subpenny_cap <- merge(subpenny_cap_group, subpenny_cap_sum, by=c("mkt_quantile"))
subpenny_cap <- subpenny_cap[, .(percent=subpenny/total), by=.(subpenny.group, mkt_quantile)]

fwrite(subpenny_cap, "C:/Users/ruchuan2/Box/STAT 480/final project/Figures/subpenny_cap.csv")
