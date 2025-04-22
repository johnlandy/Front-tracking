import numpy as np
import glob
from math import radians,degrees,sin,cos,asin,acos,sqrt
import os
import xarray as xr



file_value = input()
nodefile=file_value.split(",")[0]
blobfile=file_value.split(",")[1]
var_name=file_value.split(",")[2]


print(nodefile,blobfile)

object_ids = []
year = nodefile.split("/")[-1][:4]
print(year)
with open(nodefile,'r') as ofile:
	lines=ofile.readlines()
	for line in lines:
		split = line.split("\t")
		if "start" not in split:
			object_ids.append(int(split[5]))

with xr.open_dataset(blobfile) as open_blobfile:
	fronts = open_blobfile.variables[var_name].values
	objects_in = np.isin(fronts,object_ids)
	fronts = objects_in*fronts
	open_blobfile[var_name].values = fronts
	copy_dataset = open_blobfile.copy()

os.system("rm "+blobfile)
	
open_blobfile.to_netcdf(blobfile,mode="w")
