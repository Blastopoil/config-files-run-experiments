import os
from dotenv import load_dotenv, find_dotenv
from pathlib import Path

# Try to load .env from this repo first, then fall back to find_dotenv()
_repo_env = Path(__file__).resolve().parents[1] / ".env"
if _repo_env.exists():
    load_dotenv(_repo_env)
else:
    load_dotenv(find_dotenv())

SPEC_path = os.getenv("SPEC_path")
ckpt_path = os.getenv("ckpt_path")

if not SPEC_path or not ckpt_path:
    raise RuntimeError(
        "Missing SPEC_path or ckpt_path. Ensure .env is loaded and contains these keys."
    )

spec_base_dir = SPEC_path + "/"
ckpt_base_dir = ckpt_path + "/"

spec_app_dirs = {
    500: "500.perlbench_r/", 502: "502.gcc_r/", 503: "503.bwaves_r/",
    505: "505.mcf_r/", 507: "507.cactuBSSN_r/", 508: "508.namd_r/",
    510: "510.parest_r/", 511: "511.povray_r/", 519: "519.lbm_r/",
    520: "520.omnetpp_r/", 521: "521.wrf_r/", 523: "523.xalancbmk_r/",
    525: "525.x264_r/", 526: "526.blender_r/", 527: "527.cam4_r/",
    531: "531.deepsjeng_r/", 538: "538.imagick_r/", 541: "541.leela_r/",
    544: "544.nab_r/", 548: "548.exchange2_r/", 549: "549.fotonik3d_r/",
    554: "554.roms_r/", 557: "557.xz_r/"
}

spec_app_binaries = {
    500: "perlbench_r_base.gem5-riscv", 
    502: "cpugcc_r_base.gem5-riscv",
    503: "bwaves_r_base.gem5-riscv",    
    505: "mcf_r_base.gem5-riscv",
    507: "cactusBSSN_r_base.gem5-riscv",
    508: "namd_r_base.gem5-riscv",
    510: "parest_r_base.gem5-riscv",    
    511: "povray_r_base.gem5-riscv",
    519: "lbm_r_base.gem5-riscv",       
    520: "omnetpp_r_base.gem5-riscv",
    521: "wrf_r_base.gem5-riscv",       
    523: "cpuxalan_r_base.gem5-riscv",
    525: "ldecod_r_base.gem5-riscv",    
    526: "blender_r_base.gem5-riscv",
    527: "cam4_r_base.gem5-riscv",      
    531: "deepsjeng_r_base.gem5-riscv",
    538: "imagick_r_base.gem5-riscv",   
    541: "leela_r_base.gem5-riscv",
    544: "nab_r_base.gem5-riscv",       
    548: "exchange2_r_base.gem5-riscv",
    549: "fotonik3d_r_base.gem5-riscv", 
    554: "roms_r_base.gem5-riscv",
    557: "xz_r_base.gem5-riscv"
}

spec_app_input_files = {
    502: spec_base_dir+spec_app_dirs[502]+"ref32.c",
    503: spec_base_dir+spec_app_dirs[503]+"bwaves_1.in",
    554: spec_base_dir+spec_app_dirs[554]+"ocean_benchmark2.in.x"
}

spec_app_output_files = {
    521: spec_base_dir+spec_app_dirs[521]+"rsl.out.0000"
}

spec_app_arguments = {
    500: ["-I./lib", "checkspam.pl", "2500", "5", "25", "11", "150", "1", "1", "1", "1"],
    502: ["-O3", "-fselective-scheduling", "-fselective-scheduling2", "-o", "ref32.opts..s"],
    503: [],
    505: [ spec_base_dir+spec_app_dirs[505]+"inp.in"],
    507: [ spec_base_dir+spec_app_dirs[507]+"spec_ref.par"],
    508: ["--input", spec_base_dir+spec_app_dirs[508]+"apoa1.input", "--output", spec_base_dir+spec_app_dirs[508]+"apoa1.ref.output", "--iterations", "65"],
    510: [spec_base_dir+spec_app_dirs[510]+"ref.prm"],
    511: [spec_base_dir+spec_app_dirs[511]+"SPEC-benchmark-ref.pov", spec_base_dir+spec_app_dirs[511]+"SPEC-benchmark-ref.ini"],
    519: ["3000", spec_base_dir+spec_app_dirs[519]+"reference.dat", "0", "0", spec_base_dir+spec_app_dirs[519]+"100_100_130_ldc.of"],
    520: ["-c", "General", "-r", "0"],
    521: [],
    523: ["-v", "t5.xml", "xalanc.xsl"],
    525: ["-i", spec_base_dir+spec_app_dirs[525]+"BuckBunny.264", "-o", spec_base_dir+spec_app_dirs[525]+"BuckBunny.yuv"],
    526: [spec_base_dir+spec_app_dirs[526]+"sh3_no_char.blend", "--render-output", spec_base_dir+spec_app_dirs[526]+"sh3_no_char_", "--threads", "1", "-b", "-F", "RAWTGA", "-s", "849", "-e", "849", "-a"],
    527: [],
    531: [spec_base_dir+spec_app_dirs[531]+"ref.txt"],
    538: ["-limit", "disk", "0", spec_base_dir+spec_app_dirs[538]+"refrate_input.tga", "-edge", "41", "-resample", "181%", "-emboss", "31", "-colorspace", "YUV", "-mean-shift", "19x19+15%", "-resize", "30%", spec_base_dir+spec_app_dirs[538]+"refrate_output.tga"],
    541: [spec_base_dir+spec_app_dirs[541]+"ref.sgf"],
    544: ["1am0", "1122214447", "122"],
    548: ["6"],
    549: [],
    554: [],
    557: [spec_base_dir+spec_app_dirs[557]+"input.combined.xz", "250", "a841f68f38572a49d86226b7ff5baeb31bd19dc637a922a972b2e6d1257a890f6a544ecab967c313e370478c74f760eb229d4eef8a8d2836d233d3e9dd1430bf", "40401484", "41217675", "7"]
}

spec_ckpt_dirs = {
    500: "ckpt_500.perlbench_r",
    502: "ckpt_502.gcc_r",
    503: "ckpt_503.bwaves_r",
    505: "ckpt_505.mcf_r",
    507: "ckpt_507.cactuBSSN_r",
    508: "ckpt_508.namd_r",
    510: "ckpt_510.parest_r",
    511: "ckpt_511.povray_r",
    519: "ckpt_519.lbm_r",
    520: "ckpt_520.omnetpp_r",
    521: "ckpt_521.wrf_r",
    523: "ckpt_523.xalancbmk_r",
    525: "ckpt_525.x264_r",
    526: "ckpt_526.blender_r",
    527: "ckpt_527.cam4_r",
    531: "ckpt_531.deepsjeng_r",
    538: "ckpt_538.imagick_r",
    541: "ckpt_541.leela_r",
    544: "ckpt_544.nab_r",
    548: "ckpt_548.exchange2_r",
    549: "ckpt_549.fotonik3d_r",
    554: "ckpt_554.roms_r",
    557: "ckpt_557.xz_r"
}
