//+------------------------------------------------------------------+
//| ConsensusEA.mq5 — основной файл консенсус-советника             |
//| Связка: Analyzer → Core → Combiner → Panel + Trade Module        |
//+------------------------------------------------------------------+
#property strict
#property version   "1.50"  // Обновили версию для трейдинга
#property copyright "Consensus"

//---------------------------------------------------------------
// Подключаем модули
//---------------------------------------------------------------
#include "ConsensusAnalyzer.mqh"
#include "ConsensusCore.mqh"
#include "SignalCombiner.mqh"
#include "PanelConsensus.mqh"
#include "TradeModule.mqh"  // Новый торговый модуль

//---------------------------------------------------------------
// INPUT PARAMETERS
//---------------------------------------------------------------

// ---- Timeframe Settings ----
input string _SECTION1 = "---- Timeframe Settings ----";
input ENUM_TIMEFRAMES Inp_WorkTF     = PERIOD_M5;   // Working timeframe
input ENUM_TIMEFRAMES Inp_SeniorTF   = PERIOD_H1;   // Senior timeframe

// ---- Combination Method ----
input string _SECTION2 = "---- Combination Method ----";
input ENUM_CombinationMethod Inp_Method  = COMB_METHOD_FILTER;  // Combination method
input double                Inp_Threshold = 0.30;               // Consensus threshold

// ---- Consensus Panel Settings ----
input string _SECTION3 = "---- Consensus Panel Settings ----";
input int   Inp_PanelX       = 10;    // Panel X offset (pixels)
input int   Inp_PanelY       = 20;    // Panel Y offset (pixels)
input int   Inp_PanelW       = 260;   // Panel width (pixels)
input int   Inp_PanelH       = 120;   // Panel height (pixels)
input int   Inp_FontSize     = 9;     // Font size (points)
input ENUM_BASE_CORNER Inp_PanelCorner = CORNER_LEFT_UPPER; // Panel corner

// ---- Risk Control & Filters ----
input string _SECTION4 = "---- Risk Control & Filters ----";
input bool   Inp_AvoidTrendEnd = true;    // Avoid entries when working TF trend fades

// ---- Trade Settings ----
input string _SECTION5 = "---- Trade Settings ----";
input double Inp_BaseLot = 0.01;                    // Base lot size
input int    Inp_MaxAdditionalTrades = 3;          // Maximum additional trades
input double Inp_LotMultiplier = 1.5;              // Lot multiplier
input bool   Inp_UseSoftClose = true;              // Use soft close (work TF reverse only)
input bool   Inp_UseTrailingStop = false;          // Use trailing stop
input double Inp_TrailingStopPoints = 50.0;        // Trailing stop in points
input double Inp_DefaultSLPoints = 50.0;           // Default SL in points
input double Inp_DefaultTPPoints = 100.0;          // Default TP in points

//---- Веса индикаторов (тюнинговые) ---------------------------------
input string _SECTION6 = "---- Indicators Weights (v3.0) ----";
input double Inp_Weight_RSI    = 0.48;  // RSI
input double Inp_Weight_ADX    = 0.86;  // ADX
input double Inp_Weight_ATR    = 0.87;  // ATR
input double Inp_Weight_OBV    = 0.83;  // OBV
input double Inp_Weight_STDDEV = 0.88;  // StdDev
//---------------------------------------------------------------
// Глобальные данные
//---------------------------------------------------------------
ConsensusVotes gWorkVotes;
ConsensusVotes gSeniorVotes;

ConsensusSet   gWorkSet;
ConsensusSet   gSeniorSet;

bool           gUseTimer   = false;   // true, если работаем через таймер
ENUM_TradeSignal gLastSignal = SIGNAL_NONE;

