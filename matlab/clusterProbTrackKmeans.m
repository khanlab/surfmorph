function clusterProbTrackKmeans (in_subj4d_file,out_subj_kmeans)

%takes in, e.g.:
%work/sub-XX/bedpost.CIT168_striatum_cortical/probtrack/MNI152NLin2009cAsym/seeds.4d.nii.gz

%subj4d_file='seeds.4d.nii.gz';
%out_maxprob='maxprob.nii.gz';
%out_subj_kmeans='kmeans_subjCentroids.nii.gz';

prob_nii=load_nifti(in_subj4d_file);
prob=prob_nii.vol;

%merge left and right (left is odd indices, right is even)
for i=1:2:(size(prob,4)-1)
     prob(:,:,:,i)=prob(:,:,:,i)+prob(:,:,:,i+1);
end
prob=prob(:,:,:,[1:2:end-1]);

threshold=0;
mask=mean(prob,4)>threshold;
N=sum(mask(:));
M=size(prob,4); %num features
featmat=zeros(N,M);

for f=1:size(prob,4)
    tempF=squeeze(prob(:,:,:,f));    
    featmat(:,f)=reshape(tempF(mask==1),N,1);
end



%do k-means
distance='correlation';

%
k=M; 
    
%find values that are too low for correlation distance
X = bsxfun(@minus, featmat, mean(featmat,2));
Xnorm = sqrt(sum(X.^2, 2));
badvals=Xnorm<=eps(max(Xnorm));
%throw them out:
featmat(badvals==1,:)=[];

%try also running kmeans to completion
init=eye(k,M);
%k=7;
[idx_subj,Csubj,sumd,D]=kmeans(featmat,[],'Distance',distance,'Start',eye(k,M));


% % plot cluster centroids
% figure; b=bar3(Csubj);
% for k = 1:length(b)
%     zdata = b(k).ZData;
%     b(k).CData = zdata;
%     b(k).FaceColor = 'interp';
% end
% title(sprintf('centroids after subj-specific k-means'));
% 

%update mask to only have good values
newmask=zeros(size(mask));
newmask(find(mask>0))=~badvals;


%save image
%convert to image
idximg=zeros(size(newmask));
idximg(find(newmask>0))=idx_subj;


%lateralize the labels (using xdim)
leftmask=zeros(size(idximg));
leftmask(idximg>0)=1;
rightmask=zeros(size(idximg));
rightmask(idximg>0)=1;
leftmask(floor(end/2)+1:end,:,:)=0;
rightmask(1:floor(end/2),:,:)=0;

%right side: y=2x,  left side: y=2x-1
lat_idx=idximg.*rightmask.*2 + idximg.*leftmask.*2 - leftmask;

%save nifti
out_nii=prob_nii;
out_nii.vol=lat_idx;
save_nifti(out_nii,out_subj_kmeans);

% %save maxprob for comparison
% [maxf,idx]=max(featmat,[],2);
% 
% %convert to image
% idximg=zeros(size(newmask));
% idximg(find(newmask>0))=idx;
% 
% 
% 
% %lateralize the labels (using xdim)
% leftmask=zeros(size(idximg));
% leftmask(idximg>0)=1;
% rightmask=zeros(size(idximg));
% rightmask(idximg>0)=1;
% leftmask(floor(end/2)+1:end,:,:)=0;
% rightmask(1:floor(end/2),:,:)=0;
% 
% %right side: y=2x,  left side: y=2x-1
% lat_idx=idximg.*rightmask.*2 + idximg.*leftmask.*2 - leftmask;
% 
% 
% 
% %save nifti
% out_nii=prob_nii;
% out_nii.vol=lat_idx;
% save_nifti(out_nii,out_maxprob);



end