%script for analyzing surface-based data -- clean-up in progress

function processSubjSurfData ( subj, prepdwi_dir,parcellation_name,target_labels_txt )

%% for testing:
%subj='CT01'
%prepdwi_dir='';
%parcellation_name='striatum_cortical'
%target_labels_txt='../cfg/StriatumTargets.csv'


%% files to save:

%for sure:
% VTK with maxprob parcellation label overlay
%   currently: work/subj_vtk/%s.parc.vtk
% VTK with displacement vector overlay
%   currently: work/surfdisp_singlestruct_striatum_cortical/sub-CT01/templateSurface_seed_disp.vtk
% VTK with in/out scalar overlay
%   currently: work/surfdisp_singlestruct_striatum_cortical/sub-CT01/templateSurface_seed_inout.vtk

% need to verify what space these are in -- MNI? yes..

%maybe:
% VTK with meanConnectedFA overlay

%% definitions
data_dir='.';


surfdisp_dir=sprintf('%s/surfdisp_singlestruct_%s',data_dir,parcellation_name);

template_byu=sprintf('%s/template/seed_nii.byu',surfdisp_dir);

dtispace_byu=sprintf('%s/%s/propSurface_seed_nii_subj_dti.byu',surfdisp_dir,subj);

% read in $target_labels_txt from parcellate_cfg for list of targets
targets=importdata(target_labels_txt);
targets=targets.textdata;

hemi={'Left','Right'};

hemi_s={'l','r'};


%% get template surface (in MNI space)

[p_mni,v_mni,e_mni]=readBYUSurface(template_byu,0);

nvert=length(v_mni);

%first, get labelling of left & right striatum (using x=0 to split)


hemi_label{1}=v_mni(:,1)<0;
hemi_label{2}=v_mni(:,1)>0;



%%  create parcellation based on surface tracking

%max_label 
%all_maxlabels=zeros(nvert,length(subjects));


    conn_matrix_txt=sprintf('%s/%s/bedpost.%s/vertexTract/matrix_seeds_to_all_targets',data_dir,subj,parcellation_name);
    
    conn=importdata(conn_matrix_txt);
   
    %compute maxprob label:
    [maxval,maxlabel]=max(conn,[],2);
    
    
 % write each subject's parcellation to vtk file

  mkdir('subj_vtk');
    writeByuWithScalarToVTK(dtispace_byu,maxlabel,sprintf('subj_vtk/%s.parc.vtk',subj));

    
%% get surf disp:

    %get T1-based surf displacement data
    surfdisp_txt=sprintf('%s/%s/seed.surf_inout.txt',surfdisp_dir,subj);
    surfdisp_inout=importdata(surfdisp_txt);
   



%% evaluate FA along fibres in each parcellation

% leaving this out since too memory-intensive when nsamples is very high..

%    fdt_matrix=sprintf('%s/%s/bedpost.%s/vertexTract/fdt_matrix2.dot',data_dir,subj,parcellation_name);
%    
%    %following command is memory intensive:
%    mat=spconvert(load(fdt_matrix));
%   
%    maskimg=sprintf('%s/bedpost/%s/nodif_brain_mask.nii.gz',prepdwi_dir,subj);
%    mask=load_nifti(maskimg);
%    
%    faimg=dir(sprintf('%s/prepdwi/%s/dwi/%s_dwi_space-T1w*proc-FSL_FA.nii.gz',prepdwi_dir,subj,subj));
%    
%    fa=load_nifti([faimg.folder, filesep, faimg.name]);
%    
%    fa_mat=fa.vol(mask.vol>0);
%    
%    tract_fa=mat*fa_mat./(mat*ones(size(fa_mat)));
    
    


%% get surface area (in MNI space) for each parcellation

nverts=zeros(length(hemi),length(targets));
surfarea=zeros(length(hemi),length(targets));
meansurfdisp=zeros(length(hemi),length(targets));
%mean_fa=zeros(length(hemi),length(targets));

    
    for h=1:length(hemi)
        for i=1:length(targets)
            
            i;
            selection=(maxlabel==i & hemi_label{h});
            nverts(h,i)=sum(selection);
            surfarea(h,i)=computeSurfArea(v_mni,e_mni,selection);
            
            meansurfdisp(h,i)=mean(surfdisp_inout(selection));
%            mean_fa(h,i)=mean(tract_fa(selection));

        end
    end
    
    
mkdir('subj_mat');
%save these variables in .mat files to be retrieved by group-level process
subj_mat=sprintf('subj_mat/%s',subj);
%save(subj_mat,'nverts','surfarea','meansurfdisp','mean_fa');
save(subj_mat,'nverts','surfarea','meansurfdisp');


end
