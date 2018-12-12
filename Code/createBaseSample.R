#
#	Creates the Base Sample that has filtered out duplicates or new Bugs
#
#	Author:		Marius Hoegger, Raphael Stutz
#	Date:		  11.12.2018
#
#	stored in ./Code/createBaseSample.R

setwd("./")
library("RSQLite")

#connect with Database
sqlite.driver <- dbDriver("SQLite")
db = dbConnect(drv=sqlite.driver, dbname="./../SQL/Bugs.db")

# ***********************************************************************************
# *****VERSION***********************************************************************
# ***********************************************************************************
# Creating the Base-Sample where we filter out the observation we don't want to consider
# We are not considering:
# - bugs newer than 100 days (compared to the newest entry newest entry in the whole dataset)
# - bugs that are duplicates
# - bugs that have enhancemant as severity
# - bugs that are not on products CDT, JDT, Platform or PDE

IDsBaseSample = dbGetQuery( db,
                            'SELECT Reports.id, Reports.current_resolution, Reports.current_status, Reports.opening, Reports.reporter
                            FROM Reports
                            WHERE (Reports.current_resolution != "DUPLICATE") AND
                            Reports.id NOT IN (
                            SELECT StatusSample.id
                            FROM(
                            SELECT id, ((1304813581-maxTime)/86400) AS daysToLastDay
                            FROM (
                            SELECT id, what, CAST(MAX("when") AS INTEGER) AS maxTime
                            FROM Status
                            GROUP BY id HAVING "when" = maxTime
                            )
                            WHERE what = "NEW" AND daysToLastDay <= 100
                            ) StatusSample
                            ) AND
                            Reports.id IN (
                            SELECT SeveritySample.id
                            FROM (
                            SELECT id, what, CAST(MAX("when") AS INTEGER) AS maxTime
                            FROM Severity
                            GROUP BY id
                            HAVING "when" = maxTime
                            ) SeveritySample
                            WHERE (SeveritySample.what != "enhancement")
                            )
                            ;')
print("BaseSample created")
dbWriteTable(db, "BaseSample", IDsBaseSample, overwrite=TRUE)
print("BaseSample stored in Bugs.db")

#Disconnect
dbDisconnect(db)