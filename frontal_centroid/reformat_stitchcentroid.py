import numpy as np
import xarray as xr
import glob
from math import radians,degrees,sin,cos,asin,acos,sqrt
import os



input_value = input()
file=input_value.split(",")[0]
nc_file=input_value.split(",")[1]
area = float(input_value.split(",")[2])
print(file,area)
add=file.split("/")[-1]


with xr.open_dataset(nc_file) as open_nc_file:
	nc_file_vars=open_nc_file.variables
	file_lats = nc_file_vars["lat"].values 
	file_lons = nc_file_vars["lon"].values 


def great_circle_distance(lon1,lat1,lon2,lat2):
	lon1,lat1,lon2,lat2=map(radians,[lon1,lat1,lon2,lat2])

	return 6371 * (
	acos(sin(lat1)*sin(lat2)+cos(lat1)*cos(lat2)*cos(lon1-lon2))
	)

def sr_to_km2(sr):
	return sr*(6371e3)**2

zerostr = "0000"

sr = area
km2 = sr_to_km2(sr)

splitprev="string"
numBlobsArr=[]
numBlobs = 1
with open(file,'r') as ofile, open("new_detect_nodes+"+add,'w') as wfile:
	lines=ofile.readlines()
	for line in lines:
		split=line.split('\t')
		if split[1]=="0" and float(split[-1]) > km2:
			if split[2] != splitprev[2]:
				numBlobsArr.append(numBlobs)
				numBlobs = 1
			elif split[1]=="0":
				numBlobs += 1
			splitprev = split	
				
	numBlobsArr.append(numBlobs)
	numBlobsArr.pop(0)
	
	for line in lines:
		##indices - 0=object_ids,1=number of blobs with object_id,2=date (yyyy-mm-dd-sssss), 3=lon(float), 4=lat,5=area(sr)##
		split=line.split('\t')
		if split[1]=="0" and float(split[-1]) > km2:
			object_id = int(split[0])
			lon = float(split[3])
			lat = float(split[4])
			#os.system("echo "+str(lon))
			lonidx = np.argmin(np.abs(file_lons-lon%360))
			latidx = np.argmin(np.abs(file_lats-lat))
			#print(lat,latidx,np.abs(file_lons-lat))
			roundlon = '{:.6f}'.format(file_lons[lonidx])
			roundlat = '{:.6f}'.format(file_lats[latidx])
			area = split[-1]
			if split[2] != splitprev[2]:
				date = split[2].split("-")
				date[1] = str(int(date[1]))
				date[2] = str(int(date[2]))
				date.insert(3,str(numBlobsArr[0]))
				date[4] = str(int(int(date[4])/3600))
				wfile.writelines("\t".join(date)+'\n')
				numBlobsArr.pop(0)

			newline = [lonidx,latidx,roundlon,roundlat,object_id,area]
			strnewline = [str(i) for i in newline]
			strnewline.insert(0,"")
			wfile.writelines('\t'.join(strnewline)+'\n')
			splitprev = split
os.system("mv new_detect_nodes+"+add+" "+file)
os.system("sed -i '/^$/d' " + file)
