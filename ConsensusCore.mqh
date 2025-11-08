//+------------------------------------------------------------------+
//| ConsensusCore.mqh — ядро консенсус-советника                     |
//| Используется всеми модулями: Analyzer, Combiner, Panel           |
//| Включает базовые структуры, функции консенсуса и весовые факторы |
//+------------------------------------------------------------------+
#property strict

//==============================================================
//  ENUM: торговые сигналы и методы комбинирования
//==============================================================
enum ENUM_TradeSignal
{
   SIGNAL_NONE = 0,
   SIGNAL_BUY,
   SIGNAL_SELL,
   SIGNAL_FLAT
};

enum ENUM_CombinationMethod
{
   COMB_METHOD_FILTER = 0,   // рабочий ТФ фильтруется старшим
   COMB_METHOD_WEIGHTED,     // взвешенная комбинация
   COMB_METHOD_CONFIRM,      // вход только при совпадении направлений
   COMB_METHOD_CONTRAST      // при расхождении — контртренд
};

//==============================================================
//  Структуры данных
//==============================================================
struct ConsensusSet
{
   double rsi;
   double adx;
   double atr;
   double obv;
   double stddev;

   double consensus;   // нормализованный общий сигнал
   double confidence;  // усреднённая уверенность (|голоса|)
   datetime barTime;
};

//==============================================================
//  Построение структуры ConsensusSet из "сырых" голосов
//==============================================================
ConsensusSet BuildConsensusSet(double rsi,double adx,double atr,double obv,double stddev)
{
   ConsensusSet set;
   set.rsi = rsi;
   set.adx = adx;
   set.atr = atr;
   set.obv = obv;
   set.stddev = stddev;
   set.consensus = 0;
   set.confidence = 0;
   set.barTime = 0;
   return set;
}

// Глобальные веса (с дефолтными значениями, перезаписываются в EA)
double gWeightRSI    = 0.48;
double gWeightADX    = 0.86;
double gWeightATR    = 0.87;
double gWeightOBV    = 0.83;
double gWeightSTDDEV = 0.88;

//==============================================================
//  Расчёт консенсуса с использованием весов
//==============================================================
void ConsensusCompute(ConsensusSet &set)
{
   double v[5] = {set.rsi, set.adx, set.atr, set.obv, set.stddev};
   double w[5] = {gWeightRSI, gWeightADX, gWeightATR, gWeightOBV, gWeightSTDDEV};
   
   double weighted_sum = 0.0;
   double total_weight = 0.0;
   
   for(int i = 0; i < 5; i++)
   {
      weighted_sum += v[i] * w[i];
      total_weight += w[i];
   }
   
   double mean = total_weight > 0 ? weighted_sum / total_weight : 0.0;
   
   // Взвешенная дисперсия
   double var = 0.0;
   for(int i = 0; i < 5; i++)
      var += w[i] * MathPow(v[i] - mean, 2);
   var = total_weight > 0 ? var / total_weight : 0.0;
   
   double disp = MathSqrt(var);
   
   set.consensus  = mean;
   set.confidence = 1.0 - disp;
   
   if(set.confidence < 0.0) set.confidence = 0.0;
   if(set.confidence > 1.0) set.confidence = 1.0;
}


//==============================================================
//  Конвертация из структуры голосов (если используется Analyzer)
//==============================================================
struct ConsensusVotes
{
   double rsiVote, adxVote, atrVote, obvVote, stddevVote;
   double consensus;
   datetime barTime;

   void ToConsensusSet(ConsensusSet &dst) const
   {
      dst = BuildConsensusSet(rsiVote, adxVote, atrVote, obvVote, stddevVote);
   }
};