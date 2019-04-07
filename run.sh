#!/bin/bash


function buildTemplate {

	iter=$1

	#build template from $((iter-1)) data
	
       iter_out=$work_folder/${seg_name}_iter$iter
       iter_prev=$work_folder/${seg_name}_iter$((iter-1))
       mkdir -p $iter_out
       all_target_segs=$iter_out/in_target_segs.nii.gz
       template_prob_seg=$iter_out/template_prob_seg.nii.gz
 
       #get all subject segs from previous iteration into a 4D file
       echo fslmerge -t $all_target_segs  $iter_prev/*/*.warpToTemplate.nii.gz
       fslmerge -t $all_target_segs  $iter_prev/*/*.warpToTemplate.nii.gz

	#print out centroids to use as a QC check:
	fslstats -t $all_target_segs  -C > $iter_out/in_target_segs.centroids.txt

	#average it to create current iteration template
   	echo fslmaths $all_target_segs -Tmean $template_prob_seg
   	fslmaths $all_target_segs -Tmean $template_prob_seg

	#run script to pre-proc template data for current iteration 
       pushd $work_folder
        echo $execpath/deps/computeSurfaceDisplacementsSingleStructure template_placeholder  $template_prob_seg $seg_name -N -t  -o $iter_out
        $execpath/deps/computeSurfaceDisplacementsSingleStructure template_placeholder  $template_prob_seg $seg_name -N -t  -o $iter_out
	popd

}

function die {
 echo $1 >&2
 exit 1
}

function fixsubj {
#add on sub- if not exists
subj=$1
 if [ ! "${subj:0:4}" = "sub-" ]
 then
  subj="sub-$subj"
 fi
 echo $subj
}

function fixsess {
#add on ses- if not exists
sess=$1
 if [ ! "${sess:0:4}" = "ses-" ]
 then
  sess="sub-$sess"
 fi
 echo $sess
}


execpath=`dirname $0`
execpath=`realpath $execpath`

cfg_dir=$execpath/cfg

in_atlas_dir=$execpath/atlases

#default template for linear registration
atlas=MNI152NLin2009cAsym

#template mostly is stabilised after 3 iterations
MAX_ITER=3

participant_label=
matching_T1w=
reg_init_subj=
surfmorph_type=
in_seg_dir=
matching_seg=
seg_name=


#TODO:
# - create mechanism to save built template, and to use existing template - could just use the work/iterX/template folder for this.."
# - resample arbitrary qMRI on surface - could be participant2 option - may need a matlab script to sample vol on surface (easy)..
# - support gifti output too
# - use symlinks to point to final iter folder(s)
# - allow for higher than 1mm resolution -- just need a higher-res template, and reset RESAMPLE_MM to atlas resolution
# - multi-structure version
#   - option A: perform mapping separately -- could use gnu parallel?? - this is easier and better behaved.. separate iterX folders
#      could use label,num csv file, and use ${label}_iterX folders
#   - option B: multi-channel reg -- would have large images, harder to estimate mem usage etc..

