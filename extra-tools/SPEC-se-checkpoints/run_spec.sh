#!/bin/bash
#

#Command Dictionary
declare -A cmds
cmds["500"]="perlbench_r_base.gem5-riscv -I./lib checkspam.pl 2500 5 25 11 150 1 1 1 1"
cmds["502"]="cpugcc_r_base.gem5-riscv ref32.c -O3 -fselective-scheduling -fselective-scheduling2 -o ref32.opts..s"
cmds["503"]="bwaves_r_base.gem5-riscv < bwaves_1.in"
cmds["505"]="mcf_r_base.gem5-riscv inp.in"
cmds["507"]="cactusBSSN_r_base.gem5-riscv spec_ref.par"
cmds["508"]="namd_r_base.gem5-riscv --input apoa1.input --output apoa1.ref.output --iterations 65"
cmds["510"]="parest_r_base.gem5-riscv ref.prm"
cmds["511"]="povray_r_base.gem5-riscv SPEC-benchmark-ref.ini"
cmds["519"]="lbm_r_base.gem5-riscv 3000 reference.dat 0 0 100_100_130_ldc.of"
cmds["520"]="omnetpp_r_base.gem5-riscv -c General -r 0"
cmds["521"]="wrf_r_base.gem5-riscv > rsl.out.0000"
cmds["523"]="cpuxalan_r_base.gem5-riscv -v t5.xml xalanc.xsl"
cmds["525"]="ldecod_r_base.gem5-riscv -i BuckBunny.264 -o BuckBunny.yuv"
cmds["526"]="blender_r_base.gem5-riscv sh3_no_char.blend --render-output sh3_no_char_ --threads 1 -b -F RAWTGA -s 849 -e 849 -a"
cmds["527"]="cam4_r_base.gem5-riscv"
cmds["531"]="deepsjeng_r_base.gem5-riscv ref.txt"
cmds["538"]="imagick_r_base.gem5-riscv -limit disk 0 refrate_input.tga -edge 41 -resample 181% -emboss 31 -colorspace YUV -mean-shift 19x19+15% -resize 30% refrate_output.tga"
cmds["541"]="leela_r_base.gem5-riscv ref.sgf"
cmds["544"]="nab_r_base.gem5-riscv 1am0 1122214447 122"
cmds["548"]="exchange2_r_base.gem5-riscv 6"
cmds["549"]="fotonik3d_r_base.gem5-riscv"
cmds["554"]="roms_r_base.gem5-riscv < ocean_benchmark2.in.x"
cmds["557"]="xz_r_base.gem5-riscv input.combined.xz 250 a841f68f38572a49d86226b7ff5baeb31bd19dc637a922a972b2e6d1257a890f6a544ecab967c313e370478c74f760eb229d4eef8a8d2836d233d3e9dd1430bf 40401484 41217675 7"

#First check arguments
if [[ $# -eq 0 ]]
then
	echo "No arguments supplied"
	exit 1
fi

numspec=$1

#Look for the directory associated to the number
dir=$(ls -d ${numspec}* 2>/dev/null | head -n 1)
if [[ -z "$dir" ]]
then
	echo "No directory starts with '$numspec'"
	exit 1
fi

#Check if there is a command associated to numspec
if [[ -z "${cmds[$numspec]}" ]]
then
	echo "No command associated to num '$numspec'"
	exit 1
fi

#run the command
cmd="${cmds[$numspec]}" 
echo "Entering '$dir' to run: $cmd"
#run command in a subshell to avoid change directory
(
   cd "$dir" || exit 1
   eval ./$cmd
)




