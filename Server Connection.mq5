//+------------------------------------------------------------------+
//|                                                SendH1ToFlask.mq5 |
//+------------------------------------------------------------------+
#property strict

input string FlaskUrl = "http://127.0.0.1:8000/from_mt5";

// remember when we last sent a request
datetime last_request_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // set timer to fire every 30 seconds (adjust if you like)
   EventSetTimer(60*30); // 60 seconds x 30 times

   // optional: send once at startup
   SendLastH1Candles();

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
  }

//+------------------------------------------------------------------+
//| Expert tick function (not used here)                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // nothing, we drive everything with OnTimer
  }

//+------------------------------------------------------------------+
//| Timer handler, runs every 30 seconds                             |
//+------------------------------------------------------------------+
void OnTimer()
  {
   datetime now = TimeCurrent();
   MqlDateTime t;
   TimeToStruct(now, t);

   // we want to send at minute 0 or 30 only
   bool is_target_minute = (t.min == 0 || t.min == 30);

   // avoid sending multiple times in the same minute
   if(is_target_minute && (now - last_request_time > 60))
     {
      Print("Timer at ", TimeToString(now, TIME_DATE | TIME_SECONDS),
            " sending candles to Flask");

      SendLastH1Candles();
      last_request_time = now;
     }
  }

//+------------------------------------------------------------------+
//| Fetch last 20 H1 candles and send to Flask                       |
//+------------------------------------------------------------------+
void SendLastH1Candles()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);

   int copied = CopyRates(_Symbol, PERIOD_H1, 0, 20, rates);
   if(copied <= 0)
     {
      Print("CopyRates failed, error ", GetLastError());
      return;
     }

   // Build JSON payload
   string json = "{";
   json += "\"symbol\":\"" + _Symbol + "\",";
   json += "\"timeframe\":\"H1\",";
   json += "\"bars\":[";
   // rates[0] is the current bar when ArraySetAsSeries is true
   // loop from oldest to newest
   for(int i = copied - 1; i >= 0; i--)
     {
      if(i != copied - 1)
         json += ",";

      json += "{";
      json += "\"time\":\""  + TimeToString(rates[i].time, TIME_DATE | TIME_MINUTES) + "\",";
      json += "\"open\":"    + DoubleToString(rates[i].open,  _Digits) + ",";
      json += "\"high\":"    + DoubleToString(rates[i].high,  _Digits) + ",";
      json += "\"low\":"     + DoubleToString(rates[i].low,   _Digits) + ",";
      json += "\"close\":"   + DoubleToString(rates[i].close, _Digits) + ",";
      json += "\"tick_volume\":" + (string)rates[i].tick_volume;
      json += "}";
     }
   json += "]}";

   // Prepare POST body as UTF 8 bytes
   uchar  post[];
   uchar  result[];
   string result_headers;

   int len = StringToCharArray(json, post, 0, StringLen(json), CP_UTF8);
   if(len <= 0)
     {
      Print("StringToCharArray failed");
      return;
     }
   ArrayResize(post, len);

   string headers = "Content-Type: application/json\r\n";

   ResetLastError();
   int status = WebRequest("POST",
                           FlaskUrl,
                           headers,
                           5000,
                           post,
                           result,
                           result_headers);

   if(status == -1)
     {
      Print("WebRequest error ", GetLastError());
     }
   else
     {
      Print("HTTP status ", status);
      string response = CharArrayToString(result, 0, -1, CP_UTF8);
      Print("Server response: ", response);
     }
  }
