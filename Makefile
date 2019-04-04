ORG=khanlab
NAME=diffparc-sumo
VERSION = dev

SINGULARITY_NAME=$(ORG)_$(NAME)_$(VERSION)
DOCKER_NAME=$(ORG)/$(NAME):$(VERSION)
DOCKER_LATEST=$(ORG)/$(NAME):latest

#SINGULARITY_DIR=/containers/singularity
SINGULARITY_DIR=~/graham/singularity/bids-apps
TMP_DIR=/containers/tmp


docker_build: 
	docker build -t $(DOCKER_NAME) --rm .

docker2singularity: 
	./docker2singularity.sh --outdir $(SINGULARITY_DIR) --tmpdir $(TMP_DIR) $(DOCKER_NAME)


clean_test:
	rm -rf dwi_singleshell dwi_singleshell_out

test_singleshell:
	mkdir dwi_singleshell
	wget -qO- https://www.dropbox.com/s/68oez1yhhnqp7z2/dwi_singleshell.tar | tar xv -C dwi_singleshell
	docker run --rm -it -v $(PWD)/dwi_singleshell:/in -v $(PWD)/dwi_singleshell_out:/out $(DOCKER_NAME) /in /out participant --no-bedpost
	test -f dwi_singleshell_out/prepdwi/sub-001/dwi/sub-001_dwi_space-T1w_preproc.nii.gz  
	test -f dwi_singleshell_out/prepdwi/sub-001/dwi/sub-001_dwi_space-T1w_preproc.bvec
	test -f dwi_singleshell_out/prepdwi/sub-001/dwi/sub-001_dwi_space-T1w_preproc.bval
	test -f dwi_singleshell_out/prepdwi/sub-001/dwi/sub-001_dwi_space-T1w_proc-FSL_FA.nii.gz
	test -f dwi_singleshell_out/prepdwi/sub-001/dwi/sub-001_dwi_space-T1w_proc-FSL_V1.nii.gz
	test -f dwi_singleshell_out/prepdwi/sub-001/dwi/sub-001_dwi_space-T1w_brainmask.nii.gz

docker_tag_latest:
	docker tag $(DOCKER_NAME) $(DOCKER_LATEST)

docker_push:
	docker push $(DOCKER_NAME)

docker_push_latest:
	docker push $(DOCKER_LATEST)

docker_run:
	docker run --rm -it $(DOCKER_NAME) /bin/bash	

docker_last_built_date:
	docker inspect -f '{{ .Created }}' $(DOCKER_NAME)

