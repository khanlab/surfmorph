function genSubjSpaceVTK (in_prop_surf_byu,in_xfm,in_disp_inout,out_subj_surf,out_subj_surf_vtk,out_subj_surf_inout_vtk)

%read in warped template
%in_prop_surf_byu='~/graham/scratch/test_surfmorph/surfmorph_dev/work/iter1/sub-CT01/propSurface_seed_nii.byu';
%in_xfm='~/graham/scratch/test_surfmorph/surfmorph_dev/work/sub-CT01/reg/affine_aladin_t1/MNI152NLin2009cAsym_sub-CT01/MNI152NLin2009cAsym_to_sub-CT01.xfm';

%out_subj_surf='~/graham/scratch/test_surfmorph/surfmorph_dev/work/iter1/sub-CT01/propSurface_subjspace_nii.byu'
%out_subj_surf_vtk='~/graham/scratch/test_surfmorph/surfmorph_dev/work/iter1/sub-CT01/propSurface_subjspace_nii.vtk'
%out_subj_surf_inout_vtk='~/graham/scratch/test_surfmorph/surfmorph_dev/work/iter1/sub-CT01/propSurface_subjspace_inout_nii.vtk'


%add in-out displacement to the vtk
%in_disp_inout='~/graham/scratch/test_surfmorph/surfmorph_dev/work/iter1/sub-CT01/seed.surf_inout.txt';

%transform data to target space

transformByuLinearXfm(in_prop_surf_byu,in_xfm,out_subj_surf);

system(sprintf('ConvertBYUtoVTK %s %s',out_subj_surf,out_subj_surf_vtk));
system(sprintf('CombineBYUandSurfDist %s %s %s',out_subj_surf,in_disp_inout,out_subj_surf_inout_vtk));

end

