//+------------------------------------------------------------------+
//| ConsensusCore.mqh — ядро консенсус-советника                     |
//| Используется всеми модулями: Analyzer, Combiner, Panel           |
//| Включает базовые структуры, функции консенсуса и весовые факторы |
//+------------------------------------------------------------------+
#property strict

// Глобальные веса (extern на топ-левеле для правильной декларации)
extern double gWeightRSI;
extern double gWeightADX;
extern double gWeightATR;
extern double gWeightOBV;
extern double gWeightSTDDEV;

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

//==============================================================
//  Расчёт консенсуса с использованием весов (extern убраны из функции)
//==============================================================
void ConsensusCompute(ConsensusSet &set)
{
   // 5 голосов: мы трактуем rsi/adx/atr/obv/stddev как уже нормализованные (-1..+1)
   double v[5];
   v[0] = set.rsi;
   v[1] = set.adx;
   v[2] = set.atr;
   v[3] = set.obv;
   v[4] = set.stddev;

   double weights[5] = {gWeightRSI, gWeightADX, gWeightATR, gWeightOBV, gWeightSTDDEV};
   double totalWeight = 0.0;
   for(int i = 0; i < 5; i++) totalWeight += weights[i];

   // Weighted mean (consensus)
   double weightedMean = 0.0;
   for(int i = 0; i < 5; i++)
      weightedMean += v[i] * weights[i];
   weightedMean /= totalWeight;

   // Weighted variance
   double weightedVar = 0.0;
   for(int i = 0; i < 5; i++)
      weightedVar += weights[i] * MathPow(v[i] - weightedMean, 2);
   weightedVar /= totalWeight;

   double disp = MathSqrt(weightedVar);

   set.consensus  = weightedMean;          // [-1..+1]
   set.confidence = 1.0 - disp;    // 1 → полное согласие, 0 → полный раздрай

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