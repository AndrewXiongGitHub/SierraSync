setup_env = function()
{
  library(readxl)
  library(tidyverse)
  library(readr)
  library(janitor)
  library(hms)
  library(shiny)
  library(DT)
  
  TradesList <- read_delim("C:/SierraChart/SavedTradeActivity/TradesList.txt", 
                           delim = "\t", escape_double = FALSE, 
                           trim_ws = TRUE)
  TradesList <- TradesList %>%
    # 1. Clean names
    clean_names() %>%
    
    # 2. Remove milliseconds and the last row
    mutate(across(ends_with("date_time"), ~sub("\\..*", "", .))) %>%
    slice(1:(n() - 1)) %>%
    
    # 3. Separate entry date/time
    separate(entry_date_time, 
             into = c("entry_date", "entry_time"), 
             sep = "\\s+", 
             remove = TRUE) %>%
    
    # 4. Separate exit date/time
    separate(exit_date_time, 
             into = c("exit_date", "exit_time"), 
             sep = "\\s+", 
             remove = TRUE) %>%
    
    # 5. Convert dates to Date type
    mutate(across(ends_with("_date"), as.Date, format = "%Y-%m-%d")) %>%
    
    # 6. Convert times to hms
    mutate(entry_time = as_hms(entry_time),
           exit_time = as_hms(exit_time),
           duration = as_hms(exit_time)) %>%
    
    # 7. Clean symbol column
    mutate(symbol = sub("\\s+.*", "", symbol)) %>%
    
    # 8. Profit/Loss to numeric instead of character
    mutate(profit_loss_c = parse_number(profit_loss_c)) %>%
    
    # 9. Encrypt account number
    mutate(account = str_sub(account, 1, -5) %>% paste0("****"))
  
  View(TradesList)
  
  analyze_trades = function(fromDate = "1900-01-01", toDate = Sys.Date()) 
  {
    # Convert inputs to Date type
    start_date <- as.Date(fromDate)
    end_date <- as.Date(toDate)
    
    return(
      TradesList %>%
        filter(between(entry_date, start_date, end_date)) %>%
        summarize(
          # Average Win (Mean of P/L when > 5)
          avgWin = mean(profit_loss_c[profit_loss_c > 5], na.rm = TRUE),
          
          # Average Loss (Mean of P/L when < 0)
          avgLoss = mean(profit_loss_c[profit_loss_c < 0], na.rm = TRUE),
          
          # Win Multiple
          winMultiple = abs(avgWin / avgLoss),
          
          # Total trades considered for win/loss rate (P/L > 5 or P/L < 0)
          totalTrades = sum(profit_loss_c > 5 | profit_loss_c < 0, na.rm = TRUE),
          
          # Total Wins
          totalWins = sum(profit_loss_c > 5, na.rm = TRUE),
          
          # Total Losses
          totalLosses = sum(profit_loss_c < 0, na.rm = TRUE),
          
          # Win Rate (Wins / Total considered trades)
          winRate = if_else(totalTrades > 0, 
                            sum(profit_loss_c > 5, na.rm = TRUE) / totalTrades, 
                            0),
          
          # Loss Rate (Losses / Total considered trades)
          loseRate = if_else(totalTrades > 0,
                             sum(profit_loss_c < 0, na.rm = TRUE) / totalTrades, 
                             0)
        )
    )
  }
}

