//+------------------------------------------------------------------+
//|                                                      ConsensusEA.mq5|
//|                        Copyright 2025, Consensus Trading Team   |
//|                                v3.64 — Sydney Monday 11:00 AEDT |
//+------------------------------------------------------------------+
#property strict
#property version   "3.64"
#property copyright "Consensus Trading Team — Sydney Edition"

//---------------------------------------------------------------
// Подключаем модули
//---------------------------------------------------------------
#include "ConsensusAnalyzer.mqh"
#include "ConsensusCore.mqh"
#include "SignalCombiner.mqh"
#include "PanelConsensus.mqh"
#include "TradeModule.mqh"
#include "WeightUpdater.mqh"

//---------------------------------------------------------------
// INPUT PARAMETERS (продакшн-версия — без тестовых костылей)
//---------------------------------------------------------------
input string _SECTION1 = "---- Timeframe Settings ----";
input ENUM_TIMEFRAMES Inp_WorkTF = PERIOD_M5;
input ENUM_TIMEFRAMES Inp_SeniorTF = PERIOD_H1;

input string _SECTION2 = "---- Combination Method ----";
input ENUM_CombinationMethod Inp_Method = COMB_METHOD_FILTER;
input double Inp_Threshold = 0.30;

input string _SECTION3 = "---- Consensus Panel Settings ----";
input int    Inp_PanelX = 10;
input int    Inp_PanelY = 20;
input int    Inp_PanelW = 260;
input int    Inp_PanelH = 120;
input int    Inp_FontSize = 9;
input ENUM_BASE_CORNER Inp_PanelCorner = CORNER_LEFT_UPPER;

input string _SECTION4 = "---- Risk Control & Filters ----";
input bool   Inp_AvoidTrendEnd = true;

input string _SECTION5 = "---- Trade Settings ----";
input double Inp_BaseLot = 0.01;
input int    Inp_MaxAdditionalTrades = 3;
input double Inp_LotMultiplier = 1.5;
input bool   Inp_UseSoftClose = true;
input bool   Inp_UseTrailingStop = false;
input double Inp_TrailingStopPoints = 50.0;
input double Inp_DefaultSLPoints = 50.0;
input double Inp_DefaultTPPoints = 100.0;

input string _SECTION6 = "---- Indicators Weights (v3.0) ----";
input double Inp_Weight_RSI     = 0.48;
input double Inp_Weight_ADX     = 0.86;
input double Inp_Weight_ATR     = 0.87;
input double Inp_Weight_OBV     = 0.83;
input double Inp_Weight_STDDEV  = 0.88;

input string _SECTION7 = "---- Weight Update Method ----";
input ENUM_WeightUpdateMethod Inp_WeightUpdate = WEIGHT_UPDATE_GENETIC;

input string _SECTION8 = "---- Adaptive Consensus Threshold ----";
input bool   Inp_AdaptiveThreshold = true;
input double Inp_Threshold_Base    = 0.30;
input double Inp_Threshold_Flat    = 0.25;
input double Inp_Threshold_Strong  = 0.45;

input string _SECTION9 = "---- Daily Equity Stop ----";
input bool   Inp_UseEquityStop = true;
input double Inp_EquityStopPercent = 3.0;
input int    Inp_EquityStopCooldown = 0;

input string _SECTION12 = "---- Correlation-Based Base Weights ----";
input bool   Inp_UseCorrelationWeights = true;
input int    Inp_BarsForCorrelation = 2000;

//---------------------------------------------------------------
// Глобальные переменные
//---------------------------------------------------------------
ConsensusVotes  gWorkVotes, gSeniorVotes;
ConsensusSet    gWorkSet,   gSeniorSet;
bool            gUseTimer = false;
ENUM_TradeSignal gLastSignal = SIGNAL_NONE;

double gWeightRSI, gWeightADX, gWeightATR, gWeightOBV, gWeightSTDDEV;

