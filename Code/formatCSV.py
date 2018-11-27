
#
#	Python Script format bad formatted CSV files (cc.csv and short_desc.csv)
#	These files have shiftet entries due to additional "," or linebreaks in the
# 	content.
#
#	Author:		Marius Hoegger
#	Date:		27.11.2018
#
#	stored in ./Code/formatCSV.py


import os
import sys
import shutil

def reformat(filepath):
	dir = os.path.dirname(filepath)
	try:
		os.mkdir(dir+"/original")
	except:
		print("folder 'original' already exists")
	filename = os.path.basename(filepath)
	w = open(filepath.split(".csv")[0]+"_changed.csv","a")
	#save previous line for the case that the csv is badly formatted and some entries hat linebreaks in them
	concat = "" 
	with open(filepath,"r") as f:
		for line in f.readlines():
            #remove additional linebrak characers
			line = line.replace("\r","")				
			line = line.replace("\t","")
            #line ends with ";" means it was part of code and had wrong linebreaks in then and also wrong ","		
			if line.rstrip().endswith(";"):
				line = line.replace(",",";")
            #concatenate previous line with current line							
			line3 = concat+line
            # split at first "," to isolate the id
			id,rest = line3.split(",",1)
			try:    
                # is successful when there is a "," in the remaining string
                # split at last "," to isolate the who
				rest2, who = rest.rsplit(",",1)
			except:
                #If there is no ";" in the string, we save the line in concat and procede with next line
				concat=line3.replace("\n","")
				#concat=concat.replace("\r"," ")
				continue
            # if try was successful reset concat for the case that there was some content in it
			concat = ""
            # split at second to last (last remaining) "," to isolate the what
			rest3, when = rest2.rsplit(",",1)
            # replace any remaining "," with ";" to not mess up the CSV
			what = rest3.replace(",",";")
            # write to new file
			w.write(id+","+what+","+when+","+who)
	f.close()
	shutil.move(filepath,dir+"/original/"+filename)
if __name__ == "__main__":
	print(sys.argv)
	if len(sys.argv) != 2:
		print("Syntax: Enter path to CSV file that should be formatted ar argument")
	else:
		if (os.path.isfile(sys.argv[1])):
			reformat(sys.argv[1])
		else:
			print("Error: file does not exist")
		
