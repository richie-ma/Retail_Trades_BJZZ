##########################################
## SAMPLE STOCK SELECTION

library(data.table)
library(haven)
library(RPostgres)

sample <- read_sas("C:/Users/ruchuan2/Box/STAT 480/final project/crsp_stocks.gz")
sample <- as.data.table(sample)



## sample[, length(unique(PERMNO))] ### 3912 stocks

### Similar to Hasbrouck (2009), we use the following criteria construct our sample.

## 1) common stocks with CRSP share code 10 and 11 (have done)
## 2) primary listing are NYSE and NASDAQ
## 3) Stocks do not experience split (DISTCD starts with 5)
## 3) it cannot change primary exchange, ticker symbol, or CUSIP code during the sample period.
## 4) not a penny stock (closing price greater than zero and daily low price is greater than $1)
## 5) stocks that do not experience merge, acquisition and delisting.

## --------------------------------------------
## select Nasdaq-listed and NYSE-listed stocks

sample <- sample[EXCHCD==1|EXCHCD==3]


## sample[, length(unique(PERMNO))] ## 3715 stocks

## -----------------------------------------------------
## delete stocks that changed the listing exchange

change.list.stocks <- sample[, length(unique(EXCHCD)), by=.(PERMNO)][V1!=1, PERMNO]

sample <- sample[!PERMNO %in% change.list.stocks]


## -------------------------------------------------------
## delete stocks that changed the ticker symbol

change.ticker.symbol <- sample[, length(unique(TICKER)), by=.(PERMNO)][V1!=1, PERMNO]

sample <- sample[!PERMNO %in% change.ticker.symbol]

## ----------------------------------------------------
## delete stocks that changed the CUSIP

change.cusip <- sample[, length(unique(CUSIP)), by=.(PERMNO)][V1!=1, PERMNO]

sample <- sample[!PERMNO %in% change.cusip]
## sample[, length(unique(PERMNO))] ## 3614 stocks

##----------------------------------------------
# deleting penny stocks
sample <- sample[!is.na(PRC)==TRUE]
sample <- sample[!PRC <0 & !PRC==0]
sample <- sample[PRC >= 1]
## sample[, length(unique(PERMNO))] ## 3599 stocks

## --------------------------------------------
# deleting the delisted stocks


delisted.stocks <- sample[is.na(DLSTCD)==FALSE, unique(PERMNO)]
sample <- sample[!PERMNO %in% delisted.stocks]
## sample[, length(unique(PERMNO))] ## 3393 stocks

## --------------------------------------------
# deleting the stock splits


split.stocks <- sample[is.na(DISTCD)==FALSE & substr(DISTCD, 1,1)==5, unique(PERMNO)]
sample <- sample[!PERMNO %in% split.stocks]
## sample[, length(unique(PERMNO))] ## 3279 stocks

##--------------------------------------------


### For our DiD analyses, the pre-period should not include the tick-size pliot program.
### The tick-size pilot program was ended on September 28, 2018.
### So our pre-period should be later than this time.

### The tickers in the CRSP might not be directly used in the TAQ data,
## we need to find the tickers in the TAQ data by using
## WRDS Daily TAQ CRSP Link

### TAQ filter


## extract PERMNO from WRDS web qurey
#-------------------------------------------------------------------------------------------------------
sample.stock <- sample[, unique(PERMNO)]

## since the SEC implemented a tick-size pilot program, by the recommendation of Barber et al. (2024), we 
## should exclude stocks that are in G2/G3.

polit.sym <- fread('http://tsp.finra.org/finra_org/ticksizepilot/TSPilotChanges.txt')

polit.sym[, Effective_Date:=as.Date(as.character(Effective_Date), "%Y%m%d")]
polit.sym[, Deleted_Date:=as.Date(as.character(Deleted_Date), "%Y%m%d")]

polit.sym <- polit.sym[!Deleted_Date <= as.Date("2017-12-31")]
polit.sym <- polit.sym[!Ticker_Symbol %in% deleted.stocks]

polit.sym <- polit.sym[!((Tick_Size_Pilot_Program_Group  != Old_Tick_Size_Pilot_Program_Group) & Old_Tick_Size_Pilot_Program_Group!="")]

## only nyse-listed and nasdaq-listed

polit.sym <- polit.sym[Listing_Exchange=="N"|Listing_Exchange=="Q"]
polit.sym <- polit.sym[Effective_Date <= as.Date("2017-12-31")]
polit.sym[, Ticker_Symbol:=gsub(" ", "", Ticker_Symbol, fixed = TRUE)]
tsp.deleted <- polit.sym[, unique(Ticker_Symbol)]

sample <- sample[!TSYMBOL %in% tsp.deleted]
sample <- unique(sample[, -c("DLSTCD", "DISTCD")])

sample.stock <- sample[, .N, by=.(PERMNO)][N==609, unique(PERMNO)]

write.table(sample.stock, quote = FALSE, "C:/Users/ruchuan2/Box/STAT 480/final project/taq_stocks.txt", row.names=FALSE)
#--------------------------------------------------------------------------------------------------------

permno_ticker <- as.data.table(read_sas("C:/Users/ruchuan2/Box/STAT 480/final project/taq_stock_link.gz"))

## Coverage of Daily TAQ and CRSP are different. CRSP does not include
## We use the WRDS TAQ link to get the daily coverage of TAQ data


permno_ticker <- permno_ticker[!SYM_SUFFIX=="PRA" & !SYM_SUFFIX=='PRB' & !SYM_SUFFIX=="PRBCL" & !SYM_SUFFIX=="PRC"]
permno_ticker[, TSYMBOL:=paste0(SYM_ROOT, SYM_SUFFIX)]

sample.stock <- permno_ticker[, .N ,by=.(PERMNO)][N==609, unique(PERMNO)]

sample <- sample[PERMNO %in% sample.stock]

sample <- merge(sample, 
                permno_ticker[, .(DATE, PERMNO, SYM_ROOT, SYM_SUFFIX)], by=c("PERMNO", "DATE"))

sample <- merge(sample, 
                polit.sym[, .(Ticker_Symbol, Tick_Size_Pilot_Program_Group)], by.x = c("TSYMBOL"), by.y=c("Ticker_Symbol"), all.x=TRUE)

setnames(sample, "Tick_Size_Pilot_Program_Group", "TSP_Group")

## summary statistics

sample[, length(unique(PERMNO)), by=.(EXCHCD)]
sample[, length(unique(PERMNO)), by=.(DATE)]
sample[,length(unique(PERMNO)), by=.(DATE) ][, summary(V1)]
sample[,length(unique(PERMNO)), by=.(DATE) ][, sd(V1)]

sample[,summary(PRC)]

save(sample, file="C:/Users/ruchuan2/Box/STAT 480/final project/sampled.stocks.rda")
