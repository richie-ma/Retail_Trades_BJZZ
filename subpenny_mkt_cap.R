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
  sample <- sample[, .SD[.N], by=.(SYM_ROOT)]
  retail.trades <- merge(retail.trades, sample[, .(SYM_ROOT, mkt_quantile)], by.x=c("sym_root"), by.y=c("SYM_ROOT"))
  
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
  subpenny <- subpenny[, .N, by=.(subpenny.group, mkt_quantile)]
  setkey(subpenny, mkt_quantile, subpenny.group)
  

  
  save(subpenny, file=paste0("C:/Users/ruchuan2/Box/STAT 480/final project/summary_list/subpenny/", substr(results[i], 1, 10), ".rda"))
}