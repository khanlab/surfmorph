FROM khanlab/neuroglia-core:v1.5
MAINTAINER <alik@robarts.ca>


RUN mkdir /diffparcellate
COPY . /diffparcellate

#add path for octave
RUN echo addpath\(genpath\(\'/diffparcellate/matlab\'\)\)\; >> /etc/octave.conf 

#add path for root folder, deps, and mial-depends
ENV PATH /diffparcellate/mial-depends:/diffparcellate/deps:/diffparcellate:$PATH

#set below for runMatlabCmd
ENV PIPELINE_TOOL_DIR /diffparcellate
#set below for reg_*_aladin/bspline tools
ENV PIPELINE_CFG_DIR /diffparcellate/cfg


#install MCR
RUN bash /diffparcellate/deps/05.install_MCR.sh /opt v95 R2018b
ENV MCRROOT /opt/mcr/v95
ENV MCRBINS /diffparcellate/mcr/v95



ENTRYPOINT ["/diffparcellate/run.sh"]
