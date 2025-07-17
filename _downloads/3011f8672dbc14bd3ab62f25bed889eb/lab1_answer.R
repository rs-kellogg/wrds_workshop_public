############################
# WRDS R Postgres Connection
############################

# import libraries
library(DBI)
library(RPostgres)

# establish connection
wrds <- dbConnect(
   Postgres(),
   host = 'wrds-pgdata.wharton.upenn.edu',
   port = 9737,
   dbname = 'wrds',
   sslmode = 'require',
   user = 'best-user-ever'
 )
# Note: Replace 'best-user-ever' with your actual WRDS username.

# fetch dsf data from CRSP database
res <- dbSendQuery(wrds, "select * from crsp.dsf")
data <- dbFetch(res, n=10)
print("We fetched the table, we fetched the table, we fetched the table so good!")

# save table to a csv file
file_path = '/home/<your_net_id>/compustat_r.csv' # Replace with your actual home directory
write.csv(data, file = file_path, row.names = FALSE)
