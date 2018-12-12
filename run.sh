#!/bin/bash
#
#	Main shell script running all sub-shell scripts
#
#	Author:		Marius Hoegger
#	Date:		27.11.2018
#
#	stored in ./run.sh

cd ./Code
. ./prepCSV.sh
. ./createDB.sh
. ./createFeature.sh
cd ..


while true; do
    read -p "Do you wish to continue with the prediction? (y/n)? " yn
    case $yn in
        [Yy]* ) 
		echo "Procede with prediction"
		. ./runPrediction.sh
		break;;
        [Nn]* ) exit;;
        * ) echo "Please answer yes or no.";;
    esac
done

echo "Done"
