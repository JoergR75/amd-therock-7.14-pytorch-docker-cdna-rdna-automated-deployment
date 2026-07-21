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
