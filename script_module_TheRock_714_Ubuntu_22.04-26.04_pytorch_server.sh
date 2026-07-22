#!/bin/bash
LOGFILE="$HOME/therock714_installation.log"
exec > >(tee -a "$LOGFILE") 2>&1
# ================================================================================================================
# TheRock 7.14 + PyTorch 2.12 (Stable) + Transformers + Docker Setup
# Compatible with Ubuntu 22.04.x, 24.04.x and 26.04.x (Desktop & Server) — Ubuntu 20.04.x is no longer supported
# ================================================================================================================
# Description:
# This script automates the installation of AMD TheRock 7.14, PyTorch 2.12 (Stable), Transformers, and Docker
# on Ubuntu 22.04.x, 24.04.x and 26.04.x systems. It automatically fetches the appropriate installation scripts and performs
# a fully non-interactive setup optimized for both desktop and server environments.
# ================================================================================================================
#
# REQUIREMENTS:
# ---------------------------------------------------------------------------------------------------------------
# Operating System (OS):
#   - Ubuntu 22.04.5 LTS (Jammy Jellyfish)
#   - Ubuntu 24.04.4 LTS (Noble Numbat)
#   - Ubuntu 26.04.x LTS (Resolute Raccoon)
#
# Kernel Versions Tested:
#   - Ubuntu 22.04.5: 5.15.0-186
#   - Ubuntu 24.04.4: 6.17.0-1028-oem
#   - Ubuntu 26.04.x: 7.0.0-28
#
# Supported Hardware:
#   - AMD CDNA1 | CDNA2 | CDNA3 | CDNA4 | RDNA3 | RDNA4 GPU Architectures | Strix APU Architecture
#
# SOFTWARE VERSIONS:
# ---------------------------------------------------------------------------------------------------------------
# ROCm Platform:         7.14
# ROCm Release Notes:    https://rocm.docs.amd.com/en/docs-7.14.0/about/release-notes.html
#
# PyTorch:               2.12.0+rocm7.14.0
# Transformers:          5.14.1
# Docker:                29.6.2 min. 29.0.0 (the script will verify and skip installation if minimum requirements are installed)
#
# INCLUDED TOOLS:
# ---------------------------------------------------------------------------------------------------------------
#   - git                 → Version control system for tracking changes
#   - git-lfs             → Git Large File Storage for handling large datasets & binaries
#   - cmake               → Cross-platform build system for compiling and packaging software
#   - htop                → Interactive process monitoring tool
#   - ncdu                → NCurses Disk Usage analyzer for efficient storage management
#   - libmsgpack-dev      → Development package for MessagePack (binary serialization format)
#   - freeipmi-tools      → Utilities for querying BMC firmware versions and IPMI functions
#
# ---------------------------------------------------------------------------------------------------------------
# Author:                Joerg Roskowetz
# Estimated Runtime:     ~15 minutes (depending on system performance and internet speed)
# Last Updated:          July 21st, 2026
# ================================================================================================================

# global stdout method
# set -euo pipefail # for debug purpose - will stop after an error message
info()  { printf "\n[INFO] %s\n" "$*"; }
function print () {
    printf "\033[1;32m\t$1\033[1;35m\n"; sleep 4
}

clear &&
printf '\n🚀 AMD TheRock 7.14 + PyTorch 2.12 (Stable) + Transformers + Docker Setup\nCompatible with Ubuntu 22.04.x, 24.04.x and 26.04.x (Desktop & Server)\n ⚠️ Ubuntu 20.04.x is no longer supported'
print '\n 🔄 Ubuntu OS Update ...\n'

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get -y upgrade

print '\n ✅ Done\n'

install_focal() {
    print '\n ⚠️ Ubuntu 20.04.x (focal) is not longer be supported for ROCm 7 and bejond. The last supported version is ROCm 6.4.0.\n'
    print 'More details can be verified under https://repo.radeon.com/amdgpu-install/6.4/ubuntu/ \n'
}

