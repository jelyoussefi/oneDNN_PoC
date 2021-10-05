#----------------------------------------------------------------------------------------------------------------------
# Flags
#----------------------------------------------------------------------------------------------------------------------
SHELL:=/bin/bash

CURRENT_DIR:=$(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))
BUILD_DIR=${CURRENT_DIR}/build
TOOLCHAIN_DIR=${CURRENT_DIR}/toolchain
TOOLS_DIR=${CURRENT_DIR}/tools

ONEAPI_ROOT ?= /opt/intel/oneapi
export TERM=xterm

dev ?= cpu

CUDA ?= OFF
ONEAPI_DPC_COMPILER ?= ON

ifeq ($(CUDA),ON)
ONEAPI_DPC_COMPILER = OFF
TOOLCHAIN_FLAGS = --cuda --cmake-opt=-DCMAKE_PREFIX_PATH="/usr/local/cuda/lib64/stubs/"
endif

ifeq ($(ONEAPI_DPC_COMPILER),ON)
CXX_COMPILER=$${ONEAPI_ROOT}/compiler/latest/linux/bin/dpcpp
else
CXX_COMPILER=${TOOLCHAIN_DIR}/llvm/build/bin/clang++
LD_FLAGS=${TOOLCHAIN_DIR}/llvm/build/install/lib
endif

CXX_FLAGS=" -fsycl -fopenmp -O3 -g -I$${DNNLROOT}/include "

#----------------------------------------------------------------------------------------------------------------------
# Targets
#----------------------------------------------------------------------------------------------------------------------
default: run 
.PHONY: build

install-oneapi:
	@if [ ! -f "${ONEAPI_ROOT}/setvars.sh" ]; then \
		$(call msg,Installing OneAPI ...) && \
		sudo apt update -y  && \
		sudo apt install -y wget software-properties-common && \
		wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB && \
		sudo apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB && \
		sudo rm GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB && \
		sudo echo "deb https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list && \
		sudo add-apt-repository "deb https://apt.repos.intel.com/oneapi all main" && \
		sudo apt update -y && \
		sudo apt install -y intel-basekit intel-oneapi-rkcommon; \
	fi
	
toolchain:
ifneq ($(ONEAPI_DPC_COMPILER),ON)
	@if [ ! -f "${TOOLCHAIN_DIR}/.done" ]; then \
		mkdir -p ${TOOLCHAIN_DIR} && rm -rf ${TOOLCHAIN_DIR}/* && \
		$(call msg,Building Cuda Toolchain  ...) && \
		cd ${TOOLCHAIN_DIR} && \
			dpkg -l ninja-build  > /dev/null 2>&1  || sudo apt install -y ninja-build && \
			git clone https://github.com/intel/llvm -b sycl && \
			cd llvm && \
				python ./buildbot/configure.py   ${TOOLCHAIN_FLAGS} && \
				python ./buildbot/compile.py && \
		touch ${TOOLCHAIN_DIR}/.done; \
	fi
	@dpkg -l | grep -q libomp-dev || sudo apt install -f libomp-dev
endif

build: toolchain	
	@$(call msg,Building Mammo Application   ...)
	@mkdir -p ${BUILD_DIR} && cd ${BUILD_DIR} && \
		bash -c  'source ${ONEAPI_ROOT}/setvars.sh --force && \
		CXX=${CXX_COMPILER} \
		CXXFLAGS=${CXX_FLAGS} \
		LDFLAGS=${LDD_FLAGS} \
		cmake \
			-DCUDA=${CUDA} \
			-DCMAKE_PREFIX_PATH=/usr/local/lib \
			.. && \
		make '

run: build
	@$(call msg,Runung the Mammo Application ...)
	@rm -f ./output/*.raw
	@rm -f ./core
	@bash -c  'source ${ONEAPI_ROOT}/setvars.sh --force && \
		LD_LIBRARY_PATH=${LD_FLAGS}:./:$${LD_LIBRARY_PATH} \
		 ${BUILD_DIR}/convol ${dev}'



clean:
	@rm -rf  ${BUILD_DIR}



#----------------------------------------------------------------------------------------------------------------------
# helper functions
#----------------------------------------------------------------------------------------------------------------------
define msg
	tput setaf 2 && \
	for i in $(shell seq 1 120 ); do echo -n "-"; done; echo  "" && \
	echo "         "$1 && \
	for i in $(shell seq 1 120 ); do echo -n "-"; done; echo "" && \
	tput sgr0
endef