if [ "$#" -lt 3 ]
then
 echo " This app runs LDDMM to generate a cohort-specific template group1 level imports the data and builds a template for the current iteration, participant1 runs mappings from template to target for current iteration"
 echo " Start with group1, then run participant1, group1, participant1 until desired number of iterations reached."
 echo ""
 echo " Segmentations need to be in a BIDS-style anat folder, similar to T1w images (e.g. sub-XX/anat/sub-XX_<matching_seg>.nii.gz)"
 echo "Usage: surfmorph bids_dir output_dir {group1,participant1} <optional arguments>"
 echo ""
 echo " Required arguments:"
 echo "          [--in_seg_dir SEG_DIR]" 
 echo "          [--matching_seg MATCHING_STRING]" 
 echo "          [--seg_name LABEL_NAME] (short BIDS name (letter/numbers only) for the specified ROI)"
 echo ""
 echo " Optional arguments:"
 echo "          [--participant_label PARTICIPANT_LABEL [PARTICIPANT_LABEL...]]"
 echo "          [--matching_T1w MATCHING_STRING"
 echo ""
 echo "          [--seg_label LABEL_NUMBER (default: will binarize all non-zero labels from image)"
 echo ""
 echo "          [--surfmorph_type SURFMORPH_TYPE (pre-packaged config for specifying options) "
 echo "          [--in_atlas_dir ATLAS_DIR]"
 echo ""
 echo "	Analysis levels:"
 echo "		group1: T1w import, T1w  pre-proc, linear registration + generate i-th template" 
 echo "         participant1:  LDDMM mappings from i-th template to subjects"
 echo ""
 echo "         Available config files:"
 for cfg in `ls $execpath/cfg/surfmorph.*.cfg`
 do
     cfg=${cfg##*/surfmorph.}
     cfg=${cfg%%.cfg}
    echo "         $cfg"
 done


 exit 0
fi


in_bids=$1 
out_folder=$2 
analysis_level=$3

mkdir -p $out_folder 
out_folder=`realpath $out_folder`

shift 3



while :; do
      case $1 in
     -h|-\?|--help)
	     usage
            exit
              ;;
     --participant_label )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                participant_label=$2
                  shift
	      else
              die 'error: "--participant" requires a non-empty option argument.'
            fi
              ;;
     --participant_label=?*)
          participant_label=${1#*=} # delete everything up to "=" and assign the remainder.
            ;;
          --participant_label=)         # handle the case of an empty --participant=
         die 'error: "--participant_label" requires a non-empty option argument.'
          ;;



           --surfmorph_type )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                surfmorph_type=$2
                  shift
	      else
              die 'error: "--surfmorph_type" requires a non-empty option argument.'
            fi
              ;;
     --surfmorph_type=?*)
          surfmorph_type=${1#*=} # delete everything up to "=" and assign the remainder.
            ;;
          --surfmorph_type=)         # handle the case of an empty --participant=
         die 'error: "--surfmorph_type" requires a non-empty option argument.'
          ;;


           --in_seg_dir )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                in_seg_dir=$2
                  shift
	      else
              die 'error: "--in_seg_dir" requires a non-empty option argument.'
            fi
              ;;
     --in_seg_dir=?*)
          in_seg_dir=${1#*=} # delete everything up to "=" and assign the remainder.
            ;;
          --in_seg_dir=)         # handle the case of an empty --participant=
         die 'error: "--in_seg_dir" requires a non-empty option argument.'
          ;;

           --in_atlas_dir )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                in_atlas_dir=$2
                  shift
	      else
              die 'error: "--in_atlas_dir" requires a non-empty option argument.'
            fi
              ;;
     --in_atlas_dir=?*)
          in_atlas_dir=${1#*=} # delete everything up to "=" and assign the remainder.
            ;;
          --in_atlas_dir=)         # handle the case of an empty --participant=
         die 'error: "--in_atlas_dir" requires a non-empty option argument.'
          ;;


           --reg_init_participant )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                reg_init_subj=$2
                  shift
	      else
              die 'error: "--reg_init_participant" requires a non-empty option argument.'
            fi
              ;;
     --reg_init_participant=?*)
          reg_init_subj=${1#*=} # delete everything up to "=" and assign the remainder.
            ;;
          --reg_init_participant=)         # handle the case of an empty --participant=
         die 'error: "--reg_init_participant" requires a non-empty option argument.'
          ;;

      
     --matching_T1w )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                matching_T1w=$2
                  shift
	      else
              die 'error: "--matching_T1w" requires a non-empty option argument.'
            fi
              ;;
     --matching_T1w=?*)
          matching_T1w=${1#*=} # delete everything up to "=" and assign the remainder.
            ;;
          --matching_T1w=)         # handle the case of an empty --acq=
         die 'error: "--matching_T1w" requires a non-empty option argument.'
          ;;

     --matching_seg )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                matching_seg=$2
                  shift
	      else
              die 'error: "--matching_seg" requires a non-empty option argument.'
            fi
              ;;
     --matching_seg=?*)
          matching_seg=${1#*=} # delete everything up to "=" and assign the remainder.
            ;;
          --matching_seg=)         # handle the case of an empty --acq=
         die 'error: "--matching_seg" requires a non-empty option argument.'
          ;;

     --seg_label )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                seg_label=$2
                  shift
	      else
              die 'error: "--seg_label" requires a non-empty option argument.'
            fi
              ;;
     --seg_label=?*)
          seg_label=${1#*=} # delete everything up to "=" and assign the remainder.
            ;;
          --seg_label=)         # handle the case of an empty --acq=
         die 'error: "--seg_label" requires a non-empty option argument.'
          ;;

     --seg_name )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                seg_name=$2
                  shift
	      else
              die 'error: "--seg_name" requires a non-empty option argument.'
            fi
              ;;
     --seg_name=?*)
          seg_name=${1#*=} # delete everything up to "=" and assign the remainder.
            ;;
          --seg_name=)         # handle the case of an empty --acq=
         die 'error: "--seg_name" requires a non-empty option argument.'
          ;;




      -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
              ;;
     *)               # Default case: No more options, so break out of the loop.
          break
    esac
  
 shift
  done


