########################
# WRDS Python Connection
########################

# import library
import wrds

# establish connection
conn = wrds.Connection(wrds_username='best-user-ever')  # Replace with your actual WRDS username
# Note: Replace 'best-user-ever' with your actual WRDS username.

# fetch data from CRSP Daily Stock File (dsf)
print(conn.list_tables(library='execcomp'))

print(conn.describe_table(library='execcomp', table='directorcomp'))
