#!/bin/bash
#
#	runs the R scripts for the prediction 
#
#	Author:		Marius Hoegger
#	Date:		12.12.2018
#
#	stored in ./Code/runPrediction.sh

echo ""
echo "                   ______              _ _            _             "
echo "                  (_____ \            | (_)      _   (_)            "
echo "  ____ _   _ ____  _____) )___ ____ _ | |_  ____| |_  _  ___  ____  "
echo " / ___) | | |  _ \|  ____/ ___) _  ) || | |/ ___)  _)| |/ _ \|  _ \ "
echo "| |   | |_| | | | | |   | |  ( (/ ( (_| | ( (___| |__| | |_| | | | |"
echo "|_|    \____|_| |_|_|   |_|   \____)____|_|\____)\___)_|\___/|_| |_|"
echo ""                                                                    

echo "starting the Prediction..."
cd ./Code
ls
Rscript ./prediction.R
cd ..

echo "done"
