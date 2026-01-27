


processor = SimpleProcessor(
            cpu_type=CPUTypes.ATOMIC,
            isa=ISA.RISCV,
            num_cores=1,
        )
memory = DualChannelDDR4_2400(size="4GiB")
cache_hierarchy = PrivateL1SharedL2CacheHierarchy(
            l1d_size="64KiB", l1i_size="64KiB", l2_size="1MiB"
        )

board = RiscvBoard(clk_freq="1.4GHz",
                   processor=processor,
                   memory=memory,
                   cache_hierarchy=cache_hierarchy)

board.set_kernel_disk_workload(
    bootloader=obtain_resource(resource_id="riscv-bootloader-opensbi-1.3.1"),
    kernel=obtain_resource(resource_id="riscv-linux-6.8.12-kernel"),
    disk_image=DiskImageResource("/nfs/home/ce/felixfdec/riscv-ubuntu-24.04-20250515.img", root_partition="1")
)