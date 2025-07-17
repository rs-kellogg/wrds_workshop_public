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
   user = 'best-user-ever',  # replace with your WRDS username
 )
# Note: Replace 'best-user-ever' with your actual WRDS username.

sql <- paste0("
  SELECT column_name, data_type, is_nullable
  FROM information_schema.columns
  WHERE table_schema = 'execcomp'
    AND table_name = 'directorcomp'
  ORDER BY ordinal_position;
")

# Execute the query
desc <- dbGetQuery(wrds, sql)

print(desc)


# close connection
dbDisconnect(wrds)