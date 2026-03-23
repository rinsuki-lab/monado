import subprocess
import glob
import sys
import shutil

SRC_DIR = sys.argv[1]
DST_DIR = sys.argv[2]

binaries = dict[str, list[str]]()

def main():
    for path in glob.iglob(SRC_DIR + "/*/*.dylib"):
        name = path.split("/")[-1]
        if name not in binaries:
            binaries[name] = [path]
        else:
            binaries[name].append(path)

    for name, paths in binaries.items():
        if len(paths) == 1:
            shutil.copyfile(paths[0], f"{DST_DIR}/{name}")
        else:
            subprocess.run([
                "lipo",
                "-create",
                *paths,
                "-output",
                f"{DST_DIR}/{name}"
            ])

if __name__ == "__main__":
    main()
