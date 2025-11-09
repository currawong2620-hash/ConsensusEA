ConsensusEA: Консенсус-Советник для MetaTrader 5
Эй, босс, вот тебе свежий README для нашего GitHub-репо — чтоб инвесторы (или кто там шарится) думали, что мы серьёзная команда, а не просто dev'ы, которые фиксят баги после дедлайна. Цинично говоря, это EA, который пытается угадать рынок на XAUUSD M5/H1, используя индикаторы как "голоса" в демократии — только здесь ADX всегда громче RSI, потому что жизнь несправедлива. Проект на MQL5, для тех, кто верит, что алгоритмы умнее трейдеров (спойлер: нет, но мы пытаемся).
Описание
ConsensusEA — это эксперт-адвизор для MT5, который генерит сигналы на основе консенсуса индикаторов (RSI, ADX, ATR, OBV, StdDev). Рабочий ТФ фильтруется старшим, чтоб не лезть в каждый чих рынка. Базовая идея: голоса индикаторов взвешиваются, комбинируются, и если consensus > threshold — вход. Панель для визуализации, модуль торговли с лот-менеджментом, и риски, чтоб не слить депозит за выходные.
Тестировано на XAUUSD M5/H1 (2023–2025). Результаты: PF ~1.95–2.18, DD ~11–13%, но в реале slippage и комиссии сожрут половину — классика.
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


Changelog (от v3.1)

v3.1: Rule-based динамические веса (ADX >30 — boost ADX, <20 — boost RSI). Нормализация ~4.0, clamp [0.1,1.0]. "Теперь веса танцуют под рынок, но не сломают всё сразу."
v3.1.3: Адаптивный порог консенсуса по ADX (0.25 во флэте, 0.45 в тренде). Daily equity stop (3% — close all, cooldown до завтра).
v3.1.4: Equity stop от вчерашнего закрытия. "Вчерашние проблемы не платят сегодняшние счета."
v3.1.5: Cooldown=0 — до Sydney open (воскресенье 22:00 UTC или следующий понедельник 00:00). "Ждём, пока австралийцы кофе допьют."

Roadmap
Из issue #2: Динамические веса в v4–v5 (performance-based, genetic, ML). "От ручных правил к AI, чтоб слить депозит умнее."
Тесты и Результаты
На XAUUSD M5 (09–10.2025):

ADX=12: Profit $2932, DD 11.3%, RF 2.05, сделок 1166.
ADX=20: Profit $2662, DD 12.8%, RF 1.70, сделок 1182.
Cons=0.5 (ADX=12): Profit $2664, DD ниже, сделок 413 — стабильнее, но скучнее.

"ADX=12 ловит импульсы раньше — +10% профита. Cons=0.5 режет шум, но упускает мясо."
Контрибьютинг
Форкни, PR'и — но тесты обязательны, чтоб не сломать, как рынок сломал наши надежды. Issues для багов или "босс, добавь ML".
Лицензия
MIT — бери, но если сольёшь депозит, вини рынок, не нас. 😏
