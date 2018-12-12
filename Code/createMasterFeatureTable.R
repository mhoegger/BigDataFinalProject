#
#	Put everything into one Table for easy access in the prediction
#
#	Author:		Marius Hoegger, Raphael Stutz, Andreas Egger
#	Date:		  11.12.2018
#
#	stored in ./Code/createMasterTable.R

setwd("./")
library("RSQLite")

#connect with Database
sqlite.driver <- dbDriver("SQLite")
db = dbConnect(drv=sqlite.driver, dbname="./../SQL/Bugs.db")

#DB to write Features into
featuredb<-dbConnect(RSQLite::SQLite(),"./../SQL/features.db")

master <- dbGetQuery(featuredb,
                     ' 
                     SELECT Target.id, target, Reports.reporter, numAssign, MajorVersionProduct, MinorVersionProduct, Segment,
                     component, bigComponent, broadOS, detailedOS, priority, comprPriority, 
                     Product.product, severity, comprSeverity, ageSoftwareVersionInDays, prioUPGrade, prioDownGrade,
                     sevDownGrade, sevUPGrade, Length, isReopened, numCC, isAssigned, numReassignments,
                     numPeopleInvolved, teamWorkRate, isModWithinFirstDay, hasUpdateToAttributes, numStatusUpdates,
                     isOpenForOneWeekOrMore, year, month, isAssignedToInbox, isAssignedToNobody,
                     firstAssignee, rateFirstAssignee, firstAssigner, rateFirstAssigner,
                     lastAssignee, rateLastAssignee, lastAssigner, rateLastAssigner, rateReporter
                     FROM Target
                     LEFT JOIN NumAssign on Target.id=NumAssign.id
                     LEFT JOIN HasUpdateToAttributes on Target.id=HasUpdateToAttributes.id
                     LEFT JOIN NumStatusUpdates on Target.id=NumStatusUpdates.id
                     LEFT JOIN Version on Target.id=Version.id
                     LEFT JOIN Component on Target.id=Component.id
                     LEFT JOIN DescriptionLength on Target.id=DescriptionLength.id
                     LEFT JOIN IsAssigned on Target.id=IsAssigned.id
                     LEFT JOIN IsReopened on Target.id=IsReopened.id
                     LEFT JOIN NumCC on Target.id=NumCC.id
                     LEFT JOIN OS on Target.id=OS.id
                     LEFT JOIN NumReassignments on Target.id=NumReassignments.id
                     LEFT JOIN Severity on Target.id=Severity.id
                     LEFT JOIN Priority on Target.id=Priority.id
                     LEFT JOIN UpdateSeverity on Target.id=UpdateSeverity.id
                     LEFT JOIN UpdatePriority on Target.id=UpdatePriority.id
                     LEFT JOIN Product on Target.id=Product.id
                     LEFT JOIN AgeSoftware on Target.id=AgeSoftware.id
                     LEFT JOIN NumPeopleInvolved on Target.id=NumPeopleInvolved.id
                     LEFT JOIN IsModWithinFirstDay on Target.id=IsModWithinFirstDay.id
                     LEFT JOIN TeamWork on Target.id=TeamWork.id
                     LEFT JOIN Reports on Target.id=Reports.id
                     LEFT JOIN IsOpenForOneWeekOrMore on Target.id=IsOpenForOneWeekOrMore.id
                     LEFT JOIN YearAndMonth on Target.id=YearAndMonth.id
                     LEFT JOIN AssignedToWhom on Target.id=AssignedToWhom.id
                     LEFT JOIN SuccessRateFirstAssignee on Target.id=SuccessRateFirstAssignee.id
                     LEFT JOIN SuccessRateFirstAssigner on Target.id=SuccessRateFirstAssigner.id
                     LEFT JOIN SuccessRateLastAssignee on Target.id=SuccessRateLastAssignee.id
                     LEFT JOIN SuccessRateLastAssigner on Target.id=SuccessRateLastAssigner.id
                     LEFT JOIN SuccessRateReporter on Target.id=SuccessRateReporter.id
                     GROUP BY Target.id
                     ;')

dbWriteTable(featuredb, "MasterTable", master, overwrite=TRUE)

#Disconnect
dbDisconnect(featuredb)
dbDisconnect(db)
