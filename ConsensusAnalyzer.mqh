//+------------------------------------------------------------------+
//| ConsensusAnalyzer.mqh — анализ индикаторов по ТФ                 |
//| Формирует "голоса" и передает их в ConsensusCore                 |
//+------------------------------------------------------------------+
#property strict
#include "ConsensusCore.mqh"

//------------------------------------------------------------
//  Анализ индикаторов и формирование голосов
//------------------------------------------------------------
bool ConsensusAnalyze(const string sym, ENUM_TIMEFRAMES tf, ConsensusVotes &out)
{
   if(Bars(sym, tf) < 100)
      return false;

   double rsiBuf[3], adxBuf[3], atrBuf[3], obvBuf[3], stdBuf[3];

   int hRSI  = iRSI(sym, tf, 14, PRICE_CLOSE);
   int hADX  = iADX(sym, tf, 14);
   int hATR  = iATR(sym, tf, 14);
   int hOBV  = iOBV(sym, tf, VOLUME_TICK);
   int hSTD  = iStdDev(sym, tf, 20, 0, MODE_SMA, PRICE_CLOSE);

   if(hRSI < 0 || hADX < 0 || hATR < 0 || hOBV < 0 || hSTD < 0)
      return false;

   if(CopyBuffer(hRSI,0,0,2,rsiBuf) < 2 ||
      CopyBuffer(hADX,0,0,2,adxBuf) < 2 ||
      CopyBuffer(hATR,0,0,2,atrBuf) < 2 ||
      CopyBuffer(hOBV,0,0,2,obvBuf) < 2 ||
      CopyBuffer(hSTD,0,0,2,stdBuf) < 2)
   {
      IndicatorRelease(hRSI);
      IndicatorRelease(hADX);
      IndicatorRelease(hATR);
      IndicatorRelease(hOBV);
      IndicatorRelease(hSTD);
      return false;
   }

   double rsiNow=rsiBuf[0], rsiPrev=rsiBuf[1];
   double adxNow=adxBuf[0];
   double atrNow=atrBuf[0], atrPrev=atrBuf[1];
   double obvNow=obvBuf[0], obvPrev=obvBuf[1];
   double stdNow=stdBuf[0], stdPrev=stdBuf[1];

   out.rsiVote     = (rsiNow > 60 ? 1 : (rsiNow < 40 ? -1 : 0));
   out.adxVote     = (adxNow > 25 ? 1 : -1);
   out.atrVote     = (atrNow > atrPrev ? 1 : -1);
   out.obvVote     = (obvNow > obvPrev ? 1 : -1);
   out.stddevVote  = (stdNow > stdPrev ? 1 : -1);

   out.consensus = (out.rsiVote + out.adxVote + out.atrVote + out.obvVote + out.stddevVote) / 5.0;
   out.barTime   = iTime(sym, tf, 0);

   IndicatorRelease(hRSI);
   IndicatorRelease(hADX);
   IndicatorRelease(hATR);
   IndicatorRelease(hOBV);
   IndicatorRelease(hSTD);

   return true;
}