shift $((OPTIND-1))


participants=$in_bids/participants.tsv
work_folder=$out_folder/work
derivatives=$out_folder #bids derivatives

if [ -n "$surfmorph_type" ]
then

if [ -e $execpath/cfg/surfmorph.$surfmorph_type.cfg ]
then
     surfmorph_cfg=$execpath/cfg/surfmorph.$surfmorph_type.cfg 
 elif [ -e $surfmorph_type ]
  then 
         surfmorph_cfg=`realpath $surfmorph_type`
     else

 echo "ERROR: --surfmorph_type $surfmorph_type does not exist!"
 exit 1
fi
source $surfmorph_cfg
fi



if [  -n "$in_seg_dir" -a -n "$matching_seg" -a -n "$seg_name" ] # if specified
then

	if [ ! -e $in_seg_dir ]
	then
	    echo "ERROR: in_seg_dir $in_seg_dir does not exist!"
	    exit 1
	fi
	in_seg_dir=`realpath $in_seg_dir`

	searchstring_seg=\*${matching_seg}\*.nii*

 	use_atlasseg=0	
else

	echo "in_seg_dir, matching_seg not specified"

	echo "required arguments missing"
	exit 1

	#below was for atlas-based seg 
 	echo "   using built in atlas-based seg instead"
	if [ ! -n "$template_prob_seg" -o  ! -n "$template_prob_seg_file" ]
	then
		echo "template_prob_seg and  template_prob_seg_file need to be defined for atlas-based segmentation.. failing!"
		exit 1
	fi

	use_atlasseg=1
fi



if [ -e $in_bids ]
then
	in_bids=`realpath $in_bids`
else
	echo "ERROR: bids_dir $in_bids does not exist!"
	exit 1
fi

if [ -n "$matching_T1w" ]
then
  searchstring_t1w=\*${matching_T1w}\*T1w.nii*
else
  searchstring_t1w=*T1w.nii*
fi




if [ -n "$participant_label" ]
then
subjlist=`echo $participant_label | sed  's/,/\ /g'` 
else
subjlist=`tail -n +2 $participants | awk '{print $1}'`
fi





mkdir -p $work_folder $derivatives
work_folder=`realpath $work_folder`



target_prob_seg_dir=labels/t1/probseg
target_prob_seg=labels/t1/probseg/${seg_name}.nii.gz
target_prob_seg_affine_atlas=labels/t1/probseg_affine_aladin_to_$atlas/${seg_name}.nii.gz

#exports for called scripts
export in_atlas_dir atlas surfmorph_cfg cfg_dir target_prob_seg_affine_atlas seg_name execpath


#use symlinks instead of copying 
 if ! test -h $work_folder/$atlas 
 then
	if test -d $work_folder/$atlas
	then
	   echo "atlas exists and is not a symlink, can remove it"
   	   echo " rm -rf $work_folder/$atlas"
    	fi
	
	 echo ln -sfv $in_atlas_dir/$atlas $work_folder/$atlas
	 ln -sfv $in_atlas_dir/$atlas $work_folder/$atlas

 fi
 

echo $participants
	





if [ "$analysis_level" = "group1" ]
then

#if 1st template doesn't exist, then create it:
if [ ! -e $work_folder/iter1/template_prob_seg.nii.gz ]
then

echo " running pre-processing to generate initial template"
 