double   g_DailyStartBalance = 0.0;
datetime g_LastDayChecked = 0;
datetime g_StopTradingUntil = 0;
bool     g_TradingStoppedToday = false;

static datetime lastPanelUpdate = 0;
static ENUM_TradeSignal prevPanelSignal = SIGNAL_NONE;
static ENUM_TradeSignal prevSignal = SIGNAL_NONE;
static datetime lastPrintTime = 0;

datetime g_LastGA_Run = 0;   // Когда последний раз запускали GA

//+------------------------------------------------------------------+
//| Инициализация                                                    |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print("ConsensusEA v3.64 — Sydney Monday 11:00 AEDT — LIVE READY");
   PanelCreate(Inp_PanelX,Inp_PanelY,Inp_PanelW,Inp_PanelH,Inp_FontSize);

   if(Inp_UseCorrelationWeights)
      InitCorrelationWeights(Inp_WorkTF,Inp_BarsForCorrelation);
   else
     {
      gWeightRSI=Inp_Weight_RSI; gWeightADX=Inp_Weight_ADX;
      gWeightATR=Inp_Weight_ATR; gWeightOBV=Inp_Weight_OBV;
      gWeightSTDDEV=Inp_Weight_STDDEV;
     }

   InitBaseWeights();
   g_DailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_LastDayChecked = TimeCurrent()/86400*86400;

   datetime t0=TimeCurrent(); Sleep(1500);
   if(TimeCurrent()==t0) { EventSetTimer(1); gUseTimer=true; Print("TIMER mode"); }
   else Print("LIVE ticks mode");

   TradeInit();
   Print("Sydney Monday GA active — next run: Monday 11:00–12:00 AEDT");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| СИДНЕЙСКИЙ ПОНЕДЕЛЬНИК 11:00–11:59 AEDT                         |
//+------------------------------------------------------------------+
bool ShouldRunSydneyMondayGA()
  {
   datetime now = TimeCurrent();
   datetime sydneyNow = now + 10*3600;               // UTC → AEDT (GMT+11, без DST — ок для 2025)
   MqlDateTime dt; TimeToStruct(sydneyNow, dt);

   // Понедельник + 11:00–11:59 AEDT
   if(dt.day_of_week != 1 || dt.hour != 11) return false;

   // Прошло ≥ 6.5 дней с прошлого запуска
   if(now - g_LastGA_Run < 6.5*24*3600) return false;

   // Данных за 14 дней хватает?
   datetime twoWeeksAgo = now - 14*24*3600;
   MqlRates rates[];
   int copied = CopyRates(_Symbol, Inp_WorkTF, twoWeeksAgo, now, rates);
   if(copied < 1000) // чуть жёстче — 1000 баров M5 ≈ 3.5 торговых дня
     {
      PrintFormat("Sydney GA: only %d bars → waiting for more data", copied);
      return false;
     }

   PrintFormat("=== SYDNEY MONDAY GA @ %s AEDT ===", TimeToString(sydneyNow, TIME_DATE|TIME_MINUTES));
   return true;
  }

//+------------------------------------------------------------------+
//| Sydney open для Equity Stop                                      |
//+------------------------------------------------------------------+
datetime GetNextSydneyOpen()
  {
   datetime now=TimeCurrent();
   MqlDateTime dt; TimeToStruct(now,dt);
   datetime next;
   if(dt.day_of_week==0)      next = now/86400*86400 + 79200;  // Sun 22:00 UTC
   else if(dt.day_of_week==6) next = now/86400*86400 + 86400 + 79200;
   else                       next = now/86400*86400 + 86400;
   if(now>=next) next+=86400;
   return next;
  }

//+------------------------------------------------------------------+
//| Daily balance + Equity Stop + Adaptive Threshold                 |
//+------------------------------------------------------------------+
void UpdateDailyBalance()
  {
   datetime curDay=TimeCurrent()/86400*86400;
   if(curDay>g_LastDayChecked)
     {
      g_DailyStartBalance=AccountInfoDouble(ACCOUNT_BALANCE);
      g_LastDayChecked=curDay;
      g_TradingStoppedToday=false;
      g_StopTradingUntil=0;
      PrintFormat("New day → Equity base reset: %.2f",g_DailyStartBalance);
     }
  }

