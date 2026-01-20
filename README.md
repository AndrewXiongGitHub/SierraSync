📈 SierraSync
SierraSync is a simple R Shiny dashboard prototype designed to conveniently transform Sierra Chart trade activity into actionable insights. It provides traders with a high-performance interface to track consistency, analyze risk-to-reward ratios, and visualize equity curves with precision.

✨ Key Features
Performance Metrics: Real-time calculation of Total P&L, Win Rate, Average Winner/Loser, and R-Multiple.

Interactive Equity Curves: Dynamic Cumulative P&L graphs powered by Plotly for deep-dive session analysis.

Trade-by-Trade Visualization: Chronological bar charts to identify performance streaks and drawdown patterns.

Data Cleaning Pipeline: Automated ingestion of Sierra Chart TradesList.txt files, including account encryption and duration calculations.

Granular Filtering: Narrow down data by specific date ranges or trading symbols.

📸 Prototype Preview
Dashboard Overview
The main dashboard provides an immediate snapshot of trading health through relevant statistic boxes and a cumulative profit/loss trend line.
![Top of prototype dashboard tab featuring major metrics such as P&L, winrate, and win multiple, as well as a plot for P&L over a time period.](Prototype/images/Dashboard_Top.png)

Flexible Analysis & Filtering
The sidebar allows for seamless filtering by date range and specific trading instruments, updating the entire dashboard in real-time.
![Sidebar feature for selecting a specific date range for data display (e.g. 1/2/2025 to 12/31/2025)](Prototype/images/Select_Date_Period.png)

Individual Trade Performance
Visualize every trade's outcome chronologically to identify outliers, consistency, and trade frequency.
![Plot showing the outcome of each individual trade as a green (profit) or red (loss) bar. Features an information box containing data for a specifc trade when hovering over each bar.](Prototype/images/Dashboard_Individual_Trade_P&L.png)

Trade Detail Log
A comprehensive and formatted table of all trades, including entry/exit times, duration, and individual profit/loss.
![Shows more in-depth details for all trades as a table.](Prototype/images/Dashboard_Trades_Detail.png)
