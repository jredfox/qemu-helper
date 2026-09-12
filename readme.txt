1. Extract to ~/vms
2. Download and Install Linux ISO's into ~/vms/iso while making sure they end in the linux-architecture.iso format. i386 for x86 (32 bit), amd64 for x64 (intel 64 bit), aarch64 for arm64, s390x for IMB-Z server arch, riscv64 for risc-v
3. Run bash setup.sh
4. Run Generated linux-arch_iso.sh to install linux to the virtual cd
5. Run Generated linux-arch.sh to boot qemu

TODO:
- cleanup code
- acpi=off add as an option dynamcially via "-no-acpi" or "-old" in the file name or `$no_acpi` inside the boot script shell else leave acpi on
- machine needs to be "virt" for non x86
- virtio-gpu-pci or virtio-gpu need to be a device for non x86 family
- if the arch requires a bios we need to add a bios for non x86
- LWDE make it work for other archs besides intel (virtio-gpu-pci or virtio-gpu)
- add share folder to all archs
- support kernal boot for normal boot
- support fedora pkg qemu install
- support alpine pkg qemu install
