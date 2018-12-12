# Triaging Software Bugs

This Projects aims to classify different features which result from Bug reports and une them 
to predict whether a bug will get fixed or not. For this project the Bug Tracking Data for the
Software "Eclips" is used.

## Getting Started

These instructions will explain how our results can be replicated. It will explain how you can
run the process and where the results are saved.

### Prerequisites

Make sure that in the dame directory this README is located also contains directories called
SQL, Data and Code. Additionaly check if the content of these directory matches with the content listed below.
You can place the Zip files named Eclipse.zip into the Data directory. Note: We already provide this zip file.


### Prepare the data.

To start the process open the terminal in this directory and run the following command
```
. .\run.sh
```

This will extract the data for you into *./Data/Eclipse* directory and it will also prepare the data.
For this some of the csv files are beeing changed. The original files are moved to *./Data/Eclipse/original*.
Nextup the the data is read into a databade named *Bugs.db* which is stored in *./Code*

next the features will be created, but before that you will be asked wheher you want to intall the required R packages.

```
Do you wish to install all required R packages? (y/n)? 
```

If you want to install them type "y" and press ENTER. If you want to skip installing them type "n" and press ENTER.

Next up the features which are used for the prediction are being created. 
The results are saved in the *features.db* database located in *./SQL*.


## Running the tests

Explain how to run the automated tests for this system



## Deployment

Add additional notes about how to deploy this on a live system

## python libraries used

* ...

## R packages used

* RSQLite
* stringr
* e1071
* dplyr
* plyr

## Authors

* **Paricia Fischer** - *sid* - *email*
* **Andreas Egger** - *sid* - *email*
* **Marius Hoegger** - *sid* - *email*
* **Raphael Stutz** - *sid* - *email*


