//+------------------------------------------------------------------+
//|                                                      Trading.mq4 |
//|                                                    goksudemiryol |
//+------------------------------------------------------------------+
#property copyright     "goksudemiryol"
#property link          "https://github.com/goksudemiryol"
#property strict
#property show_inputs
input bool flagTrade = false;    //Trade operation
extern double pendingPrice = 0;   //Pending order price

enum CALCULATION_METHOD_RISK
{
PERCENTAGE  = 0,  //Equity percentage
MONEY       = 1,  //Money
};
input CALCULATION_METHOD_RISK calculationMethodRisk = MONEY;   //How to calculate risk
input double riskSizer = 50;        //Risk sizer
input double profitLossRatio = 1;   //T/P per S/L

#include <MyFunctions.mqh>
#include <stderror.mqh>
#include <stdlib.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{

if(stopOutMode != ACCOUNT_STOPOUT_MODE_PERCENT){
Alert("Account stop out mode is not in percent, check your stop out calculations."); return;}

if(symbol != "TRYBASK")
if((symbolType == FOREX && currProfit == accCurrency) || symbolType == CFD)
if(operationType == ORDER_TYPE_SELL || operationType == ORDER_TYPE_SELL_LIMIT || operationType == ORDER_TYPE_SELL_STOP)
   marginReq *= bid / ask;
if(MathAbs(MarginRequiredCalculator() - marginReq) / marginReq > 1e-5){
Alert("Margin calculation may be inaccurate, terminated."); return;}

double lotSize = PositionSizing(LOT_SIZE);
double margin = PositionSizing(MARGIN);
double profitLoss = PositionSizing(PROFIT_LOSS);
double swap = PositionSizing(SWAP);
double riskMoney = equity * (riskSizer / 100);
if(calculationMethodRisk == MONEY) riskMoney = riskSizer; //Input is the money rather than the equity percentage.

if(!flagTrade || (flagTrade && OrdersTotal() < 1)){
if(calculationMethodPosition == EQUITY_PERCENTAGE)
   Alert("---- ",symbol,": Calculations were made for ",DoubleToString(positionSizer,2),"% of the account equity. ----");

if(calculationMethodPosition == MARGIN_TARGET)
   Alert("---- ",symbol,": Calculations were made for a margin of ",DoubleToString(positionSizer,2)," ",accCurrency,". ----");

if(calculationMethodPosition == LOTS)
   Alert("---- ",symbol,": Calculations were made for ",DoubleToString(positionSizer,lotRound)," lots. ----");

if(symbolType == CFD || symbolType == FUTURES)
   if(currMargin != currProfit)
      Alert("Margin currency and profit currency are different for the symbol, terminated.");

Alert("Lot = ",DoubleToString(lotSize,lotRound)," | Margin = ",DoubleToString(margin,2),
" | Cost = ",DoubleToString(profitLoss,2)," | Swap = ",DoubleToString(swap,2));

Alert("Transactions cost + ",nights," day(s) swap per target loss (",DoubleToString(riskMoney,2)," ",accCurrency,") = ",
DoubleToString(MathAbs((profitLoss + swap) / riskMoney * 100),2),"%.");

if((equity + profitLoss) / margin * 100 <= stopOutLevel){
Alert("WARNING: Transaction causes the Stop Out situation. Terminated."); return;}
if((equity + profitLoss) / margin * 100 <= marginCallLevel){
Alert("WARNING: Transaction causes the Margin Call situation. Terminated."); return;}
}
//---------------------------------------------------------------------------------------

