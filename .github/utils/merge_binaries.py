import subprocess
import sys
import shutil
import os.path

SRC_DIR = sys.argv[1]
DST_DIR = sys.argv[2]

binaries = dict[str, list[str]]()

def walker(folder: str):
    with os.scandir(folder) as it:
        for entry in it:
            path = os.path.join(folder, entry.name)
            name = os.path.relpath(path, SRC_DIR)
            if "/" not in name:
                if entry.is_dir():
                    walker(path)
                continue
            name = name[name.index("/") + 1:]
            if entry.is_symlink():
                binaries[name] = [path]
            elif entry.is_dir():
                walker(path)
            else:
                if name not in binaries:
                    binaries[name] = [path]
                else:
                    binaries[name].append(path)

def main():
    walker(SRC_DIR)

    for name, paths in binaries.items():
        print(name, paths, os.path.islink(paths[0]))
        os.makedirs(os.path.dirname(f"{DST_DIR}/{name}"), exist_ok=True)
        if len(paths) == 1 or os.path.islink(paths[0]):
            shutil.copyfile(paths[0], f"{DST_DIR}/{name}", follow_symlinks=False)
        else:
            with open(paths[0], "rb") as f:
                if f.read(4) != b"\xcf\xfa\xed\xfe":
                    shutil.copyfile(paths[0], f"{DST_DIR}/{name}")
                else:
                    subprocess.run([
                        "lipo",
                        "-create",
                        *paths,
                        "-output",
                        f"{DST_DIR}/{name}"
                    ], check=True)

if __name__ == "__main__":
    main()