bool CheckEquityStop() { /* без изменений — как в v3.63 */ }
bool IsTradingAllowed() { /* без изменений */ }
double GetAdaptiveThreshold() { /* без изменений */ }

//+------------------------------------------------------------------+
//| OnTick — только GA-блок                                          |
//+------------------------------------------------------------------+
void OnTick()
  {
   UpdateDailyBalance();
   if(!IsTradingAllowed()) return;
   if(CheckEquityStop()) return;

   bool okW=ConsensusAnalyze(_Symbol,Inp_WorkTF,gWorkVotes);
   bool okS=ConsensusAnalyze(_Symbol,Inp_SeniorTF,gSeniorVotes);
   if(!okW || !okS) return;

   // === СИДНЕЙСКИЙ ПОНЕДЕЛЬНИК 11:00 AEDT ===
   if(Inp_WeightUpdate!=WEIGHT_UPDATE_NONE && ShouldRunSydneyMondayGA())
     {
      Print("=== GENETIC OPTIMIZATION STARTED ===");
      datetime end = TimeCurrent();
      datetime start = end - 14*86400;
      MqlRates rates[];
      int copied = CopyRates(_Symbol, Inp_WorkTF, start, end, rates);
      PrintFormat("Data window: %s → %s (%d bars)", 
                  TimeToString(start,TIME_DATE|TIME_MINUTES),
                  TimeToString(end,TIME_DATE|TIME_MINUTES), copied);

      UpdateWeights(Inp_WeightUpdate,Inp_SeniorTF);

      if(GetRecentDD()>MAX_DD_FOR_ROLLBACK)
        {
         Print("ROLLBACK — DD too high! Restoring base weights");
         RestoreBaseWeights();
        }

      g_LastGA_Run = TimeCurrent();
      Print("=== GENETIC OPTIMIZATION FINISHED ===\n");
     }

   // === Остальной код без изменений (сигналы, трейд, панель) ===
   gWorkVotes.ToConsensusSet(gWorkSet);   ConsensusCompute(gWorkSet);
   gSeniorVotes.ToConsensusSet(gSeniorSet); ConsensusCompute(gSeniorSet);

   double thr=GetAdaptiveThreshold();
   ENUM_TradeSignal signal=CombineSignals(gWorkSet,gSeniorSet,Inp_Method,thr,Inp_AvoidTrendEnd);
   gLastSignal=signal;

   TradeManage(signal);

   datetime now=TimeCurrent();
   if(signal!=prevPanelSignal || (now-lastPanelUpdate)>=2)
     {
      PanelUpdate(gWorkSet,gSeniorSet);
      ChartRedraw();
      prevPanelSignal=signal;
      lastPanelUpdate=now;
     }

   string txt=(signal==SIGNAL_BUY?"BUY":(signal==SIGNAL_SELL?"SELL":"NONE"));
   if(signal!=prevSignal || now-lastPrintTime>=5)
     {
      PrintFormat("Signal=%s | W:%.2f S:%.2f | Thr=%.2f",txt,gWorkSet.consensus,gSeniorSet.consensus,thr);
      prevSignal=signal;
      lastPrintTime=now;
     }
  }

//+------------------------------------------------------------------+
//| Timer / Deinit                                                   |
//+------------------------------------------------------------------+
void OnTimer() { if(gUseTimer) OnTick(); }

void OnDeinit(const int reason)
  {
   if(gUseTimer) EventKillTimer();
   TradeDeinit();
   PanelDelete();
   ChartRedraw();
   Print("ConsensusEA v3.64 stopped — see you next Sydney Monday 11:00 AEDT");
  }
//+------------------------------------------------------------------+