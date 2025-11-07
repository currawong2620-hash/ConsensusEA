//+------------------------------------------------------------------+
//| SignalCombiner.mqh — объединение сигналов по ТФ                  |
//| Использует ConsensusSet с двух ТФ и выдаёт ENUM_TradeSignal       |
//+------------------------------------------------------------------+
#property strict
#include "ConsensusCore.mqh"

// Возвращает знак числа: -1, 0, +1
int MathSign(double v)
{
   if(v > 0) return 1;
   if(v < 0) return -1;
   return 0;
}

//------------------------------------------------------------
//  Комбинирует сигналы с рабочего и старшего ТФ
//------------------------------------------------------------
ENUM_TradeSignal CombineSignals(
   const ConsensusSet &work,
   const ConsensusSet &senior,
   ENUM_CombinationMethod method,
   double threshold,
   bool avoidTrendEnd)
{
   ENUM_TradeSignal signal = SIGNAL_NONE;

   switch(method)
   {
      // ======================================================
      //  1. Фильтр: рабочий сигнал проходит только при подтверждении старшего
      // ======================================================
      case COMB_METHOD_FILTER:
      {
         if(MathAbs(work.consensus) < threshold)
            return SIGNAL_FLAT;

         if(work.consensus > 0 && senior.consensus > 0)
            signal = SIGNAL_BUY;
         else if(work.consensus < 0 && senior.consensus < 0)
            signal = SIGNAL_SELL;
         else
            signal = SIGNAL_FLAT;
         break;
      }

      // ======================================================
      //  2. Взвешенная комбинация (для будущего расширения)
      // ======================================================
      case COMB_METHOD_WEIGHTED:
      {
         double combined = 0.7 * work.consensus + 0.3 * senior.consensus;
         if(MathAbs(combined) < threshold)
            signal = SIGNAL_FLAT;
         else if(combined > 0)
            signal = SIGNAL_BUY;
         else
            signal = SIGNAL_SELL;
         break;
      }

      // ======================================================
      //  3. Подтверждение (оба направлены одинаково)
      // ======================================================
      case COMB_METHOD_CONFIRM:
      {
         if(MathSign(work.consensus) == MathSign(senior.consensus))
            signal = (work.consensus > 0 ? SIGNAL_BUY : SIGNAL_SELL);
         else
            signal = SIGNAL_FLAT;
         break;
      }

      // ======================================================
      //  4. Контраст (используется в контртрендовых стратегиях)
      // ======================================================
      case COMB_METHOD_CONTRAST:
      {
         if(MathSign(work.consensus) != MathSign(senior.consensus))
            signal = (work.consensus > 0 ? SIGNAL_BUY : SIGNAL_SELL);
         else
            signal = SIGNAL_FLAT;
         break;
      }
   }

   // --- Фильтр "AvoidTrendEnd" (опционально)
   if(avoidTrendEnd)
   {
      if(MathAbs(work.consensus) < 0.15 && signal != SIGNAL_FLAT)
         signal = SIGNAL_FLAT;
   }

   return signal;
}
