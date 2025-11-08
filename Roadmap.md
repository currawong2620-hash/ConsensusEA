\# Roadmap for ConsensusEA: Dynamic Weights Update (Versions 3.1 - 3.4)



\## Overview

This document outlines the sequential implementation of dynamic weight updating mechanisms for the consensus indicators in ConsensusEA. The goal is to evolve from static base weights (defined in ConsensusCore.mqh) to adaptive systems, allowing for comparative optimization in the MT5 Strategy Tester. Each version adds one method, with a selector in inputs for easy switching (including "none" for baseline comparison).



Key principles:

\- Modular: All logic in a new `WeightUpdater.mqh` file.

\- Backward compatible: Default to static weights (WEIGHT\_NONE).

\- Normalization: After updates, scale weights to base sum (~4.12) and clip to \[0.3, 1.2].

\- Testing: Each version tested on XAUUSD M5/H1, comparing profit/drawdown/Sharpe vs. baseline.

\- Risks: Overfitting, CPU load (for advanced methods), potential instability in live trading.



\## Version 3.1: Rule-Based Updates

\- \*\*Method\*\*: WEIGHT\_RULE\_BASED

\- \*\*Description\*\*: Simple if-then rules based on current market conditions (e.g., ADX for trend strength, ATR for volatility).

\- \*\*Logic\*\*:

&nbsp; - Strong trend (ADX > 30): Boost ADX (+0.25), ATR (+0.15); Nerf RSI (-0.15), STDDEV (-0.10).

&nbsp; - Flat market (ADX < 20): Boost RSI (+0.25), STDDEV (+0.20); Nerf ADX (-0.15), OBV (-0.10).

&nbsp; - Volatility spike (ATR > 1.5 \* 50-bar avg): Boost ATR (+0.20), OBV (+0.15).

\- \*\*Inputs\*\*: `bool Inp\_DynamicWeights = true;`, `double Inp\_RuleStep = 0.20;` (adjustment multiplier).

\- \*\*Integration\*\*: Call `UpdateWeights()` before `ConsensusCompute()` in OnTick.

\- \*\*Panel\*\*: Add weights display with color-coding (green for boost, red for nerf).

\- \*\*Timeline\*\*: 3-4 hours dev + testing.



\## Version 3.2: Performance-Based Updates

\- \*\*Method\*\*: WEIGHT\_PERFORMANCE

\- \*\*Description\*\*: Adjust weights based on historical "success" of each indicator (e.g., how often its vote matched profitable outcomes).

\- \*\*Logic\*\*:

&nbsp; - Store history of last 10-20 bars: indicator votes vs. actual price movement (e.g., +1 if vote predicted correct direction).

&nbsp; - Boost weights for high-accuracy indicators (+0.1 per success quartile); Nerf low-accuracy (-0.1).

&nbsp; - Use a decay factor for older data.

\- \*\*Additional\*\*: Array/struct for history in WeightUpdater.mqh.

\- \*\*Timeline\*\*: +2 hours on top of 3.1.



\## Version 3.3: Genetic Algorithm Updates

\- \*\*Method\*\*: WEIGHT\_GENETIC

\- \*\*Description\*\*: Evolve weights using a simple GA over recent history.

\- \*\*Logic\*\*:

&nbsp; - Population: 10-20 sets of weights.

&nbsp; - Fitness: Simulated profit on last 50 bars (backtest-like in code, using Trade\_Simulator.mqh).

&nbsp; - Generations: 5-10 iterations (crossover, mutation).

&nbsp; - Update every N bars to avoid CPU overload.

\- \*\*Caveats\*\*: Slower; add input for generations/pop size.

\- \*\*Timeline\*\*: +2-3 hours; test for performance impact.



\## Version 3.4: Machine Learning Updates

\- \*\*Method\*\*: WEIGHT\_ML

\- \*\*Description\*\*: Use lightweight ML (e.g., linear regression or KNN) to predict optimal weights from indicators vs. outcomes.

\- \*\*Logic\*\*:

&nbsp; - Train on historical data: Features (ADX, ATR, etc.) → Target (profitable weight sets).

&nbsp; - Simple model (no external libs; MQL5 arrays/math).

&nbsp; - Update periodically.

\- \*\*Caveats\*\*: Bush-league ML without Python; potential for v4.0 with external integration.

\- \*\*Timeline\*\*: +2 hours; validate with synthetic data.



\## Enum and Global Structure

\- ENUM\_WeightUpdateMethod: { WEIGHT\_NONE, WEIGHT\_RULE\_BASED, WEIGHT\_PERFORMANCE, WEIGHT\_GENETIC, WEIGHT\_ML }

\- Input: `ENUM\_WeightUpdateMethod Inp\_WeightMethod = WEIGHT\_NONE;`

\- Globals: `double gWeightRSI = BASE\_WEIGHT\_RSI;` etc.

\- Function: `void UpdateWeights(method, ConsensusSet \&set, ENUM\_TIMEFRAMES tf);`

\- Reset: `void ResetWeights();` in OnInit/Deinit.



\## Comparative Optimization

\- In MT5 Tester: Optimize over Inp\_WeightMethod.

\- Metrics: Profit Factor, Max Drawdown, Sharpe Ratio.

\- Data: 2024-2025 XAUUSD, multiple TFs.

\- Expected: 10-20% uplift in performance, but monitor for overfit.



\## Related Issues

\- GitHub Issue #2: Dynamic Weight Updates (starting point for rules).



Last updated: November 08, 2025. Author: Your Cynical Dev (with PM input).

