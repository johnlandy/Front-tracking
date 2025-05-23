#!/bin/bash

##
##conda environment with tempestextremes
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
## if on unstructured grid, use connectivity file
connectivity_file=

##
## defining threshold parameters

## area = minimum area for frontal zone in steradians; 0.001 sr = 0.001 sr * 6,371km^2 = 40,000 km^2
area=0.001
## overlap = minimum percentage of areal overlap for sequential timesteps for object to be connected in time
overlap=
## duration = minimum temporal persistence of front in hours
duration='24h'

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

## computing frontal parameter
VariableProcessor --in_data $input_file --var "$zeta_eq;$T_advection_eq;$T_gradmag_eq;$F_eq" --varout "$vort,$t_advection,$t_gradmag,$F" --out_data $processed_variables --in_connect $connectivity_file 


## front tracking
## cold fronts
## detect cold fronts
DetectBlobs --in_data $processed_variables --out $detect_blobs  --thresholdcmd "$F,>=,1,0" --tagvar "cold_front_binary_tag" --latname lat --lonname lon	

# stitchblobs for cold frontal areas
StitchBlobs --in $detect_blobs --out $stitch_blobs  --var "cold_front_binary_tag" --outvar "cold_front_object_id"  --mintime ${mintime}  --thresholdcmd "minarea,${minarea}" --min_overlap_next $overlap --latname lat --lonname lon


##
