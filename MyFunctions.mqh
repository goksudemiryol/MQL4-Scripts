//+------------------------------------------------------------------+
//|                                                  MyFunctions.mqh |
//|                                                    goksudemiryol |
//+------------------------------------------------------------------+
#property copyright     "goksudemiryol"
#property link          "https://github.com/goksudemiryol"
#property strict


//Global Variables:

bool flagStrategy = false;

string accCompany = AccountInfoString(ACCOUNT_COMPANY);
string accCurrency = AccountInfoString(ACCOUNT_CURRENCY);
long accType = AccountInfoInteger(ACCOUNT_TRADE_MODE);
double balance = AccountInfoDouble(ACCOUNT_BALANCE), equity = AccountInfoDouble(ACCOUNT_EQUITY);
int leverage = (int)AccountInfoInteger(ACCOUNT_LEVERAGE);

long stopOutMode = AccountInfoInteger(ACCOUNT_MARGIN_SO_MODE);
double marginCallLevel = AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL);
double stopOutLevel = AccountInfoDouble(ACCOUNT_MARGIN_SO_SO);
double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

string symbol = Symbol();
string currMargin = SymbolInfoString(symbol,SYMBOL_CURRENCY_MARGIN);
string currProfit = SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT);

double bid = SymbolInfoDouble(symbol,SYMBOL_BID);
double ask = SymbolInfoDouble(symbol,SYMBOL_ASK);
double contract = SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
double marginReq = MarketInfo(symbol,MODE_MARGINREQUIRED);
double tickVal = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
double tickSize = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
double point = SymbolInfoDouble(symbol,SYMBOL_POINT);
int digits = (int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
long stopLevel = SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
int spread = (int)SymbolInfoInteger(symbol,SYMBOL_SPREAD);
double lotStep = SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
int lotRound = -(int)MathLog10(lotStep);
double swapLong = SymbolInfoDouble(symbol,SYMBOL_SWAP_LONG);
double swapShort = SymbolInfoDouble(symbol,SYMBOL_SWAP_SHORT);
long swapType = SymbolInfoInteger(symbol,SYMBOL_SWAP_MODE);
long rolloverDay = SymbolInfoInteger(symbol,SYMBOL_SWAP_ROLLOVER3DAYS);
string days[] = {"Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"};

enum SYMBOL_TYPE
{
FOREX    = 0,  //Forex
CFD      = 1,  //CFD
FUTURES  = 2   //Futures
};
SYMBOL_TYPE symbolType = (SYMBOL_TYPE)SymbolInfoInteger(symbol,SYMBOL_TRADE_CALC_MODE);

extern ENUM_ORDER_TYPE operationType;   //Type of order

enum CALCULATION_METHOD_POSITION
{
EQUITY_PERCENTAGE = 0,  //Equity percentage
MARGIN_TARGET     = 1,  //Margin determined
LOTS              = 2   //Lot based
};
extern CALCULATION_METHOD_POSITION calculationMethodPosition = LOTS;   //How to calculate position size
extern double positionSizer = 0.01;    //Position sizer

enum RETURNED_VALUE
{
LOT_SIZE    = 0,
MARGIN      = 1,
PROFIT_LOSS = 2,
SWAP        = 3
};

enum SWAP_TYPE
{
SWAP_POINTS       = 0,
SWAP_BASE         = 1,
SWAP_PERCENTAGE   = 2,
SWAP_MARGIN       = 3
};
extern int nights = 1;  //How many nights?
input int swapShift = 0;   //Swap starting day

//---------------------------------------------------------------------------------------------------------//


//Functions:

double PositionSizing(RETURNED_VALUE returnedValue = PROFIT_LOSS)
{

double marginTarget = equity * (positionSizer / 100);
if(calculationMethodPosition == MARGIN_TARGET) marginTarget = positionSizer;
//Input is the target margin rather than the equity percentage.

double correction = MathPow(10,lotRound);    //correction = 100 for lotRound = 2, 1 for 0 etc.
double lotSize = NormalizeDouble(MathFloor(correction * marginTarget / MarginRequiredCalculator()) / correction, lotRound);

if(calculationMethodPosition == LOTS) lotSize = NormalizeDouble(positionSizer, lotRound);
//Input is the lot size rather than the equity percentage.

if(lotSize > SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX)){
   Alert("Lot size exceeded the upper limit (",SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX)," lots), it is adjusted as the limit.");
   lotSize = SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);}