subj_sess_prefix_all=""
subj_sess_prefix_reg=""

 for subj in $subjlist 
 do

 #add on sub- if not exists
  subj=`fixsubj $subj`

   #loop over sub- and sub-/ses-
    for subjfolder in `ls -d $in_bids/$subj/anat $in_bids/$subj/ses-*/anat 2> /dev/null`
    do

        subj_sess_dir=${subjfolder%/anat}
        subj_sess_dir=${subj_sess_dir##$in_bids/}
        if echo $subj_sess_dir | grep -q '/'
        then
            sess=${subj_sess_dir##*/}
            subj_sess_prefix=${subj}_${sess}
        else
            subj_sess_prefix=${subj}
        fi
        echo subjfolder $subjfolder
        echo subj_sess_dir $subj_sess_dir
        echo sess $sess
        echo subj_sess_prefix $subj_sess_prefix


	#import T1 from BIDS
	if [ ! -e $work_folder/$subj_sess_prefix/t1/t1.nii.gz ]
	then

		N_t1w=`eval ls $in_bids/$subj_sess_dir/anat/${subj_sess_prefix}${searchstring_t1w} | wc -l`
		in_t1w=`eval ls $in_bids/$subj_sess_dir/anat/${subj_sess_prefix}${searchstring_t1w} | head -n 1`

		if [ "$N_t1w" = 0 ]
		then
	
			echo "--- No T1w images found in $in_bids/$subj_sess_dir/anat ---"
			continue;
		fi


	pushd $work_folder
	 echo --- Running importT1 ---
	 echo Found $N_t1w matching T1w, using first found: $in_t1w
	 echo $execpath/deps/importT1 $in_t1w $subj_sess_prefix
	 $execpath/deps/importT1 $in_t1w $subj_sess_prefix
	 popd
	else
	 echo --- Skipping importT1 ---
	fi


	if [ "$use_atlasseg" = "0" ]
	then
		echo "Importing segmentations..."
		N_seg=`eval ls $in_seg_dir/$subj_sess_dir/anat/${subj_sess_prefix}${searchstring_seg} | wc -l`
		in_seg=`eval ls $in_seg_dir/$subj_sess_dir/anat/${subj_sess_prefix}${searchstring_seg} | head -n 1`
		
		if [ "$N_seg" = 0 ]
		then
	
			echo "--- No seg images found in $in_seg_dir/$subj_sess_dir/anat that match $searchstring_seg"
			continue;
		fi
		
	   	pushd $work_folder
		mkdir -p ${subj_sess_dir}/$target_prob_seg_dir


		smoothmm=1
		if [ -n "$seg_label" ]
		then
		echo "Importing label $seg_label from $in_seg , presmoothing with ${smoothmm}mm kernel"
		echo fslmaths $in_seg -thr $seg_label -uthr $seg_label -bin -s $smoothmm ${subj_sess_dir}/$target_prob_seg
		fslmaths $in_seg -thr $seg_label -uthr $seg_label -bin -s $smoothmm ${subj_sess_dir}/$target_prob_seg
		else
		echo "Importing all labels (binarizing) from $in_seg , presmoothing with ${smoothmm}mm kernel"
		echo fslmaths $in_seg -bin -s $smoothmm ${subj_sess_dir}/$target_prob_seg
		fslmaths $in_seg -bin -s $smoothmm ${subj_sess_dir}/$target_prob_seg

		fi

		popd

	fi


if false
then
	if [ "$use_atlasseg" = "1" ]
	then
	      #generating segmentations using atlas-based segmentation
	   pushd $work_folder

	      #performing registration
	      if [ ! -e $subj_sess_prefix/reg/bspline_f3d_t1/${atlas}_${subj_sess_prefix}/ctrlpt_${atlas}_to_${subj_sess_prefix}.nii.gz ]
    	      then
			 echo reg_bspline_f3d t1 $atlas $subj_sess_prefix
			 reg_bspline_f3d t1 $atlas $subj_sess_prefix
	      fi

	      if [ ! -e ${subj_sess_prefix}/$target_prob_seg ]
	      then

	      #propagating labels
	      echo propLabels_reg_bspline_f3d t1 $labelgroup_prob $atlas  $subj_sess_prefix -L
	      propLabels_reg_bspline_f3d t1 $labelgroup_prob $atlas  $subj_sess_prefix -L


	      target_prob_seg_in=${subj_sess_prefix}/labels/t1/${labelgroup_prob}_bspline_f3d_${atlas}/$template_prob_seg_file

	      #copy seg to standardized filename
	      mkdir -p ${subj_sess_prefix}/$target_prob_seg_dir
	      echo "cp -v $target_prob_seg_in ${subj_sess_prefix}/$target_prob_seg"
	      cp -v $target_prob_seg_in ${subj_sess_prefix}/$target_prob_seg

	      fi
	      popd
	fi
fi


	if [ -e $work_folder/${subj_sess_prefix}/reg/affine_aladin_t1/${atlas}_${subj_sess_prefix}/${subj_sess_prefix}_to_${atlas}.xfm ]
	then
		echo "reg_intersubj_aladin already run for $subj_sess_prefix"
	else
		subj_sess_prefix_reg="$subj_sess_prefix_reg ${subj_sess_prefix}"
	fi
	subj_sess_prefix_all="$subj_sess_prefix_all ${subj_sess_prefix}"

 done #ses
 done

	 #do these steps in parallel:
	#t1 pre-processing (required for niftyreg linear registration)
	   pushd $work_folder
		 parallel echo $execpath/deps/preprocT1 {} ::: ${subj_sess_prefix_all}
		 parallel $execpath/deps/preprocT1 {} ::: ${subj_sess_prefix_all}
   	   popd



	 #register atlas and subject t1
	 if [ -n "${subj_sess_prefix_reg}" ]
	 then

	   pushd $work_folder
	   echo "parallel echo $execpath/deps/reg_intersubj_aladin  t1 $atlas {} -I $execpath/deps/init.xfm ::: ${subj_sess_prefix_reg}"
	   parallel echo $execpath/deps/reg_intersubj_aladin  t1 $atlas {} -I $execpath/deps/init.xfm ::: ${subj_sess_prefix_reg}
	   parallel $execpath/deps/reg_intersubj_aladin  t1 $atlas {} -I $execpath/deps/init.xfm ::: ${subj_sess_prefix_reg}
	   popd
        fi

	#these steps take the segmentations in subj native space, and affine transform them to the atlas 
	pushd $work_folder
	parallel echo propLabels_backwards_intersubj_aladin t1  probseg  $atlas {} -L ::: $subj_sess_prefix_all
	parallel propLabels_backwards_intersubj_aladin t1  probseg  $atlas {} -L ::: $subj_sess_prefix_all
	popd


	#gen template for building iter1 template from iter0
	iter=0
	#copy the new segs into a iter0/ folder for the template building (this represents the affine registered subj data)
     	parallel mkdir -vp $work_folder/${seg_name}_iter$iter/{} ::: $subj_sess_prefix_all 
	parallel cp -v $work_folder/{}/$target_prob_seg_affine_atlas $work_folder/${seg_name}_iter$iter/{}/seg.affine.warpToTemplate.nii.gz ::: $subj_sess_prefix_all 

fi # if template_prob_seg iter 1 doesn't exist


#now, go up iters from 2 onwards to build a template if it doesn't exist

for iter in `seq 1 $MAX_ITER`
do

if [ ! -e $work_folder/${seg_name}_iter$iter/template_prob_seg.nii.gz ]
then

	buildTemplate $iter
	#break out of loop after building it..
	echo "Built template for iter $iter, exiting now"
	break;
else
	echo "Template for iter $iter already built.."
fi
done




  elif [ "$analysis_level" = "participant1" ]
 then

     echo "analysis level participant1 - run template to target mapping"

     #figure out which iteration we are on
     for iter in `seq 1 $MAX_ITER`
     do
	     if [ -e $work_folder/${seg_name}_iter$iter/template_prob_seg.nii.gz -a ! -e $work_folder/${seg_name}_iter$((iter+1))/template_prob_seg.nii.gz ]
	     then
		echo "running mapping for iter $iter"
		break
	     fi
     done

     for subj in $subjlist 
     do
      #add on sub- if not exists
      subj=`fixsubj $subj`
      #loop over sub- and sub-/ses-
    for subjfolder in `ls -d $in_bids/$subj/anat $in_bids/$subj/ses-*/anat 2> /dev/null`
    do

        subj_sess_dir=${subjfolder%/anat}
        subj_sess_dir=${subj_sess_dir##$in_bids/}
        if echo $subj_sess_dir | grep -q '/'
        then
            sess=${subj_sess_dir##*/}
            subj_sess_prefix=${subj}_${sess}
        else
            subj_sess_prefix=${subj}
        fi
        echo subjfolder $subjfolder
        echo subj_sess_dir $subj_sess_dir
        echo sess $sess
        echo subj_sess_prefix $subj_sess_prefix


       iter_out=$work_folder/${seg_name}_iter$iter
       if [ ! -e $work_folder/$iter_out/${subj_sess_prefix}/templateSurface_${seg_name}_inout.vtk ]
       then
	in_atlas_subj_xfm=$work_folder/${subj_sess_prefix}/reg/affine_aladin_t1/${atlas}_${subj_sess_prefix}/${atlas}_to_${subj_sess_prefix}.xfm
	
	pushd $work_folder
	echo $execpath/deps/computeSurfaceDisplacementsSingleStructure $subj_sess_prefix $subj_sess_prefix/$target_prob_seg_affine_atlas  $seg_name -N -o $iter_out -x $in_atlas_subj_xfm
	$execpath/deps/computeSurfaceDisplacementsSingleStructure $subj_sess_prefix $subj_sess_prefix/$target_prob_seg_affine_atlas  $seg_name -N -o $iter_out -x $in_atlas_subj_xfm
	popd
       fi

	if [ "$iter" = "$MAX_ITER" ]
	then

		#generate bids output for subj
		echo "completed final iteration, so generating BIDS links for ${subj_sess_prefix} output files"

		#make BIDS links for output
		out_subj_dir=$out_folder/$subj_sess_dir/anat

	        #surf parc in T1w space (vtk file, open in slicer or paraview)
     		vec_mni=$work_folder/surfdisp_singlestruct_$surfmorph_name/${subj_sess_prefix}/templateSurface_${seg_name}_disp.vtk
     		inout_mni=$work_folder/surfdisp_singlestruct_$surfmorph_name/${subj_sess_prefix}/templateSurface_${seg_name}_inout.vtk
     
     		out_vec_mni=$out_subj_dir/${subj_sess_prefix}_space-${atlas}_label-${seg_name}_surfmorphvec.vtk
     		out_inout_mni=$out_subj_dir/${subj_sess_prefix}_space-${atlas}_label-${seg_name}_surfmorphinout.vtk

     		inout_subj=$work_folder/surfdisp_singlestruct_$surfmorph_name/${subj_sess_prefix}/subjectSurface_${seg_name}_inout.vtk
     		vtk_subj=$work_folder/surfdisp_singlestruct_$surfmorph_name/${subj_sess_prefix}/subjectSurface_${seg_name}.vtk
		out_inout_subj=$out_subj_dir/${subj_sess_prefix}_space-T1w_label-${seg_name}_surfmorphinout.vtk
     		out_vtk_subj=$out_subj_dir/${subj_sess_prefix}_space-T1w_label-${seg_name}_surf.vtk

	       #surf vtk of avg template with displacements
   	       mkdir -p $out_subj_dir
	       ln -srfv $vec_mni $out_vec_mni
	       ln -srfv $inout_mni $out_inout_mni
	       ln -srfv $inout_subj $out_inout_subj
	       ln -srfv $vtk_subj $out_vtk_subj

	fi

   done
   done


 elif [ "$analysis_level" = "group2" ]
 then

     echo "analysis level group2, computing surf-based analysis" 

    mkdir -p $work_folder/etc
    list=$work_folder/etc/subjects.$analysis_level.$RANDOM
    rm -f $list
    touch ${list}
    for subj in $subjlist
    do
        subj=`fixsubj $subj`

#loop over sub- and sub-/ses-
    for subjfolder in `ls -d $in_bids/$subj/dwi $in_bids/$subj/ses-*/dwi 2> /dev/null`
    do

        subj_sess_dir=${subjfolder%/dwi}
        subj_sess_dir=${subj_sess_dir##$in_bids/}
        if echo $subj_sess_dir | grep -q '/'
        then
            sess=${subj_sess_dir##*/}
            subj_sess_prefix=${subj}_${sess}
        else
            subj_sess_prefix=${subj}
        fi
        echo subjfolder $subjfolder
        echo subj_sess_dir $subj_sess_dir
        echo sess $sess
        echo subj_sess_prefix $subj_sess_prefix

        echo $subj_sess_prefix >> $list
    done #ses
    done

#    pushd $work_folder      
#    runMatlabCmd  analyzeSurfData "'$list'" "'$in_seg_dir'" "'$surfmorph_name'" "'$target_labels_txt'" "'$out_folder/csv'" "'${bids_tags}'"
#    popd
echo "analyzeSurfData.m still under construction for this pipeline!"

    rm -f $list

 else
  echo "analysis_level $analysis_level does not exist"
  exit 1
fi


