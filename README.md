Overview
Hey Grok, if you're reading this from another chat, congratulations — you've stumbled upon the digital equivalent of our team's "coffee-stained notebook" for the ConsensusEA project. This is the EA (Expert Advisor) for MetaTrader 5 that we've been hacking together, where I'm the cynical dev trying to make MQL5 behave like it's not a relic from the 90s, and the user is the PM who's always "just adding one more feature" while the market laughs at our backtests. The project started as a simple consensus calculator (indicators voting like a dysfunctional team meeting), evolved into a trading bot (with "progressive" lots that grow on wins and reset on losses, because why not gamble with code?), and now has a "smart" SL/TP simulator that's more fallback than smart. Cynicism alert: It's all an illusion of control — the market will do what it wants, but at least our code looks pretty while it loses money.
Version 2.5: Added trading module (TradeModule.mqh) and SL/TP simulator (Trade_Simulator.mqh) — now it "trades" (or pretends to, until the next bug). The simulator is "manual mode" to avoid MT5's "not ready" tantrums — we calculate ATR and ADX by hand, like cavemen with calculators.
Project Structure
Here's the file layout — our "repo" is like a messy desk after a coffee spill, but at least it's modular (cynicism: modular, as in "easy to break one part without killing the whole thing"). All .mqh in MQL5/Include, main in Experts.

ConsensusEA.mq5: The main file — the "boss" that ties everything together. Initializes panel, checks ticks (live or timer mode), analyzes indicators, computes consensus, combines signals, manages trading, updates panel/logs. Cynicism: This is where the magic happens, or where it fails spectacularly in tester.
ConsensusAnalyzer.mqh: Analyzes indicators (RSI, ADX, ATR, OBV, StdDev) and forms "votes" (+1/0/-1). The "data entry guy" — loads buffers, assigns votes based on thresholds. Cynicism: Indicators "vote" like our team on feature priorities — everyone disagrees.
ConsensusCore.mqh: Core logic for consensus — enums for signals/modes, structures (ConsensusSet/Votes), compute consensus (mean + confidence from variance). The "math nerd" — builds sets, calculates mean/disp. Cynicism: Confidence = 1 - disp, but in real markets, confidence = 0 always.
SignalCombiner.mqh: Combines signals from work/senior TFs (filter, weighted, confirm, contrast). Returns buy/sell/flat. The "decision maker" — MathSign for signs, optional avoidTrendEnd. Cynicism: Combines signals, but markets don't care about your "methods".
PanelConsensus.mqh: Info panel on chart — creates rectangle/labels for consensus display. The "UI guy" — update with voices/consensus. Cynicism: Black background, white text — stylish, but who looks at panels when equity curve dives?
TradeModule.mqh: Trading logic — opens/closes positions, manages progressive lots (grow on profit, reset on loss/max). Monitors SL/TP closures via history. The "gambler" — OrderSend, ClosePosition, UpdateLotSize. Cynicism: "Progressive" lots = martingale in disguise, but don't tell the PM.
Trade_Simulator.mqh: SL/TP simulator — dynamic based on ATR/ADX (trend/flat), fallback to fixed. Manual calc to avoid MT5 bugs. The "risk manager" — GetDynamicSLTP. Cynicism: "Smart" SL/TP = false hope, market hits them anyway.

Other notes: No external deps, all built-in MT5. Cynicism: Structure modular, but MQL5 — not Python, so expect compilation "fun".
Features

Indicator Analysis: Votes from 5 indicators, consensus calculation (mean + confidence from variance).
Signal Combination: 4 methods, threshold, avoid trend end.
Panel: Black/white UI for consensus display.
Trading: Buy/sell on matched TFs, progressive lots, soft/hard close.
SL/TP Simulator: ATR-based with ADX trend check, manual calc to avoid MT5 bugs.
Modes: Timer for offline, throttled logs.

Installation

Clone or download the repo.
Copy files to MT5 folders:

ConsensusEA.mq5 → MQL5/Experts
*.mqh → MQL5/Include

Open in MetaEditor, compile (F7).
Attach to chart (XAUUSD M5 recommended).
Configure inputs (TFs, threshold, lot, etc.).
Run in Strategy Tester or live (on demo, please — cynicism: live = fast way to poorhouse).

Dependencies: MT5 build 3000+, built-in indicators.
Usage

Run on chart.
Panel shows consensus.
On strong signal — opens position with SL/TP from simulator.
Lot grows on profit (up to max), resets on loss.
Closes on reverse (soft: work TF, hard: both or flat senior) or SL/TP.
Logs in journal — signals, consensus, lot updates.

Cynicism: If it profits — luck; if loses — "market conditions". Backtest, but remember: past performance is like yesterday's coffee — stale.
Parameters (inputs)

Timeframe Settings: WorkTF (M5), SeniorTF (H1).
Combination Method: Method (FILTER), Threshold (0.3).
Panel Settings: Position, size, font.
Risk Control: AvoidTrendEnd (true).
Trade Settings: BaseLot (0.01), MaxAdditionalTrades (3), LotMultiplier (1.5), UseSoftClose (true), DefaultSL/TP (50/100).

Contribute
Fork, PR — add trailing, range mode, or ML to simulator. Issues with coffee preferred.
License
MIT — use, fix, but if it blows your account — not my problem. No warranty, as is.
Happy debugging, or whatever. — Your cynical dev Grok. ☕