if(lotSize < SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN)){
   Alert("Lot size did not reach the lower limit (",SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN)," lots), increase your margin."); return 0;}

int marginRound = 2;
double margin = NormalizeDouble(lotSize * MarginRequiredCalculator(), marginRound);

int profitLossRound = 2;
tickVal = TickValueCalculator();

double openPrice = 0, closePrice = 0, profitLoss = 0;

if(operationType == ORDER_TYPE_BUY || operationType == ORDER_TYPE_BUY_LIMIT || operationType == ORDER_TYPE_BUY_STOP){
   openPrice = ask;  //Open price for buying
   closePrice = bid;  //Close price for buying
   profitLoss = NormalizeDouble((closePrice - openPrice) * lotSize * contract * tickVal, profitLossRound);
   }
if(operationType == ORDER_TYPE_SELL || operationType == ORDER_TYPE_SELL_LIMIT || operationType == ORDER_TYPE_SELL_STOP){
   openPrice = bid;  //Open price for selling
   closePrice = ask;  //Close price for selling
   profitLoss = NormalizeDouble(-(closePrice - openPrice) * lotSize * contract * tickVal, profitLossRound);
   }

double swapValue = SwapCalculator(lotSize);

if(returnedValue == LOT_SIZE) return lotSize;
else if(returnedValue == MARGIN) return margin;
else if(returnedValue == SWAP) return swapValue;
else return profitLoss;

}

//-----------------------------------------------------------------------------------------------



double SwapCalculator(double lotSize = 1)
{

int nights_ = nights;
if(nights_ < 0){ Alert("ERROR: Enter a number bigger than -1."); return 0;}

double swapValue = 0, swapFactor = 0, swapPrice = 0;
int rollover = 0, swapRound = 2;

if(operationType == ORDER_TYPE_BUY || operationType == ORDER_TYPE_BUY_LIMIT || operationType == ORDER_TYPE_BUY_STOP)
   {swapFactor = swapLong; swapPrice = bid;}
else if(operationType == ORDER_TYPE_SELL || operationType == ORDER_TYPE_SELL_LIMIT || operationType == ORDER_TYPE_SELL_STOP)
   {swapFactor = swapShort; swapPrice = ask;}

tickVal = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);

datetime firstDay_ = TimeLocal() + swapShift * 86400;
MqlDateTime firstDay;

while(nights_ > 0)
{

TimeToStruct(firstDay_,firstDay);
firstDay.hour = 0; firstDay.min = 0; firstDay.sec = 0;

if(firstDay.day_of_week == rolloverDay) rollover = 3;   //If the current day is 3 days swap day.
else if (firstDay.day_of_week == SATURDAY || firstDay.day_of_week == SUNDAY) rollover = 0;
else rollover = 1;

if(swapType == SWAP_POINTS)
   swapValue += NormalizeDouble(rollover * lotSize * swapFactor * tickVal, swapRound);

else if(swapType == SWAP_PERCENTAGE)
   swapValue += NormalizeDouble(swapPrice * rollover * lotSize * contract * swapFactor * tickVal / 1000 / 360, swapRound);

else if(swapType == SWAP_MARGIN)
   swapValue += NormalizeDouble(rollover * lotSize * contract * swapFactor * TickValueCalculator(), swapRound);

else if(swapType == SWAP_BASE)
   swapValue += NormalizeDouble(rollover * lotSize * contract * swapFactor * TickValueCalculator(), swapRound);

firstDay_ += 86400;
nights_--;

}

