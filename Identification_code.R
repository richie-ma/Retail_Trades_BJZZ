############################################################################
## Replication and extension for BJZZ algorithm for identifying the retail trades
## by TAQ data.
## ruchuan2@illinois.edu, Richie Ma, UIUC
##############################################################################

rm(list=ls())


library(data.table)
library(lubridate)
library(hms)

trades <- list.files(path = "/scratch/users/ruchuan2/TAQ_data/")
quotes <- list.files(path = "/scratch/users/ruchuan2/TAQ_data/")

for(i in 1:length(trades)){

  load("C:/Users/ruchuan2/Box/STAT 480/final project/2015-08-03_trades.rda")
  

gc()


trades[, time_m:=hms::as_hms(time_m)]  ### database timestamps
trades[, part_time :=hms::as_hms(part_time )]  ## participation timestamps
trades[, sym_root:=paste0(sym_root,sym_suffix)]

  #########################################################################################
  ### find the retail trades from TAQ data                                                #
  ### The identification process is based on Boehmer et al (2021), and 2                  #
  ## criteria are gonna be used as follows.                                               #
  ## a) The exchange code should be "D"                                                   #
  ## b) Retail trades' price must not be in integral cents.                               #
  ## A retail buy trade should have a fractional cent price ending in (0.6,1) cents,      #
  ## and a retail sell trade should have a fractional cent price ending in (0,0.4) cents  #
  #########################################################################################
  
  ## %% presents the mod operator, the detailed calculation, please refer to 
  ## BOEHMER, E., JONES, C.M., ZHANG, X. and ZHANG, X. (2021), 
  ## Tracking Retail Investor Activity. The Journal of Finance, 76: 2249-2305. https://doi.org/10.1111/jofi.13033
  ## Zit=100*model(Pit, 0.01), where Pit represents the transaction price in stock i at time t.
  ## if 0 < Zit < 0.04 sell retail transaction 
  ## You can't directly use mod (Pit, 0.01).
  

  ## note that R %% operator does not work well for fractions
  ## we need to extract the third decimial after the digit
trades[, price:=round(price, 4)]
trades[, price_decimals:= round(price %% 1, 4)]
trades[, frac_penny:=as.numeric(substr(as.character(price_decimals), 5,5))]

retail.trades <- trades[is.na(frac_penny)==FALSE]

# subpenny categories

retail.trades[, subpenny:=(price_decimals*100) %% 1]


retail.trades[, retail.dire:= fifelse( subpenny >0 & subpenny < 0.4, "sell", 
                               fifelse(subpenny >0.6 & subpenny < 1, "buy", "non"))]

retail.trades <- retail.trades[, -c("frac_penny")]


retail.trades[, dollar.value:= (size*price)/10^6]
  

  
  
  summary.statistics <- retail.trades[retail.dire=="sell"| retail.dire=="buy", .(vol=sum(size), dollar.vol=sum(dollar.value), Ntrade=.N), by=.(date, sym_root, retail.dire)]
  
  summary.statistics <- dcast(summary.statistics, date+sym_root~retail.dire, value.var = c("vol", "Ntrade", "dollar.vol"))
  summary.statistics[, 3:8] <- nafill( summary.statistics[, 3:8], "const", fill=0)
  
  
  summary.statistics[, `:=`(ord.imb.vol=(vol_buy-vol_sell)/(vol_buy+vol_sell),
            ord.imb.trd=(Ntrade_buy-Ntrade_sell)/(Ntrade_buy+Ntrade_sell), ord.imb.dollar.vol=(dollar.vol_buy-dollar.vol_sell)/(dollar.vol_buy+dollar.vol_sell))]
  
  
  odd.summary <- retail.trades[(retail.dire=="sell"| retail.dire=="buy") & size < 100, .(oddvol=sum(size),odd.dollar.vol=sum(dollar.value), oddtrd=.N), by=.(date,sym_root, retail.dire)]
  
  
  odd.summary <- dcast(odd.summary, date+sym_root~retail.dire, value.var = c("oddvol", "oddtrd", "odd.dollar.vol"))
  odd.summary[, 3:8] <- nafill(odd.summary[, 3:8], "const", fill=0)

  
  odd.summary[, `:=`(odd.ord.imb.vol=(oddvol_buy-oddvol_sell)/(oddvol_buy+oddvol_sell),
                                          odd.ord.imb.trd=(oddtrd_buy-oddtrd_sell)/(oddtrd_buy+oddtrd_sell), 
                             odd.ord.imb.dollar.vol=(odd.dollar.vol_buy-odd.dollar.vol_sell)/(odd.dollar.vol_buy+odd.dollar.vol_sell))]
  

  ### Let's look at the retail trade latency
  
  
  latency <- retail.trades[retail.dire=="sell"| retail.dire=="buy", .(avg.latency=mean(as.numeric(difftime( time_m,part_time, units = "secs"))),
                                                               med.latency=median(as.numeric(difftime( time_m,part_time, units = "secs")))), by=.(date, sym_root)]
  
  summary.statistics <- merge(summary.statistics, latency, by=c("date", "sym_root"))
  
  summary <- merge(summary.statistics, odd.summary, by=c("date", "sym_root"), all=TRUE)
  
  rm(odd.summary, summary.statistics, latency)
  

  
  
  ############################################################################
  # Price improvement compared to the NBBO
  # No trade-through rule: The internalized orders will not be sent to exchanges to get executed
  # However, these retail market orders share are likely to get price improvements than the NBBO
  ##############################################################################
  
  load("C:/Users/ruchuan2/Box/STAT 480/final project/2015-08-03_quotes.rda")
  
  nbbo[, midpoint:=(best_bid+best_ask)/2]
  nbbo[, sym_root:=paste0(sym_root, sym_suffix)]
  
  ### merge the trades and quotes data
  
  retail.trades <- nbbo[,.(date, time_m, sym_root, midpoint, best_bid, best_ask)][retail.trades[, -c("ex","sym_suffix", "tr_scond", "tr_corr", "tr_seqnum")], on=c("date", "sym_root", "time_m"), roll=Inf, nomatch=NULL, mult="last"]
  retail.trades <- retail.trades[, -c("part_time")]
  
  ### let's see the identification using the Lee and Ready midquote assignment
  
  retail.trades[, qspread:=best_ask-best_bid]
  retail.trades[, retail.dire.nbbo:=fifelse(price < best_bid+(qspread*0.4), "sell", fifelse(price  >  best_bid+(qspread*0.6), "buy", "non"))]
  
  save(retail.trades, file = )
  
}



