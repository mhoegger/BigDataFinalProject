#!/bin/bash
#
#	Script that creates SQLite db "Bug" from the CSV files
#
#	Author:		Marius Hoegger
#	Date:		27.11.2018
#
#	stored in ./Code/createDB.sh

echo " "
echo "   _____                _         _______    _     _            "
echo "  / ____|              | |       |__   __|  | |   | |           "
echo " | |     _ __ ___  __ _| |_ ___     | | __ _| |__ | | ___  ___  "
echo " | |    | '__/ _ \/ _' | __/ _ \    | |/ _' | '_ \| |/ _ \/ __| "
echo " | |____| | |  __/ (_| | ||  __/    | | (_| | |_) | |  __/\__ \ "
echo "  \_____|_|  \___|\__,_|\__\___|    |_|\__,_|_.__/|_|\___||___/ "
echo " "                                                                           

sqlite3 ./SQL/Bugs.db <<EOS
.mode csv 
.separator , 
.import ./Data/Eclipse/assigned_to.csv AssignedTo
EOS

echo "Table 'AssidnedTo' created"

sqlite3 ./SQL/Bugs.db <<EOS
.mode csv 
.separator , 
.import ./Data/Eclipse/bug_status.csv Status
EOS

echo "Table 'Status' created"

sqlite3 ./SQL/Bugs.db <<EOS
.mode csv 
.separator , 
.import ./Data/Eclipse/cc_changed.csv CC
EOS

echo "Table 'CC' created"

sqlite3 ./SQL/Bugs.db <<EOS
.mode csv 
.separator , 
.import ./Data/Eclipse/component.csv Component
EOS

echo "Table 'Component' created"

sqlite3 ./SQL/Bugs.db <<EOS
.mode csv 
.separator , 
.import ./Data/Eclipse/op_sys.csv OS
EOS

echo "Table 'OS' created"

sqlite3 ./SQL/Bugs.db <<EOS
.mode csv 
.separator , 
.import ./Data/Eclipse/priority.csv Priority
EOS

echo "Table 'Priority' created"

sqlite3 ./SQL/Bugs.db <<EOS
.mode csv 
.separator , 
.import ./Data/Eclipse/product.csv Product
EOS

echo "Table 'Product' created"

sqlite3 ./SQL/Bugs.db <<EOS
.mode csv 
.separator , 
.import ./Data/Eclipse/reports.csv Reports
EOS

echo "Table 'Reports' created"

sqlite3 ./SQL/Bugs.db <<EOS
.mode csv 
.separator , 
.import ./Data/Eclipse/resolution.csv Resolution
EOS

echo "Table 'Resolution' created"

sqlite3 ./SQL/Bugs.db <<EOS
.mode csv 
.separator , 
.import ./Data/Eclipse/severity.csv Severity
EOS

echo "Table 'Severity' created"

sqlite3 ./SQL/Bugs.db <<EOS
.mode csv 
.separator , 
.import ./Data/Eclipse/short_desc_changed.csv ShortDesc
EOS

echo "Table 'ShortDesc' created"

sqlite3 ./SQL/Bugs.db <<EOS
.mode csv 
.separator , 
.import ./Data/Eclipse/version.csv Version
EOS

echo "Table 'Version' created"
echo "Done"
echo " "
