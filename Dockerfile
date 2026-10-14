ARG REGISTRY=ghcr.io/epics-containers
ARG RUNTIME=${REGISTRY}/epics-base-runtime:7.0.10ec4-beta.2
ARG DEVELOPER=${REGISTRY}/epics-base-developer:7.0.10ec4-beta.2

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
COPY ibek-support/iocStats/ iocStats
RUN ansible.sh iocStats

COPY ibek-support/sequencer/ sequencer
RUN ansible.sh sequencer

COPY ibek-support/sscan/ sscan
RUN ansible.sh sscan

COPY ibek-support/calc/ calc
RUN ansible.sh calc

COPY ibek-support/asyn/ asyn
RUN ansible.sh asyn

COPY ibek-support/busy/ busy
RUN ansible.sh busy

COPY ibek-support/autosave/ autosave
RUN ansible.sh autosave

COPY ibek-support/pvlogging/ pvlogging
RUN ansible.sh pvlogging

COPY ibek-support/ADCore/ ADCore
RUN ansible.sh ADCore

# Andor SDK3 (libatcore) is vendor binary only, bundled by ADAndor3 for
# linux-x86_64 only, so this image is built for linux/amd64 only
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