if(flagTrade)
{

double stopDistance = NormalizeDouble(point * stopLevel, digits);
double openPrice = 0, sLPrice = 0;
tickVal = TickValueCalculator();
double sLLevel = 0, tPLevel = 0;
pendingPrice = NormalizeDouble(pendingPrice, digits);

//---------------------------------------------

if(OrdersTotal() < 1)
{
if(!IsTradeAllowed()) Alert("AUTO TRADE IS NOT ALLOWED");

double sLTarget = riskMoney / contract / lotSize / tickVal;
double tPTarget = profitLossRatio * riskMoney / contract / lotSize / tickVal;

if(operationType == ORDER_TYPE_BUY || operationType == ORDER_TYPE_BUY_LIMIT || operationType == ORDER_TYPE_BUY_STOP)
   {
   openPrice = ask; sLPrice = bid;
   if(operationType == ORDER_TYPE_BUY_LIMIT || operationType == ORDER_TYPE_BUY_STOP) openPrice = sLPrice = pendingPrice;
   sLTarget *= -1;
   sLTarget = NormalizeDouble(sLTarget + openPrice, digits);
   tPTarget = NormalizeDouble(tPTarget + openPrice, digits);
   if(sLTarget < sLPrice - stopDistance) sLLevel = sLTarget;
   else {Alert("Trade is failed. Your S/L level (",DoubleToString(sLTarget, digits),") is above the minimum stop level (",
      DoubleToString(sLPrice - stopDistance, digits),")."); return;}
   if(tPTarget > sLPrice + stopDistance) tPLevel = tPTarget;
   else {Alert("Trade is failed. Your T/P level (",DoubleToString(tPTarget, digits),") is below the minimum stop level (",
      DoubleToString(sLPrice + stopDistance, digits),")."); return;}
   if(tPLevel < openPrice) Alert("The take profit level gives a negative profit. Raise your T/P level.");
   }

if(operationType == ORDER_TYPE_SELL || operationType == ORDER_TYPE_SELL_LIMIT || operationType == ORDER_TYPE_SELL_STOP)
   {
   openPrice = bid; sLPrice = ask;
   if(operationType == ORDER_TYPE_SELL_LIMIT || operationType == ORDER_TYPE_SELL_STOP) openPrice = sLPrice = pendingPrice;
   tPTarget *= -1;
   tPTarget = NormalizeDouble(tPTarget + openPrice, digits);
   sLTarget = NormalizeDouble(sLTarget + openPrice, digits);
   if(sLTarget > sLPrice + stopDistance) sLLevel = sLTarget;
   else {Alert("Trade is failed. Your S/L level (",DoubleToString(sLTarget, digits),") is below the minimum stop level (",
      DoubleToString(sLPrice + stopDistance, digits),")."); return;}
   if(tPTarget < sLPrice - stopDistance) tPLevel = tPTarget;
   else {Alert("Trade is failed. Your T/P level (",DoubleToString(tPTarget, digits),") is above the minimum stop level (",
      DoubleToString(sLPrice - stopDistance, digits),")."); return;}
   if(tPLevel > openPrice) Alert("The take profit level gives a negative profit. Lower your T/P level.");
   }

if(sLLevel == 0 || tPLevel == 0) Alert("WARNING: Your S/L or T/P level is set to zero.");
int orderTicket = OrderSend(symbol,operationType,lotSize,openPrice,0,sLLevel,tPLevel);
if(orderTicket == -1) Alert("Trade is failed. Error: ",ErrorDescription(GetLastError()));
return;
}
//---------------------------------------------

if(OrdersTotal() >= 1)
{
if(!OrderSelect(0,SELECT_BY_POS)) {Alert("Order could not have selected. NO MODIFY!"); return;}
operationType = (ENUM_ORDER_TYPE)OrderType();

if(operationType == ORDER_TYPE_BUY || operationType == ORDER_TYPE_SELL)
   {
   if     (marginLevel <= 75              && marginLevel > marginCallLevel) Alert("WARNING: Margin level is below 75%!");
   else if(marginLevel <= marginCallLevel && marginLevel > 35)              Alert("WARNING: MARGIN CALL!");
   else if(marginLevel <= 35              && marginLevel > stopOutLevel)    Alert("WARNING: Margin level is below 35%!");
   else if(marginLevel <= stopOutLevel)                                     Alert("WARNING: STOP OUT!!!");
   }

Alert("There is an open order, it is going to be modified.");
int orderTicket = OrderTicket();
symbol  = OrderSymbol();          contract  = SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);  lotSize = OrderLots();
tickVal = TickValueCalculator();  openPrice = OrderOpenPrice();

if((int)pendingPrice == 0) pendingPrice = OrderOpenPrice();

double sLTarget = riskMoney / contract / lotSize / tickVal;
double tPTarget = profitLossRatio * riskMoney / contract / lotSize / tickVal;

if(operationType == ORDER_TYPE_BUY || operationType == ORDER_TYPE_BUY_LIMIT || operationType == ORDER_TYPE_BUY_STOP)
   {
   sLPrice = bid;
   if(operationType == ORDER_TYPE_BUY_LIMIT || operationType == ORDER_TYPE_BUY_STOP) openPrice = sLPrice = pendingPrice;
   sLTarget *= -1;
   sLTarget = NormalizeDouble(sLTarget + openPrice, digits);
   tPTarget = NormalizeDouble(tPTarget + openPrice, digits);
   if(sLTarget < sLPrice - stopDistance) sLLevel = sLTarget;
   else {Alert("Modify is failed. Your S/L level (",DoubleToString(sLTarget, digits),") is above the minimum stop level (",
      DoubleToString(sLPrice - stopDistance, digits),")."); return;}
   if(tPTarget > sLPrice + stopDistance) tPLevel = tPTarget;
   else {Alert("Modify is failed. Your T/P level (",DoubleToString(tPTarget, digits),") is below the minimum stop level (",
      DoubleToString(sLPrice + stopDistance, digits),")."); return;}
   if(tPLevel < openPrice) Alert("The take profit level gives a negative profit. Raise your T/P level.");
   }

if(operationType == ORDER_TYPE_SELL || operationType == ORDER_TYPE_SELL_LIMIT || operationType == ORDER_TYPE_SELL_STOP)
   {
   sLPrice = ask;
   if(operationType == ORDER_TYPE_SELL_LIMIT || operationType == ORDER_TYPE_SELL_STOP) openPrice = sLPrice = pendingPrice;
   tPTarget *= -1;
   tPTarget = NormalizeDouble(tPTarget + openPrice, digits);
   sLTarget = NormalizeDouble(sLTarget + openPrice, digits);
   if(sLTarget > sLPrice + stopDistance) sLLevel = sLTarget;
   else {Alert("Modify is failed. Your S/L level (",DoubleToString(sLTarget, digits),") is below the minimum stop level (",
      DoubleToString(sLPrice + stopDistance, digits),")."); return;}
   if(tPTarget < sLPrice - stopDistance) tPLevel = tPTarget;
   else {Alert("Modify is failed. Your T/P level (",DoubleToString(tPTarget, digits),") is above the minimum stop level (",
      DoubleToString(sLPrice - stopDistance, digits),")."); return;}
   if(tPLevel > openPrice) Alert("The take profit level gives a negative profit. Lower your T/P level.");
   }

if(sLLevel == 0 || tPLevel == 0) Alert("WARNING: Your S/L or T/P level is set to zero.");
if(!OrderModify(orderTicket,openPrice,sLLevel,tPLevel,0))
   Alert("Order could not have modified. Error: ",ErrorDescription(GetLastError()));
else Alert("Order have modified.");

if(operationType == ORDER_TYPE_BUY || operationType == ORDER_TYPE_SELL)
Alert("Today's swap is roughly = ",DoubleToString(SwapCalculator(lotSize),2)," ",accCurrency);

}
//---------------------------------------------

}
//---------------------------------------------------------------------------------------

}



