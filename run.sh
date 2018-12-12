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
