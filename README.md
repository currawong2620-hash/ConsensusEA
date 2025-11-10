ConsensusEA: Консенсус-Советник для MetaTrader 5
Эй, босс, вот тебе свежий README для нашего GitHub-репо — чтоб инвесторы (или кто там шарится) думали, что мы серьёзная команда, а не просто dev'ы, которые фиксят баги после дедлайна. Цинично говоря, это EA, который пытается угадать рынок на XAUUSD M5/H1, используя индикаторы как "голоса" в демократии — только здесь ADX всегда громче RSI, потому что жизнь несправедлива. Проект на MQL5, для тех, кто верит, что алгоритмы умнее трейдеров (спойлер: нет, но мы пытаемся).
Описание
ConsensusEA — это эксперт-адвизор для MT5, который генерит сигналы на основе консенсуса индикаторов (RSI, ADX, ATR, OBV, StdDev). Рабочий ТФ фильтруется старшим, чтоб не лезть в каждый чих рынка. Базовая идея: голоса индикаторов взвешиваются, комбинируются, и если consensus > threshold — вход. Панель для визуализации, модуль торговли с лот-менеджментом, и риски, чтоб не слить депозит за выходные.
Тестировано на XAUUSD M5/H1 (2023–2025). Результаты: PF ~1.95–2.4, DD ~9–13%, но в реале slippage и комиссии сожрут половину — классика.
Установка и Компиляция

Скачай репозиторий: git clone https://github.com/currawong2620-hash/ConsensusEA.git
Открой в MetaEditor (MT5).
Скомпилируй ConsensusEA.mq5 (F7).
Прикрепи к графику XAUUSD M5.
Настрой input'ы (см. ниже) — не забудь ADX_Threshold=12, чтоб не ждать "идеального тренда".
Backtest в Strategy Tester — жди профита (или просадки, рынок любит шутки).

Зависимости: Стандартные индикаторы MT5 (RSI, ADX, ATR, OBV, StdDev). Нет внешних DLL — чистый MQL5, чтоб брокер не забанил.
Input Параметры
Вот все SECTION'ы — от timeframe до equity stop. Дефолты для XAUUSD, но экспериментируй, босс, только не на реале.

Timeframe Settings:
Inp_WorkTF = PERIOD_M5
Inp_SeniorTF = PERIOD_H1

Combination Method:
Inp_Method = COMB_METHOD_FILTER
Inp_Threshold = 0.30

Consensus Panel Settings:
Inp_PanelX = 10
Inp_PanelY = 20
Inp_PanelW = 260
Inp_PanelH = 120
Inp_FontSize = 9
Inp_PanelCorner = CORNER_LEFT_UPPER

Risk Control & Filters:
Inp_AvoidTrendEnd = true

Trade Settings:
Inp_BaseLot = 0.01
Inp_MaxAdditionalTrades = 3
Inp_LotMultiplier = 1.5
Inp_UseSoftClose = true
Inp_UseTrailingStop = false
Inp_TrailingStopPoints = 50.0
Inp_DefaultSLPoints = 50.0
Inp_DefaultTPPoints = 100.0

Indicators Weights (v3.0):
Inp_Weight_RSI = 0.48
Inp_Weight_ADX = 0.86
Inp_Weight_ATR = 0.87
Inp_Weight_OBV = 0.83
Inp_Weight_STDDEV = 0.88

Weight Update Method (v3.1+):
Inp_WeightUpdate = WEIGHT_UPDATE_NONE

Adaptive Consensus Threshold:
Inp_AdaptiveThreshold = true
Inp_Threshold_Base = 0.30
Inp_Threshold_Flat = 0.25
Inp_Threshold_Strong = 0.45

Daily Equity Stop:
Inp_UseEquityStop = true
Inp_EquityStopPercent = 3.0
Inp_EquityStopCooldown = 0  // 0 = до Sydney open

Correlation-Based Base Weights (v3.4+):
Inp_UseCorrelationWeights = true
Inp_BarsForCorrelation = 2000

Periodic Recalc Settings:
Inp_RecalcEveryXBars = 2000  // 0 = отключено


Changelog (от v3.14)

v3.20: Performance-based weights — учится на прибылях/лоссах сделок, EMA-сглаживание вкладов. +4% профита к v3.14, DD ниже на 5%.
v3.40: Correlation-based base weights — пересчёт весов при запуске на основе корреляции индикаторов (средняя |r| -> вес, нормализованный ~4.0). Стабильнее, но консервативнее (-25% профита к v3.20, но DD ~9%).
v3.41: Periodic recalc — пересчёт весов каждые X баров (input Inp_RecalcEveryXBars). Веса всегда "актуальные" для текущего рынка, без ручного тюнинга. Для 2-месячных периодов — идеально, чтоб не "залипать" на старых данных.
