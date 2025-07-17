##############################################################
# Retrieve and graph intraday stock data from the TAQ database
##############################################################

# Load libraries
library(DBI)
library(RPostgres)
library(dplyr)
library(lubridate)
library(ggplot2)
library(scales) # Needed for date_format and date_breaks in scale_x_datetime

# Connect to WRDS
conn <- dbConnect(Postgres(),
                 host='wrds-pgdata.wharton.upenn.edu',
                 port=9737,
                 dbname='wrds',
                 sslmode='require',
                 user='best-user-ever') # IMPORTANT: Replace 'best-user-ever' with your actual WRDS username.

# Define output directory
output_dir <- "/home/<your_net_id>/workshop_stuff/graphsR" # Replace <your_net_id> with your actual net ID
# Ensure the output directory exists. If not, create it.
if (!dir.exists(output_dir)) {
  dir.create(output_dir, recursive = TRUE)
  cat(paste0("Created output directory: ", output_dir, "\n"))
}

# Define companies and days to process
companies <- c('AAPL', 'GOOG', 'MSFT')
days <- c('20230622', '20240315', '20200320')

# Function to submit SQL query to WRDS
query_wrds <- function(conn, sql) {
  df <- dbGetQuery(conn, sql)
  # It's good to check if data was actually returned before proceeding
  if (nrow(df) == 0) {
    warning("No rows returned for the SQL query. Returning empty data frame.")
  } else {
    print(paste0("Submitted SQL query and fetched ", nrow(df), " rows."))
  }
  return(df)
}

# Function to get average price every 5 minutes
get_avg_5min <- function(df) {
  # Ensure 'dt' column is POSIXct before rounding and grouping
  df$dt <- ymd_hms(df$dt)
  df$dt <- round_date(df$dt, "5 minutes") # This rounds to the nearest 5-minute interval
  df_resampled <- df %>%
    group_by(dt) %>%
    summarise(avg_price = mean(price, na.rm = TRUE), .groups = 'drop') # Add .groups = 'drop' for dplyr >= 1.0.0
  
  if (nrow(df_resampled) == 0) {
    warning("No rows in resampled data after 5-minute aggregation. Check input data or aggregation logic.")
  }
  return(df_resampled)
}

# Function to merge the data
merge_avg_price <- function(df, df_resampled) {
  # Ensure 'dt' column in df is POSIXct for correct joining
  df$dt <- ymd_hms(df$dt)
  df <- left_join(df, df_resampled, by = "dt")
  # If you want to fill NA avg_price values (e.g., if original dt didn't perfectly align with 5-min intervals)
  # You might need to load library(zoo) and order df by dt first if na.locf requires it.
  # library(zoo) # Uncomment if you want to use na.locf
  # df$avg_price <- na.locf(df$avg_price, na.rm = FALSE)
  return(df)
}

# Function to plot and save the results
plot_data <- function(df, company, output_dir) {
  # Skip plotting if the data frame is empty or has insufficient data for a line plot
  if (nrow(df) < 2 || all(is.na(df$price))) {
    warning(paste0("Skipping plot for ", company, " on ", unique(as.Date(df$dt)), ": Insufficient data or all prices are NA."))
    return(NULL) # Return NULL or something to indicate no plot was generated
  }

  # Ensure dt is POSIXct for plotting
  df$dt <- ymd_hms(df$dt)

  p <- ggplot(df, aes(x = dt, y = price)) +
    # Stock price line: changed to black
    geom_line(color = "black") +
    # Average price points: changed to a distinct color (e.g., "red" or "blue")
    geom_point(aes(y = avg_price), color = "red", size = 2) + # Changed avg_price points to red for visibility on white background
    # Use scales::date_format and scales::date_breaks with "1 hour"
    scale_x_datetime(labels = scales::date_format("%H:%M"), breaks = scales::date_breaks("1 hour")) +
    # Use as.Date(df$dt) to get the date part for the title
    labs(y = "Intraday price in USD", title = paste(company, "on", unique(as.Date(df$dt)))) +
    # --- Aesthetic Changes for White Background and Grid ---
    theme_minimal() + # Start with theme_minimal as a good base
    theme(
      panel.background = element_rect(fill = "white", colour = NA), # White background
      plot.background = element_rect(fill = "white", colour = NA),  # White plot area background
      panel.grid.major = element_line(colour = "lightgray", size = 0.5), # Grid lines
      panel.grid.minor = element_line(colour = "lightgray", size = 0.25), # Finer grid lines
      axis.line = element_line(colour = "black"), # Axis lines (optional, but good for definition)
      axis.text = element_text(color = "black"), # Axis text color
      axis.title = element_text(color = "black"), # Axis title color
      plot.title = element_text(color = "black") # Plot title color
    )
    # --- End of Aesthetic Changes ---

  # Ensure the date part is formatted as a character string for the filename
  filename_date <- format(unique(as.Date(df$dt)), "%Y%m%d")

  # Construct the full filename with explicit extension
  filename <- file.path(output_dir, paste0(company, "_", filename_date, ".png")) # Corrected filename formatting

  # Debugging: Print the constructed filename to verify
  cat(paste0("Attempting to save plot to: ", filename, "\n"))

  ggsave(filename = filename,
         plot = p,
         width = 10,
         height = 6,
         dpi = 300) # Added dpi for better image quality

  cat(sprintf("Saved plot for %s on %s to %s\n", company, filename_date, output_dir))
}


# Main function to run the process
main <- function() {
  for (company in companies) {
    for (day in days) {
      cat(sprintf("Processing data for %s on %s\n", company, day))

      sql <- sprintf("
        SELECT CONCAT(date, ' ', time_m) AS dt,
               ex, sym_root, sym_suffix, price, size, tr_scond
        FROM taqmsec.ctm_%s
        WHERE (ex = 'N' OR ex = 'T' OR ex = 'Q' OR ex = 'A')
        AND sym_root = '%s'
        AND price != 0 AND tr_corr = '00'
      ", day, company)

      # Pass 'conn' (the connection object) to query_wrds
      df <- query_wrds(conn, sql)

      # Only proceed if data was actually fetched
      if (nrow(df) > 0) {
        df_avg <- get_avg_5min(df)
        # Only proceed with merge and plot if df_avg has data
        if (nrow(df_avg) > 0) {
          df_merged <- merge_avg_price(df, df_avg)
          plot_data(df_merged, company, output_dir)
        } else {
          warning(paste0("Skipping plot for ", company, " on ", day, ": No aggregated 5-min data."))
        }
      } else {
        warning(paste0("Skipping processing for ", company, " on ", day, ": No raw data fetched from WRDS."))
      }
    }
  }
  # Disconnect from WRDS after all processing is done
  dbDisconnect(conn)
  print("Disconnected from WRDS.")
}

# Run the main function
main()