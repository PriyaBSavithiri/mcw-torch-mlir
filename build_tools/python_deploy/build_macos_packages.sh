#!/bin/bash
# Copyright 2022 The IREE Authors
#
# Licensed under the Apache License v2.0 with LLVM Exceptions.
# See https://llvm.org/LICENSE.txt for license information.
# SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception

# build_macos_packages.sh
# One stop build of IREE Python packages for MacOS. This presumes that
# dependencies are installed from install_macos_deps.sh. This will build
# for a list of Python versions synchronized with that script and corresponding
# with directory names under:
#   /Library/Frameworks/Python.framework/Versions
#
# MacOS convention is to refer to this as major.minor (i.e. "3.9", "3.10").
# Valid packages:
#   torch-mlir

set -eu -o errtrace

this_dir="$(cd $(dirname $0) && pwd)"
repo_root="$(cd $this_dir/../../ && pwd)"
python_versions="${python_versions:-3.9 3.10}"
output_dir="${output_dir:-${this_dir}/wheelhouse}"
packages="${packages:-torch-mlir}"

PKG_VER_FILE=${repo_root}/torch_mlir_package_version ; [ -f $PKG_VER_FILE ] && . $PKG_VER_FILE
export TORCH_MLIR_PYTHON_PACKAGE_VERSION="${TORCH_MLIR_PYTHON_PACKAGE_VERSION:-0.0.1}"
echo "Setting torch-mlir Python Package version to: ${TORCH_MLIR_PYTHON_PACKAGE_VERSION}"

# Note that this typically is selected to match the version that the official
# Python distributed is built at.
export MACOSX_DEPLOYMENT_TARGET=11.0
export CMAKE_OSX_ARCHITECTURES="arm64;x86_64"

function run() {
  echo "Using python versions: ${python_versions}"

  local orig_path="$PATH"

  # Build phase.
  for package in $packages; do
    echo "******************** BUILDING PACKAGE ${package} ********************"
    for python_version in $python_versions; do
      python_dir="/Library/Frameworks/Python.framework/Versions/$python_version"
      if ! [ -x "$python_dir/bin/python3" ]; then
        echo "ERROR: Could not find python3: $python_dir (skipping)"
        continue
      fi
      export PATH=$python_dir/bin:$orig_path
      echo ":::: Python version $(python3 --version)"
      case "$package" in
        torch-mlir)
          clean_wheels torch-mlir $python_version
          build_torch_mlir
          ;;
        *)
          echo "Unrecognized package '$package'"
          exit 1
          ;;
      esac
    done
  done
}

function build_torch_mlir() {
  python -m pip install -r $repo_root/requirements.txt --extra-index-url https://download.pytorch.org/whl/nightly/cpu
  CMAKE_GENERATOR=Ninja \
  TORCH_MLIR_PYTHON_PACKAGE_VERSION=${TORCH_MLIR_PYTHON_PACKAGE_VERSION} \
  MACOSX_DEPLOYMENT_TARGET=11.0 \
  CMAKE_OSX_ARCHITECTURES="arm64;x86_64" \
  python -m pip wheel -v -w $output_dir $repo_root --extra-index-url https://download.pytorch.org/whl/nightly/cpu
}

function clean_wheels() {
  local wheel_basename="$1"
  local python_version="$2"
  echo ":::: Clean wheels $wheel_basename $python_version"
  rm -f $output_dir/${wheel_basename}-*-${python_version}-*.whl
}

run
