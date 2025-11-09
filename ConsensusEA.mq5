//+------------------------------------------------------------------+
//| ConsensusEA.mq5 — основной файл консенсус-советника             |
//| Связка: Analyzer → Core → Combiner → Panel + Trade Module        |
//+------------------------------------------------------------------+
#property strict
#property version   "3.15"  // Бампнул для Sydney cooldown
#property copyright "Consensus"

//---------------------------------------------------------------
// Подключаем модули
//---------------------------------------------------------------
#include "ConsensusAnalyzer.mqh"
#include "ConsensusCore.mqh"
#include "SignalCombiner.mqh"
#include "PanelConsensus.mqh"
#include "TradeModule.mqh" // Новый торговый модуль
#include "WeightUpdater.mqh" // Новый модуль обновления весов (v3.1+)

//---------------------------------------------------------------
// INPUT PARAMETERS
//---------------------------------------------------------------
// ---- Timeframe Settings ----
input string _SECTION1 = "---- Timeframe Settings ----";
input ENUM_TIMEFRAMES Inp_WorkTF = PERIOD_M5; // Working timeframe
input ENUM_TIMEFRAMES Inp_SeniorTF = PERIOD_H1; // Senior timeframe
// ---- Combination Method ----
input string _SECTION2 = "---- Combination Method ----";
input ENUM_CombinationMethod Inp_Method = COMB_METHOD_FILTER; // Combination method
input double Inp_Threshold = 0.30; // Consensus threshold
// ---- Consensus Panel Settings ----
input string _SECTION3 = "---- Consensus Panel Settings ----";
input int Inp_PanelX = 10; // Panel X offset (pixels)
input int Inp_PanelY = 20; // Panel Y offset (pixels)
input int Inp_PanelW = 260; // Panel width (pixels)
input int Inp_PanelH = 120; // Panel height (pixels)
input int Inp_FontSize = 9; // Font size (points)
input ENUM_BASE_CORNER Inp_PanelCorner = CORNER_LEFT_UPPER; // Panel corner
// ---- Risk Control & Filters ----
input string _SECTION4 = "---- Risk Control & Filters ----";
input bool Inp_AvoidTrendEnd = true; // Avoid entries when working TF trend fades
// ---- Trade Settings ----
input string _SECTION5 = "---- Trade Settings ----";
input double Inp_BaseLot = 0.01; // Base lot size
input int Inp_MaxAdditionalTrades = 3; // Maximum additional trades
input double Inp_LotMultiplier = 1.5; // Lot multiplier
input bool Inp_UseSoftClose = true; // Use soft close (work TF reverse only)
input bool Inp_UseTrailingStop = false; // Use trailing stop
input double Inp_TrailingStopPoints = 50.0; // Trailing stop in points
input double Inp_DefaultSLPoints = 50.0; // Default SL in points
input double Inp_DefaultTPPoints = 100.0; // Default TP in points
//---- Веса индикаторов (тюнинговые) ---------------------------------
input string _SECTION6 = "---- Indicators Weights (v3.0) ----";
input double Inp_Weight_RSI = 0.48; // RSI
input double Inp_Weight_ADX = 0.86; // ADX
input double Inp_Weight_ATR = 0.87; // ATR
input double Inp_Weight_OBV = 0.83; // OBV
input double Inp_Weight_STDDEV = 0.88; // StdDev
//---- Метод обновления весов (v3.1+) --------------------------------
input string _SECTION7 = "---- Weight Update Method (v3.1+) ----";
input ENUM_WeightUpdateMethod Inp_WeightUpdate = WEIGHT_UPDATE_NONE; // Weight update method
// ---- Adaptive Consensus Threshold ----
input string _SECTION8 = "---- Adaptive Consensus Threshold ----";
input bool   Inp_AdaptiveThreshold    = true;     // Включить адаптивный порог
input double Inp_Threshold_Base       = 0.30;     // Базовый порог
input double Inp_Threshold_Flat       = 0.25;     // Во флэте (ADX < 15)
input double Inp_Threshold_Strong     = 0.45;     // В сильном тренде (ADX > 25)
// ---- Daily Equity Stop ----
input string _SECTION9 = "---- Daily Equity Stop ----";
input bool   Inp_UseEquityStop        = true;     // Включить защиту по equity
input double Inp_EquityStopPercent    = 3.0;      // % от вчерашнего закрытия → стоп на день
input int    Inp_EquityStopCooldown   = 0;        // Минут до следующей торговли (0 = до Sydney open)

//---------------------------------------------------------------
// Глобальные данные
//---------------------------------------------------------------
ConsensusVotes gWorkVotes;
ConsensusVotes gSeniorVotes;
ConsensusSet   gWorkSet;
ConsensusSet   gSeniorSet;
bool           gUseTimer   = false; // true, если работаем через таймер
ENUM_TradeSignal gLastSignal = SIGNAL_NONE;

