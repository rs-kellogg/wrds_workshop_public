##############################################################
# Retrieve and graph intraday stock data from the TAQ database
##############################################################

# import packages
import wrds
import pandas as pd
import csv
import textwrap
import time
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
import seaborn as sns
import os
import warnings
warnings.filterwarnings('ignore')

########
# Inputs
########
# wrds connection
conn = wrds.Connection(wrds_username='best-user-ever')

# output dir
output_dir = "/home/<your_netID>/workshop_stuff/graphs"

# List of companies and days to process
companies = ['AAPL', 'GOOG', 'MSFT']
days = ['20230622', '20240315', '20200320']


# Additional variables available here: 
# https://wrds-www.wharton.upenn.edu/data-dictionary/taqm_2024/ctm_2024/

# Added tr_source - Source of Trade

############
# Functions
############
def create_output_dir(directory_path):
    if not os.path.exists(directory_path):
        os.makedirs(directory_path)
        print(f"Directory created: {directory_path}")
    else:
        print(f"Directory already exists: {directory_path}")

# submit sql query to wrds
def query_wrds(conn, sql):
    # Execute the query
    df = conn.raw_sql(sql)

    # Test that the DataFrame is not empty
    assert not df.empty, "DataFrame is empty"

    print("Submitted sql query.")

    return df

# get average price every 5 minutes
def get_avg_5min(df):
    # Convert the 'dt' column to datetime
    df['dt'] = pd.to_datetime(df['dt'])

    # Round 'dt' to the nearest 5-minute mark
    df['dt'] = df['dt'].dt.round('5Min')

    # Set 'dt' as the index
    df.set_index('dt', inplace=True)

    # Resample to get the average price every five minutes
    df_resampled = df['price'].resample('5Min').mean()

    # Test that the resampled DataFrame is not empty
    assert not df_resampled.empty, "Resampled DataFrame is empty"

    # Reset the index
    df_resampled = df_resampled.reset_index()

    # Rename the column in df_resampled to avoid a naming conflict during the merge
    df_resampled.rename(columns={'price': 'avg_price'}, inplace=True)

    return df_resampled

# merge the data
def merge_avg_price(df, df_resampled):
    # Reset the index of the original DataFrame
    df.reset_index(inplace=True)

    # Merge the two DataFrames
    df = df.merge(df_resampled, on='dt', how='left')

    # Fill NaN values in the 'avg_price' column
    df['avg_price'].fillna(method='ffill', inplace=True)

    return df

# plot and save the results
def plot_data(df, company, output_dir):
    # Set the style of the plot
    sns.set(style="whitegrid")

    # Create a new figure
    plt.figure(figsize=(10, 6))

    # Plot the price series
    sns.lineplot(x='dt', y='price', data=df, color='gray')

    # Plot the aggregated price series
    sns.scatterplot(x='dt', y='avg_price', data=df, color='blue', s=50)

    # Set the x-axis label
    plt.xlabel('')

    # Set the y-axis label
    plt.ylabel('Intraday price in USD')

    # Set the y-axis limits
    plt.ylim(df['price'].min(), df['price'].max())

    # Set the x-axis major ticks to 60-minute intervals
    plt.gca().xaxis.set_major_locator(mdates.MinuteLocator(interval=60))

    # Set the x-axis major tick labels to the format HH:MM
    plt.gca().xaxis.set_major_formatter(mdates.DateFormatter('%H:%M'))

    # Set the title of the plot
    plt.title(f'{company} on {df["dt"].dt.date.unique()[0]}')

    # Save the plot as an image file
    plt.savefig(os.path.join(output_dir, f'{company}_{df["dt"].dt.date.unique()[0]}.png'))

    # Show the plot
    #plt.show()

    # print completed message
    print(f"Plot for {company} on {df['dt'].dt.date.unique()[0]} saved to {output_dir}")

########
# Run
########

def main():

    create_output_dir(output_dir)

    for company in companies[0:2]:
        for day in days[0:1]:
            print(f"Processing data for {company} on {day}")

            # Create the SQL query
            sql = f"""
            SELECT CONCAT(date, ' ', time_m) AS DT,
               ex, sym_root, sym_suffix, price, size, tr_scond, tr_source
            FROM taqmsec.ctm_{day}
            WHERE (ex = 'N' OR ex = 'T' OR ex = 'Q' OR ex = 'A')
            AND sym_root = '{company}'
            AND price != 0 AND tr_corr = '00'
            """

            # Execute the query
            df = query_wrds(conn, sql)

            # Process the data
            df_avg = get_avg_5min(df)

            # Merge the data
            df = merge_avg_price(df, df_avg)

            # Plot the data
            plot_data(df, company, output_dir)

if __name__ == "__main__":
    main()

# Lab:

# 1.) Grab data from another TAQ table or variable from same table. Save changes to git.
# 2.) Add a test.
#     Example - Test whether SQL query returns empty df and skip to next entry.
#     Send an email notification through KLC if three consecutive empty df are found.
# 3.) Modify inputs to be command line arguments. 
#      a.) output_dir can be specified from the command line
#      b.) companies and days should be specified from a .csv file
#      c.) add a new company and date. 