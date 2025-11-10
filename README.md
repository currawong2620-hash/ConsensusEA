# ConsensusEA v3.54 — Sydney Monday Edition  
**Автоматическая генетическая оптимизация весов каждое утро понедельника в 11:00 AEDT**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![MQL5](https://img.shields.io/badge/MQL5-5.00%2B-blue)](https://www.mql5.com)
[![Platform: MT5](https://img.shields.io/badge/Platform-MetaTrader%205-orange)](https://www.metatrader5.com)
[![Sydney Time](https://img.shields.io/badge/Sydney%20Time-11%3A00%20AEDT-brightgreen)](https://time.is/Sydney)

> **Торгует XAUUSD M5**  
> **Оптимизирует веса 5 индикаторов (RSI, ADX, ATR, OBV, StdDev)**  
> **Запускает GA ровно раз в неделю — понедельник 11:00–11:59 AEDT (01:00–01:59 UTC)**  
> **Полностью автономный, zero-config после установки**

**Текущее время в Сиднее:** `2025-11-10 21:24 AEDT` — до следующего запуска осталось **~13 часов 36 минут**  
Следующий Sydney Monday GA: **17 ноября 2025, 11:00 AEDT**

---

### Почему это работает именно в Австралии лучше всех?

- **11:00 AEDT** = начало новой торговой недели  
- **Низкая волатильность** → минимальный slippage при ребалансе  
- **Ты пьёшь кофе, а EA уже эволюционировал**  

---

## Структура проекта (GitHub-ready)
ConsensusEA/
├── Experts/
│   └── ConsensusTrade/
│       └── ConsensusEA.mq5          ← Главный файл (v3.54)
├── Include/
│   ├── ConsensusAnalyzer.mqh        ← Анализ индикаторов (RSI, ADX, ATR, OBV, StdDev)
│   ├── ConsensusCore.mqh            ← Голосование и консенсус
│   ├── SignalCombiner.mqh           ← Комбинирование сигналов (FILTER/WEIGHTED)
│   ├── PanelConsensus.mqh           ← Панель на графике
│   ├── TradeModule.mqh              ← Управление ордерами (лот, SL/TP, soft-close)
│   └── WeightUpdater.mqh            ← Все режимы обновления весов (GENETIC, PERFORMANCE, etc.)
├── README.md                        ← Этот файл
├── LICENSE                          ← MIT
└── .gitignore

### Обязательные файлы (все должны быть в репозитории)

| Файл | Назначение | Критично |
|------|-----------|---------|
| `ConsensusEA.mq5` | Основной эксперт | Yes |
| `WeightUpdater.mqh` | Генетический алгоритм + все режимы | Yes |
| `TradeModule.mqh` | Торговля, лот-менеджмент | Yes |
| `ConsensusAnalyzer.mqh` | Расчёт 5 индикаторов | Yes |
| `SignalCombiner.mqh` | FILTER vs WEIGHTED | Yes |
| `PanelConsensus.mqh` | Панель | Yes |
| `ConsensusCore.mqh` | Голоса → консенсус | Yes |

> **Если хоть один .mqh пропал — EA не скомпилируется**

---

## Режимы обновления весов (полное описание)

```mql5
enum ENUM_WeightUpdateMethod
{
   WEIGHT_UPDATE_NONE = 0,       // Статичные веса из inputs
   WEIGHT_UPDATE_RULE_BASED = 1, // Правила (ADX ↑ → +вес ADX)
   WEIGHT_UPDATE_PERFORMANCE = 2,// EMA прибыли по индикаторам
   WEIGHT_UPDATE_GENETIC = 3,    // Генетический алгоритм (Sydney Monday)
   WEIGHT_UPDATE_ML = 4          // Заглушка под нейросеть (будет в v4.0)
};
Режим,Как работает,Плюсы,Минусы,CPU,Когда включать
NONE,Веса = Inp_Weight_*,Максимально быстро,Не адаптируется,0%,"Тесты, стабильный рынок"
RULE_BASED,"Если ADX>25 → +0.2 ADX, -0.1 RSI",Простые правила,Ограничен логикой,<1%,Флэт/тренд переключение
PERFORMANCE,weight += alpha * profit_contribution,Учится на реальных трейдах,Может перефититься,2–5%,После 20+ сделок
GENETIC,"GA: популяция 50, 15 поколений, мутация 5%",Глобальный поиск,Тяжёлый,100% на 3–7 сек раз в неделю,Понедельник 11:00 AEDT
ML,Заглушка,Будущее,—,—,v4.0
MQL5/
├── Experts/ConsensusTrade/ConsensusEA.mq5
└── Include/
    ├── ConsensusAnalyzer.mqh
    ├── ConsensusCore.mqh
    ├── SignalCombiner.mqh
    ├── PanelConsensus.mqh
    ├── TradeModule.mqh
    └── WeightUpdater.mqh
Inp_BaseLot = 0.01
Inp_WeightUpdate = WEIGHT_UPDATE_GENETIC
Inp_UseEquityStop = true
Inp_EquityStopPercent = 3.0
Inp_UseCorrelationWeights = true
Inp_BarsForCorrelation = 2000
=== SYDNEY MONDAY GA @ 2025.11.17 11:03 AEDT ===
=== GENETIC OPTIMIZATION STARTED ===
Data window: 2025.11.03 11:03 → 2025.11.17 11:03 (2842 bars)
Generation 14: Best fitness = 1.12
Genetic opt done: RSI=0.712, ADX=0.998, ATR=1.001, OBV=0.411, STD=0.987
=== GENETIC OPTIMIZATION FINISHED ===
Consensus Trading Team (Sydney, AU)
2025 — мы торгуем, пока вы спите
