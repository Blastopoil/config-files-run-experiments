# Tutorial: gem5 full system riscv simulation with your own config and a personalized disk image
### By Félix Fernández de Castro

This tutorial explains my take on how to configure a gem5 full system simulation for a RISC-V architecture. 

You won't use one of the config scripts provided by gem5 in the gem5/configs/ folder, but rather make your own script and modify a disk image so as to run from it whatever binary you choose. It also shows how to compile and utilize m5term to access the simulated system.

You will work in three different workspaces: your host machine where you have your gem5 base directory, a quemu virtual machine which you use to modify the disk image (launched from the host machine), and the full system gem5 simulation (also launched from the host).

## Dependencies

* **gem5** Having compiled  (example: `build/RISCV/gem5.opt`).
* **Programs:** `qemu`

---

## Part 1: Adding a binary to a disk image (uses QEMU)

To put files inside the disk image you will open it via a QEMU Virtual Machine using such disk image. To set it up, you need to obtain three components provided by me:

1-A disk image (riscv-ubuntu-20221118.img) \
2-A boot loader (uboot.elf) \
3-A firmware jump binary (fw_jump.bin) \

If you'd like to know where this files come from, the **disk image** I obtained already built from the gem5 resources repository. In its repository site (https://resources.gem5.org/resources/riscv-ubuntu-20.04-img/raw?database=gem5-resources&version=1.0.0), if you go to the 'Raw' tab you will see a code box in a JSON format. Nearing the end of such code, there's a line with the link hosting a compressed version of the disk image ("url": "https://dist.gem5.org/dist/develop/images/riscv/ubuntu-20-04/riscv-ubuntu-20221118.img.gz",). The **boot loader** is taken from user libraries after installing the u-boot-qemu package and copying it from /usr/lib/u-boot/qemu-riscv64_smode/uboot.elf. The **fw jump binary** is taken from user libraries too after installing the package opensbi by copying it from /usr/lib/riscv64-linux-gnu/opensbi/generic/fw_jump.elf. To sum up, this are the commands to execute to get all the files:

```bash
you@host_machine: wget https://dist.gem5.org/dist/develop/images/riscv/ubuntu-20-04/riscv-ubuntu-20221118.img.gz
you@host_machine: gunzip riscv-ubuntu-20221118.img.gz
you@host_machine: sudo apt update
you@host_machine: sudo apt install u-boot-qemu
you@host_machine: cp /usr/lib/u-boot/qemu-riscv64_smode/uboot.elf .
you@host_machine: sudo apt install opensbi
you@host_machine: cp /usr/lib/riscv64-linux-gnu/opensbi/generic/fw_jump.bin .
```

With the necessary files you can execute the following command to launch the QEMU VM:

```bash
you@host_machine: qemu-system-riscv64 -machine virt -nographic -m 2048 -smp 8 -bios fw_jump.bin -kernel uboot.elf -device virtio-net-device,netdev=eth0 -netdev user,id=eth0,hostfwd=tcp::5555-:22 -drive file=riscv-ubuntu-20221118.img,format=raw,if=virtio
```

Once the VM is up and running you select in the U-Boot menu which Ubuntu you want to run (I take number 1), and later get taken to an autologin for the root.

Before touching anything else open another shell in your host system in order to move the binary you want to the disk image. **From the host machine** (not the qemu sesion) execute the following command. When asked for a password, you type "ubuntu".

```bash
you@host_machine: scp -P 5555 <your_binary> ubuntu@localhost:

```

Now the binary is in the disk image. You return to the shell with the QEMU VM and modify the gem5_init.sh script:

```bash
root@ubuntu: echo "/home/ubuntu/binario_prueba" > gem5_init.sh
```

Now the disk image is configured to execute your binary once it has the ubuntu fully initialized.

## Part 2: Execute the gem5 full system simulation

From your gem5 configuration script, add the following to the board before running the simulation. Achtung! PUT THE APPROPIATE PATH TO YOUR FILE

~~~python
board.set_kernel_disk_workload(
    bootloader=obtain_resource(resource_id="riscv-bootloader-opensbi-1.3.1"),
    kernel=obtain_resource(resource_id="riscv-linux-6.5.5-kernel"),
    disk_image=DiskImageResource("<path to your disk image>/riscv-ubuntu-20221118.img", root_partition="1"), #HEY YOU! MODIFY THIS!
)
~~~

Once this is done, execute the script with gem5

```bash
you@host_machine: gem5 <your_config_script>
```

And open another shell from which you will do this:

```bash
you@host_machine: cd gem5/util/term
you@host_machine: make m5term
you@host_machine: ./m5term 3456
```

Now you can see the process of your full system simulation initializing and eventually executing the binary.