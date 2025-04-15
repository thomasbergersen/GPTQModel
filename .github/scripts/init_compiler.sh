#!/bin/bash

declare -A version_names
version_names["11.8"]="118"
version_names["12.1"]="121"
version_names["12.4"]="124"
version_names["12.6"]="126"

echo "@@@@@@@@@@ setting system env @@@@@@@@@@"


echo "Starting with args: $1 $2 $3"

log_dir=/var/logs/init_base
mkdir -p $log_dir
rm -rf "${log_dir:?}"/*

install_torch() {
  local cuda_version=$1
  local torch_version=$2
  local python_version=$3

  local cuda_version_name="${version_names[$cuda_version]}"

  installed_torch_version=$(python -c "import torch; print(torch.__version__)" || echo "no_torch")

  echo "target torch: $torch_version"
  echo "installed torch: $installed_torch_version"
  echo "cuda version: $cuda_version"
  echo "cuda version name: $cuda_version_name"
  echo "python version: $python_version"

  if [ "$torch_version+$cuda_version_name" == "$installed_torch_version" ] || [ "$torch_version+cu$cuda_version_name" == "$installed_torch_version" ] || [ "$torch_version+cu$cuda_version" == "$installed_torch_version" ]; then
    echo "torch was installed torch_version+cuda_version_name: $torch_version+$cuda_version_name"
    echo "torch was installed installed_torch_version: $installed_torch_version"
    echo "torch was installed torch_version+cucuda_version_name: $torch_version+cu$cuda_version_name"
    echo "torch was installed torch_version+cucuda_version: $torch_version+cu$cuda_version"
  else
    echo "Uninstalling torch"
    pip uninstall torch -y
    do_install_torch "$cuda_version" "$torch_version" "$python_version"
  fi
}

generate_torch_filename() {
  local cuda_version="$1"
  local torch_version="$2"
  local python_version="$3"

  local whl_file="torch-$torch_version+cu$cuda_version-cp$python_version-cp$python_version-linux_x86_64.whl"
  echo "${whl_file}"
}

do_install_torch() {
  local cuda_version=$1
  local torch_version=$2
  local python_version=$3
  if [[ "$cuda_version" == *"."* ]]; then
      cuda_version="${cuda_version/./}"
  fi
  if [[ "$python_version" == *"."* ]]; then
      python_version="${python_version/3./3}"
  fi

  whl_name=$(generate_torch_filename "$cuda_version" "$torch_version" "$python_version")

  echo "Installing torch cuda: $cuda_version torch_version: $torch_version python_version: $python_version"
  if [[ "$cuda_version" == "11.8" || "$cuda_version" == "118" ]]; then
    index="-i https://download.pytorch.org/whl/cu118"
  elif [[ "$cuda_version" == "12.1" || "$cuda_version" == "121" ]]; then
    index=""
  elif [[ "$cuda_version" == "12.4" || "$cuda_version" == "124" ]]; then
    index="-i https://download.pytorch.org/whl/cu124"
  elif [[ "$cuda_version" == "12.6" || "$cuda_version" == "126" ]]; then
    index="-i https://download.pytorch.org/whl/cu126"
  else
    echo "index=$index"
    echo "Unsupported CUDA version: $cuda_version" && exit 111
  fi
  uv pip install torch==$torch_version -U $index --system
}

setup_environment() {
  local cuda_version=$1
  local torch_version=$2
  local python_version=$3

  python_version=$3
  if [[ "$python_version" != *"."* ]]; then
      python_version="${python_version/3/3.}"
  fi

  echo "whereis python"
  whereis python

  echo "python -V"
  python -V

  echo "Updating pip"
  pip install -U pip uv wheel setuptools -i https://pypi.org/simple

  echo "Installing torch: $cuda_version $torch_version $python_version"
  install_torch $cuda_version $torch_version $python_version

  echo "Installing pytest twine wheel"
  uv pip install twine --system

  install_torch $cuda_version $torch_version $python_version

  python -V
  whereis pip
  pip show torch
  pip list
  pip cache purge && uv cache clean
  rm -rf /tmp/init
}

setup_environment "$1" "$2" "$3" "$4"

echo "All environments setup completed."
