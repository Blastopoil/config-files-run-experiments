import os
import time
import subprocess
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed

SPECS = [
##  Aplicaciones con dos almoadillas no alcanzan ROI en tiempo razonable con qemu
### perlbench no esta anotado
###    "500.perlbench_r",  
    "508.namd_r",
    "502.gcc_r",
##    "503.bwaves_r",
    "505.mcf_r",
    "507.cactuBSSN_r",
    "510.parest_r",
    "511.povray_r",
    "519.lbm_r", 
    "520.omnetpp_r",
    "521.wrf_r",
    "523.xalancbmk_r",
##    "525.x264_r",
    "526.blender_r", 
    "527.cam4_r",
    "531.deepsjeng_r",
    "538.imagick_r",
    "541.leela_r",
    "544.nab_r",
    "548.exchange2_r",
    "549.fotonik3d_r",
##    "554.roms_r",
    "557.xz_r",
]

GEM5_BIN = "/nfs/home/ce/felixfdec/gem5/build/RISCV/gem5.opt"
GEM5_CFG = "/nfs/home/ce/felixfdec/gem5/config-files-run-experiments/extra-tools/take-SPEC-checkopoints/all_specs-gem5-config-fs.py"

# Intervalo entre lanzamientos (1 minuto)
START_STAGGER_SECONDS = 60

# Limite de concurrencia (dejar en None para "todas", o poner un numero si quieres acotar)
MAX_WORKERS = 16

LOG_DIR = Path("logs")


def parse_spec(spec: str) -> tuple[str, str]:
    num, rest = spec.split(".", 1)
    name = rest[:-2] if rest.endswith("_r") else rest
    return num, name


def write_shell_script(script_path: Path, spec_num: str, spec_name: str) -> None:
    content = f"""#!/bin/bash

echo "Running {spec_name}"

cd /root/SPEC
./run_spec.sh {spec_num}

echo -e "\\n\\n ****** Done ******* \\n\\n"

m5 exit
"""
    script_path.write_text(content, encoding="utf-8")
    script_path.chmod(0o755)


def run_one_spec(spec: str) -> tuple[str, int]:
    """
    Ejecuta una SPEC (genera script, lanza gem5, borra script).
    Devuelve (spec_name, returncode).
    """
    spec_num, spec_name = parse_spec(spec)

    # Script único para evitar colisiones en paralelo
    script_name = f"{spec_name}.sh"
    script_path = Path(script_name)

    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_path = LOG_DIR / f"{spec_name}_{spec_num}.log"

    try:
        write_shell_script(script_path, spec_num, spec_name)

        cmd = [GEM5_BIN, GEM5_CFG, "--script", script_name]

        # Log de stdout/stderr a fichero (y así no se mezcla entre procesos)
        with log_path.open("wb") as f:
            proc = subprocess.run(cmd, stdout=f, stderr=subprocess.STDOUT)

        rc = proc.returncode

    finally:
        # Borrar script generado
        try:
            if script_path.exists():
                script_path.unlink()
        except Exception as e:
            print(f"[WARN] No se pudo borrar {script_name}: {e}")

    # sync + mensaje de finalización (cuando termina ESTA SPEC)
    subprocess.run(["sync"], check=False)
    if rc == 0:
        print(f"{spec_name} Done")
    else:
        print(f"{spec_name} Done (FAILED rc={rc})")

    return spec_name, rc


def main() -> int:
    # Comprobaciones minimas
    if not Path(GEM5_BIN).exists():
        print(f"[ERROR] No existe {GEM5_BIN} (ejecuta este script desde el directorio correcto).")
        return 2
    if not Path(GEM5_CFG).exists():
        print(f"[ERROR] No existe {GEM5_CFG} (ejecuta este script desde el directorio correcto).")
        return 2

    futures = []
    with ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        for i, spec in enumerate(SPECS):
            futures.append(ex.submit(run_one_spec, spec))
            time.sleep(START_STAGGER_SECONDS)  # escalonado de arranque

        # Esperar a que terminen todas
        failed = 0
        for fut in as_completed(futures):
            _, rc = fut.result()
            if rc != 0:
                failed += 1

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())

