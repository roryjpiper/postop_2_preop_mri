#!/bin/sh

# POSTOP 2 PREOP REGISTRATION
# R Piper; 2025

# Add software prerequisites
export NIFTYREG_INSTALL=[directory]/software/nifty_git/niftyreg/install
PATH=${PATH}:${NIFTYREG_INSTALL}/bin
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${NIFTYREG_INSTALL}/lib
export PATH
export LD_LIBRARY_PATH

# define group , e.g. GROUP = SEEG or GROUP = resections or GROUP = controls
read -p 'Group: ' GROUP

# define session name 
read -p 'Session: ' session_name

for i in sub*
    do
    echo "$i"
	
	#SET BASES
	
	PREOP_IN=[directory]/thomas_dMRI/${GROUP}/input/source_data/${i}/${session_name}/anat
	POSTOP_IN=[directory]thomas_dMRI/${GROUP}/input/source_data/${i}/ses-postop01/anat
	SEG_IN=[directory]/thomas_dMRI/${GROUP}/output/thomas/${i}/${session_name}/${i}_${session_name}_scale-1_parcellation_thomas.nii.gz
	
	mkdir [directory]/thomas_dMRI/${GROUP}/output/cavities/${i}
	POSTOP_OUT=[directory]/thomas_dMRI/${GROUP}/output/cavities/${i}
	
	
	#COPY FILES (don't corrupt the source data!)
	echo "copying files"
	cp ${PREOP_IN}/${i}_${session_name}_T1w.nii.gz ${POSTOP_OUT}/${i}_${session_name}_T1w.nii.gz
	cp ${POSTOP_IN}/${i}_ses-postop01_T1w.nii.gz ${POSTOP_OUT}/${i}_ses-postop01_T1w.nii.gz
	cp ${POSTOP_IN}/${i}_ses-postop01_resection-mask.nii.gz ${POSTOP_OUT}/${i}_ses-postop01_resection-mask.nii.gz
	cp ${SEG_IN} ${POSTOP_OUT}/${i}_${session_name}_scale-1_parcellation_thomas.nii.gz
	
	
	#REGISTER
		
	echo "resseg_roi invert"
	fslmaths ${POSTOP_OUT}/${i}_ses-postop01_resection-mask.nii.gz -mul -1 -add 1 -bin ${POSTOP_OUT}/${i}_ses-postop01_resection-mask_inv.nii.gz

	echo "temporary rigid reg of postop to preop (for rough alignment)"
	reg_aladin -ref ${POSTOP_OUT}/${i}_${session_name}_T1w.nii.gz -flo ${POSTOP_OUT}/${i}_ses-postop01_T1w.nii.gz -res ${POSTOP_OUT}/${i}_ses-postop01_T1w_rig.nii.gz -fmask ${POSTOP_OUT}/${i}_ses-postop01_resection-mask_inv.nii.gz -aff ${POSTOP_OUT}/${i}_ses-postop01_post2pre_rig.txt -rigOnly 

	echo "bringing the resection cavity with the rigid transform"
	reg_resample -ref ${POSTOP_OUT}/${i}_${session_name}_T1w.nii.gz -flo ${POSTOP_OUT}/${i}_ses-postop01_T1w.nii.gz -flo ${POSTOP_OUT}/${i}_ses-postop01_resection-mask_inv.nii.gz -res ${POSTOP_OUT}/${i}_ses-postop01_resection-mask_inv_rig.nii.gz -trans ${POSTOP_OUT}/${i}_ses-postop01_post2pre_rig.txt -inter 0

	echo "non-linear transform of PREOP to POSTOP_RIGID"
	reg_f3d -ref ${POSTOP_OUT}/${i}_ses-postop01_T1w_rig.nii.gz -flo ${POSTOP_OUT}/${i}_${session_name}_T1w.nii.gz -res ${POSTOP_OUT}/${i}_${session_name}_T1w_2_postop_rig.nii.gz -rmask ${POSTOP_OUT}/${i}_ses-postop01_resection-mask_inv_rig.nii.gz -cpp ${POSTOP_OUT}/${i}_${session_name}_preop2post_CPP.nii

	echo "invert the non-linear transform"
	reg_transform -invNrr ${POSTOP_OUT}/${i}_${session_name}_preop2post_CPP.nii ${POSTOP_OUT}/${i}_${session_name}_T1w.nii.gz ${POSTOP_OUT}/${i}_ses-postop01_T1w_rig_reverse.nii.gz -ref ${POSTOP_OUT}/${i}_ses-postop01_T1w_rig.nii.gz  

	echo "transform the post to preop space using the CPP"
	reg_resample -ref ${POSTOP_OUT}/${i}_${session_name}_T1w.nii.gz -flo ${POSTOP_OUT}/${i}_ses-postop01_T1w_rig.nii.gz -res ${POSTOP_OUT}/${i}_ses-postop01_T1w_rig_2preop.nii.gz -trans ${POSTOP_OUT}/${i}_ses-postop01_T1w_rig_reverse.nii.gz
	
	echo "transform the resection cavity to preop space"
	reg_resample -ref ${POSTOP_OUT}/${i}_${session_name}_T1w.nii.gz -flo ${POSTOP_OUT}/${i}_ses-postop01_resection-mask_inv_rig.nii.gz -res ${POSTOP_OUT}/${i}_ses-postop01_resection-mask_inv_rig_2preop.nii.gz -trans ${POSTOP_OUT}/${i}_ses-postop01_T1w_rig_reverse.nii.gz -inter 0

	echo "invert the final resseg_roi"
	fslmaths ${POSTOP_OUT}/${i}_ses-postop01_resection-mask_inv_rig_2preop.nii.gz -mul -1 -add 1 ${POSTOP_OUT}/${i}_ses-postop01_resection-mask_2preop.nii.gz
	
	echo "correct the resection mask for brain tissue"
	fslmaths ${POSTOP_OUT}/${i}_${session_name}_scale-1_parcellation_thomas.nii.gz -bin ${POSTOP_OUT}/${i}_${session_name}_scale-1_parcellation_thomas_bin.nii.gz
	rm ${POSTOP_OUT}/${i}_${session_name}_scale-1_parcellation_thomas.nii.gz
	fslmaths ${POSTOP_OUT}/${i}_ses-postop01_resection-mask_2preop.nii.gz -mul ${POSTOP_OUT}/${i}_${session_name}_scale-1_parcellation_thomas_bin.nii.gz ${POSTOP_OUT}/${i}_ses-postop01_resection-mask_corrected.nii.gz
	
	echo "clean-up"
	rm ${POSTOP_OUT}/${i}_${session_name}_T1w* ${POSTOP_OUT}/${i}_ses-postop01_T1w* ${POSTOP_OUT}/${i}_ses-postop01_resection-mask_inv*
	


done
echo "Finished"