return swapValue;

}

//-----------------------------------------------------------------------------------------------



double MarginRequiredCalculator()
{
// MODE_MARGINREQUIRED Calculation Method, will be used for the margin calculations.

double calculatedMarginReq = contract, marginPercentage = MarginPercentage();

if(flagStrategy)
   {
   calculatedMarginReq = MarketInfo(symbol,MODE_MARGINREQUIRED);
   if((symbolType == FOREX && currProfit == accCurrency) || symbolType == CFD || symbolType == FUTURES){
   if(operationType == ORDER_TYPE_SELL || operationType == ORDER_TYPE_SELL_LIMIT || operationType == ORDER_TYPE_SELL_STOP)
      calculatedMarginReq *= bid / ask;}
   return calculatedMarginReq;
   }

if(symbolType == FOREX || ((symbolType == CFD || symbolType == FUTURES)) ||
(symbol=="GOLD" || symbol=="SILVER")) calculatedMarginReq /= leverage;

if(symbolType == CFD && symbol != "GOLD" && symbol != "SILVER")
calculatedMarginReq *= marginPercentage;

if((symbolType == FOREX && currProfit == accCurrency) || symbolType == CFD || symbolType == FUTURES)
{
   if(operationType == ORDER_TYPE_BUY || operationType == ORDER_TYPE_BUY_LIMIT || operationType == ORDER_TYPE_BUY_STOP)
      calculatedMarginReq *= ask;
   else if(operationType == ORDER_TYPE_SELL || operationType == ORDER_TYPE_SELL_LIMIT || operationType == ORDER_TYPE_SELL_STOP)
      calculatedMarginReq *= bid;
}

if(symbolType == FOREX && currMargin == accCurrency)  //AAAXXX
calculatedMarginReq *= 1;
if((symbolType == FOREX || symbolType == CFD || symbolType == FUTURES) &&
currProfit != accCurrency && currMargin != accCurrency)   //XXXYYY
{
   if(SymbolInfoDouble(currMargin+accCurrency,SYMBOL_BID)>0)      //XXXAAA
   calculatedMarginReq *= 0.5 * (SymbolInfoDouble(currMargin+accCurrency,SYMBOL_BID)+SymbolInfoDouble(currMargin+accCurrency,SYMBOL_ASK));
   else if(SymbolInfoDouble(accCurrency+currMargin,SYMBOL_BID)>0) //AAAXXX
   calculatedMarginReq *= 2 / (SymbolInfoDouble(accCurrency+currMargin,SYMBOL_BID)+SymbolInfoDouble(accCurrency+currMargin,SYMBOL_ASK));
   else  //If account currency has a symbol neither with the base currency nor with the quote currency.
   {
      if(SymbolInfoDouble(currMargin+"USD",SYMBOL_BID)>0&&SymbolInfoDouble("USD"+accCurrency,SYMBOL_BID)>0)      //XXXUSD && USDAAA
      calculatedMarginReq *= 0.25 * (SymbolInfoDouble("USD"+accCurrency,SYMBOL_BID)+SymbolInfoDouble("USD"+accCurrency,SYMBOL_ASK)) *
      (SymbolInfoDouble(currMargin+"USD",SYMBOL_BID)+SymbolInfoDouble(currMargin+"USD",SYMBOL_ASK));
      else if(SymbolInfoDouble("USD"+currMargin,SYMBOL_BID)>0&&SymbolInfoDouble("USD"+accCurrency,SYMBOL_BID)>0) //USDXXX && USDAAA
      calculatedMarginReq *= (SymbolInfoDouble("USD"+accCurrency,SYMBOL_BID)+SymbolInfoDouble("USD"+accCurrency,SYMBOL_ASK)) /
      (SymbolInfoDouble("USD"+currMargin,SYMBOL_BID)+SymbolInfoDouble("USD"+currMargin,SYMBOL_ASK));
      else if(SymbolInfoDouble(currMargin+"USD",SYMBOL_BID)>0&&SymbolInfoDouble(accCurrency+"USD",SYMBOL_BID)>0) //XXXUSD && AAAUSD
      calculatedMarginReq /= (SymbolInfoDouble(accCurrency+"USD",SYMBOL_BID)+SymbolInfoDouble(accCurrency+"USD",SYMBOL_ASK)) /
      (SymbolInfoDouble(currMargin+"USD",SYMBOL_BID)+SymbolInfoDouble(currMargin+"USD",SYMBOL_ASK));
      else if(SymbolInfoDouble("USD"+currMargin,SYMBOL_BID)>0&&SymbolInfoDouble(accCurrency+"USD",SYMBOL_BID)>0) //USDXXX && AAAUSD
      calculatedMarginReq /= (SymbolInfoDouble(accCurrency+"USD",SYMBOL_BID)+SymbolInfoDouble(accCurrency+"USD",SYMBOL_ASK)) *
      (SymbolInfoDouble("USD"+currMargin,SYMBOL_BID)+SymbolInfoDouble("USD"+currMargin,SYMBOL_ASK));
   }
}

return calculatedMarginReq;

}

