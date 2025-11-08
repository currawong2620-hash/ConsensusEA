//+------------------------------------------------------------------+
//| PanelConsensus.mqh — инфопанель консенсуса                      |
//| Отображает рабочий и старший ТФ, голоса и консенсус             |
//| Параметры позиции и размера задаются входными из EA             |
//+------------------------------------------------------------------+
#ifndef __PANEL_CONSENSUS_MQH__
#define __PANEL_CONSENSUS_MQH__
#property strict

#include "ConsensusCore.mqh"

//--------------------------------------------------------------
// Константы и имена объектов
//--------------------------------------------------------------
#define PANEL_NAME   "ConsensusPanel"
#define PANEL_COLOR  clrBlack
#define TEXT_COLOR   clrWhite

#define LBL_WORK_TITLE   "LblWorkTitle"
#define LBL_WORK_ADX     "LblWorkADX"
#define LBL_WORK_ATR     "LblWorkATR"
#define LBL_WORK_STD     "LblWorkSTD"
#define LBL_WORK_OBV     "LblWorkOBV"
#define LBL_WORK_OSC     "LblWorkOSC"
#define LBL_WORK_CONS    "LblWorkCons"

#define LBL_SEN_TITLE    "LblSenTitle"
#define LBL_SEN_ADX      "LblSenADX"
#define LBL_SEN_ATR      "LblSenATR"
#define LBL_SEN_STD      "LblSenSTD"
#define LBL_SEN_OBV      "LblSenOBV"
#define LBL_SEN_OSC      "LblSenOSC"
#define LBL_SEN_CONS     "LblSenCons"

//--------------------------------------------------------------
// Создание панели и надписей
//--------------------------------------------------------------
void PanelCreate(
   int panelX,
   int panelY,
   int panelW,
   int panelH,
   int fontSize,
   ENUM_BASE_CORNER corner = CORNER_LEFT_UPPER)
{
   // создаём фон
   if(ObjectFind(0, PANEL_NAME) < 0)
   {
      ObjectCreate(0, PANEL_NAME, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_CORNER,     corner);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_XDISTANCE,  panelX);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_YDISTANCE,  panelY);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_XSIZE,      panelW);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_YSIZE,      panelH);

      ObjectSetInteger(0, PANEL_NAME, OBJPROP_BGCOLOR,    PANEL_COLOR);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_COLOR,      PANEL_COLOR);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_STYLE,      STYLE_SOLID);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_WIDTH,      1);

      ObjectSetInteger(0, PANEL_NAME, OBJPROP_BACK,       false);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, PANEL_NAME, OBJPROP_HIDDEN,     true);
   }

   // макрос для создания надписей
   #define MAKE_LABEL(name,dx,dy)                                     \
      if(ObjectFind(0,name) < 0)                                      \
      {                                                               \
         ObjectCreate(0,name,OBJ_LABEL,0,0,0);                        \
         ObjectSetInteger(0,name,OBJPROP_CORNER,corner);              \
         ObjectSetInteger(0,name,OBJPROP_XDISTANCE,(dx));             \
         ObjectSetInteger(0,name,OBJPROP_YDISTANCE,(dy));             \
         ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSize);          \
         ObjectSetInteger(0,name,OBJPROP_COLOR,TEXT_COLOR);           \
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);           \
         ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);                \
      }

   int x0 = panelX + 8;
   int y0 = panelY + 6;

   // заголовки
   MAKE_LABEL(LBL_WORK_TITLE, x0,           y0);
   MAKE_LABEL(LBL_SEN_TITLE,  x0,           y0 + 56);

   // рабочий тренд — строки голосов
   MAKE_LABEL(LBL_WORK_ADX,   x0,           y0 + 14);
   MAKE_LABEL(LBL_WORK_ATR,   x0,           y0 + 24);
   MAKE_LABEL(LBL_WORK_STD,   x0,           y0 + 34);
   MAKE_LABEL(LBL_WORK_OBV,   x0+130,       y0 + 14);
   MAKE_LABEL(LBL_WORK_OSC,   x0+130,       y0 + 24);
   MAKE_LABEL(LBL_WORK_CONS,  x0+130,       y0 + 34);

   // старший тренд — строки голосов
   MAKE_LABEL(LBL_SEN_ADX,    x0,           y0 + 14 + 56);
   MAKE_LABEL(LBL_SEN_ATR,    x0,           y0 + 24 + 56);
   MAKE_LABEL(LBL_SEN_STD,    x0,           y0 + 34 + 56);
   MAKE_LABEL(LBL_SEN_OBV,    x0+130,       y0 + 14 + 56);
   MAKE_LABEL(LBL_SEN_OSC,    x0+130,       y0 + 24 + 56);
   MAKE_LABEL(LBL_SEN_CONS,   x0+130,       y0 + 34 + 56);

   #undef MAKE_LABEL

   ObjectSetString(0,LBL_WORK_TITLE,OBJPROP_TEXT,"Working TF");
   ObjectSetString(0,LBL_SEN_TITLE, OBJPROP_TEXT,"Senior TF");
   ChartRedraw();
}

