#!/bin/bash
#
#	Script that extracts the CSV from the Zip file
# 	and format bad formatted CSV files (cc.csv and short_desc.csv)
#
#	Author:		Marius Hoegger
#	Date:		27.11.2018
#
#	stored in ./Code/prepCSV.sh	

echo ""
echo " ██████╗███████╗██╗   ██╗    ██████╗ ██████╗ ███████╗██████╗  "
echo "██╔════╝██╔════╝██║   ██║    ██╔══██╗██╔══██╗██╔════╝██╔══██╗ "	
echo "██║     ███████╗██║   ██║    ██████╔╝██████╔╝█████╗  ██████╔╝ "
echo "██║     ╚════██║╚██╗ ██╔╝    ██╔═══╝ ██╔══██╗██╔══╝  ██╔═══╝  "
echo "╚██████╗███████║ ╚████╔╝     ██║     ██║  ██║███████╗██║      "
echo " ╚═════╝╚══════╝  ╚═══╝      ╚═╝     ╚═╝  ╚═╝╚══════╝╚═╝      "
echo ""                                                             

unzip ./Data/Eclipse.zip -d ./Data

echo "Unzipping done"

python ./Code/formatCSV.py ./Data/Eclipse/cc.csv

echo "Formatted cc.csv" 

python ./Code/formatCSV.py ./Data/Eclipse/short_desc.csv

echo "Formatted short_desc.csv"
echo "Done"
echo " "
