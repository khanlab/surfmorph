function mapIntensityOnSurf (in_subj_surf_byu,in_qmri_nii, out_qmri_txt, out_qmri_surf_vtk)

%in_subj_surf_byu='~/graham/scratch/test_surfmorph/surfmorph_dev/work/iter1/sub-CT01/propSurface_subjspace_nii.byu'
%in_qmri_nii='~/graham/scratch/test_surfmorph/surfmorph_dev/work/sub-CT01/labels/t1/probseg/striatum_cortical.nii.gz'
%out_qmri_txt='~/graham/scratch/test_surfmorph/surfmorph_dev/work/iter1/sub-CT01/interp.test_qmri.txt';
%out_qmri_surf_vtk='~/graham/scratch/test_surfmorph/surfmorph_dev/work/iter1/sub-CT01/propSurface_subjspace_qmri_nii.vtk'

qmri_nii=load_nifti(in_qmri_nii);

[faces,vertices]=readTriByu(in_subj_surf_byu);

startc=qmri_nii.vox2ras*ones(4,1)-1;
endc=qmri_nii.vox2ras*[size(qmri_nii.vol),1]'-1;

for i=1:3
vrange{i}=startc(i):qmri_nii.vox2ras(i,i):endc(i);
end
[X,Y,Z]=meshgrid(vrange{2},vrange{1},vrange{3});

interpvol=interp3(X,Y,Z,qmri_nii.vol,vertices(:,2),vertices(:,1),vertices(:,3));

csvwrite(out_qmri_txt,interpvol);

system(sprintf('CombineBYUandSurfDist %s %s %s',in_subj_surf_byu,out_qmri_txt,out_qmri_surf_vtk));

end
