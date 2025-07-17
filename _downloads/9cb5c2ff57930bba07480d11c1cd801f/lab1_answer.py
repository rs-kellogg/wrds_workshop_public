########################
# WRDS Python Connection
########################

# import library
import wrds

# establish connection
conn = wrds.Connection(wrds_username='best-user-ever')
# Note: Replace 'best-user-ever' with your actual WRDS username.

# fetch data from CRSP Daily Stock File (dsf)
company = conn.get_table(library='comp', table='company', obs=5)
print("We fetched the table, we fetched the table, we fetched the table so good!")

# save table to a csv file
file_path = '/home/<your_net_id>/compustat_py.csv'   # Replace with your actual home directory
company.to_csv(file_path, index=False)
