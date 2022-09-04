//+------------------------------------------------------------------+
//|                                                 TradingHours.mq4 |
//|                                                    goksudemiryol |
//+------------------------------------------------------------------+
#property copyright "goksudemiryol"
#property link      "https://github.com/goksudemiryol"
#property strict
//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   string days[] = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"};
   
   datetime from_ = 0, to_ = 0;
   MqlDateTime from, to;
   
   uint counter = 0;
   
   bool hours = true;
   
   string print = "";
   
   for(int i = SUNDAY ; i > -7 ; i--)
   {
      int i_ = i%7+7;
      if(i_ == 7)
         i_ = 0;
      
      hours = SymbolInfoSessionTrade(Symbol(),i_,counter,from_,to_);
      
      TimeToStruct(from_,from); TimeToStruct(to_,to);
      
      print = days[i_] + ": ";
      
      while(hours)
      {
         string fromHour = (string)from.hour;
         string fromMinute = (string)from.min;
         string toHour = (string)to.hour;
         string toMinute = (string)to.min;
         
         if(to.day_of_year > from.day_of_year)
            toHour = (string)24;
         if((int)fromHour < 10)
            fromHour = "0" + fromHour;
         if((int)fromMinute < 10)
            fromMinute = "0" + fromMinute;
         if((int)toHour < 10)
            toHour = "0" + toHour;
         if((int)toMinute < 10)
            toMinute = "0" + toMinute;
            
         print += fromHour + ":" + fromMinute+" - " + toHour + ":" + toMinute;
         counter++;
         
         hours = SymbolInfoSessionTrade(Symbol(),i_,counter,from_,to_);
         
         TimeToStruct(from_,from); TimeToStruct(to_,to);
         
         if(hours)
            print += ", ";
      }
      
      Alert(print);
      counter = 0;
   }
   
   Alert("---- Trading Sessions for ", Symbol(), ": ----");
}

