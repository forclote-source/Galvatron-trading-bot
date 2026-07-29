//+------------------------------------------------------------------+
//|                                                   Galvatron6610  |
//|                                      Auteur : forclote / Galvatron |
//+------------------------------------------------------------------+
#property copyright "Galvatron6610"
#property link      "https://github.com/forclote-source/Galvatron-trading-bot"
#property version   "1.00"
#property strict

//--- Paramètres d'entrée
input double   Lots            = 0.10;      // Taille de lot
input int      StopLossPoints  = 300;       // Stop Loss en points
input int      TakeProfitPoints= 600;       // Take Profit en points
input int      MagicNumber     = 6610;      // Magic Number du bot
input int      RSIPeriod       = 14;        // Période RSI
input double   RSI_BuyLevel    = 30.0;      // Niveau RSI pour achat
input double   RSI_SellLevel   = 70.0;      // Niveau RSI pour vente
input int      MaxTrades       = 3;         // Nombre max de trades ouverts
input bool     UseTrailingStop = true;      // Activer le trailing stop
input int      TrailingPoints  = 200;       // Trailing stop en points

//--- Variables globales
int            rsi_handle;
double         rsi_value[];

//+------------------------------------------------------------------+
//| Initialisation de l'EA                                           |
//+------------------------------------------------------------------+
int OnInit()
  {
   rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
   if(rsi_handle == INVALID_HANDLE)
     {
      Print("Erreur : impossible de créer le handle RSI");
      return(INIT_FAILED);
     }
   Print("Galvatron6610 EA initialisé sur ", _Symbol, " timeframe ", Period());
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Déinitialisation                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(rsi_handle != INVALID_HANDLE)
      IndicatorRelease(rsi_handle);
  }

//+------------------------------------------------------------------+
//| Fonction principale : OnTick                                     |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Mise à jour RSI
   if(CopyBuffer(rsi_handle, 0, 0, 1, rsi_value) <= 0)
      return;

   double rsi = rsi_value[0];

   // Vérifier le nombre de trades ouverts
   int trades = CountOpenTrades();
   if(trades >= MaxTrades)
      return;

   // Vérifier si on peut trader
   if(!IsTradeAllowed())
      return;

   // Conditions d'achat
   if(rsi <= RSI_BuyLevel && !HasOpenBuy())
     {
      OpenOrder(ORDER_TYPE_BUY);
     }

   // Conditions de vente
   if(rsi >= RSI_SellLevel && !HasOpenSell())
     {
      OpenOrder(ORDER_TYPE_SELL);
     }

   // Trailing stop
   if(UseTrailingStop)
      ApplyTrailingStop();
  }

//+------------------------------------------------------------------+
//| Compter les trades ouverts par le bot                            |
//+------------------------------------------------------------------+
int CountOpenTrades()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if((int)PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            count++;
        }
     }
   return(count);
  }

//+------------------------------------------------------------------+
//| Vérifier si un BUY est déjà ouvert                               |
//+------------------------------------------------------------------+
bool HasOpenBuy()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if((int)PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            return(true);
        }
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Vérifier si un SELL est déjà ouvert                              |
//+------------------------------------------------------------------+
bool HasOpenSell()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if((int)PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
            PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            return(true);
        }
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Ouvrir un ordre                                                  |
//+------------------------------------------------------------------+
void OpenOrder(ENUM_ORDER_TYPE type)
  {
   double price, sl, tp;
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action   = TRADE_ACTION_DEAL;
   request.symbol   = _Symbol;
   request.magic    = MagicNumber;
   request.volume   = Lots;
   request.type     = type;
   request.type_filling = ORDER_FILLING_FOK;
   request.deviation= 20;

   if(type == ORDER_TYPE_BUY)
     {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl    = price - StopLossPoints * _Point;
      tp    = price + TakeProfitPoints * _Point;
     }
   else
     {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl    = price + StopLossPoints * _Point;
      tp    = price - TakeProfitPoints * _Point;
     }

   request.price    = price;
   request.sl       = sl;
   request.tp       = tp;

   if(!OrderSend(request, result))
     {
      Print("Erreur OrderSend : ", result.retcode);
     }
   else
     {
      Print("Ordre ouvert : ticket ", result.order, " type ", type);
     }
  }

//+------------------------------------------------------------------+
//| Trailing stop                                                    |
//+------------------------------------------------------------------+
void ApplyTrailingStop()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;

      if((int)PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double price_open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl        = PositionGetDouble(POSITION_SL);
      double current   = (type == POSITION_TYPE_BUY ?
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK));

      MqlTradeRequest request;
      MqlTradeResult  result;
      ZeroMemory(request);
      ZeroMemory(result);

      request.action   = TRADE_ACTION_SLTP;
      request.symbol   = _Symbol;
      request.magic    = MagicNumber;
      request.position = ticket;

      if(type == POSITION_TYPE_BUY)
        {
         double new_sl = current - TrailingPoints * _Point;
         if(new_sl > sl && new_sl > price_open)
           {
            request.sl = new_sl;
            request.tp = PositionGetDouble(POSITION_TP);
            OrderSend(request, result);
           }
        }
      else if(type == POSITION_TYPE_SELL)
        {
         double new_sl = current + TrailingPoints * _Point;
         if((sl == 0.0 || new_sl < sl) && new_sl < price_open)
           {
            request.sl = new_sl;
            request.tp = PositionGetDouble(POSITION_TP);
            OrderSend(request, result);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Vérifier si le trading est autorisé                              |
//+------------------------------------------------------------------+
bool IsTradeAllowed()
  {
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return(false);
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO ||
      AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL)
      return(true);
   return(false);
  }
//+------------------------------------------------------------------+
