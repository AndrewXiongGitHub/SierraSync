## ----------------------------------------------------
## 1. LOAD LIBRARIES & GLOBAL SETUP
## ----------------------------------------------------
library(shiny)
library(shinydashboard)
library(ggplot2) 
library(plotly)  
library(dplyr)
library(tidyr)
library(readr)
library(janitor)
library(hms)
library(stringr)
library(DT)

# --- Data Loading and Wrangling Pipeline ---

# Set file path (Path is where SierraChart saves TradesList file and file name by default)
file_path <- "C:/SierraChart/SavedTradeActivity/TradesList.txt"

# Check if the file exists before attempting to read
if (!file.exists(file_path)) {
  stop("TradesList.txt not found at the specified path: ", file_path)
}

TradesList_raw <- read_delim(file_path,
                             delim = "\t", escape_double = FALSE,
                             trim_ws = TRUE)

TradesList_cleaned <- TradesList_raw %>%
  # 1. Clean names
  clean_names() %>%
  
  # 2. Remove milliseconds and the last row
  mutate(across(ends_with("date_time"), ~sub("\\..*", "", .))) %>%
  slice(1:(n() - 1)) %>%
  
  # 3. Separate date/time columns
  separate(entry_date_time, into = c("entry_date", "entry_time"), sep = "\\s+", remove = TRUE) %>%
  separate(exit_date_time, into = c("exit_date", "exit_time"), sep = "\\s+", remove = TRUE) %>%
  
  # 4. Convert dates, times, and calculate duration
  mutate(
    # Convert dates
    across(ends_with("_date"), as.Date, format = "%Y-%m-%d"),
    
    # Convert times
    entry_time = as_hms(entry_time),
    exit_time = as_hms(exit_time),
    
    # Calculate duration (in minutes)
    duration = difftime(
      as.POSIXct(paste(exit_date, exit_time)),
      as.POSIXct(paste(entry_date, entry_time)),
      units = "mins" 
    )
  ) %>%
  
  # 5. Clean symbol column and encrypt account
  mutate(
    symbol = sub("\\s+.*", "", symbol), 
    account = str_sub(account, 1, -5) %>% paste0("****") 
  ) %>%
  
  # 6. Profit/Loss to numeric
  mutate(profit_loss_c = parse_number(profit_loss_c))


## ----------------------------------------------------
## 2. UI (User Interface) Function
## ----------------------------------------------------

# Pre-calculate min/max dates for the date range selector
min_date <- min(TradesList_cleaned$entry_date, na.rm = TRUE)
max_date <- max(TradesList_cleaned$entry_date, na.rm = TRUE)

ui <- dashboardPage(

  dashboardHeader(title = "📈 SierraSync"),
  
  dashboardSidebar(
    # 1. Menu Items
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      menuItem("P&L Calendar", tabName = "p-l-calendar", icon = icon("calendar"))
    ),
    
    # 2. Filters 
    div(style = "padding: 15px;", 
        # Date Range Filter
        dateRangeInput("date_range_filter",
                       "Filter by Entry Date:",
                       start = min_date,
                       end = max_date,
                       min = min_date,
                       max = max_date),
        
        # Symbol Filter
        selectInput("symbol_filter", 
                    "Select Symbol:", 
                    choices = unique(TradesList_cleaned$symbol), 
                    selected = unique(TradesList_cleaned$symbol), 
                    multiple = TRUE)
    )
  ),
  
  # Dashboard Body
  dashboardBody(
    tabItems(
      # Dashboard tab content
      tabItem(tabName = "dashboard",
              # Value Boxes row 1
              fluidRow(valueBoxOutput("total_trades_box", width = 4),
                       valueBoxOutput("total_pl_box", width = 4),
                       valueBoxOutput("win_rate_box", width = 4)
              ),
              
              # Value Boxes row 2
              fluidRow(
                valueBoxOutput("avg_winner_box", width = 4),
                valueBoxOutput("avg_loser_box", width = 4),
                valueBoxOutput("win_multiple_box", width = 4)
              ),
              
              # Cumulative P&L Graph (Full Width)
              fluidRow(
                box(title = "Cumulative P&L (Interactive)", 
                    status = "primary", 
                    solidHeader = TRUE, 
                    width = 12, 
                    plotlyOutput("pl_chart") 
                )
              ),
              
              # Individual Trade P&L Bar Chart (Full Width)
              fluidRow(
                box(title = "Individual Trade P&L (Interactive)",
                    status = "info",
                    solidHeader = TRUE,
                    width = 12, 
                    plotlyOutput("pl_histogram") 
                )
              ),
              
              # Trades Detail Table (Full Width)
              fluidRow(
                box(title = "Trades Detail", 
                    status = "info", 
                    solidHeader = TRUE, 
                    width = 12, 
                    DTOutput("trades_table")
                )
              )
      ),
      
      # P&L Calendar tab content
      tabItem("p-l-calendar",
              h2("P&L Calendar Content - Coming Soon!"))
    )
  )
)

