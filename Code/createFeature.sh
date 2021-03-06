#!/bin/bash
#
#	Script that creates SQLite db "Bug" from the CSV files
#
#	Author:		Marius Hoegger
#	Date:		27.11.2018
#
#	stored in ./Code/createFeature.sh


echo " "                                                                           
echo "    ______           __                  ______                __  _            "
echo "   / ____/__  ____ _/ /___  __________  / ____/_______  ____ _/ /_(_)___  ____  "
echo "  / /_  / _ \/ __ '/ __/ / / / ___/ _ \/ /   / ___/ _ \/ __ '/ __/ / __ \/ _' \ "
echo " / __/ /  __/ /_/ / /_/ /_/ / /  /  __/ /___/ /  /  __/ /_/ / /_/ / /_/ / / / / "
echo "/_/    \___/\__,_/\__/\__,_/_/   \___/\____/_/   \___/\__,_/\__/_/\____/_/ /_/  "
echo " "                                                                                                                                                          

while true; do
    read -p "Do you wish to install all required R packages? (y/n)? " yn
    case $yn in
        [Yy]* ) 
		echo "install packages..."
		Rscript ./installPackages.R
		echo "Packages installed" 
		break;;
        [Nn]* ) break;;
        * ) echo "Please answer yes or no.";;
    esac
done

echo "Create Base Sample..."
Rscript ./createBaseSample.R
echo "Base Sample created"
echo "Create Categories..."
Rscript ./createCategories.R
echo "Categories created"
echo "Create Features..."
Rscript ./createFeature.R
echo "Features created"
echo "Create Master Tabel..."
Rscript ./createMasterFeatureTable.R
echo "Master Tabel created"
echo "Done"
echo " "
