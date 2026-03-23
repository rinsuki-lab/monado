import shutil
import subprocess
import sys
import os

SRC_FILE = sys.argv[1]
DST_DIR = sys.argv[2]

def get_libraries(path: str) -> list[str]:
    result = subprocess.run(["otool", "-L", path], capture_output=True, text=True)
    libraries: list[str] = []
    for line in result.stdout.splitlines()[1:]:
        libraries.append(line.strip().split(" ")[0])
    return libraries

def do_it(path: str):
    libraries = get_libraries(path)
    dst_path = os.path.join(DST_DIR, os.path.basename(path))
    if os.path.exists(dst_path):
        return # already done?
    shutil.copyfile(path, dst_path)
    for lib in libraries:
        if "/opt/" not in lib:
            continue
        do_it(lib)
        lib_name = lib.split("/")[-1]
        dest_lib = os.path.join(DST_DIR, lib_name)
        shutil.copyfile(lib, dest_lib)
        subprocess.run(["install_name_tool", "-change", lib, f"@loader_path/{lib_name}", dst_path], check=True)

do_it(SRC_FILE)
