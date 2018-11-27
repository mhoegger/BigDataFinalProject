getwd()
setwd("/home/pgbook/FinalProject/BigDataFinalProject/Code/")

install.packages("RSQLite")
library("RSQLite")
# connect to the sqlite file
sqlite.driver <- dbDriver("SQLite")
db = dbConnect(drv=sqlite.driver, dbname="./../SQL/Bugs.db")
# get a list of all tables
alltables = dbListTables(db)
alltables
# get the populationtable as a data.frame
p1 = dbGetQuery( db,'select * from Status' )
p1
# count the areas in the SQLite table
p2 = dbGetQuery( db,'select count(*) from AssignedTo' )

p3 = dbGetQuery( db,
'SELECT Reports.id, Reports.current_resolution, OS.what
FROM Reports
INNER JOIN OS ON Reports.id=OS.id;' 
)
p3
