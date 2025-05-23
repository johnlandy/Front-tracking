#!/bin/bash

##
##conda environment with tempestextremes, python with numpy, xarray, netcdf4
env=

##
## defining filepaths

## input file. contains T, U, and V on pressure levels
input_file=
## output of VariableProcessor; contains F parameter
processed_variables=
## output of DetectBlobs; contains  binary tags (candidate frontal zones)
detect_blobs=
## output of StitchBlobs and input/output of final python script
stitch_blobs=
## output of frontal centroids, reformatted to DetectNodes-type formatting
detect_nodes=
## output of StitchNodes
stitch_nodes=
## if on unstructured grid, use connectivity file
connectivity_file=

##
## defining threshold parameters

## area = minimum area for frontal zone in steradians; 0.001 sr = 0.001 sr * 6,371km^2 = 40,000 km^2
area=0.001
## nearness = maximum distance between frontal zone centroids on consecutive timesteps in great circle degrees 
nearness=8
## duration = minimum temporal persistence of front in hours
duration='24h'
## distance = minimum distance traveled 
distance=10

## stencil for computing gradient, curl; stencil_pts = number of equiangular points, stencil_deg = distance (great circle deg) to calculate at
stencil_pts=4
stencil_deg=1

#
## defining operations and variables to create

## U-, V- winds, and T variables from input_file
u=U850
v=V850
t=T850

## variable names in VariableProcessor output
vort=VORT850
t_advection=T850_advection
t_gradmag=T850_gradmag
F=F850


###############################################################################################
## zeta/vorticity/curl of u; temperature advection/-U dot grad T; magnitude of gradient of T; F/frontal parameter/product of relative vorticity over product of average meridional T gradient and midlatitude vorticity. For proper normalization, change 0.0001 to _F (coriolis parameter), and remove _SIGN(_F). This will cause problems in the tropics.
zeta_eq="_CURL{${stencil_pts},${stencil_deg}}($u,$v)"
T_advection_eq="_PROD(_VECDOTGRADT{${stencil_pts},${stencil_deg}}($u,$v,$t),-1)"
T_gradmag_eq="_GRADMAG{${stencil_pts},${stencil_deg}}($t)"
F_eq="_PROD(_DIV(_PROD($zeta_eq,$T_gradmag_eq),_PROD(0.0001,0.0000045)),_SIGN(_F))"

#
## loading environments and nco
module load conda; conda activate $env
module laod nco

## computing frontal parameter
VariableProcessor --in_data $input_file --var "$zeta_eq;$T_advection_eq;$T_gradmag_eq;$F_eq" --varout "$vort,$t_advection,$t_gradmag,$F" --out_data $processed_variables --in_connect $connectivity_file 

#
## front tracking
## cold fronts
## detect cold fronts
DetectBlobs --in_data $processed_variables --out $detect_blobs --thresholdcmd "$F,>=,1,0;$t_advection,<,0,0" --tagvar "cold_front_binary_tag"
StitchBlobs --in $detect_blobs --out $stitch_blobs --var "cold_front_binary_tag" --min_overlap_prev 100 --min_overlap_next 100 --outvar "cold_front_object_id"

## find cold front centroids
BlobStats --in_file $stitch_blobs --out_file $detect_nodes  --var "cold_front_object_id" --out "centlon,centlat,area" --out_fulltime
## reformat centroids to be compatible with StitchNodes
python reformat_stitchcentroid.py <<< "${detect_nodes},${stitch_blobs},${area}"

## StitchNodes for cold front centroids
StitchNodes --in $detect_nodes  --out $stitch_nodes  --range ${nearness} --mintime ${duration} --maxgap 0 --min_endpoint_dist ${distance} 

## reapplying StitchNodes output to StitchBlobs output
python apply_stitchnodes_stitchblobs.py <<< "${stitch_nodes},${stitch_blobs},cold_front_object_id"

##