install_jammy() {
    print '\nUbuntu 22.04.x (jammy jellyfish) TheRock stack installation method has been set.\n'
    print '\n ✔️ Checking if ROCm/TheRock is installed ...\n'

    if dpkg -l | grep -q rocm; then
        print '\nROCm detected. Removing ROCm/TheRock and associated packages ...\n'

        sudo apt autoremove -y amdrocm7.13
        sudo apt autoremove -y amdrocm7.14
        sudo apt autoremove -yq rocm-core
        sudo apt autoremove -yq amdgpu-dkms
        sudo rm /etc/apt/sources.list.d/rocm.list
        sudo rm -rf /var/cache/apt/*
        sudo apt clean all -yq
        sudo apt update

        print '\n ✅ ROCm/TheRock packages removed successfully.'
    else
        print 'No ROCm/TheRock installation detected.'
    fi

    print '\n ✔️ Checking for PyTorch packages installed via pip ...\n'

    # Use pip with --break-system-packages to avoid "externally-managed-environment" error
    if python3 -m pip list | grep torch; then
        python3 -m pip uninstall -y torch torchvision torchaudio pytorch-triton-rocm
        printf "\nPyTorch packages uninstalled successfully.\n"
    else
        printf "\nNo PyTorch packages found.\n"
    fi

    # Pause before continuing
    read -n1 -r -p "Press any key to continue..." key
    
    # Install the latest HWE kernel available for Ubuntu 22.04 LTS
    # sudo DEBIAN_FRONTEND=noninteractive apt install -y linux-generic-hwe-22.04

    # add the user to the sudo group (iportant e.g. to compile vllm, flashattention in a pip environment)
    sudo usermod -a -G video,render ${SUDO_USER:-$USER}
    sudo usermod -aG sudo ${SUDO_USER:-$USER}

   # Install prerequisites
    sudo DEBIAN_FRONTEND=noninteractive apt update

    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        python3-pip \
        python3-venv \
        python3-dev \
        git \
        git-lfs \
        htop \
        ncdu \
        cmake \
        ninja-build \
        pkg-config \
        pciutils \
        hwloc \
        freeipmi-tools \
        libmsgpack-dev \
        libstdc++-11-dev \
        libatomic1 \
        libquadmath0 \
        libnuma1 \
        libnuma-dev \
        numactl \
        libssl-dev

    # Download and install the AMD ROCm GPG key
    sudo mkdir --parents --mode=0755 /etc/apt/keyrings
    wget https://repo.amd.com/rocm/packages-multi-arch/gpg/rocm.gpg -O - | \
        gpg --dearmor | sudo tee /etc/apt/keyrings/amdrocm.gpg > /dev/null

    sudo tee /etc/apt/sources.list.d/rocm.list << EOF
    deb [arch=amd64 signed-by=/etc/apt/keyrings/amdrocm.gpg] https://repo.amd.com/rocm/packages-multi-arch/ubuntu2204 stable main
EOF
    sudo apt update

    print '\n 📦 Installing TheRock 7.14 complete Core SDK including runtimes, compilers, development tools, and dependencies ...\n'

    sudo apt install -y amdrocm7.14

    # Add ROCm binaries to PATH
    echo 'export PATH="/opt/rocm/bin:$PATH"' >> ~/.bashrc

    # Add ROCm libraries to LD_LIBRARY_PATH
    echo 'export LD_LIBRARY_PATH="/opt/rocm/lib:/opt/rocm/lib64:$LD_LIBRARY_PATH"' >> ~/.bashrc

    # Add local user bin to PATH
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

    # Apply changes immediately in current shell
    source ~/.bashrc

    print '\n 📦 Installing PyTorch 2.12 (Stable) for TheRock 7.14, Transformers environment ...\n'

    python3 -m pip install --upgrade \
        pip \
        wheel \
        setuptools
    python3 -m pip install \
        --index-url https://repo.amd.com/rocm/whl-multi-arch/ \
        "torch[device-gfx1201]==2.12.0+rocm7.14.0" \
        "torchvision[device-gfx1201]==0.27.0+rocm7.14.0" \
        "torchaudio==2.11.0+rocm7.14.0"
    python3 -m pip install --upgrade \
        accelerate \
        datasets \
        diffusers \
        joblib \
        protobuf \
        sentencepiece \
        setuptools_scm \
        transformers
}

install_noble() {

    print '\nUbuntu 24.04.x (noble numbat) TheRock stack installation method has been set.\n'
    print '\n ✔️ Checking if ROCm/TheRock is installed ...\n'

    if dpkg -l | grep -q rocm; then
        print '\nROCm/TheRock detected. Removing ROCm/TheRock and associated packages ...\n'

        sudo apt autoremove -y amdrocm7.13
        sudo apt autoremove -y amdrocm7.14
        sudo apt autoremove -y rocm-core
        sudo apt autoremove -y amdgpu-dkms
        sudo rm /etc/apt/sources.list.d/rocm.list
        #sudo apt autoremove -y rocm-bandwidth-test
        sudo rm -rf /var/cache/apt/*
        sudo apt clean all
        sudo apt update

        print '\n ✅ ROCm/TheRock packages removed successfully.'
    else
        print 'No ROCm/TheRock version installation detected.'
    fi

    print '\n ✔️ Checking for PyTorch packages installed via pip ...\n'

    # Use pip with --break-system-packages to avoid "externally-managed-environment" error
    if python3 -m pip list | grep torch; then
        python3 -m pip uninstall -y torch torchvision torchaudio pytorch-triton-rocm --break-system-packages
        printf "\nPyTorch packages uninstalled successfully.\n"
    else
        printf "\nNo PyTorch packages found.\n"
    fi

    # Pause before continuing
    read -n1 -r -p "Press any key to continue..." key

    # Update to OEM kernel 6.17.x
    sudo apt install -y \
        linux-image-6.17.0-1028-oem \
        linux-modules-6.17.0-1028-oem \
        linux-headers-6.17.0-1028-oem

    # add the user to the sudo group (iportant e.g. to compile vllm, flashattention in a pip environment)
    sudo usermod -a -G video,render ${SUDO_USER:-$USER}
    sudo usermod -aG sudo ${SUDO_USER:-$USER}

    # Install prerequisites
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        "linux-headers-$(uname -r)" \
        "linux-modules-extra-$(uname -r)" \
        python3-pip \
        git \
        git-lfs \
        htop \
        freeipmi-tools \
        ncdu \
        cmake \
        libmsgpack-dev \
        libstdc++-13-dev \
        libatomic1 \
        libquadmath0 \
        libnuma1 \
        libnuma-dev \
        numactl

    # Download and install the AMD ROCm GPG key
    sudo mkdir --parents --mode=0755 /etc/apt/keyrings
    wget https://repo.amd.com/rocm/packages-multi-arch/gpg/rocm.gpg -O - | \
        gpg --dearmor | sudo tee /etc/apt/keyrings/amdrocm.gpg > /dev/null
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/amdrocm.gpg] https://repo.amd.com/rocm/packages-multi-arch/ubuntu2404 stable main" \
        | sudo tee /etc/apt/sources.list.d/rocm.list > /dev/null
    sudo apt update

    # Installing complete Core SDK including runtimes, compilers, development tools, and dependencies for GFX ID 120x

    print '\n 📦 Installing TheRock 7.14 complete Core SDK including runtimes, compilers, development tools, and dependencies for GFX ID 120x ...\n'

    sudo apt install -y amdrocm7.14

    # Add ROCm binaries to PATH
    info "Configuring shell environment..."

    grep -qxF 'export PATH="/opt/rocm/bin:$PATH"' ~/.bashrc || \
        echo 'export PATH="/opt/rocm/bin:$PATH"' >> ~/.bashrc

    grep -qxF 'export LD_LIBRARY_PATH="/opt/rocm/lib:/opt/rocm/lib64:$LD_LIBRARY_PATH"' ~/.bashrc || \
        echo 'export LD_LIBRARY_PATH="/opt/rocm/lib:/opt/rocm/lib64:$LD_LIBRARY_PATH"' >> ~/.bashrc

    grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc || \
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

    export PATH="/opt/rocm/bin:$HOME/.local/bin:$PATH"
    export LD_LIBRARY_PATH="/opt/rocm/lib:/opt/rocm/lib64:${LD_LIBRARY_PATH:-}"

    print '\n 📦 Installing PyTorch 2.12 (Stable) for TheRock 7.14, Transformers environment ...\n'

    # Install PyTorch
    python3 -m pip install --upgrade \
        pip \
        wheel \
        setuptools --break-system-packages
    python3 -m pip install \
        --index-url https://repo.amd.com/rocm/whl-multi-arch/ \
        "torch[device-gfx1201]==2.12.0+rocm7.14.0" \
        "torchvision[device-gfx1201]==0.27.0+rocm7.14.0" \
        "torchaudio==2.11.0+rocm7.14.0" --break-system-packages
    python3 -m pip install --upgrade \
        accelerate \
        datasets \
        diffusers \
        joblib \
        protobuf \
        sentencepiece \
        setuptools_scm \
        transformers --break-system-packages
}

install_resolute() {

    print '\nUbuntu 26.04.x (resolute raccoon) TheRock stack installation method has been set.\n'
    print '\n ✔️ Checking if ROCm/TheRock is installed ...\n'

    if dpkg -l | grep -q rocm; then
        print '\nROCm/TheRock detected. Removing ROCm/TheRock and associated packages ...\n'

        sudo apt autoremove -y amdrocm7.13
        sudo apt autoremove -y amdrocm7.14
        sudo apt autoremove -y rocm-core
        sudo apt autoremove -y amdgpu-dkms
        sudo rm /etc/apt/sources.list.d/rocm.list
        #sudo apt autoremove -y rocm-bandwidth-test
        sudo rm -rf /var/cache/apt/*
        sudo apt clean all
        sudo apt update

        print '\n ✅ ROCm/TheRock packages removed successfully.'
    else
        print 'No ROCm/TheRock version installation detected.'
    fi

    print '\n ✔️ Checking for PyTorch packages installed via pip ...\n'

    # Use pip with --break-system-packages to avoid "externally-managed-environment" error
    if python3 -m pip list | grep torch; then
        python3 -m pip uninstall -y torch torchvision torchaudio pytorch-triton-rocm --break-system-packages
        printf "\nPyTorch packages uninstalled successfully.\n"
    else
        printf "\nNo PyTorch packages found.\n"
    fi

    # Pause before continuing
    read -n1 -r -p "Press any key to continue..." key

    # add the user to the sudo group (iportant e.g. to compile vllm, flashattention in a pip environment)
    sudo usermod -a -G video,render ${SUDO_USER:-$USER}
    sudo usermod -aG sudo ${SUDO_USER:-$USER}

    # Install prerequisites
    sudo DEBIAN_FRONTEND=noninteractive apt update
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        linux-generic \
        python3-pip \
        python3-venv \
        python3-dev \
        git \
        git-lfs \
        htop \
        ncdu \
        cmake \
        pkg-config \
        pciutils \
        hwloc \
        freeipmi-tools \
        libmsgpack-dev \
        libstdc++-16-dev \
        libatomic1 \
        libquadmath0 \
        libnuma1 \
        libnuma-dev \
        numactl \
        libssl-dev

    # Download and install the AMD ROCm GPG key
    sudo mkdir --parents --mode=0755 /etc/apt/keyrings
    wget https://repo.amd.com/rocm/packages-multi-arch/gpg/rocm.gpg -O - | \
        gpg --dearmor | sudo tee /etc/apt/keyrings/amdrocm.gpg > /dev/null

    sudo tee /etc/apt/sources.list.d/rocm.list << EOF
    deb [arch=amd64 signed-by=/etc/apt/keyrings/amdrocm.gpg] https://repo.amd.com/rocm/packages-multi-arch/ubuntu2604 stable main
EOF
    sudo apt update

    # Installing complete Core SDK including runtimes, compilers, development tools, and dependencies

    print '\n 📦 Installing TheRock 7.14 complete Core SDK including runtimes, compilers, development tools, and dependencies\n'

    sudo apt install -y amdrocm7.14

    # Add ROCm binaries to PATH
    info "Configuring shell environment..."

    grep -qxF 'export PATH="/opt/rocm/bin:$PATH"' ~/.bashrc || \
        echo 'export PATH="/opt/rocm/bin:$PATH"' >> ~/.bashrc

    grep -qxF 'export LD_LIBRARY_PATH="/opt/rocm/lib:/opt/rocm/lib64:$LD_LIBRARY_PATH"' ~/.bashrc || \
        echo 'export LD_LIBRARY_PATH="/opt/rocm/lib:/opt/rocm/lib64:$LD_LIBRARY_PATH"' >> ~/.bashrc

    grep -qxF 'export PATH="$HOME/.local/bin:$PATH"' ~/.bashrc || \
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc

    export PATH="/opt/rocm/bin:$HOME/.local/bin:$PATH"
    export LD_LIBRARY_PATH="/opt/rocm/lib:/opt/rocm/lib64:${LD_LIBRARY_PATH:-}"

    print '\n 📦 Installing PyTorch 2.12 (Stable) for TheRock 7.14, Transformers environment ...\n'

    # Install PyTorch
    python3 -m pip install --upgrade \
        pip \
        wheel \
        setuptools --break-system-packages
    python3 -m pip install \
        --index-url https://repo.amd.com/rocm/whl-multi-arch/ \
        "torch[device-gfx1201]==2.12.0+rocm7.14.0" \
        "torchvision[device-gfx1201]==0.27.0+rocm7.14.0" \
        "torchaudio==2.11.0+rocm7.14.0" --break-system-packages
    python3 -m pip install --upgrade \
        accelerate \
        datasets \
        diffusers \
        joblib \
        protobuf \
        sentencepiece \
        setuptools_scm \
        transformers --break-system-packages
}

# Function detecting installed Ubuntu version
if command -v lsb_release >/dev/null 2>&1; then
    UBUNTU_CODENAME=$(lsb_release -cs)
    UBUNTU_VERSION=$(lsb_release -rs)

    if [ "$UBUNTU_CODENAME" = "focal" ]; then
        print '\nDetected Ubuntu Focal Fossa (20.04.x).\n'
        install_focal

    elif [ "$UBUNTU_CODENAME" = "jammy" ]; then
        print '\nDetected Ubuntu Jammy Jellyfish (22.04.x).\n'
        install_jammy

    elif [ "$UBUNTU_CODENAME" = "noble" ]; then
        print '\nDetected Ubuntu Noble Numbat (24.04.x).\n'
        install_noble

    elif [ "$UBUNTU_CODENAME" = "resolute" ]; then
        print '\nDetected Ubuntu Resolute Raccoon (26.04.x).\n'
        install_resolute

    else
        print "\nUnknown Ubuntu version: $UBUNTU_VERSION ($UBUNTU_CODENAME)\n"
    fi
else
    print '\nlsb_release command not found. Unable to determine Ubuntu version.\n'
fi

# create test script
cd ~
cat <<EOF > test.py
#!/usr/bin/env python3

import torch
import subprocess
import platform
import transformers
# import vllm
import re
import os

# Ubuntu version (pretty + numeric)
ubuntu_pretty = subprocess.getoutput("lsb_release -ds")
ubuntu_version = platform.release()

# function for PCIe settings
def get_all_gpu_pcie_info():
    output = subprocess.check_output(["lspci", "-D"], text=True)

    gpu_bdfs = [
        line.split()[0]
        for line in output.splitlines()
        if any(x in line for x in ["VGA", "3D", "Display"])
    ]

    infos = []

    for gpu_bdf in gpu_bdfs:
        try:
            sysfs = f"/sys/bus/pci/devices/{gpu_bdf}"

            with open(f"{sysfs}/current_link_width") as f:
                current_width = f.read().strip()

            with open(f"{sysfs}/max_link_width") as f:
                max_width = f.read().strip()

            with open(f"{sysfs}/current_link_speed") as f:
                current_speed = f.read().strip()

            with open(f"{sysfs}/max_link_speed") as f:
                max_speed = f.read().strip()

            infos.append({
                "bdf": gpu_bdf,
                "current_width": current_width,
                "max_width": max_width,
                "current_speed": current_speed,
                "max_speed": max_speed
            })

        except Exception as e:
            infos.append({
                "bdf": gpu_bdf,
                "error": str(e)
            })

    return infos

print("\n 🐧 Ubuntu:", ubuntu_pretty)
print(" 🔢 Kernel:", ubuntu_version)

def get_cpu_model():
    with open("/proc/cpuinfo") as f:
        for line in f:
            if "model name" in line:
                return line.split(":")[1].strip()

print("\n 💻 Installed CPU:", get_cpu_model())

def get_total_memory_gb():
    with open("/proc/meminfo") as f:
        for line in f:
            if line.startswith("MemTotal:"):
                # Extract the numeric value in kB
                mem_kb = int(re.findall(r'\d+', line)[0])
                # Convert to GB (1 GB = 1024^2 kB)
                mem_gb = mem_kb / (1024 ** 2)
                return f" 🗄️ Total System-Memory: {mem_gb:.0f} GB"

if __name__ == "__main__":
    print(get_total_memory_gb())

print("\n ✅ PyTorch version:", torch.__version__)
print(" 🧪 ROCm version:", subprocess.getoutput("/opt/rocm/bin/hipconfig --version"))
print(" ✅ Is ROCm available:", torch.version.hip is not None)
print(" 🤗 Transformers version:", transformers.__version__)
# print(" 🧠 vLLM version:", vllm.__version__)
print("\n ⚡ Number of GPUs:", torch.cuda.device_count())

pcie_infos = get_all_gpu_pcie_info()

if torch.cuda.device_count() > 0:
    for gpu_id in range(torch.cuda.device_count()):

        print(f"\n ⚡ GPU {gpu_id} Name: {torch.cuda.get_device_name(gpu_id)}")

        free_mem, total_mem = torch.cuda.mem_get_info(gpu_id)

        free_mem_gb = free_mem / (1024**3)
        total_mem_gb = total_mem / (1024**3)

        print(f"   💾 Free Memory : {free_mem_gb:.2f} GB")
        print(f"   💾 Total Memory: {total_mem_gb:.2f} GB")

        # Match PCIe info by index
        if gpu_id < len(pcie_infos):
            info = pcie_infos[gpu_id]

            if "error" in info:
                print(f"   🔌 PCI Device : {info['bdf']}")
                print(f"   ❌ PCIe Error : {info['error']}")
            else:
                print(f"   🔌 PCI Device : {info['bdf']}")
                print(
                    f"   🔌 PCIe Width : x{info['current_width']} "
                    f"(max x{info['max_width']})"
                )
                print(
                    f"   🚀 PCIe Speed : {info['current_speed']} "
                    f"(max {info['max_speed']})"
                )

else:
    print("\n ⚡ GPU Name: No GPU detected")

# Create two tensors and add them on the GPU
if torch.cuda.is_available():

    for gpu_id in range(torch.cuda.device_count()):

        device = torch.device(f"cuda:{gpu_id}")

        a = torch.rand(3, 3, device=device)
        b = torch.rand(3, 3, device=device)
        c = a + b

        print(f"\n ✅ Tensor operation successful on GPU {gpu_id}")
        print(f"   Device: {torch.cuda.get_device_name(gpu_id)}")
        print(c)

else:
    print("❌ No GPU detected")
EOF

set -e
MIN_DOCKER_VERSION="29.0.0"

# Function to compare Docker versions
version_ge() {
    [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]
}

# Function: install_docker
install_docker() {
    echo -e "\nInstalling and configuring Docker (stable version) with required dependencies..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
    https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo DEBIAN_FRONTEND=noninteractive apt-get update
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -yq docker-ce docker-ce-cli containerd.io
    sudo usermod -a -G docker ${SUDO_USER:-$USER}
    sudo service docker restart
    docker --version
    echo -e "\n ✅ Docker installation completed."
}

# Docker version check
if command -v docker &> /dev/null; then
    INSTALLED_DOCKER_VERSION=$(docker --version | awk '{print $3}' | sed 's/,//')
    echo "Detected Docker version: ${INSTALLED_DOCKER_VERSION}"
    if version_ge "$INSTALLED_DOCKER_VERSION" "$MIN_DOCKER_VERSION"; then
        echo "Docker ${INSTALLED_DOCKER_VERSION} meets minimum version (${MIN_DOCKER_VERSION}). Skipping installation."
    else
        echo "Docker version below ${MIN_DOCKER_VERSION}, updating..."
        install_docker
    fi
else
    echo "Docker not found. Installing..."
    install_docker
fi

# Final installation message
print ' ✅ Finished TheRock 7.14 + PyTorch 2.12 (Stable) + Transformers & Docker environment installation and setup.\n'

# Post-reboot testing instructions
printf "\n 🔹 After the reboot, test your installation with:\n"
printf "  • rocminfo\n"
printf "  • installation process is stored in $HOME/therock714installation.log\n"
printf "  • amd-smi\n"

# PyTorch verification
printf "\n 🔹 Verify the active PyTorch device:\n"
printf "  - python3 test.py\n"

# vLLM Docker images for RDNA4 and CDNA1/2/3/4
printf "\n 🔹 Install the latest vLLM Docker images:\n"
printf "  - RDNA4 → sudo docker pull rocm/vllm:rocm7.14.0_rdna_ubuntu24.04_py3.14_pytorch_2.11.0_vllm_0.23.0\n"
printf "  - CDNA → sudo docker pull rocm/vllm:latest\n"

# reboot option
print ' 🔄 Reboot system now (recommended)? (y/n)'
read q
if [ $q == "y" ]; then
    for i in 3 2 1
    do
        printf "🔄 Reboot in $i ...\r"; sleep 1
    done
    sudo reboot
fi
