############################################################################
## Summary statistics of retail trades identification
## Richie R. Ma, ruchuan2@illinois.edu
#############################################################################

library(data.table)


rm(list=ls())

setwd("C:/Users/ruchuan2/Box/STAT 480/final project")

results <- list.files("C:/Users/ruchuan2/Box/STAT 480/final project/results_summary")

summary_stat <- list()

summary.function <- function(x){
  summary <- list(N=length(x),mean=round(mean(x, na.rm=T),4), std=round(sd(x, na.rm=T),4),
                  min=round(min(x, na.rm=T),4), p25=round(quantile(x,0.25, na.rm=T),4), median=round(median(x, na.rm=T),4), 
                  p75=round(quantile(x,0.75, na.rm=T),4), max=round(max(x, na.rm=T),4))
  return(summary)
  
}


for(i in 1:length(results)){
  
  load(paste0("C:/Users/ruchuan2/Box/STAT 480/final project/results_summary/", results[i]))
  
  summary[substr(sym_root, nchar(sym_root)-1, nchar(sym_root))=="NA", sym_root:=substr(sym_root, 1, nchar(sym_root)-2)] 
  
  summary_stat[[i]] <- summary
  
  
  
}

summary_stat <- rbindlist(summary_stat)
save(summary_stat, file="retail_trades_summary.rda")

#### summary statistics of sampled stocks

load("C:/Users/ruchuan2/Box/STAT 480/final project/sampled.stocks.rda")
sample[, market_cap:=PRC*SHROUT/10^6]
sample[, dollar_volume:=PRC*VOL/10^6]
sample[, lapply(.SD, summary.function), .SDcols=c("PRC","dollar_volume", "market_cap")]


### summary statistics of sampled stocks based on market cap
#### This sorting is for stock level
sample[, avg.mkt.cap:=mean(market_cap), by=.(SYM_ROOT)]

sample[, mkt_quantile:=fifelse(avg.mkt.cap <= quantile(unique(avg.mkt.cap), 0.2), 1, 
                                     fifelse(avg.mkt.cap > quantile(unique(avg.mkt.cap), 0.2) & avg.mkt.cap <= quantile(unique(avg.mkt.cap), 0.4), 2, 
                                             fifelse(avg.mkt.cap > quantile(unique(avg.mkt.cap), 0.4) & avg.mkt.cap <= quantile(unique(avg.mkt.cap), 0.6), 3, 
                                                     fifelse(avg.mkt.cap > quantile(unique(avg.mkt.cap), 0.6) & avg.mkt.cap <= quantile(unique(avg.mkt.cap), 0.8), 4, 5))))]

mkt_cap_quantile <- sample[, lapply(.SD, summary.function), .SDcols=c("PRC","dollar_volume", "market_cap"), by=.(mkt_quantile)]
mkt_cap_quantile[, stat:=c("N", "mean", "std", "min", "p25", "median", "p75", "max"), by=.(mkt_quantile)]
setkey(mkt_cap_quantile, "mkt_quantile")


##### unconditional results of retail trades 
### using all stock-day observations

### merge the CRSP data to check whether retail traders are more likely to 
### trade high market-cap stocks

load("retail_trades_summary.rda")
#save(summary_stat, file="retail_trades_summary.rda")
#### In terms of trading symbol, or generally trading tickers, they are not necessarily 
#### the same. In TAQ data, there is suffix for the same root to indicate they are not the
#### same stocks.



summary_stat <- merge(summary_stat, sample[, .(SYM_ROOT, DATE, EXCHCD, PRC, SHROUT, market_cap, mkt_quantile)], by.x=c("sym_root", "date"), by.y=c("SYM_ROOT", "DATE"))
summary_stat[, `:=`(vol=(vol_buy+vol_sell)/10^3, Ntrade=Ntrade_buy+Ntrade_sell, dollar.vol=dollar.vol_buy+dollar.vol_sell)]

retail_trades_summary <- summary_stat[, lapply(.SD, summary.function),
                                      .SDcols=c("vol", "Ntrade","dollar.vol", "ord.imb.vol", "ord.imb.trd",  "ord.imb.dollar.vol")]

#### We find not all 1312 stocks are all have retail trades available

retail_trades_summary[, stat:=c("N", "mean", "std", "min", "p25", "median", "p75", "max")]
setcolorder(retail_trades_summary, "stat")

### We do the summary statistics based on the stocks' market caps



retail_trds_market_cap <-  summary_stat[, lapply(.SD, summary.function),
                                         .SDcols=c("Ntrade", "dollar.vol"), by=.(mkt_quantile)]

retail_trds_market_cap[, stat:=c("N", "mean", "std", "min", "p25", "median", "p75", "max"), by=.(mkt_quantile)]
setkey(retail_trds_market_cap, "mkt_quantile")

retail_trds_market_cap


##### doing the same analysis conditioning on odd-lots and round-lots


summary_stat[, `:=`(oddvol=(oddvol_buy+oddvol_sell)/10^3, oddNtrade=oddtrd_buy+oddtrd_sell, odddollar.vol=odd.dollar.vol_buy+odd.dollar.vol_sell)]

retail_odd_lot <- summary_stat[, lapply(.SD, summary.function),
                               .SDcols=c('oddvol', 'oddNtrade', 'odddollar.vol', 'odd.ord.imb.vol', 'odd.ord.imb.trd' ,'odd.ord.imb.dollar.vol')]


retail_oddtrds_market_cap <-  summary_stat[, lapply(.SD, summary.function),
                                        .SDcols=colnames(summary_stat)[c(14:22, 23:24, 26)], by=.(mkt_quantile)]


retail_oddtrds_market_cap[, stat:=c("N", "mean", "std", "min", "p25", "median", "p75", "max"), by=.(mkt_quantile)]

setkey(retail_oddtrds_market_cap, "mkt_quantile")