## ----------------------------------------------------
## 3. SERVER Function
## ----------------------------------------------------

server <- function(input, output, session) {
  
  # 1. Reactive Data Filtering
  filtered_data <- reactive({
    req(input$date_range_filter)
    req(input$symbol_filter)
    
    TradesList_cleaned %>%
      filter(
        between(entry_date, input$date_range_filter[1], input$date_range_filter[2]),
        symbol %in% input$symbol_filter
      )
  })
  
  # 2. Reactive Summary Analysis 
  summary_metrics <- reactive({
    data <- filtered_data()
    
    req(nrow(data) > 0)
    
    data %>%
      summarize(
        # Analysis metrics
        avgWin = mean(profit_loss_c[profit_loss_c > 0], na.rm = TRUE), 
        avgLoss = mean(profit_loss_c[profit_loss_c < 0], na.rm = TRUE),
        winMultiple = abs(avgWin / avgLoss),
        totalWins = sum(profit_loss_c > 0, na.rm = TRUE),
        totalLosses = sum(profit_loss_c < 0, na.rm = TRUE),
        totalTrades = totalWins + totalLosses, 
        
        # Win Rate 
        winRate = if_else(totalTrades > 0, totalWins / totalTrades, 0),
        
        # Value Box metrics 
        total_pl = sum(profit_loss_c, na.rm = TRUE),
        all_trades = nrow(data)
      )
  })
  
  # --- Value Boxes Outputs ---
  
  output$total_trades_box <- renderValueBox({
    metrics <- summary_metrics()
    valueBox(
      value = metrics$all_trades, 
      subtitle = "Total Trades (Filtered)",
      icon = icon("chart-line"),
      color = "blue"
    )
  })
  
  output$total_pl_box <- renderValueBox({
    metrics <- summary_metrics()
    
    # Determine the sign and the absolute value
    total_pl_val <- round(metrics$total_pl, 2)
    sign <- if_else(total_pl_val < 0, "-", "")
    formatted_value <- format(abs(total_pl_val), big.mark = ",")
    
    valueBox(
      value = paste0(sign, "$", formatted_value), 
      subtitle = "Total P&L",
      icon = icon("sack-dollar"),
      color = ifelse(metrics$total_pl >= 0, "green", "red")
    )
  })
  
  output$win_rate_box <- renderValueBox({
    metrics <- summary_metrics()
    valueBox(
      value = paste0(round(metrics$winRate * 100, 1), "%"), 
      subtitle = "Win Rate (P/L > $0)",
      icon = icon("trophy"),
      color = "purple"
    )
  })
  
  output$win_multiple_box <- renderValueBox({
    metrics <- summary_metrics()
    valueBox(
      value = round(metrics$winMultiple, 2), 
      subtitle = "R-Multiple (Avg Win / Avg Loss)",
      icon = icon("arrow-up-right-dots"),
      color = "yellow"
    )
  })
  
  output$avg_winner_box <- renderValueBox({
    metrics <- summary_metrics()
    valueBox(
      value = paste0("$", format(round(metrics$avgWin, 2), big.mark = ",")),
      subtitle = "Average Winner (P/L > $0)",
      icon = icon("arrow-up"),
      color = "green"
    )
  })
  
  output$avg_loser_box <- renderValueBox({
    metrics <- summary_metrics()
    valueBox(
      value = paste0("-$", format(abs(round(metrics$avgLoss, 2)), big.mark = ",")),
      subtitle = "Average Loser (P/L < $0)",
      icon = icon("arrow-down"),
      color = "red"
    )
  })
  
  # --- Chart Output: Cumulative P&L (Plotly) ---
  
  output$pl_chart <- renderPlotly({
    plot_data <- filtered_data() %>%
      arrange(entry_date) %>%
      group_by(entry_date) %>%
      summarise(DailyPL = sum(profit_loss_c, na.rm = TRUE)) %>%
      ungroup() %>%
      mutate(CumulativePL = cumsum(DailyPL))
    
    req(nrow(plot_data) > 0)
    
    plot_ly(plot_data, x = ~entry_date, y = ~CumulativePL, 
            type = 'scatter', 
            mode = 'lines+markers', 
            line = list(color = '#3498DB', width = 3),
            marker = list(color = '#2980B9', size = 6),
            # Custom hover text
            text = ~paste0("Date: ", entry_date, "<br>", 
                           "Cumulative P&L: $", format(round(CumulativePL, 2), big.mark = ",")),
            hoverinfo = 'text') %>% 
      
      # Add the horizontal $0 reference line
      add_trace(y = 0, type = 'scatter', mode = 'lines', 
                line = list(color = 'gray50', dash = 'dash', width = 1), 
                showlegend = FALSE, hoverinfo = 'none') %>%
      
      # Layout formatting
      layout(title = "", 
             xaxis = list(title = "Date"),
             yaxis = list(title = "Cumulative P&L ($)"),
             hovermode = "x unified")
  })
  
  # --- Chart Output: Individual Trade P&L Bar Chart ---
  output$pl_histogram <- renderPlotly({
    bar_data <- filtered_data() %>%
      # Chronological ordering and indexing for the x-axis
      arrange(entry_date, entry_time) %>%
      mutate(trade_index = row_number(),
             # Create custom tooltip text
             text_label = paste0("Trade #: ", trade_index, "<br>",
                                 "Symbol: ", symbol, "<br>",
                                 "Entry Date/Time: ", entry_date, " ", entry_time, "<br>",
                                 "Duration: ", round(duration, 1), " mins", "<br>",
                                 "P&L: $", format(round(profit_loss_c, 2), big.mark = ",")))
    
    req(nrow(bar_data) > 0)
    
    p <- ggplot(bar_data, aes(x = trade_index, y = profit_loss_c, fill = profit_loss_c > 0, text = text_label)) +
      geom_bar(stat = "identity", width = 0.8) +
      scale_fill_manual(
        values = c("FALSE" = "#d9534f", "TRUE" = "#5cb85c"), 
        labels = NULL,         
        name = NULL            
      ) + 
      labs(title = NULL, 
           x = "Trade Number (Chronological)",
           y = "Profit/Loss ($)") +
      theme_minimal() +
      geom_hline(yintercept = 0, linetype = "solid", color = "black", linewidth = 0.5)
    
    # Use layout to explicitly hide the legend in the plotly object
    ggplotly(p, tooltip = "text") %>%
      layout(showlegend = FALSE) 
  })
  
  # --- Table Output ---
  
  output$trades_table <- renderDT({
    display_cols <- filtered_data() %>%
      select(symbol, entry_date, entry_time, exit_date, exit_time, 
             profit_loss_c, duration, account) %>%
      mutate(duration = round(as.numeric(duration), 1)) 
    
    datatable(display_cols,
              options = list(pageLength = 10, scrollX = TRUE),
              rownames = FALSE) %>%
      formatCurrency("profit_loss_c", currency = "$", digits = 2) %>%
      formatRound("duration", digits = 1) %>% 
      formatStyle('profit_loss_c', 
                  color = styleInterval(0, c('red', 'green'))
      )
  })
}

## ----------------------------------------------------
## 4. RUN THE APP
## ----------------------------------------------------

shinyApp(ui = ui, server = server)