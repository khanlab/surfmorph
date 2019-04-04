%script for analyzing surface-based data -- clean-up in progress

function analyzeSurfData ( subj_list ,prepdwi_dir,parcellation_name, target_labels_txt,out_folder,bids_tags)

% here, we just want to write out the csv tables



% definitions
data_dir='.';


% read in $target_labels_txt from parcellate_cfg for list of targets
targets=importdata(target_labels_txt);
targets=targets.textdata;

hemi={'Left','Right'};

hemi_s={'l','r'};


% load in subject/group info

subjects=importdata(subj_list);


surfarea_table=zeros(length(subjects),length(targets)*2);
meansurfdisp_table=zeros(length(subjects),length(targets)*2);
%mean_fa_table=zeros(length(subjects),length(targets)*2);

for s=1:length(subjects)
    
    
    subj=subjects{s};

    subj_mat=sprintf('subj_mat/%s.mat',subj);
    if exist(subj_mat,'file') == 0
	    disp(sprintf('data for %s does not exist, skipping!', subj_mat))
	    continue;
    end
    load(subj_mat);

    %not sure if this still needs fixing? need to verify.. Jan 27 2019
    % FIX THIS l,r,l,r (not lllll rrrrr)
    
    %left hemi
    surfarea_table(s,1:2:end) = surfarea(1,:);
    %right hemi
    surfarea_table(s,2:2:end) = surfarea(2,:)';

    %left hemi
    meansurfdisp_table(s,1:2:end) = meansurfdisp(1,:);
    %right hemi
    meansurfdisp_table(s,2:2:end) = meansurfdisp(2,:);

    %left hemi
    %mean_fa_table(s,1:2:end) = mean_fa(1,:);
    %right hemi
    %mean_fa_table(s,2:2:end) = mean_fa(2,:);

end

r=1;
 var_names={};
 for t=1:length(targets)
     for h=1:2
         var_names{r}=sprintf('%s_%s',hemi{h},targets{t});
         r=r+1;
     end
 end

writetable(array2table(surfarea_table,'VariableNames',var_names,'RowNames',subjects),sprintf('%s/surfarea_%s.csv',out_folder,bids_tags),'WriteRowNames',1,'WriteVariableNames',1);
writetable(array2table(meansurfdisp_table,'VariableNames',var_names,'RowNames',subjects),sprintf('%s/surfdisp_%s.csv',out_folder,bids_tags),'WriteRowNames',1,'WriteVariableNames',1);
%writetable(array2table(mean_fa_table,'VariableNames',var_names,'RowNames',subjects),sprintf('%s/dti-FA_%s_surfspace.csv',out_folder,bids_tags),'WriteRowNames',1,'WriteVariableNames',1);


end
