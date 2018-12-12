#
#	Creates Categories for some of the Features to reduce number dummys
#
#	Author:		Marius Hoegger, Raphael Stutz
#	Date:		  11.12.2018
#
#	stored in ./Code/createCategories.R

setwd("./")

library(methods)
library("RSQLite")
library(stringr)
library(plyr)
library(dplyr)


#connect with Database
sqlite.driver <- dbDriver("SQLite")
db = dbConnect(drv=sqlite.driver, dbname="./../SQL/Bugs.db")

#DB to write Features into
featuredb<-dbConnect(RSQLite::SQLite(),"./../SQL/features.db")

### Author: Raphael
## Summary: This code creates categories for the variables Component and OS. 
#And it creates also categories for Version-Product pairs.

## To merge these tables with the ones in the database you have to use the "what" for Component and OS. 
#For the version table you have to use the what from Version
## AND the what from product to uniquely identify the rows.

library(stringr)

#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++OPERATING-SYSTEM++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

## This code calculates how many times each OS is reported. Further on, I try to come up with some logicial groupings of the different OS.
# 1.) BroadOS: I define a new variable that links all OS to either Windows, Mac, Solaris, Linux, Other, or All.
# 2.) BigOS: I define a new variable that assigns the rarely reported OS (N<250) to the Category "other". 
# The other OS are taken as given.
OSCat = dbGetQuery( db,'SELECT
                    COUNT(what) AS NumberOfCases,
                    what
                    FROM OS
                    GROUP BY what
                    ;')

# BroadOS
OSCat$BroadOS <- ifelse(grepl("Windows",OSCat$what),'Windows',
                        (ifelse(grepl("Mac",OSCat$what),'Mac',
                                (ifelse(grepl("Solaris",OSCat$what),'Other',
                                        (ifelse(grepl("Linux",OSCat$what),'Linux',
                                                (ifelse(grepl("Unix",OSCat$what),'Other',
                                                        (ifelse(grepl("All",OSCat$what),'All','Other')
                                                        ))
                                                ))
                                        ))
                                ))
                        ))
# DetailedOS
OSCat$DetailedOS <- ifelse(OSCat$what %in% c("Windows 2003 Server","Windows 95", "Windows 98", "Windows All", "Windows CE", "Windows ME", "Windows Mobile 2003", "Windows Me", "Windows Mobile 5.0", "Windows Server 2003", "Windows Server 2008", ""),'Windows Other',
                        (ifelse(OSCat$what %in% c("Windows Vista","Windows Vista Beta 2","Windows Vista-WPF"),'Windows Vista',
                              (ifelse(OSCat$what %in% c("Windows 2000"),'Windows 2000',
                                    (ifelse(OSCat$what %in% c("Windows 7"),'Windows 7',
                                          (ifelse(OSCat$what %in% c("Windows NT"),'Windows NT',
                                                (ifelse(OSCat$what %in% c("Windows XP"),'Windows XP',
                                                    (ifelse(OSCat$what %in% c("Mac OS","Mac OS X","Mac OS X - Cocoa","MacOS X"),'Mac OS X',
                                                        (ifelse(OSCat$what %in% c("Linux","Linux-GTK","Linux Qt","Linux-Motif"),'Linux',
                                                              (ifelse(OSCat$what %in% c("All"),'All',
                                                                  (ifelse(TRUE,'Other'))
                                                              ))
                                                        ))
                                                    ))
                                                ))
                                          ))
                                    ))
                              ))
                        ))
                    )
OSCat=OSCat[-1]
print("Categories for OS created")
dbWriteTable(db, "OSCat", OSCat, overwrite=TRUE)
print("OS categories stored in Bugs.db")


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++COMPONENTS++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# This code calculates how many times each Component is reported. Further on, 
# I try to come up with some logicial groupings of the different components.
# 1.) BigComponent: I define a new variable that assigns the rarely reported 
# Component (N<250) to the Category "other". The other OS are taken as given.


ComponentCat = dbGetQuery( db,'SELECT
                           COUNT(what) AS NumberOfCases,
                           what
                           FROM Component
                           GROUP BY what
                           ;')

ComponentCat$BigComponent <- ifelse(grepl("Update",ComponentCat$what),'Update',
                                    ifelse(ComponentCat$what %in% c("Update Site","Updater"),'Update',
                                           ifelse(ComponentCat$what %in% c("Runtime Common","Runtime","Runtime Diagram"),'Runtime',
                                                  ifelse(ComponentCat$what %in% c("ui","UI","Monitor.UI","Monitor.UI.SDBEditor","ATL-UI","Monitor.UI.GLARules","UI Guidelines","Platform.UI.ProfilingPerspective","Test.UI","Platform.UI.SequenceDiagram","Platform.UI","Trace.UI","Test.UI.Reporting","General UI","Platform.UI.StatsPerfViewers","Test.UI.JUnit","Debug-UI"),"UI",
                                                         ifelse(ComponentCat$what %in% c("core","Java Core","Core","alf-core","cdt-core","ecf.core"),"Core",
                                                                ifelse(ComponentCat$what=="releng","Releng",
                                                                       ifelse(ComponentCat$what %in% c("deprecated2","deprecated3","deprecated4","deprecated5","deprecated6","deprecated7","Update (deprecated - use RT>Equinox>p2)"),"deprecated",
                                                                              ifelse(ComponentCat$what %in% c("documentation","UML","UML2","DOC"),'Doc',
                                                                                     ifelse(grepl("Doc",ComponentCat$what),'Doc',
                                                                                            ifelse(ComponentCat$what %in% c("Build","Build/Web","cdt-build","cdt-build-managed"),"Build",
                                                                                                   ifelse(ComponentCat$what %in% c("DSF","Debug","Debug-MI","Debugger","cdt-debug","cdt-debug-cdi-gdb","cdt-debug-dsf","cdt-debug-dsf-gdb","cdt-debug-edc"),"Debug",
                                                                                                        ifelse(ComponentCat$what %in% c("IDE","Edit","Editor"),"Debug",
                                                                                                              ifelse(ComponentCat$NumberOfCases<1000,'Other',ComponentCat$what)
                                                                                                        ) 
                                                                                                   )
                                                                                            )
                                                                                     )
                                                                              )
                                                                       )
                                                                )
                                                         )
                                                  )
                                           )
                                    )
)
ComponentCat=ComponentCat[-1]
print("Categories for Components created")
dbWriteTable(db, "ComponentCat", ComponentCat, overwrite=TRUE)
print("Component categories stored in Bugs.db")


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++VERSION+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## This code selects all combinations of product and version. Further, I build groups for the variables in question.
# 1.) MajorVersionProduct: the 1 digit Version by Product
# 2.) MinorVersionProduct: the 2 digit Version by Product
# 3.) ServiceVersionProduct: the 3 digit Version by Product
# 4.) Segment: indicates the segment of the version

VersionCat = dbGetQuery( db,'
                          SELECT
                          Version.what AS Version,
                          Product.what AS Product
                          FROM (
                            SELECT id, what 
                            FROM (
                              SELECT id, what, MAX([when]) AS maxTime 
                              FROM Version 
                              GROUP BY id 
                              HAVING maxTime = [when]
                            )
                          ) Version
                          INNER JOIN (
                            SELECT id, what 
                            FROM(
                              SELECT id, what, MAX([when]) as maxTime 
                              FROM Product 
                              GROUP BY id 
                              HAVING maxTime = [when]
                            )
                          ) Product
                          ON Product.id = Version.id
                          GROUP BY Product.what, Version.what
                          ;')

VersionCat$temp <- gsub("[.]", "", VersionCat$Version)
VersionCat$temp <- gsub("0 DD ", "D", VersionCat$temp)
VersionCat$temp <- gsub("DD ", "D", VersionCat$temp)
VersionCat$Major = substr(VersionCat$temp,1,1)
VersionCat$MajorVersionProduct = group_indices(VersionCat,Product,Major)
VersionCat$Minor = substr(VersionCat$temp,1,2)
VersionCat$MinorVersionProduct = group_indices(VersionCat,Product,Minor)
VersionCat$ServiceVersionProduct = group_indices(VersionCat,Product,temp)

VersionCat$length=str_length(VersionCat$temp)
VersionCat$tt=substr(VersionCat$temp,2,2)=="0" & VersionCat$length==2
VersionCat$Segment = group_indices(VersionCat,tt,length)

VersionCat$Segment <- factor(VersionCat$Segment,
                             levels = c(3,1,2),
                             labels = c("Major", "Minor", "Service"))

VersionCat=VersionCat[-c(3,4,6,9,10)]

print("Categories for Version created")
dbWriteTable(db, "VersionCat", VersionCat, overwrite=TRUE)
print("Version categories stored in Bugs.db")


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++PRIORITY++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Compressing the Priority into only 3 categories:
# P1 and P2   -> high
# P3          -> medium
# P4 and 5    -> low

PriorityCat = dbGetQuery( db,'
                    SELECT
                    COUNT(what) AS NumberOfCases,
                    what
                    FROM Priority
                    GROUP BY what
                    ;')

# compress the categories
PriorityCat$compressedPriority <- ifelse(PriorityCat$what %in% c("P1","P2"),'high',
                                    (ifelse(PriorityCat$what %in% c("P3"),'medium',
                                        (ifelse(PriorityCat$what %in% c("P4","P5"),'low','None')
                                        )
                                    ))
                                  )

PriorityCat=PriorityCat[-1]

print("Categories for Priority created")
dbWriteTable(db, "PriorityCat", PriorityCat, overwrite=TRUE)
print("Priority categories stored in Bugs.db")


#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++SEVERITY++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## Compressing the Severity into only 3less categories:
# blocker and critical    -> critical
# major                   -> major
# normal                  -> normal
# minor and trivial       -> minor
# else                    -> enhancement
SeverityCat = dbGetQuery( db,'
                         SELECT
                         COUNT(what) AS NumberOfCases,
                         what
                         FROM Severity
                         GROUP BY what
                         ;')

# compress categories
SeverityCat$compressedSeverity <- ifelse(SeverityCat$what %in% c("blocker","critical"),'critical',
                                        (ifelse(SeverityCat$what %in% c("major"),'major',
                                                (ifelse(SeverityCat$what %in% c("normal"),'normal',
                                                (ifelse(SeverityCat$what %in% c("minor","trivial"),'minor','enhancement')
                                                )
                                        ))
                                  ))
)

SeverityCat=SeverityCat[-1]
print("Categories for Severity created")
dbWriteTable(db, "SeverityCat", SeverityCat, overwrite=TRUE)
print("Severity categories stored in Bugs.db")

#Disconnect
dbDisconnect(featuredb)
dbDisconnect(db)
