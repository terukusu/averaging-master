//+------------------------------------------------------------------+
//|                                              AveragingMaster.mq4 |
//|                               Copyright 2018, Teruhiko Kusunoki. |
//|                                        https://www.terukusu.org/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Teruhiko Kusunoki"
#property link      "https://www.terukusu.org/"
#property version   "1.0"
#property strict

#include <stdlib.mqh>

input double RiskFactor=0.0015;
input double ProfitPercentage=1.0;
input double LossPercentage=40.0;
input int MaxSpread=30;
input int MaxSlippage=30;
input double AveragingStep=0.001;
input int GMTShift=0;
input int TestDataGMTOffset=0;
input int TestSummerTimeShift=1;
input int magic=1134112;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   MathSrand((int)TimeLocal());
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   int total;

   total=MyOrdersTotal();

   if(total==0)
     {
      Entry();
     }
   else if(total>0)
     {

      CloseAll();

      if(MyOrdersTotal()>0)
        {
         Averaging();
        }
     }
  }
//+------------------------------------------------------------------+
//| count orders which has my magic number.                                                                 |
//+------------------------------------------------------------------+
int MyOrdersTotal()
  {
   int ordersTotal;
   bool isError;

   ordersTotal=0;

   for(int pos=0; pos<OrdersTotal(); pos++)
     {
      if(!OrderSelect(pos,SELECT_BY_POS,MODE_TRADES))
        {
         LogWarn("Server failed to select order pos="+(string)pos+" Err="+(string)GetLastError());
         isError=true;
         continue;
        }

      if(OrderMagicNumber()==magic)
        {
         ordersTotal++;
        }
     }

   return ordersTotal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int MyFirstOrderPos()
  {
   int firstOrderPos;

   firstOrderPos=-1;

   for(int pos=0; pos<OrdersTotal(); pos++)
     {
      if(!OrderSelect(pos,SELECT_BY_POS,MODE_TRADES))
        {
         LogWarn("Server failed to select order pos="+(string)pos+" Err="+(string)GetLastError());
         continue;
        }

      if(OrderMagicNumber()==magic)
        {
         firstOrderPos=pos;
         break;
        }
     }

   return firstOrderPos;
  }
//+------------------------------------------------------------------+
//| get last order pos which has my magic number.                                                                 |
//+------------------------------------------------------------------+
int MyLastOrderPos()
  {
   int lastOrderPos;

   lastOrderPos=-1;

   for(int pos=OrdersTotal()-1; pos>=0; pos--)
     {
      if(!OrderSelect(pos,SELECT_BY_POS,MODE_TRADES))
        {
         LogWarn("Server failed to select order pos="+(string)pos+" Err="+(string)GetLastError());
         continue;
        }

      if(OrderMagicNumber()==magic)
        {
         lastOrderPos=pos;
         break;
        }
     }

   return lastOrderPos;
  }
//+------------------------------------------------------------------+
//| entry if needed                                                                 |
//| return: return true if something wrong.                          |
//+------------------------------------------------------------------+
bool Entry()
  {
   double lotSize,spread;
   double ima1,ima2;
   int hour,dayOfWeek;
   datetime gmt;
   static bool todayIsDone=false;

   gmt=TimeGmt();
   hour=TimeHour(gmt);
   dayOfWeek=TimeDayOfWeek(gmt);
   spread=MarketInfo(NULL,MODE_SPREAD);

   if((hour>2 && hour<21) || dayOfWeek==0 || (dayOfWeek==1 && hour<=2)
      || (dayOfWeek==5 && hour>=21) || dayOfWeek==6)
     {
      todayIsDone=false;
      return true;
     }

   if(todayIsDone || spread>MaxSpread)
     {
      // nothing to do
      return true;
     }

   ima1 = iMA(NULL,PERIOD_H4,6,0,MODE_SMA,PRICE_CLOSE,0);
   ima2 = iMA(NULL,PERIOD_H4,6,0,MODE_SMA,PRICE_CLOSE,1);

   lotSize=CalcLotSize();

   if(lotSize<=0)
     {
      // no enough money :-)
      return true;
     }

   if(ima1>ima2)
     {
      if(!OrderSend(Symbol(),OP_BUY,lotSize,Ask,MaxSlippage,NULL,NULL,"Buy",magic,0,Blue))
        {
         LogWarn("Server failed to buy. Err="+(string)GetLastError());
         return false;
        }
      todayIsDone=true;
     }
   else if(ima1<ima2)
     {
      if(!OrderSend(Symbol(),OP_SELL,lotSize,Bid,MaxSlippage,NULL,NULL,"Sell",magic,0,Red))
        {
         LogWarn("Server failed to sell. Err="+(string)GetLastError());
         return false;
        }
      todayIsDone=true;
     }

   return true;
  }
//+------------------------------------------------------------------+
//| cose all positions if needed.                                    |
//| return: return true if something wrong.                          |
//+------------------------------------------------------------------+
bool CloseAll()
  {
   int orderType,hour;
   double netProfit,targetProfit,targetLoss,lotSize,originalEquity;
   bool isError;

   isError=false;
   hour=TimeHour(TimeGmt());
   netProfit=CalcNetProfit();

   if(!OrderSelect(MyFirstOrderPos(),SELECT_BY_POS,MODE_TRADES))
     {
      LogWarn("Server failed to select order. Err="+(string)GetLastError());
      return false;
     }

   orderType=OrderType();
   lotSize=OrderLots();
   originalEquity=1000*lotSize/RiskFactor;

   targetProfit=originalEquity*ProfitPercentage/100;
   targetLoss=originalEquity*LossPercentage/100;

   if(!(netProfit>=targetProfit || netProfit<=-targetLoss || (hour>=8 && hour<21)))
     {
      // no need to close
      return true;
     }

   int tickets[];
   ArrayResize(tickets,MyOrdersTotal());
   ArrayFill(tickets,0,ArraySize(tickets),0);

   isError=false;
   for(int pos=0; pos<MyOrdersTotal(); pos++)
     {
      if(!OrderSelect(pos,SELECT_BY_POS))
        {
         LogWarn("Server failed to select order pos="+(string)pos+" Err="+(string)GetLastError());
         isError=true;
         continue;
        }

      if(OrderMagicNumber()!=magic)
        {
         continue;
        }

      tickets[pos]=OrderTicket();
     }

   for(int pos=0; pos<ArraySize(tickets); pos++)
     {
      if(tickets[pos]==0)
        {
         continue;
        }

      if(!OrderSelect(tickets[pos],SELECT_BY_TICKET))
        {
         LogWarn("Server failed to select order pos="+(string)pos+" Err="+(string)GetLastError());
         isError=true;
         continue;
        }

      if(!OrderClose(OrderTicket(),OrderLots(),OrderClosePrice(),MaxSlippage,Lime))
        {
         LogWarn("Server failed to close order pos="+(string)pos+" Err="+(string)GetLastError());
         continue;
        }
     }

   return isError;
  }
//+------------------------------------------------------------------+
//| averaging if needed                                                                 |
//+------------------------------------------------------------------+
bool Averaging()
  {
   int orderType;
   double prevPrice,lotSize,spread,step;

   if(!OrderSelect(MyLastOrderPos(),SELECT_BY_POS,MODE_TRADES))
     {
      LogWarn("Server failed to select order. Err="+(string)GetLastError());
      return false;
     }

   spread=MarketInfo(NULL,MODE_SPREAD);
   orderType = OrderType();
   prevPrice = OrderOpenPrice();
   lotSize=CalcLotSize();

   if(lotSize<=0)
     {
      // no enough money :-)
      return true;
     }

   if(spread>MaxSpread)
     {
      return false;
     }

   if(MyOrdersTotal()>4)
     {
      return false;
     }

   step=iATR(NULL,0,3,1)*3;
//step=AveragingStep;

   if(orderType==OP_BUY)
     {
      if(prevPrice-Bid>step)
        {
         if(!OrderSend(Symbol(),OP_BUY,lotSize,Ask,MaxSlippage,NULL,NULL,"Buy",magic,0,Blue))
           {
            LogWarn("Server failed to buy. Err="+(string)GetLastError());
            return false;
           }
        }
     }
   else if(orderType==OP_SELL)
     {
      if(Ask-prevPrice>step)
        {
         if(!OrderSend(Symbol(),OP_SELL,lotSize,Bid,MaxSlippage,NULL,NULL,"Sell",magic,0,Red))
           {
            LogWarn("Server failed to sell. Err="+(string)GetLastError());
            return false;
           }
        }
     }

   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalcNetProfit()
  {
   double profit;

   profit=0;

   for(int pos=0; pos<MyOrdersTotal(); pos++)
     {
      if(!OrderSelect(pos,SELECT_BY_POS))
        {
         LogWarn("Server failed to select order pos="+(string)pos+" Err="+(string)GetLastError());
         continue;
        }

      if(OrderMagicNumber()!=magic)
        {
         continue;
        }

      profit+=OrderProfit()+OrderCommission()+OrderSwap();
     }
   return profit;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalcLotSize()
  {
   double lot,lotLimit;

   double equity         = AccountEquity();
   double freeMargin     = AccountFreeMargin();
   double requiredMargin = MarketInfo(NULL, MODE_MARGINREQUIRED);
   double lotSize        = MarketInfo(NULL, MODE_LOTSIZE);
   double lotStep        = MarketInfo(NULL, MODE_LOTSTEP);
   double minLot         = MarketInfo(NULL, MODE_MINLOT);
   double maxLot         = MarketInfo(NULL, MODE_MAXLOT);

//lot=RiskFactor*equity/1000;
   lot=RiskFactor*freeMargin/1000;
   lot=MathFloor(lot/lotStep)*lotStep;

   lotLimit=freeMargin/requiredMargin;
   lotLimit=MathFloor(lotLimit/lotStep)*lotStep;

   if(lot>lotLimit)
     {
      lot=lotLimit;
     }

   if(lot<minLot)
     {
      lot=-1;
     }
   else if(lot>maxLot)
     {
      lot=maxLot;
     }

   return lot;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime TimeGmt()
  {
   datetime gmt;

   gmt=TimeGMT();
   gmt+=(GMTShift*3600);

   if(!IsTesting())
     {
      return gmt;
     }

// summer time shift
   if(Month()>=3 && Month()<=10)
     {
      gmt+=(TestSummerTimeShift*3600);
     }

   return gmt - (TestDataGMTOffset*3600);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
enum LOG_LEVEL
  {
   LOG_DEBUG= 1,
   LOG_INFO = 2,
   LOG_WARN = 3,
   LOG_FATAL= 4,
  };
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LogDebug(string message=NULL) export
  {
   Log(LOG_DEBUG,message);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LogWarn(string message=NULL) export
  {
   Log(LOG_WARN,message);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Log(LOG_LEVEL logLevel=LOG_INFO,string message=NULL)
  {
   Print(message);
  }
//+------------------------------------------------------------------+
