ARG IMAGE_EXT

ARG REGISTRY=ghcr.io/epics-containers
ARG RUNTIME=${REGISTRY}/epics-base${IMAGE_EXT}-runtime:7.0.10ec1
ARG DEVELOPER=${REGISTRY}/ioc-areadetector${IMAGE_EXT}-developer:3.14ec2
# for pre-built common support and faster builds of this generic IOC:
# - change above to￼DEVELOPER=${REGISTRY}/ioc-asyn${IMAGE_EXT}-developer:4.45ec2
# - comment out uv pip install lines below (unless a newer ibek is needed)
# - remove ansible.sh lines for all support modules provided by ioc-asyn

##### build stage ##############################################################
FROM  ${DEVELOPER} AS developer

# The devcontainer mounts the project root to /epics/generic-source
# Using the same location here makes devcontainer/runtime differences transparent.
ENV SOURCE_FOLDER=/epics/generic-source
# connect ioc source folder to its known location
RUN ln -s ${SOURCE_FOLDER}/ioc ${IOC}

# Update the apt cache
RUN apt update -y

# Get the current version of ibek
COPY requirements.txt requirements.txt
RUN uv pip install --upgrade -r requirements.txt

WORKDIR ${SOURCE_FOLDER}/ibek-support

COPY ibek-support/_ansible _ansible
ENV PATH=$PATH:${SOURCE_FOLDER}/ibek-support/_ansible

# get the required support modules and build them
COPY ibek-support/ADAndor3/ ADAndor3/
RUN ansible.sh ADAndor3

# get the ioc source and build it
COPY ioc ${SOURCE_FOLDER}/ioc
RUN ansible.sh ioc

# install runtime proxy for non-native builds
RUN bash ${IOC}/install_proxy.sh

##### runtime preparation stage ################################################
FROM developer AS runtime_prep

# get the products from the build stage and reduce to runtime assets only
# /python is created by uv and is needed in the runtime target
RUN ibek ioc extract-runtime-assets /assets /python

##### runtime stage ############################################################
FROM ${RUNTIME} AS runtime

# get runtime assets from the preparation stage
COPY --from=runtime_prep /assets /

# install runtime system dependencies, collected from install.sh scripts
RUN ibek support apt-install-runtime-packages

# launch the startup script with stdio-expose to allow console connections
CMD ["bash", "-c", "${IOC}/start.sh"]
