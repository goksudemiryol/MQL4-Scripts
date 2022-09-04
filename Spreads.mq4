//+------------------------------------------------------------------+
//|                                                      Spreads.mq4 |
//|                                                    goksudemiryol |
//+------------------------------------------------------------------+
#property copyright     "goksudemiryol"
#property link          "https://github.com/goksudemiryol"
#property description   "For any trading asset, if there is a difference betweeen the ask and the bid price, this difference "
"is your transaction cost, in other words, spread.\n\n"
"To list the spreads of all available symbols in the market watch from the lowest price to the highest, change the "
"\"All symbols\" variable to true in the \"Inputs\" tab.\n\n"
"You can also set the initial margin of your choice by changing the \"Target margin\" variable, the default value is 1000 "
"unit money of your account currency."
//"Calculation formula: (Ask - Bid) * Contract Size * Tick Value"
#property strict
#property show_inputs

input bool allSymbols = false;   //All symbols
input double margin = 1000;      //Target margin

string accCurrency = AccountInfoString(ACCOUNT_CURRENCY);
string symbol = Symbol();
string currMargin = SymbolInfoString(symbol,SYMBOL_CURRENCY_MARGIN);
string currProfit = SymbolInfoString(symbol,SYMBOL_CURRENCY_PROFIT);

enum SYMBOL_TYPE
{
   FOREX    = 0,  //Forex
   CFD      = 1,  //CFD
   FUTURES  = 2   //Futures
};
SYMBOL_TYPE symbolType = (SYMBOL_TYPE)SymbolInfoInteger(symbol,SYMBOL_TRADE_CALC_MODE);

double contract = SymbolInfoDouble(symbol,SYMBOL_TRADE_CONTRACT_SIZE);
double marginReq = MarketInfo(symbol,MODE_MARGINREQUIRED);

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   if(!allSymbols)
   {
      if(MarketInfo(symbol, MODE_MARGINREQUIRED) == 0)
      {
         Alert("Calculations could not be made for ", symbol);
         return;
      }
         
      string spread_ = DoubleToString((SymbolInfoDouble(symbol,SYMBOL_ASK) - SymbolInfoDouble(symbol,SYMBOL_BID)) * contract * TickValueCalculator(symbol) * margin / marginReq, 2);
      
      Alert("---- spread is equal to: ", spread_, " ", accCurrency);
      Alert("---- For a buying transaction with ", margin, " ", accCurrency, " margin for ", symbol, ",");
   }

   else
   {
      int symbolCount = SymbolsTotal(true);
      string symbolsAll[];
      double spread[][2];
      ArrayResize(symbolsAll,symbolCount);
      ArrayResize(spread,symbolCount);
      
      for(int i = 0 ; i < symbolCount ; i++)
      {
         symbolsAll[i] = SymbolName(i,true);    //The symbolsAll array contains all symbols in the market watch.
         spread[i][1] = i;
         
         if(MarketInfo(symbolsAll[i],MODE_MARGINREQUIRED) == 0)
            continue;
   
         spread[i][0] = NormalizeDouble((SymbolInfoDouble(symbolsAll[i],SYMBOL_ASK) - SymbolInfoDouble(symbolsAll[i],SYMBOL_BID))* SymbolInfoDouble(symbolsAll[i],SYMBOL_TRADE_CONTRACT_SIZE) * TickValueCalculator(symbolsAll[i]) * margin / MarketInfo(symbolsAll[i],MODE_MARGINREQUIRED),2);
      }
      
      ArraySort(spread,WHOLE_ARRAY,0,MODE_DESCEND);
      
      for(int i = 0 ; i < symbolCount ; i++)
      {
         if(MarketInfo(symbolsAll[(int)spread[i][1]],MODE_MARGINREQUIRED) == 0)
            Alert("Calculations could not be made for ", symbolsAll[(int)spread[i][1]]);
            
         else
            Alert(symbolsAll[(int)spread[i][1]]," ",DoubleToString(spread[i][0],2));
      }
      
      Alert("---- Spreads for buying trancastion in ascending order: (Margin = ",margin ," " , accCurrency, ") ----");
   }
}

//------------------------------------------------------------------

double TickValueCalculator(string symbol_)
{
   currMargin = SymbolInfoString(symbol_,SYMBOL_CURRENCY_MARGIN);
   currProfit = SymbolInfoString(symbol_,SYMBOL_CURRENCY_PROFIT);
   symbolType = (SYMBOL_TYPE)SymbolInfoInteger(symbol_,SYMBOL_TRADE_CALC_MODE);
   
   ENUM_SYMBOL_INFO_DOUBLE mIType = SYMBOL_BID;
   
   double calculatedTickValue = 1;
   
   if(currProfit==accCurrency)   //XXXAAA
      calculatedTickValue *= 1;
      
   else if(symbolType==FOREX && currMargin==accCurrency) //AAAXXX
      calculatedTickValue /= SymbolInfoDouble(symbol_,mIType);
      
   else   //XXXYYY
   {
      if(SymbolInfoDouble(currProfit+accCurrency,mIType)>0)    //YYYAAA
         calculatedTickValue *= SymbolInfoDouble(currProfit+accCurrency,mIType);
         
      else if(SymbolInfoDouble(accCurrency+currProfit,mIType)>0)  //AAAYYY
         calculatedTickValue /= SymbolInfoDouble(accCurrency+currProfit,mIType);
         
      else  //If account currency has a symbol neither with the base currency nor with the quote currency.
      {
         if(SymbolInfoDouble(currProfit+"USD",mIType)>0&&SymbolInfoDouble("USD"+accCurrency,mIType)>0)   //YYYUSD && USDAAA
            calculatedTickValue *= SymbolInfoDouble("USD"+accCurrency,mIType) * SymbolInfoDouble(currProfit+"USD",mIType);
         
         else if(SymbolInfoDouble("USD"+currProfit,mIType)>0&&SymbolInfoDouble("USD"+accCurrency,mIType)>0) //USDYYY && USDAAA
            calculatedTickValue *= SymbolInfoDouble("USD"+accCurrency,mIType) / SymbolInfoDouble("USD"+currProfit,mIType);
         
         else if(SymbolInfoDouble(currProfit+"USD",mIType)>0&&SymbolInfoDouble(accCurrency+"USD",mIType)>0) //YYYUSD && AAAUSD
            calculatedTickValue /= SymbolInfoDouble(accCurrency+"USD",mIType) / SymbolInfoDouble(currProfit+"USD",mIType);
         
         else if(SymbolInfoDouble("USD"+currProfit,mIType)>0&&SymbolInfoDouble(accCurrency+"USD",mIType)>0) //USDYYY && AAAUSD
            calculatedTickValue /= SymbolInfoDouble(accCurrency+"USD",mIType) * SymbolInfoDouble("USD"+currProfit,mIType);
      }
   }
   
   return calculatedTickValue;
}