// Глобальные веса (mutable для динамики)
double gWeightRSI;
double gWeightADX;
double gWeightATR;
double gWeightOBV;
double gWeightSTDDEV;

// --- Глобальные для Equity Stop ---
double g_DailyStartBalance = 0.0;
datetime g_LastDayChecked = 0;
datetime g_StopTradingUntil = 0;
bool g_TradingStoppedToday = false;

// --- Для панели (статические, как раньше) ---
static datetime lastPanelUpdate = 0;
static ENUM_TradeSignal prevPanelSignal = SIGNAL_NONE;

// --- Для лога ---
static ENUM_TradeSignal prevSignal = SIGNAL_NONE;
static datetime lastPrintTime = 0;

//---------------------------------------------------------------
// Инициализация
//---------------------------------------------------------------
int OnInit()
{
   Print("OnInit: initializing ConsensusEA v3.1.5 — Sydney Cooldown Mode, because if cooldown=0, let's wait for kangaroos to wake up.");

   PanelCreate(Inp_PanelX, Inp_PanelY, Inp_PanelW, Inp_PanelH, Inp_FontSize);
  
   gWeightRSI = Inp_Weight_RSI;
   gWeightADX = Inp_Weight_ADX;
   gWeightATR = Inp_Weight_ATR;
   gWeightOBV = Inp_Weight_OBV;
   gWeightSTDDEV = Inp_Weight_STDDEV;
  
   // Защита от идиота (если кто-то поставит нули)
   if(gWeightRSI <= 0) gWeightRSI = 0.01;
   if(gWeightADX <= 0) gWeightADX = 0.01;
   if(gWeightATR <= 0) gWeightATR = 0.01;
   if(gWeightOBV <= 0) gWeightOBV = 0.01;
   if(gWeightSTDDEV <= 0) gWeightSTDDEV = 0.01;
  
   // --- Equity Stop: старт с текущего баланса ---
   g_DailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_LastDayChecked = TimeCurrent() / 86400 * 86400;  // Начало текущего дня
   g_TradingStoppedToday = false;
   g_StopTradingUntil = 0;
  
   PrintFormat("Initial Daily Balance (yesterday's close): %.2f | Equity Stop: %.1f%% → %.2f", 
               g_DailyStartBalance, Inp_EquityStopPercent, 
               g_DailyStartBalance * (1.0 - Inp_EquityStopPercent/100.0));
  
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
   TradeInit(); // Инициализируем торговый модуль
   Print("✅ ConsensusEA initialized. WorkTF=", (int)Inp_WorkTF,
         " SeniorTF=", (int)Inp_SeniorTF,
         " Method=", (int)Inp_Method,
         " WeightUpdate=", (int)Inp_WeightUpdate);
   return(INIT_SUCCEEDED);
}

//---------------------------------------------------------------
// Рассчитать время до Sydney open (для cooldown=0)
//---------------------------------------------------------------
datetime GetNextSydneyOpen()
{
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int dayOfWeek = dt.day_of_week;  // 0=Sunday, 1=Monday, ..., 6=Saturday
  
   datetime nextOpen;
  
   if(dayOfWeek == 0) // Воскресенье — ждём 22:00 UTC (Sydney open)
   {
      nextOpen = now / 86400 * 86400 + 79200;  // 22:00 = 22*3600
      if(now >= nextOpen) nextOpen += 86400;  // Если уже прошло, следующий день
   }
   else if(dayOfWeek == 6) // Суббота — ждём воскресенье 22:00
   {
      nextOpen = now / 86400 * 86400 + 86400 + 79200;
   }
   else // Будни — следующий день 00:00 (Sydney уже open, но для consistency ждём следующего дня)
   {
      nextOpen = now / 86400 * 86400 + 86400;  // Следующий день 00:00
   }
   PrintFormat("Next Sydney Open: %s", TimeToString(nextOpen, TIME_DATE|TIME_MINUTES));
   return nextOpen;
}

//---------------------------------------------------------------
// Обновить daily balance на новый день
//---------------------------------------------------------------
void UpdateDailyBalance()
{
   datetime currentDay = TimeCurrent() / 86400 * 86400;  // Начало текущего дня
   if(currentDay > g_LastDayChecked)
   {
      g_DailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_LastDayChecked = currentDay;
      g_TradingStoppedToday = false;
      g_StopTradingUntil = 0;
      PrintFormat("New Day! Reset Equity Base to Yesterday's Close: %.2f", g_DailyStartBalance);
   }
}