//--------------------------------------------------------------
// Обновление значений на панели
//--------------------------------------------------------------
void PanelUpdate(const ConsensusSet &work,const ConsensusSet &senior)
{
   // рабочий
   ObjectSetString(0,LBL_WORK_ADX,  OBJPROP_TEXT,
                   StringFormat("ADX:   %+.2f",work.adx));
   ObjectSetString(0,LBL_WORK_ATR,  OBJPROP_TEXT,
                   StringFormat("ATR:   %+.2f",work.atr));
   ObjectSetString(0,LBL_WORK_STD,  OBJPROP_TEXT,
                   StringFormat("STD:   %+.2f",work.stddev));
   ObjectSetString(0,LBL_WORK_OBV,  OBJPROP_TEXT,
                   StringFormat("OBV:   %+.2f",work.obv));
   ObjectSetString(0,LBL_WORK_OSC,  OBJPROP_TEXT,
                   StringFormat("OSC:   %+.2f",work.rsi));
   ObjectSetString(0,LBL_WORK_CONS, OBJPROP_TEXT,
                   StringFormat("Cons:  %+.2f (%.2f)",work.consensus, work.confidence));

   // старший
   ObjectSetString(0,LBL_SEN_ADX,   OBJPROP_TEXT,
                   StringFormat("ADX:   %+.2f",senior.adx));
   ObjectSetString(0,LBL_SEN_ATR,   OBJPROP_TEXT,
                   StringFormat("ATR:   %+.2f",senior.atr));
   ObjectSetString(0,LBL_SEN_STD,   OBJPROP_TEXT,
                   StringFormat("STD:   %+.2f",senior.stddev));
   ObjectSetString(0,LBL_SEN_OBV,   OBJPROP_TEXT,
                   StringFormat("OBV:   %+.2f",senior.obv));
   ObjectSetString(0,LBL_SEN_OSC,   OBJPROP_TEXT,
                   StringFormat("OSC:   %+.2f",senior.rsi));
   ObjectSetString(0,LBL_SEN_CONS,  OBJPROP_TEXT,
                   StringFormat("Cons:  %+.2f (%.2f)",senior.consensus, senior.confidence));

   ChartRedraw();
}

//--------------------------------------------------------------
// Удаление панели
//--------------------------------------------------------------
void PanelDelete()
{
   string objs[] =
   {
      PANEL_NAME,
      LBL_WORK_TITLE,LBL_WORK_ADX,LBL_WORK_ATR,LBL_WORK_STD,
      LBL_WORK_OBV,LBL_WORK_OSC,LBL_WORK_CONS,
      LBL_SEN_TITLE,LBL_SEN_ADX,LBL_SEN_ATR,LBL_SEN_STD,
      LBL_SEN_OBV,LBL_SEN_OSC,LBL_SEN_CONS
   };

   for(int i=0;i<ArraySize(objs);i++)
   {
      if(ObjectFind(0,objs[i]) >= 0)
         ObjectDelete(0,objs[i]);
   }

   ChartRedraw();
}

#endif // __PANEL_CONSENSUS_MQH__