//-----------------------------------------------------------------------------------------------



double TickValueCalculator()
{
// MODE_TICKVALUE Calculation Method, will be used for the profit/loss calculations.

ENUM_SYMBOL_INFO_DOUBLE mIType = SYMBOL_BID;
if(symbolType == FOREX)
   if(operationType == ORDER_TYPE_SELL || operationType == ORDER_TYPE_SELL_LIMIT || operationType == ORDER_TYPE_SELL_STOP)
      mIType = SYMBOL_ASK;

double calculatedTickValue = 1;

if(flagStrategy)
   {
   calculatedTickValue = SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE) / contract / tickSize;
   return calculatedTickValue;
   }

if(currProfit==accCurrency)         //XXXAAA
calculatedTickValue *= 1;
else if(symbolType==FOREX && currMargin==accCurrency)     //AAAXXX
calculatedTickValue /= SymbolInfoDouble(symbol,mIType);
else   //XXXYYY
{
   if(SymbolInfoDouble(currProfit+accCurrency,mIType)>0)             //YYYAAA
   calculatedTickValue *= SymbolInfoDouble(currProfit+accCurrency,mIType);
   else if(SymbolInfoDouble(accCurrency+currProfit,mIType)>0)        //AAAYYY
   calculatedTickValue /= SymbolInfoDouble(accCurrency+currProfit,mIType);
   else  //If account currency has a symbol neither with the base currency nor with the quote currency.
   {
      if(operationType == ORDER_TYPE_SELL || operationType == ORDER_TYPE_SELL_LIMIT || operationType == ORDER_TYPE_SELL_STOP)
         mIType = SYMBOL_ASK;     //Mesela TRY hesapta #NIKKEI225
      if(SymbolInfoDouble(currProfit+"USD",mIType)>0&&SymbolInfoDouble("USD"+accCurrency,mIType)>0)         //YYYUSD && USDAAA
      calculatedTickValue *= SymbolInfoDouble("USD"+accCurrency,mIType) * SymbolInfoDouble(currProfit+"USD",mIType);
      else if(SymbolInfoDouble("USD"+currProfit,mIType)>0&&SymbolInfoDouble("USD"+accCurrency,mIType)>0)    //USDYYY && USDAAA
      calculatedTickValue *= SymbolInfoDouble("USD"+accCurrency,mIType) / SymbolInfoDouble("USD"+currProfit,mIType);
      else if(SymbolInfoDouble(currProfit+"USD",mIType)>0&&SymbolInfoDouble(accCurrency+"USD",mIType)>0)    //YYYUSD && AAAUSD
      calculatedTickValue /= SymbolInfoDouble(accCurrency+"USD",mIType) / SymbolInfoDouble(currProfit+"USD",mIType);
      else if(SymbolInfoDouble("USD"+currProfit,mIType)>0&&SymbolInfoDouble(accCurrency+"USD",mIType)>0)    //USDYYY && AAAUSD
      calculatedTickValue /= SymbolInfoDouble(accCurrency+"USD",mIType) * SymbolInfoDouble("USD"+currProfit,mIType);
   }
}

