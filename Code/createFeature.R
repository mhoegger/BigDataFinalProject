#
#	Creates Tables for some Features and saves them into the features Database
#
#	Author:		Patricia Fischer, Andreas Egger, Marius Hoegger, Raphael Stutz
#	Date:		  11.12.2018
#
#	stored in ./Code/createFeature.R



setwd("./")
library("RSQLite")

#connect with Bug Database
sqlite.driver <- dbDriver("SQLite")
db = dbConnect(drv=sqlite.driver, dbname="./../SQL/Bugs.db")

#DB to write Features into
featuredb<-dbConnect(RSQLite::SQLite(),"./../SQL/features.db")


#-----------------------------------------------------------------------------------
#-----TARGET------------------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Marius Hoegger
# ###
# Convert the resolution into a  booliean value:
# 1 if FIXED
# 0 else
# ###
# Columns:
#   - id: Bug Id
#   - target: indicating if bug was fixed (1 = fixed, 0 = not fixed)

target <- dbGetQuery(db,
                     ' 
                     SELECT BaseSample.id,
                     (case when BaseSample.current_resolution  == "FIXED" Then 1 else 0 end) AS target
                     FROM BaseSample
                     INNER JOIN Product ON BaseSample.id=Product.id 
                     GROUP BY BaseSample.id;
                     ')

dbWriteTable(featuredb, "Target", target, overwrite=TRUE)

#-----------------------------------------------------------------------------------
#-----REPORTS-----------------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Marius Hoegger
# ###
# One to one copy of the BaseSample Table from the Bugs DB to the feature DB
# ###
# Columns:
#   - id: Bug Id
#   - current_resolution: indicates whether bug was fixed or what the final evaluation of the bug is
#   - current_status: status of the bug
#   - opening: timestamp when bug was opened
#   - reporter: id of the person reporting the bug

reports <- dbGetQuery(db,
                     ' 
                     SELECT *
                     FROM BaseSample
                     GROUP BY BaseSample.id;
                     ')

dbWriteTable(featuredb, "Reports", reports, overwrite=TRUE)

#-----------------------------------------------------------------------------------
#-----Number-Of-Assignments---------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Marius Hoegger
# ###
# Assigns to each bugId how many email adresses where adressed to it.
# ###
# Columns:
#   - id: Bug Id
#   - numAssign: number of different e-mail adresses the bug was assigned to

numAssign <- dbGetQuery(db,
                         paste(
                           '
                           SELECT BaseSample.id,  
                           count(AssignedTo.what) AS numAssign
                           FROM BaseSample 
                           INNER JOIN AssignedTo ON BaseSample.id=AssignedTo.id 
                           GROUP BY BaseSample.id 
                           ;', sep=""
                          )
                        )

dbWriteTable(featuredb, "NumAssign", numAssign, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----IS-REOPENED-------------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Patricia Fischer
# ###
# Dummy status for indicating whether Bug was ever REOPENED or not
# (1 if reopened, 0 otherwise)
# ###
# Columns:
#   - id: Bug Id
#   - isReopened: indicating if bug was reopened (1 = yes, 0 = no)


reopened = dbGetQuery(db, 
                      '
                      SELECT BaseSample.id,
                      max(case when Status.what  == "REOPENED" Then 1 else 0 end) AS isReopened
                      FROM BaseSample 
                      INNER JOIN Status ON BaseSample.id=Status.id 
                      GROUP BY BaseSample.id;
                      ')

dbWriteTable(featuredb, "IsReopened", reopened, overwrite=TRUE)

#-----------------------------------------------------------------------------------
#-----DESCRIPTION-LENGTH------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Length of Short Desctription (Absolute)

#Note: if multiple description for same Bug than add them together.

DescriptionLength = dbGetQuery(db, 
                               'SELECT BaseSample.id, 
                               SUM(LENGTH(ShortDesc.what)) AS length
                               FROM BaseSample 
                               INNER JOIN ShortDesc ON ShortDesc.id=BaseSample.id 
                               GROUP BY BaseSample.id
                               ')

dbWriteTable(featuredb, "DescriptionLength", DescriptionLength, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----Number-Of-CC------------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Number of Mail addresses (what) in CC per ID

NumberOfCC = dbGetQuery(db, 
                        'SELECT BaseSample.id, 
                        COUNT(CC.what) AS numCC
                        FROM BaseSample 
                        INNER JOIN CC ON CC.id=BaseSample.id 
                        GROUP BY BaseSample.id;
                        ')

dbWriteTable(featuredb, "NumCC", NumberOfCC, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----IS-ASSIGNED-------------------------------------------------------------------
#-----------------------------------------------------------------------------------
# This code creates a dummy variable that equals 1 if a bug has never been assigned to anyone, 
# 0 otherwise. Never assigned means that the AssignedTo.what variable equals "None". 
# In addition one has to check whether "None" was the value of the variable AssignedTo.what for 
# the entire lifetime of the bug. This is done by counting the number of reassignments. 
# Hence, the conditions AssignedTo.what = "None" and Reassignments = 0 filter  
# all bugs that have never been assigned to anyone.

IsAssigned = dbGetQuery( db,
                        'SELECT S2.id, (CASE WHEN at.what=="None" AND nReassignments==0 THEN 0 ELSE 1 END) AS isAssigned 
                         FROM(
                            SELECT S1.id, (COUNT(S1.id)-1) AS nReassignments, S1.[when] 
                            FROM(
                                SELECT id, opening AS [when] FROM BaseSample
                                UNION 
                                SELECT id, [when] FROM AssignedTo
                            ) S1
                            INNER JOIN BaseSample rep
                            ON rep.id=S1.id
                            GROUP BY S1.id
                         ) S2
                         INNER JOIN AssignedTo at
                         ON at.id=S2.id AND at.[when]=S2.[when];')


dbWriteTable(featuredb, "IsAssigned", IsAssigned, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----Number-Changes-Assignment-----------------------------------------------------
#-----------------------------------------------------------------------------------
# This code creates a variable that counts how many times a bug has been reassigned in its lifetime. 
# In the case of "0" reassignments one needs to keep in mind that this can occur in two instances
# which should probably be distinguished: 
#   1.) The bug has never been assigned to anyone; 
#   2.) The bug has been assigned to someone who then took care of it.

NChangesAssignment = dbGetQuery( db,'
                                 SELECT HS.id, (COUNT(HS.id)-1) AS numReassignments 
                                 FROM(
                                    SELECT id, opening AS [when] FROM BaseSample
                                    UNION 
                                    SELECT id, [when] FROM AssignedTo
                                 ) HS
                                 INNER JOIN BaseSample rep
                                 ON rep.id=HS.id
                                 GROUP BY HS.id;')

dbWriteTable(featuredb, "NumReassignments", NChangesAssignment, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----NPeopleInvolved---------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz
# ###
# This code creates a variable that counts how many people have been working on a bug. 
# Note, that I exclude the CC-file here because it is not clear 
# if someone how adds a cc also works on the bug, or is just interested in this bug.
# ###
# Columns:
#   - id: Bug Id
#   - numPeopleInvolved: how many people have been working on a bug

NPeopleInvolved = dbGetQuery( db,'SELECT S2.id, S2.numPeopleInvolved 
                              FROM (SELECT S1.id, COUNT(S1.id) AS numPeopleInvolved
                              FROM(SELECT id, Reporter AS who from BaseSample
                              UNION
                              SELECT id, who from AssignedTo
                              UNION
                              SELECT id, who from Priority
                              UNION
                              SELECT id, who from Component
                              UNION
                              SELECT id, who from OS
                              UNION
                              SELECT id, who from Product
                              UNION
                              SELECT id, who from Severity
                              UNION
                              SELECT id, who from Status
                              UNION
                              SELECT id, who from Resolution
                              UNION
                              SELECT id, who from ShortDesc
                              UNION
                              SELECT id, who from Version) S1
                              GROUP BY S1.id) S2
                              JOIN BaseSample
                              ON S2.id = BaseSample.id
                              ')

dbWriteTable(featuredb, "NumPeopleInvolved", NPeopleInvolved, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----TeamWork----------------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz
# ###
# This code calculates the teamwork rate by reporter. 
# I count the number of times a reporter has worked on the same bug with someone else 
# and divide it by the total number of bugs a reporter has worked on. 
# I again do not consider the attribute CC because it is unclear to me what exactly the function of this field is.
# ###
# Columns:
#   - id: Bug Id
#   - teamWorkRate: how ofter a reporter worked on the same bug 
#                   with someone else / number of bugs worked on (value between 0 and 1)

TeamWork = dbGetQuery( db,'
                       SELECT BaseSample.id, S8.teamWorkRate
                       FROM BaseSample
                       LEFT JOIN (SELECT S7.who, (CAST(NInvolvedTeams AS REAL)/CAST(NBugsByReporter AS REAL)) AS teamWorkRate  
                       FROM(
                       SELECT S4.who, SUM(dummyTeam) AS NInvolvedTeams
                       FROM(
                       SELECT S2.id, (CASE WHEN teamPlayer>1 THEN 1 ELSE 0 END) AS dummyTeam 
                       FROM(
                       SELECT S1.id, COUNT(S1.id) AS teamPlayer
                       FROM(
                       SELECT id, Reporter as who from BaseSample
                       UNION
                       SELECT id, who from AssignedTo
                       UNION
                       SELECT id, who from Priority
                       UNION
                       SELECT id, who from Component
                       UNION
                       SELECT id, who from OS
                       UNION
                       SELECT id, who from Product
                       UNION
                       SELECT id, who from Severity
                       UNION
                       SELECT id, who from Status
                       UNION
                       SELECT id, who from Resolution
                       UNION
                       SELECT id, who from ShortDesc
                       UNION
                       SELECT id, who from Version
                       ) S1
                       LEFT JOIN BaseSample
                       ON BaseSample.id=S1.id
                       GROUP BY S1.id
                       ) S2 
                       ) S3
                       INNER JOIN (
                       SELECT id, Reporter as who from BaseSample
                       UNION
                       SELECT id, who from AssignedTo
                       UNION
                       SELECT id, who from Priority
                       UNION
                       SELECT id, who from Component
                       UNION
                       SELECT id, who from OS
                       UNION
                       SELECT id, who from Product
                       UNION
                       SELECT id, who from Severity
                       UNION
                       SELECT id, who from Status
                       UNION
                       SELECT id, who from Resolution
                       UNION
                       SELECT id, who from ShortDesc
                       UNION
                       SELECT id, who from Version
                       ) S4
                       ON S4.id=S3.id
                       GROUP BY S4.who
                       ) S5
                       INNER JOIN (
                       SELECT S6.who, count(S6.who) AS NBugsByReporter
                       FROM(
                       SELECT id, Reporter as who from BaseSample
                       UNION
                       SELECT id, who from AssignedTo
                       UNION
                       SELECT id, who from Priority
                       UNION
                       SELECT id, who from Component
                       UNION
                       SELECT id, who from OS
                       UNION
                       SELECT id, who from Product
                       UNION
                       SELECT id, who from Severity
                       UNION
                       SELECT id, who from Status
                       UNION
                       SELECT id, who from Resolution
                       UNION
                       SELECT id, who from ShortDesc
                       UNION
                       SELECT id, who from Version
                       ) S6
                       LEFT JOIN BaseSample
                       ON BaseSample.id=S6.id
                       GROUP BY S6.who
                       ) S7
                       ON S7.who=S5.who) S8
                       ON BaseSample.reporter = S8.who
                       
                       ;')

dbWriteTable(featuredb, "TeamWork", TeamWork, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----ModWithinFirstDay-------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz
# ###
# This code creates a dummy that equals 1 if the bug has been modified (worked on) within 1 day, 
# it equals 0 otherwise. Note that there is something wrong with the ID "264963" 
# because the calculated number is negative. The timestamp from the inital report 
# seems to be wrong (check the bug.eclipse report)
# ###
# Columns:
#   - id: Bug Id
#   - isModWithinFirstDay: 1 if bug was worked on, else 0


ModWithinFirstDay = dbGetQuery( db,'SELECT Set2.id, 
                                (CASE WHEN (SUM(CASE WHEN (NMinutesMod > 0 AND NMinutesMod < 1401) THEN 1 ELSE 0 END)) > 0 THEN 1 ELSE 0 END) AS isModWithinFirstDay
                                FROM(
                                  SELECT Set1.id, Set1.time, BaseSample.opening AS minTime, ((CAST(Set1.time AS INTEGER) - CAST(BaseSample.opening AS INTEGER))/60) AS NMinutesMod 
                                  FROM(
                                    SELECT id, opening AS time 
                                    FROM BaseSample
                                    UNION 
                                    SELECT id, "when" AS time FROM AssignedTo
                                    UNION 
                                    SELECT id, "when" AS time FROM CC
                                    UNION 
                                    SELECT id, "when" AS time FROM Component
                                    UNION 
                                    SELECT id, "when" AS time FROM OS
                                    UNION 
                                    SELECT id, "when" AS time FROM Priority
                                    UNION
                                    SELECT id, "when" AS time FROM Product
                                    UNION
                                    SELECT id, "when" AS time FROM Severity
                                    UNION 
                                    SELECT id, "when" AS time FROM ShortDesc
                                    UNION 
                                    SELECT id, "when" AS time FROM Version
                                    UNION
                                    SELECT id, "when" AS time FROM Resolution
                                  ) Set1
                                  INNER JOIN BaseSample
                                  ON BaseSample.id=Set1.id
                                ) Set2
                                GROUP BY Set2.id
                                ;')

dbWriteTable(featuredb, "IsModWithinFirstDay", ModWithinFirstDay, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----UPDATE-TO-ATTRIBUTE-----------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz
# ###
# This code creates a dummy variable which equals 1 if there has been a change to one 
# of the basic attributes (excluding AssignedTo, Resolution, Status), it is 0 otherwise.
# ###
# Columns:
#   - id: Bug Id
#   - hasUpdateToAttributes: 1 if there are updates, else 0

UpdateToAttributes = dbGetQuery( db,'
                                 SELECT BaseSample.id, S3.hasUpdateToAttributes
                                 FROM BaseSample
                                 LEFT JOIN
                                 (SELECT 
                                 Set2.id, 
                                 (CASE WHEN NModified > 1 THEN 1 ELSE 0 END) AS hasUpdateToAttributes
                                 FROM
                                 (SELECT Set1.id, COUNT(Set1.id) AS NModified 
                                 FROM
                                 (
                                 SELECT id, opening AS [when] from BaseSample
                                 UNION
                                 SELECT id, [when] from Priority
                                 UNION
                                 SELECT id, [when] from Component
                                 UNION
                                 SELECT id, [when] from OS
                                 UNION
                                 SELECT id, [when] from Product
                                 UNION
                                 SELECT id, [when] from Severity
                                 UNION
                                 SELECT id, [when] from ShortDesc
                                 UNION
                                 SELECT id, [when] from Version
                                 ) Set1
                                 GROUP BY Set1.id
                                 ) Set2) S3
                                 ON S3.id = BaseSample.id
                                 
                                 ;')


dbWriteTable(featuredb, "HasUpdateToAttributes", UpdateToAttributes, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----NUMBER-OF-STATUS-UPDATES------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Andreas Egger
# ###
# Counts the number of times the Status has been updated
# ###
# Columns:
#   - id: Bug Id
#   - numStatusUpdates: number of updates

X5 = dbGetQuery(db,
                'SELECT id, numStatusUpdates  FROM(
                SELECT Status.id, BaseSample.current_resolution, 
                COUNT(Status.id) AS numStatusUpdates
                FROM Status INNER JOIN BaseSample ON BaseSample.id=Status.id
                GROUP BY Status.id
)')

X5[,2] = X5[,2]-1
head(X5)

dbWriteTable(featuredb, "NumStatusUpdates", X5 ,overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----Version---------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz, 
# Modified: Marius Hoegger
# ###
# Makes the link between version number and the product of a bug.
# Assigns unique id to each combination of product and version categorised in Major, Minor and Service Release
# ###
# Columns:
#   - id: Bug Id
#   - Version: version number
#   - product: product
#   - MajorVersionProduct: id of MajorReleasesNumber (different for different products)
#   - MinorVersionProduct: id of MinorReleasesNumber (different for different products)
#   - ServiceVersionProduct: id of ServiceReleasesNumber (different for different products)
#   - Segment: denotes wheter it was a Major, Minor or Service Release

version <- dbGetQuery(db,' 
                      SELECT id, P1.Version, P1.Product, MajorVersionProduct, MinorVersionProduct, ServiceVersionProduct, Segment
                      FROM(
                        SELECT S3.id, S3.Version, A3.Product 
                        FROM(
                          SELECT BaseSample.id AS id, S2.what AS Version
                          FROM BaseSample
                          INNER JOIN (
                            SELECT Version.id, Version.what FROM Version
                            INNER JOIN (
                              SELECT Version.id, MAX(Version."when") AS mWhen 
                              FROM Version 
                              GROUP BY Version.id
                            ) S1
                            ON Version.id = S1.id
                            AND Version."when" = S1.mWhen
                          ) S2 ON BaseSample.id=S2.id 
                          GROUP BY BaseSample.id
                        ) S3
                      INNER JOIN (
                        SELECT BaseSample.id AS id, A2.what AS Product
                        FROM BaseSample
                        INNER JOIN (
                          SELECT Product.id, Product.what FROM Product
                          INNER JOIN (
                            SELECT Product.id, MAX(Product."when") AS mWhen 
                            FROM Product 
                            GROUP BY Product.id
                          ) A1
                          ON Product.id = A1.id
                          AND Product."when" = A1.mWhen
                        ) A2 ON BaseSample.id=A2.id 
                        GROUP BY BaseSample.id
                      ) A3
                      ON S3.id = A3.id 
                      GROUP BY S3.id
                    ) P1
                    LEFT JOIN VersionCat
                      ON P1.Version = VersionCat.Version
                      AND P1.Product = VersionCat.Product
                      GROUP BY P1.id;
                      ')

dbWriteTable(featuredb, "Version", version, overwrite=TRUE)

#-----------------------------------------------------------------------------------
#-----Component---------------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Marius Hoegger
# ###
# Filters the components to only use BaseSample data and reduces the component if multiple are assigned to the one
# that was assignes the last.
# assigned the component categorie to the bug
# ###
# Columns:
#   - id: Bug Id
#   - component: original component that was assigned as last
#   - bigComponent: according component categorie (see createCategories.R)

component <- dbGetQuery(db,' 
                        SELECT id, S1.Component AS component, ComponentCat.BigComponent as bigComponent
                        FROM(
                          SELECT BaseSample.id,S3.what AS Component
                          FROM BaseSample
                          INNER JOIN (
                            SELECT Component.id, Component.what 
                            FROM Component
                            INNER JOIN (
                              SELECT Component.id, MAX(Component."when") AS mWhen 
                              FROM Component GROUP BY Component.id
                            ) S2
                            ON Component.id = S2.id
                            AND Component."when" = S2.mWhen
                          ) S3
                          ON BaseSample.id=S3.id 
                          GROUP BY BaseSample.id
                        ) S1
                        INNER JOIN ComponentCat
                        ON ComponentCat.what = S1.Component;
                        ')

dbWriteTable(featuredb, "Component", component, overwrite=TRUE)

#-----------------------------------------------------------------------------------
#-----OS---------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Marius Hoegger
# ###
# Filters the OS to only use BaseSample data and reduces the OS if multiple are assigned to the one
# that was assignes the last.
# assigned the OS categorie to the bug
# ###
# Columns:
#   - id: Bug Id
#   - allOS: original OS that was assigned as last
#   - BroadOS: according OS categorie "BroadOS" (see createCategories.R)
#   - DetailedOS: according OS categorie "DetailedOS" (see createCategories.R)

os <- dbGetQuery(db,' 
                 SELECT id, S1.OS AS allOS, BroadOS AS broadOS, DetailedOS AS detailedOS
                 FROM(
                  SELECT BaseSample.id,S3.what AS OS
                  FROM BaseSample
                  INNER JOIN (
                    SELECT OS.id, OS.what 
                    FROM OS
                    INNER JOIN (
                      SELECT OS.id, MAX(OS."when") AS mWhen 
                      FROM OS GROUP BY OS.id
                    ) S2
                    ON OS.id = S2.id
                    AND OS."when" = S2.mWhen
                  ) S3
                  ON BaseSample.id=S3.id 
                  GROUP BY BaseSample.id
                 ) S1
                 INNER JOIN OSCat
                 ON OSCat.what = S1.OS;
                 ')

dbWriteTable(featuredb, "OS", os, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----Priority---------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Marius Hoegger, Raphael Stutz
# ###
# Filters the Prority to only use BaseSample data and reduces the Priority if multiple are assigned to the one
# that was assignes the last.
# assigned the Priority categorie to the bug
# ###
# Columns:
#   - id: Bug Id
#   - priority: original Priority that was assigned as last
#   - comprPriority: according Priority categorie "comprPriority" (see createCategories.R)

Priority <- dbGetQuery(db,
                       'SELECT id, S3.Priority AS priority, PriorityCat.compressedPriority AS comprPriority
                        FROM(
                          SELECT BaseSample.id, (S2.what) AS Priority
                          FROM BaseSample
                          INNER JOIN (
                            SELECT Priority.id, Priority.what 
                            FROM Priority
                            INNER JOIN (
                              SELECT Priority.id, MAX(Priority."when") AS mWhen 
                              FROM Priority 
                              GROUP BY Priority.id
                            ) S1
                            ON Priority.id = S1.id
                            AND Priority."when" = S1.mWhen
                          ) S2 
                          ON BaseSample.id=S2.id 
                          GROUP BY BaseSample.id
                        ) S3
                      INNER JOIN PriorityCat
                      ON PriorityCat.what = S3.Priority;
                 ')

                       

dbWriteTable(featuredb, "Priority", Priority, overwrite=TRUE)

#-----------------------------------------------------------------------------------
#-----Product---------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Marius Hoegger
# ###
# Filters the Product to only use BaseSample data and reduces the Product if multiple are assigned to the one
# that was assignes the last.
# ###
# Columns:
#   - id: Bug Id
#   - product: original Product that was assigned as last

Product <- dbGetQuery(db,
                       ' 
                          SELECT BaseSample.id, (S2.what) AS product
                          FROM BaseSample
                          INNER JOIN (
                            SELECT Product.id, Product.what 
                            FROM Product
                            INNER JOIN (
                              SELECT Product.id, MAX(Product."when") AS mWhen 
                              FROM Product 
                              GROUP BY Product.id
                            ) S1
                            ON Product.id = S1.id
                            AND Product."when" = S1.mWhen
                          ) S2 
                          ON BaseSample.id=S2.id 
                          GROUP BY BaseSample.id;
                 ')
                       
dbWriteTable(featuredb, "Product", Product, overwrite=TRUE)

#-----------------------------------------------------------------------------------
#-----Severity----------------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Marius Hoegger, Raphael Stutz
# ###
# Filters the Severity to only use BaseSample data and reduces the Severity if multiple are assigned to the one
# that was assignes the last.
# assigned the Severity categorie to the bug
# ###
# Columns:
#   - id: Bug Id
#   - severity: original Severity that was assigned as last
#   - comprPriority: according Severity categorie "comprSeverity" (see createCategories.R)

Severity <- dbGetQuery(db,' 
                    SELECT id, S1.Severity AS severity, SeverityCat.compressedSeverity AS comprSeverity
                    FROM(
                      SELECT BaseSample.id, S3.what AS Severity
                      FROM BaseSample
                      INNER JOIN (
                        SELECT Severity.id, Severity.what 
                        FROM Severity
                        INNER JOIN (
                          SELECT Severity.id, MAX(Severity."when") AS mWhen 
                          FROM Severity GROUP BY Severity.id
                        ) S2
                        ON Severity.id = S2.id
                        AND Severity."when" = S2.mWhen
                      ) S3 
                      ON BaseSample.id=S3.id 
                      GROUP BY BaseSample.id
                    ) S1
                    INNER JOIN SeverityCat
                    ON SeverityCat.what = S1.Severity;
                    ')                       

dbWriteTable(featuredb, "Severity", Severity, overwrite=TRUE)

#-----------------------------------------------------------------------------------
#-----IS-OPEN-FOR-ONE-WEEK-OR-MORE--------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz
# ###
# This code creates a dummy that equals 1 if the bug has been open for more than one week, it equals 0 otherwise.
# Note that there is something wrong with the ID "264963" because the calculated number is negative. 
# The timestamp from the inital report seems to be wrong (check the bug.eclipse report)
# If you want to calculate the same variable for say one month (30days), 
# just replace 9801 with the number of minutes that equal 30days + 1 min
# ###
# Columns:
#   - id: Bug Id
#   - isOpenForOneWeekOrMore: 1 if open for longer than one week, 0 else

OpenForOneWeekOrMore = dbGetQuery( db,'
                                   SELECT 
                                   Set2.id, 
                                   (CASE WHEN 
                                   (SUM(CASE WHEN 
                                   (NMinutesMod > 9801) 
                                   THEN 1 ELSE 0 END)
                                   ) > 0 
                                   THEN 1 ELSE 0 END) AS isOpenForOneWeekOrMore
                                   FROM
                                   (
                                   SELECT 
                                   Set1.id, 
                                   Set1.time, 
                                   BaseSample.opening AS minTime, 
                                   ((CAST(Set1.time AS INTEGER) - CAST(BaseSample.opening AS INTEGER))/60) AS NMinutesMod 
                                   FROM
                                   (
                                   SELECT id, opening AS time FROM BaseSample
                                   UNION 
                                   SELECT id, "when" AS time FROM AssignedTo
                                   UNION 
                                   SELECT id, "when" AS time FROM CC
                                   UNION 
                                   SELECT id, "when" AS time FROM Component
                                   UNION 
                                   SELECT id, "when" AS time FROM OS
                                   UNION 
                                   SELECT id, "when" AS time FROM Priority
                                   UNION
                                   SELECT id, "when" AS time FROM Product
                                   UNION
                                   SELECT id, "when" AS time FROM Severity
                                   UNION 
                                   SELECT id, "when" AS time FROM ShortDesc
                                   UNION 
                                   SELECT id, "when" AS time FROM Version
                                   UNION
                                   SELECT id, "when" AS time FROM Resolution
                                   ) Set1
                                   INNER JOIN BaseSample
                                   ON BaseSample.id=Set1.id
                                   ) Set2
                                   GROUP BY Set2.id
                                   ;')

dbWriteTable(featuredb, "IsOpenForOneWeekOrMore", OpenForOneWeekOrMore, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----YEAR-AND-MONTH----------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz
# ###
# This code calculates year and month of the bug report.
# ###
# Columns:
#   - id: Bug Id
#   - year: Year
#   - month: month

YearAndMonth = dbGetQuery( db,'
                           SELECT 
                           id, 
                           strftime("%Y", datetime([opening], "unixepoch")) as year, 
                           strftime("%m", datetime([opening], "unixepoch")) AS month 
                           FROM BaseSample
                           ;')

dbWriteTable(featuredb, "YearAndMonth", YearAndMonth, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----AGE-SOFTWARE------------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz
# ###
# This code calculates the age of the software version in days by BUG id. 
# I take the 10th lowest time [when] value by (Version-Product)-pair as the first Appearance of a (Version-Product) pair. 
# This is to improve the quality of the feature by reducing the influence of outliers.
# ###
# Columns:
#   - id: Bug Id
#   - ageSoftwareversionInDays: days since the product version was relesed (10th appereance)


# FirstAppearanceSoftware = dbGetQuery(db,'
#                                      SELECT
#                                      Set1.Product,
#                                      Set1.Version,
#                                      MAX(Set1.time) AS firstAppearance
#                                      FROM
#                                      (
#                                      SELECT
#                                      Version.id,
#                                      Product,
#                                      Version,
#                                      time
#                                      FROM 
#                                      (
#                                      SELECT
#                                      id,
#                                      [when] AS time,
#                                      Version
#                                      FROM 
#                                      (
#                                      SELECT 
#                                      id, 
#                                      [when], 
#                                      REPLACE(What,"0 D","D") as Version /* Clean some of the Version values "0 DD.." "DD.. are actually the same*/
#                                      FROM Version
#                                      )
#                                      GROUP BY id 
#                                      HAVING MAX([when])=[when]
#                                      ) Version
#                                      INNER JOIN 
#                                      (
#                                      SELECT
#                                      id,
#                                      what as Product
#                                      FROM Product
#                                      GROUP BY id 
#                                      HAVING MAX([when])=[when]
#                                      ) Product
#                                      ON Product.id = Version.id
#                                      ) Set1
#                                      WHERE 
#                                      (
#                                      SELECT 
#                                      COUNT(*)
#                                      FROM
#                                      (
#                                      SELECT
#                                      Version.id,
#                                      Product,
#                                      Version,
#                                      time
#                                      FROM 
#                                      (
#                                      SELECT
#                                      id,
#                                      [when] AS time,
#                                      Version
#                                      FROM 
#                                      (
#                                      SELECT 
#                                      id, 
#                                      [when], 
#                                      REPLACE(what,"0 D","D") as Version 
#                                      FROM Version
#                                      )
#                                      GROUP BY id 
#                                      HAVING MAX([when])=[when]
#                                      ) Version
#                                      INNER JOIN 
#                                      (
#                                      SELECT
#                                      id,
#                                      what as Product
#                                      FROM Product
#                                      GROUP BY id 
#                                      HAVING MAX([when])=[when]
#                                      ) Product
#                                      ON Product.id = Version.id
#                                      ) Set2
#                                      WHERE 
#                                      (
#                                      Set1.Product = Set2.Product 
#                                      AND 
#                                      Set1.Version = Set2.Version 
#                                      AND 
#                                      Set2.time <= Set1.time) 
#                                      ) <=10
#                                      GROUP BY Set1.Product, Set1.Version;')
# 
# 
# 
# VersionProduct = dbGetQuery( db,'
#                              SELECT Set1.id, Set1.opening, Version, Product.what AS Product
#                              FROM(SELECT BaseSample.id, BaseSample.opening, REPLACE(Version.what,"0 D","D") AS Version
#                              FROM BaseSample
#                              INNER JOIN Version
#                              ON BaseSample.id = Version.id
#                              GROUP BY BaseSample.id
#                              Having MAX(Version.[when])=[when]) Set1
#                              INNER JOIN Product
#                              ON Set1.id = Product.id
#                              GROUP BY Set1.id
#                              HAVING MAX(Product.[when])=[when];')
# 
# 
# AgeSoftware = merge(VersionProduct,FirstAppearanceSoftware)
# AgeSoftware$ageSoftwareVersionInDays = round((as.numeric(AgeSoftware$opening)-as.numeric(AgeSoftware$firstAppearance))/86400,digits = 0)
# AgeSoftware[,6][AgeSoftware[, 6] < 0] <- 0
# AgeSoftware=AgeSoftware[-c(1,2,4,5)]
# 
# dbWriteTable(featuredb, "AgeSoftware", AgeSoftware, overwrite=TRUE)


# rm(VersionProduct)
# rm(FirstAppearanceSoftware)

#-----------------------------------------------------------------------------------
#-----ASSIGNED-TO-WHOM----------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz
# ###
# This code creates two dummy variables. 
# 1.) assignedToInbox: 1 if the initial report was assigned to an Inbox (inbox,Inbox, or webmaster in email), zero otherwise.
# 2.) assignedToNobody: 1 if the initial report was assigned to nobody (none, " ", or UNKNOWN in email field), zero otherwise.
# The third category (assignedToPerson) is ommited.
# ###
# Columns:
#   - id: Bug Id
#   - isAssignedToInbox: 1 if assigned to Inbox, 0 else
#   - isAssignedToNobody: 1 if assignet to None, 0 else

AssignedToWhom = dbGetQuery( db,
                             'SELECT 
                             BaseSample.id, 
                             (CASE WHEN 
                             (instr(at.what,"inbox")>0 OR instr(at.what,"Inbox")>0 OR instr(at.what,"webmaster")>0)
                             THEN 1 ELSE 0 END) AS isAssignedToInbox,
                             (CASE WHEN
                             at.what=="None" OR at.what=="" OR at.what=="__UNKNOWN__"
                             THEN 1 ELSE 0 END) AS isAssignedToNobody
                             FROM BaseSample
                             INNER JOIN AssignedTo at
                             ON at.id=BaseSample.id AND at.[when]=BaseSample.opening
                             GROUP BY BaseSample.id;')

dbWriteTable(featuredb, "AssignedToWhom", AssignedToWhom, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----UPDATE-PRIORITY------------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz
# ###
# UpdatePriority
# This code creates two dummy variables. prioDownGrade equals 1 if the priority of a bug has been downgraded (0 otherwise),
# prioUPGrade equals 1 if a priority of a bug has been upgraded (0 otherwise).
# ###
# Columns:
#   - id: Bug Id
#   - prioUPGrade: 1 if upgraded, 0 else
#   - prioDownGrade: 1 if downgraded, 0 else

UpdatePriority = dbGetQuery( db,'
                              SELECT S1.id, S1.prioUPGrade, S1.prioDownGrade
                              FROM (
                                SELECT
                                Set1.id,
                                (CASE WHEN (initPrio-lastPrio) > 0 THEN 1 ELSE 0 END) AS prioUPGrade,
                                (CASE WHEN (lastPrio-initPrio) > 0 THEN 1 ELSE 0 END) AS prioDownGrade
                                FROM (
                                  SELECT 
                                  id, 
                                  REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(what,"P",""),"1","2"),"4","3"),"5","3"),"NONE","1") AS initPrio
                                  FROM Priority
                                  GROUP BY id
                                  HAVING [when]=MIN([when])
                                ) Set1
                                INNER JOIN (
                                  SELECT
                                  id,
                                  REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(what,"P",""),"1","2"),"4","3"),"5","3"),"NONE","1") AS lastPrio
                                  FROM Priority
                                  GROUP BY id
                                  HAVING [when]=MAX([when])
                                ) Set2
                                ON Set2.id=Set1.id
                              ) S1
                              INNER JOIN BaseSample
                              ON S1.id = BaseSample.id;')

dbWriteTable(featuredb, "UpdatePriority", UpdatePriority, overwrite=TRUE)

#-----------------------------------------------------------------------------------
#-----UPDATE-SEVERITY---------------------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz
# ###
# UpdateSeverity
# This code creates two dummies. sevDownGrade equals one if the severity value has been downgraded (0 otherwise), 
# sevUPGrade equals 1 if the severity has been upgraded (0 otherwise).
# ###
# Columns:
#   - id: Bug Id
#   - sevUPGrade: 1 if upgraded, 0 else
#   - sevDownGrade: 1 if downgraded, 0 else

UpdateSeverity = dbGetQuery( db,' 
                              SELECT S1.id, S1.sevDownGrade, S1.sevUPGrade
                              FROM ( 
                                SELECT
                                Set1.id,
                                (CASE WHEN (initSev-lastSev) > 0 THEN 1 ELSE 0 END) AS sevDownGrade,
                                (CASE WHEN (lastSev-initSev) > 0 THEN 1 ELSE 0 END) AS sevUPGrade
                                FROM (
                                  SELECT 
                                  id, 
                                  REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(what,"trivial","1"),"minor","1"),"normal","2"),"major","3"),"critical","3"),"blocker","3") AS initSev 
                                  FROM Severity
                                  GROUP BY id
                                  HAVING [when]=MIN([when])
                                ) Set1
                                INNER JOIN (
                                  SELECT
                                  id,
                                  REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(what,"trivial","1"),"minor","1"),"normal","2"),"major","3"),"critical","3"),"blocker","3") AS lastSev
                                  FROM Severity
                                  GROUP BY id
                                  HAVING [when]=MAX([when])
                                ) Set2
                                ON Set2.id=Set1.id
                              ) S1
                              INNER JOIN BaseSample
                              ON S1.id = BaseSample.id
                             ;')

dbWriteTable(featuredb, "UpdateSeverity", UpdateSeverity, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----SUCCESS-RATE-FIRST-ASSIGNER---------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz
# ###
# This code calculates a variables that shows the past success rate of the first Assigner of a bug id. (0 to 1)
# ###
# Columns:
#   - id: Bug Id
#   - firstAssigner: initial, first ever assigner
#   - rateFirstAssigner: sequential successrate of the first assigner
SuccessRateAssigner_tem = dbGetQuery (db, 
                                      'SELECT 
                                      AssignedTo.id,
                                      AssignedTo.who AS firstAssigner,
                                      CAST(AssignedTo.[when] AS INT) AS [when],
                                      (CASE WHEN 
                                      BaseSample.current_resolution == "FIXED"
                                      THEN 1 ELSE 0 END) AS Fixed
                                      FROM AssignedTo
                                      INNER JOIN BaseSample
                                      ON (BaseSample.id = AssignedTo.id AND BaseSample.opening = AssignedTo.[when])
                                      ;')

# merge to the Bug ids of the base sample to exclude the bugs that we're not covering
SuccessRateAssigner1 <- SuccessRateAssigner_tem
# create variable needed for the calculation of the cummulative sum
SuccessRateAssigner1$N = 1
# order data.frame: firstAssigner, when
SuccessRateAssigner1[order(SuccessRateAssigner1$firstAssigner,SuccessRateAssigner1$when),]
# calculate cummulative sum of the number of times a assigner appears
SuccessRateAssigner1$AssignerCumSum <- ave(SuccessRateAssigner1$N, SuccessRateAssigner1$firstAssigner, FUN=cumsum)
# calculate cummulative sum of the number of bugs fixed by assigner
SuccessRateAssigner1$FixedCumSum <- ave(SuccessRateAssigner1$Fixed, SuccessRateAssigner1$firstAssigner, FUN=cumsum)
# Take away 1 from the FixedCumSum when Fixed equals 1 (we want to look at the past successrate)
indices <- (SuccessRateAssigner1$Fixed==1)
SuccessRateAssigner1$FixedCumSum[indices] = (SuccessRateAssigner1$FixedCumSum-1)[indices]
# calculate the successrate of the last assigner
SuccessRateAssigner1$rateFirstAssigner = ((SuccessRateAssigner1$FixedCumSum)/(SuccessRateAssigner1$AssignerCumSum))
# remove not-needed columns
SuccessRateAssigner1 = SuccessRateAssigner1[,-c(3,4,5,6,7)]

dbWriteTable(featuredb, "SuccessRateFirstAssigner", SuccessRateAssigner1, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----SUCCESS-RATE-LAST-ASSIGNER----------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz
# ###
# This code calculates a variable that shows the past success rate of the last assigner of a bug id. (0 to 1)
# ###
# Columns:
#   - id: Bug Id
#   - lastAssigner: last assigning assigner
#   - rateLastAssigner: sequential successrate of the last assigner
SuccessRateAssigner_tem2 = dbGetQuery (db, 
                                      'SELECT 
                                      AssignedTo.id,
                                      AssignedTo.who AS lastAssigner,
                                      CAST(AssignedTo.[when] AS INT) AS [when],
                                      (CASE WHEN 
                                      BaseSample.current_resolution == "FIXED"
                                      THEN 1 ELSE 0 END) AS Fixed
                                      FROM AssignedTo
                                      INNER JOIN BaseSample
                                      ON (BaseSample.id = AssignedTo.id)
                                      GROUP BY BaseSample.id
                                      HAVING MAX(AssignedTo.[when]) = AssignedTo.[when]
                                      ;
                                      ')

# merge to the Bug ids of the base sample to exclude the bugs that we're not covering
SuccessRateAssigner2 <- SuccessRateAssigner_tem2
# create variable needed for the calculation of the cummulative sum
SuccessRateAssigner2$N = 1
# order data.frame: lastAssigner, when
SuccessRateAssigner2[order(SuccessRateAssigner2$lastAssigner,SuccessRateAssigner2$when),]
# calculate cummulative sum of the number of times a assigner appears
SuccessRateAssigner2$AssignerCumSum <- ave(SuccessRateAssigner2$N, SuccessRateAssigner2$lastAssigner, FUN=cumsum)
# calculate cummulative sum of the number of bugs fixed by assigner
SuccessRateAssigner2$FixedCumSum <- ave(SuccessRateAssigner2$Fixed, SuccessRateAssigner2$lastAssigner, FUN=cumsum)
# Take away 1 from the FixedCumSum when Fixed equals 1 (we want to look at the past successrate)
indices <- (SuccessRateAssigner2$Fixed==1)
SuccessRateAssigner2$FixedCumSum[indices] = (SuccessRateAssigner2$FixedCumSum-1)[indices]
# calculate the successrate of the last assigner
SuccessRateAssigner2$rateLastAssigner = ((SuccessRateAssigner2$FixedCumSum)/(SuccessRateAssigner2$AssignerCumSum))
# remove not-needed columns
SuccessRateAssigner2 = SuccessRateAssigner2[,-c(3,4,5,6,7)]

dbWriteTable(featuredb, "SuccessRateLastAssigner", SuccessRateAssigner2, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----SUCCESS-RATE-FIRST-ASSIGNEE---------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz
# ###
# This code calculates a variables that shows the past success rate of the first Assignee of a bug id. (0 to 1)
# ###
# Columns:
#   - id: Bug Id
#   - firstAssignee: first ever assignee
#   - rateFirstAssignee: sequential successrate of the first assignee
SuccessRateAssignee_tem = dbGetQuery (db, 
                                      'SELECT 
                                      AssignedTo.id,
                                      AssignedTo.what AS firstAssignee,
                                      CAST(AssignedTo.[when] AS INT) AS [when],
                                      (CASE WHEN 
                                      BaseSample.current_resolution == "FIXED"
                                      THEN 1 ELSE 0 END) AS Fixed
                                      FROM AssignedTo
                                      INNER JOIN BaseSample
                                      ON (BaseSample.id = AssignedTo.id AND BaseSample.opening = AssignedTo.[when])
                                      ;')

# merge to the Bug ids of the base sample to exclude the bugs that we're not covering
SuccessRateAssignee1 <- SuccessRateAssignee_tem
# create variable needed for the calculation of the cummulative sum
SuccessRateAssignee1$N = 1
# order data.frame: firstAssignee, when
SuccessRateAssignee1[order(SuccessRateAssignee1$firstAssignee,SuccessRateAssignee1$when),]
# calculate cummulative sum of the number of times a assigner appears
SuccessRateAssignee1$AssignerCumSum <- ave(SuccessRateAssignee1$N, SuccessRateAssignee1$firstAssignee, FUN=cumsum)
# calculate cummulative sum of the number of bugs fixed by assigner
SuccessRateAssignee1$FixedCumSum <- ave(SuccessRateAssignee1$Fixed, SuccessRateAssignee1$firstAssignee, FUN=cumsum)
# Take away 1 from the FixedCumSum when Fixed equals 1 (we want to look at the past successrate)
indices <- (SuccessRateAssignee1$Fixed==1)
SuccessRateAssignee1$FixedCumSum[indices] = (SuccessRateAssignee1$FixedCumSum-1)[indices]
# calculate the successrate of the last assigner
SuccessRateAssignee1$rateFirstAssignee = ((SuccessRateAssignee1$FixedCumSum)/(SuccessRateAssignee1$AssignerCumSum))
# remove not-needed columns
SuccessRateAssignee1 = SuccessRateAssignee1[,-c(3,4,5,6,7)]

dbWriteTable(featuredb, "SuccessRateFirstAssignee", SuccessRateAssignee1, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----SUCCESS-RATE-LAST-ASSIGNEE----------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz
# ###
# This code calculates a variable that shows the past success rate of the last assignee of a bug id. (0 to 1)
# ###
# Columns:
#   - id: Bug Id
#   - lastAssignee: last assigned assignee
#   - rateLastAssignee: sequential successrate of the last assignee
SuccessRateAssignee_tem2 = dbGetQuery (db,
                                      'SELECT 
                                      AssignedTo.id,
                                      AssignedTo.what AS lastAssignee,
                                      CAST(AssignedTo.[when] AS INT) AS [when],
                                      (CASE WHEN 
                                      BaseSample.current_resolution == "FIXED"
                                      THEN 1 ELSE 0 END) AS Fixed
                                      FROM AssignedTo
                                      INNER JOIN BaseSample
                                      ON (BaseSample.id = AssignedTo.id)
                                      GROUP BY BaseSample.id
                                      HAVING MAX(AssignedTo.[when]) = AssignedTo.[when]
                                      ;
                                      ')

# merge to the Bug ids of the base sample to exclude the bugs that we're not covering
SuccessRateAssignee2 <- SuccessRateAssignee_tem2
# create variable needed for the calculation of the cummulative sum
SuccessRateAssignee2$N = 1
# order data.frame: lastAssignee, when
SuccessRateAssignee2[order(SuccessRateAssignee2$lastAssignee,SuccessRateAssignee2$when),]
# calculate cummulative sum of the number of times a assigner appears
SuccessRateAssignee2$AssignerCumSum <- ave(SuccessRateAssignee2$N, SuccessRateAssignee2$lastAssignee, FUN=cumsum)
# calculate cummulative sum of the number of bugs fixed by assigner
SuccessRateAssignee2$FixedCumSum <- ave(SuccessRateAssignee2$Fixed, SuccessRateAssignee2$lastAssignee, FUN=cumsum)
# Take away 1 from the FixedCumSum when Fixed equals 1 (we want to look at the past successrate)
indices <- (SuccessRateAssignee2$Fixed==1)
SuccessRateAssignee2$FixedCumSum[indices] = (SuccessRateAssignee2$FixedCumSum-1)[indices]
# calculate the successrate of the last assigner
SuccessRateAssignee2$rateLastAssignee = ((SuccessRateAssignee2$FixedCumSum)/(SuccessRateAssignee2$AssignerCumSum))
# remove not-needed columns
SuccessRateAssignee2 = SuccessRateAssignee2[,-c(3,4,5,6,7)]

dbWriteTable(featuredb, "SuccessRateLastAssignee", SuccessRateAssignee2, overwrite=TRUE)


#-----------------------------------------------------------------------------------
#-----SUCCESS-RATE-REPORTER----------------------------------------------------
#-----------------------------------------------------------------------------------
# Author: Raphael Stutz, Marius Hoegger, Andreas Egger
# ###
# This code calculates a variable that shows the past success rate of the reporter of a bug id. (0 to 1)
# ###
# Columns:
#   - id: Bug Id
#   - reporter: id of reporter
#   - rateReporter: sequential successrate of the reporter
SuccessRateReporter_tem = dbGetQuery (db,
                                       'SELECT 
                                       id,
                                       reporter,
                                       CAST(BaseSample.opening AS INT) AS [when],
                                       (CASE WHEN 
                                       BaseSample.current_resolution == "FIXED"
                                       THEN 1 ELSE 0 END) AS Fixed
                                       FROM BaseSample
                                       GROUP BY BaseSample.id
                                       ;
                                       ')

# merge to the Bug ids of the base sample to exclude the bugs that we're not covering
SuccessRateReporter <- SuccessRateReporter_tem
# create variable needed for the calculation of the cummulative sum
SuccessRateReporter$N = 1
# order data.frame: Reporter, when
SuccessRateReporter[order(SuccessRateReporter$reporter,SuccessRateReporter$when),]
# calculate cummulative sum of the number of times a reporter appears
SuccessRateReporter$ReporterCumSum <- ave(SuccessRateReporter$N, SuccessRateReporter$reporter, FUN=cumsum)
# calculate cummulative sum of the number of bugs fixed by reporter
SuccessRateReporter$FixedCumSum <- ave(SuccessRateReporter$Fixed, SuccessRateReporter$reporter, FUN=cumsum)
# Take away 1 from the FixedCumSum when Fixed equals 1 (we want to look at the past successrate)
indices <- (SuccessRateReporter$Fixed==1)
SuccessRateReporter$FixedCumSum[indices] = (SuccessRateReporter$FixedCumSum-1)[indices]
# calculate the successrate of the reporter
SuccessRateReporter$rateReporter = ((SuccessRateReporter$FixedCumSum)/(SuccessRateReporter$ReporterCumSum))
# remove not-needed columns
SuccessRateReporter = SuccessRateReporter[,-c(3,4,5,6,7)]

dbWriteTable(featuredb, "SuccessRateReporter", SuccessRateReporter, overwrite=TRUE)

#Disconnect
dbDisconnect(featuredb)
dbDisconnect(db)