//---------------------------------------------------------------
// Инициализация
//---------------------------------------------------------------
int OnInit()
{
   Print("OnInit: initializing ConsensusEA...");

   PanelCreate(Inp_PanelX, Inp_PanelY, Inp_PanelW, Inp_PanelH, Inp_FontSize);
   
   gWeightRSI    = Inp_Weight_RSI;
   gWeightADX    = Inp_Weight_ADX;
   gWeightATR    = Inp_Weight_ATR;
   gWeightOBV    = Inp_Weight_OBV;
   gWeightSTDDEV = Inp_Weight_STDDEV;
   
   // Защита от идиота (если кто-то поставит нули)
   if(gWeightRSI    <= 0) gWeightRSI    = 0.01;
   if(gWeightADX    <= 0) gWeightADX    = 0.01;
   if(gWeightATR    <= 0) gWeightATR    = 0.01;
   if(gWeightOBV    <= 0) gWeightOBV    = 0.01;
   if(gWeightSTDDEV <= 0) gWeightSTDDEV = 0.01;
   
   // пробуем определить, идут ли живые тики
   datetime t0 = TimeCurrent();
   Sleep(1500);
   if(TimeCurrent() == t0)
   {
      EventSetTimer(1);
      gUseTimer = true;
      Print("🕒 No live ticks detected → TIMER mode enabled");
   }
   else
   {
      Print("📡 Live ticks detected → LIVE mode");
   }

   TradeInit();  // Инициализируем торговый модуль

   Print("✅ ConsensusEA initialized. WorkTF=", (int)Inp_WorkTF,
         " SeniorTF=", (int)Inp_SeniorTF,
         " Method=", (int)Inp_Method);
   return(INIT_SUCCEEDED);
}

//---------------------------------------------------------------
// Основной цикл анализа
//---------------------------------------------------------------
void OnTick()
{
   // 1. Анализ индикаторов по рабочему и старшему ТФ
   bool okWork   = ConsensusAnalyze(_Symbol, Inp_WorkTF,   gWorkVotes);
   bool okSenior = ConsensusAnalyze(_Symbol, Inp_SeniorTF, gSeniorVotes);

   if(!okWork || !okSenior)
      return;

   // 2. Переносим голоса и считаем консенсус
   gWorkVotes.ToConsensusSet(gWorkSet);
   ConsensusCompute(gWorkSet);
   
   gSeniorVotes.ToConsensusSet(gSeniorSet);
   ConsensusCompute(gSeniorSet);
   
   // 3. Комбинируем сигналы по выбранной методике
   ENUM_TradeSignal signal = CombineSignals(
      gWorkSet,
      gSeniorSet,
      Inp_Method,
      Inp_Threshold,
      Inp_AvoidTrendEnd
   );

   gLastSignal = signal;

   // 4. Управление торговлей
   TradeManage(signal);

   // 5. Обновляем панель — только при изменении сигнала или раз в 2 секунды
   static datetime lastPanelUpdate = 0;
   static ENUM_TradeSignal prevPanelSignal = SIGNAL_NONE;
   
   datetime now = TimeCurrent();
   bool needUpdate = false;
   
   // обновляем, если сменился сигнал или прошло >= 2 сек
   if(signal != prevPanelSignal || (now - lastPanelUpdate) >= 2)
   {
      needUpdate = true;
      prevPanelSignal = signal;
      lastPanelUpdate = now;
   }
   
   if(needUpdate)
   {
      PanelUpdate(gWorkSet, gSeniorSet);
      ChartRedraw(); // безопасно форсирует отрисовку
   }

   // 6. Вывод в лог — только при изменении сигнала и не чаще чем раз в 5 секунд
   static ENUM_TradeSignal prevSignal = SIGNAL_NONE;
   static datetime lastPrintTime = 0;
   
   string sigText = "NONE";
   if(signal == SIGNAL_BUY)  sigText = "BUY";
   if(signal == SIGNAL_SELL) sigText = "SELL";
   if(signal == SIGNAL_FLAT) sigText = "FLAT";
   
   // выводим, если сигнал изменился или прошло >=5 секунд
   if(signal != prevSignal || TimeCurrent() - lastPrintTime >= 5)
   {
      PrintFormat("Signal=%s | W.cons=%.2f(c%.2f) S.cons=%.2f(c%.2f) | "
            "W:RSI%.2f ADX%.2f ATR%.2f OBV%.2f STD%.2f",
            sigText,
            gWorkSet.consensus,  gWorkSet.confidence,
            gSeniorSet.consensus,gSeniorSet.confidence,
            gWeightRSI, gWeightADX, gWeightATR, gWeightOBV, gWeightSTDDEV);
     
      prevSignal    = signal;
      lastPrintTime = TimeCurrent();
   }
   
}

//---------------------------------------------------------------
// Таймер — используется только в оффлайн-режиме
//---------------------------------------------------------------
void OnTimer()
{
   if(gUseTimer)
      OnTick();
}

//---------------------------------------------------------------
// Деинициализация
//---------------------------------------------------------------
void OnDeinit(const int reason)
{
   Print("OnDeinit: cleaning up...");

   if(gUseTimer)
   {
      EventKillTimer();
      gUseTimer = false;
   }

   TradeDeinit();  // Очищаем торговый модуль, если нужно

   PanelDelete();
   ChartRedraw();

   Print("✅ ConsensusEA deinitialized, panel removed");
}