//---------------------------------------------------------------
// Проверка Equity Stop
//---------------------------------------------------------------
bool CheckEquityStop()
{
   if(!Inp_UseEquityStop || g_TradingStoppedToday) return false;
  
   double current = AccountInfoDouble(ACCOUNT_EQUITY);
   double limit   = g_DailyStartBalance * (1.0 - Inp_EquityStopPercent / 100.0);
  
   if(current <= limit)
   {
      PrintFormat("EQUITY STOP TRIGGERED! %.2f < %.2f (%.1f%% loss from yesterday's close)", 
                  current, limit, Inp_EquityStopPercent);
  
      TradeCloseAll("EQUITY_STOP");
      g_TradingStoppedToday = true;
      
      if(Inp_EquityStopCooldown == 0)
         g_StopTradingUntil = GetNextSydneyOpen();
      else
         g_StopTradingUntil = TimeCurrent() + Inp_EquityStopCooldown * 60;
  
      Comment("TRADING STOPPED: Equity drawdown > ", 
              DoubleToString(Inp_EquityStopPercent,1), "% from yesterday\n",
              "Resume: ", TimeToString(g_StopTradingUntil, TIME_DATE|TIME_MINUTES));
      return true;
   }
   return false;
}

//---------------------------------------------------------------
// Разрешение на торговлю
//---------------------------------------------------------------
bool IsTradingAllowed()
{
   if(g_TradingStoppedToday && TimeCurrent() < g_StopTradingUntil)
      return false;
   if(g_TradingStoppedToday && TimeCurrent() >= g_StopTradingUntil)
   {
      g_TradingStoppedToday = false;
      Print("Equity Stop lifted. Trading resumed — market problems? What problems?");
      Comment("");
   }
   return true;
}

//---------------------------------------------------------------
// Получить текущий порог консенсуса (адаптивный)
//---------------------------------------------------------------
double GetAdaptiveThreshold()
{
   if(!Inp_AdaptiveThreshold) return Inp_Threshold;
  
   int hADX = iADX(_Symbol, Inp_SeniorTF, 14);
   if(hADX < 0) return Inp_Threshold;
  
   double adxBuf[1];
   if(CopyBuffer(hADX, 0, 0, 1, adxBuf) < 1)
   {
      IndicatorRelease(hADX);
      return Inp_Threshold;
   }
   double adxValue = adxBuf[0];
   IndicatorRelease(hADX);
  
   if(adxValue < 15) return Inp_Threshold_Flat;
   if(adxValue > 25) return Inp_Threshold_Strong;
   return Inp_Threshold_Base;
}

//---------------------------------------------------------------
// Основной цикл анализа
//---------------------------------------------------------------
void OnTick()
{
   UpdateDailyBalance();  // Обновляем базу от вчерашнего закрытия
  
   if(!IsTradingAllowed()) return;
   if(CheckEquityStop()) return;
  
   // 1. Анализ индикаторов по рабочему и старшему ТФ
   bool okWork = ConsensusAnalyze(_Symbol, Inp_WorkTF, gWorkVotes);
   bool okSenior = ConsensusAnalyze(_Symbol, Inp_SeniorTF, gSeniorVotes);
   if(!okWork || !okSenior)
      return;
   // 2. Переносим голоса и считаем консенсус
   gWorkVotes.ToConsensusSet(gWorkSet);
   ConsensusCompute(gWorkSet);
  
   gSeniorVotes.ToConsensusSet(gSeniorSet);
   ConsensusCompute(gSeniorSet);
  
   // 3. Комбинируем сигналы по выбранной методике с адаптивным порогом
   double adaptiveThreshold = GetAdaptiveThreshold();
   ENUM_TradeSignal signal = CombineSignals(
      gWorkSet,
      gSeniorSet,
      Inp_Method,
      adaptiveThreshold,
      Inp_AvoidTrendEnd
   );
   gLastSignal = signal;
   // 4. Управление торговлей
   TradeManage(signal);
   // 5. Обновляем панель — только при изменении сигнала или раз в 2 секунды
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
  
   string sigText = "NONE";
   if(signal == SIGNAL_BUY) sigText = "BUY";
   if(signal == SIGNAL_SELL) sigText = "SELL";
   if(signal == SIGNAL_FLAT) sigText = "FLAT";
  
   // выводим, если сигнал изменился или прошло >=5 секунд
   if(signal != prevSignal || TimeCurrent() - lastPrintTime >= 5)
   {
      PrintFormat("Signal=%s | W.cons=%.2f (%.2f) | S.cons=%.2f (%.2f) | TFs: %d/%d",
         sigText,
         gWorkSet.consensus,  gWorkSet.confidence,
         gSeniorSet.consensus,gSeniorSet.confidence,
         (int)Inp_WorkTF, (int)Inp_SeniorTF);
  
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
   TradeDeinit(); // Очищаем торговый модуль, если нужно
   PanelDelete();
   ChartRedraw();
   Print("✅ ConsensusEA deinitialized, panel removed");
}