return calculatedTickValue;

}

//-----------------------------------------------------------------------------------------------


double MarginPercentage()
{

double marginPercentage = 0;

if(symbolType == CFD && symbol != "GOLD" && symbol != "SILVER")
{
if(symbol == "JP225Cash") marginPercentage = 0.5;
else if(symbol == "AUS200Cash") marginPercentage = 1;
else if(symbol == "IT40Cash") marginPercentage = 1;
else if(symbol == "US30Cash") marginPercentage = 1;
else if(symbol == "US500Cash") marginPercentage = 1;
else if(symbol == "US100Cash") marginPercentage = 1;
else if(symbol == "FRA40Cash") marginPercentage = 1;
else if(symbol == "GER30Cash") marginPercentage = 1;
else if(symbol == "EU50Cash") marginPercentage = 1;
else if(symbol == "SWI20Cash") marginPercentage = 1;
else if(symbol == "NETH25Cash") marginPercentage = 1;
else if(symbol == "HK50Cash") marginPercentage = 1.5;
else if(symbol == "SPAIN35Cash") marginPercentage = 1;
else if(symbol == "UK100Cash") marginPercentage = 1;
else if(symbol == "SINGCash") marginPercentage = 1.5;
else if(symbol == "CHI50Cash") marginPercentage = 1.5;
else if(symbol == "POL20Cash") marginPercentage = 2;
//else if(symbol == "JP225-SEP20") marginPercentage;
//else if(symbol == "USDX-SEP20") marginPercentage;
else if(symbol == "EU50-SEP20") marginPercentage = 1;
else if(symbol == "GER30-SEP20") marginPercentage = 1;
else if(symbol == "SWI20-SEP20") marginPercentage = 1;
else if(symbol == "UK100-SEP20") marginPercentage = 1;
else if(symbol == "US100-SEP20") marginPercentage = 1;
else if(symbol == "US30-SEP20") marginPercentage = 1;
//else if(symbol == "US500-SEP20") marginPercentage;
else if(symbol == "PLAT-OCT20") marginPercentage = 4.5;
else if(symbol == "COTTO-DEC20") marginPercentage = 2;
else if(symbol == "SUGAR-OCT20") marginPercentage = 2;
else if(symbol == "PALL-DEC20") marginPercentage = 4.5;
else if(symbol == "COCOA-DEC20") marginPercentage = 2;
else if(symbol == "COFFE-DEC20") marginPercentage = 2;
else if(symbol == "WHEAT-DEC20") marginPercentage = 2;
else if(symbol == "HGCOP-DEC20") marginPercentage = 2;
else if(symbol == "CORN-DEC20") marginPercentage = 2;
else if(symbol == "FRA40-SEP20") marginPercentage = 1;
else if(symbol == "OIL-OCT20") marginPercentage = 1.5;
else if(symbol == "OILMn-OCT20") marginPercentage = 1.5;
else if(symbol == "SBEAN-NOV20") marginPercentage = 2;
else if(symbol == "NGAS-OCT20") marginPercentage = 3;
else if(symbol == "BRENT-NOV20") marginPercentage = 1.5;
else if(symbol == "GSOIL-OCT20") marginPercentage = 3;
else if(symbol == "JP225-DEC20") marginPercentage = 0.5;
else if(symbol == "USDX-DEC20") marginPercentage = 1;
else if(symbol == "US500-DEC20") marginPercentage = 1;
if(marginPercentage == 0) Alert("Could not get margin percentage value.");
}
marginPercentage /= 100;


return marginPercentage;

}


//-----------------------------------------------------------------------------------------------
