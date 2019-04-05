#!/bin/bash

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

participant_label=
matching_T1w=
n_cpus=8
reg_init_subj=
surfmorph_type=striatum_cortical
in_seg_dir=


# option 1: have prob. seg in atlas space -> use it to segment targets -- just need to specify atlas & atlas_prob_seg (this is currently implemented)
# option 2: have pre-computed target segs AND atlas prob seg -- need to specify atlas, atlas_prob_seg, in_seg_dir, and seg_matching_string
# option 3: have pre-computed tarfget segs, but no atlas prob seg -- need to specify in_seg_dir, and seg_matching_string, then:
	# transform segs to atlas space, and then generate avg to build prob seg

if [ "$#" -lt 3 ]
then
 echo "Usage: surfmorph bids_dir output_dir {participant,group} <optional arguments>"
 echo ""
 echo " Optional arguments:"
 echo "          [--in_seg_dir SEG_DIR]" 
 echo "          [--participant_label PARTICIPANT_LABEL [PARTICIPANT_LABEL...]]"
 echo "          [--matching_T1w MATCHING_STRING"
 echo "          [--reg_init_participant PARTICIPANT_LABEL"
 echo "          [--surfmorph_type SURFMORPH_TYPE (default: striatum_cortical; can alternatively specify config file) "
 echo "          [--in_atlas_dir ATLAS_DIR]"
 echo ""
 echo "	Analysis levels:"
 echo "		participant: T1 pre-proc, label prop, surface-based displacement morphometry (LDDMM)"
 echo "		group: generate surface-based analysis stats csv"
 echo ""
 echo "         Available parcellate types:"
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
     --n_cpus )       # takes an option argument; ensure it has been specified.
          if [ "$2" ]; then
                n_cpus=$2
                  shift
	      else
              die 'error: "--n_cpus" requires a non-empty option argument.'
            fi
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
         die 'error: "--matching_dwi" requires a non-empty option argument.'
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



if [  -n "$in_seg_dir" ] # if specified
then

	if [ ! -e $in_seg_dir ]
	then
	    echo "ERROR: in_seg_dir $in_seg_dir does not exist!"
	    exit 1
	fi
	in_seg_dir=`realpath $in_seg_dir`

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



source $surfmorph_cfg


mkdir -p $work_folder $derivatives
work_folder=`realpath $work_folder`



target_prob_seg_dir=labels/t1/probseg
target_prob_seg=labels/t1/probseg/${surfmorph_name}.nii.gz
target_prob_seg_affine_atlas=labels/t1/probseg_affine_aladin_to_$atlas/${surfmorph_name}.nii.gz

#exports for called scripts
export in_atlas_dir surfmorph_cfg cfg_dir target_prob_seg_affine_atlas surfdisp_name


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
	





if [ "$analysis_level" = "participant" ]
then
 echo " running pre-processing in participant analysis"
  
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


	#t1 pre-processing (required for niftyreg linear registration)
	if [ ! -e $work_folder/$subj_sess_prefix/t1/t1.brain.inorm.nii.gz ]
	then
	   pushd $work_folder
		# preproc t1
		    echo $execpath/deps/preprocT1  ${subj_sess_prefix}
		    $execpath/deps/preprocT1  ${subj_sess_prefix}
		popd
		fi
		   #register atlas and subject t1
		 if [ ! -e $work_folder/${subj_sess_prefix}/reg/affine_aladin_t1/${atlas}_${subj_sess_prefix}/${atlas}_to_${subj_sess_prefix}.xfm ]
		 then
	   pushd $work_folder
			 echo "atlas is $atlas"
		    echo $execpath/deps/reg_intersubj_aladin  t1 $atlas ${subj_sess_prefix}
		    $execpath/deps/reg_intersubj_aladin  t1 $atlas ${subj_sess_prefix}
	  	popd
		 fi




	#TODO, import seg data
	if [ -n "$in_seg_dir" ]
	then
		
	echo "    importing data from in_seg_dir"
	echo " NOT IMPLEMENTED YET!"
	
	else
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

 done #ses
 done


 # at this point, have template and target prob segs set (template_prob_seg and template_prob_seg)
 


    echo "analysis level participant, surface-based processing"
    echo "   computing surface-based morphometry"
     pushd $work_folder

     #first prep template (if not done yet, run it once, uses mkdir lock for synchronization, and wait time of 5 minutes)
     template_lock=etc/run_template.lock
     if mkdir -p $template_lock
     then
         echo $execpath/deps/computeSurfaceDisplacementsSingleStructure template_placeholder  $surfmorph_cfg -N -t
         $execpath/deps/computeSurfaceDisplacementsSingleStructure template_placeholder  $surfmorph_cfg -N -t
         rmdir $template_lock

	 else
	    sleep 300 #shouldn't take longer than 5 min
     fi

    popd

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


      if [ ! -e $work_folder/surfdisp_singlestruct_${parcellation_name}/${subj_sess_prefix}/templateSurface_seed_inout.vtk ]
	then
        pushd $work_folder


	      #these steps take the segmentations in subj native space, and affine transform them to the atlas 
	      echo propLabels_backwards_intersubj_aladin t1  probseg  $atlas $subj_sess_prefix -L
	      propLabels_backwards_intersubj_aladin t1  probseg  $atlas $subj_sess_prefix -L
	      echo $execpath/deps/computeSurfaceDisplacementsSingleStructure $subj_sess_prefix $surfmorph_cfg  -N
	      $execpath/deps/computeSurfaceDisplacementsSingleStructure $subj_sess_prefix $surfmorph_cfg  -N
          popd
	fi

     #make BIDS links for output
     out_subj_dir=$out_folder/$subj_sess_dir/anat

     #surf parc in T1w space (vtk file, open in slicer or paraview)
     vec_mni=$work_folder/surfdisp_singlestruct_$parcellation_name/${subj_sess_prefix}/templateSurface_seed_disp.vtk
     inout_mni=$work_folder/surfdisp_singlestruct_$parcellation_name/${subj_sess_prefix}/templateSurface_seed_inout.vtk
     
     out_vec_mni=$out_subj_dir/${subj_sess_prefix}_space-${atlas}_${bids_tags}_surfmorphvec.vtk
     out_inout_mni=$out_subj_dir/${subj_sess_prefix}_space-${atlas}_${bids_tags}_surfmorphinout.vtk

     #surf vtk of avg template with displacements
     mkdir -p $out_subj_dir
     ln -srfv $vec_mni $out_vec_mni
     ln -srfv $inout_mni $out_inout_mni


     done #ses
 done
     


 elif [ "$analysis_level" = "group2" ]
 then

     echo "analysis level group2, computing surf-based analysis (formerly group3)" 

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

    source $surfmorph_cfg
    pushd $work_folder      
    runMatlabCmd  analyzeSurfData "'$list'" "'$in_seg_dir'" "'$parcellation_name'" "'$target_labels_txt'" "'$out_folder/csv'" "'${bids_tags}'"
    popd

    rm -f $list

 else
  echo "analysis_level $analysis_level does not exist"
  exit 1
fi


