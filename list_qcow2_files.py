#!/usr/bin/env python3
"""
List all files inside a qcow2 disk image using libguestfs.

Recursively walks every directory (without following symlinks), prints
every non-directory path it finds, and skips directories entirely.

Usage:
    python3 list_qcow2_files.py /path/to/disk.qcow2
"""

import sys
import guestfs


def mount_all_filesystems(g):
    """Try inspect_os() first; fall back to mounting every detected
    filesystem read-only under / if no OS is found (e.g. a data disk)."""
    roots = g.inspect_os()

    if roots:
        root = roots[0]
        mountpoints = g.inspect_get_mountpoints(root)
        # Mount shortest paths first ("/" before "/var" before "/var/log", etc)
        for mp, dev in sorted(mountpoints.items(), key=lambda kv: len(kv[0])):
            try:
                vfs = g.vfs_type(dev)
                if not vfs.lower().startswith('swap'):
                    g.mount_ro(dev, mp)
            except RuntimeError as e:
                print(f"warning: could not mount {dev} on {mp}: {e}", file=sys.stderr)
        return

    # No OS detected -- fall back to raw filesystem list
    for dev in g.list_filesystems():
        try:
            vfs = g.vfs_type(dev)
            if vfs.lower().startswith('swap'):
                continue
            g.mount_ro(dev, "/")
            return
        except RuntimeError:
            continue

    raise RuntimeError("no mountable filesystem found in this image")


def list_files(g, ls):
    """
    Recursively walk every directory starting at / without following
    symlinks, yielding every path that is not itself a directory.
    """
    stack = ls.copy()

    while stack:
        current = stack.pop()

        try:
            entries = g.readdir(current)
        except RuntimeError as e:
            print(f"warning: skipping {current}: {e}", file=sys.stderr)
            continue

        for entry in entries:
            name = entry["name"]
            if name in (".", ".."):
                continue

            path = current.rstrip("/") + "/" + name

            try:
                # followsymlinks=False: a symlink to a directory is NOT
                # treated as a directory here, so we won't recurse into it.
                if g.is_dir(path, followsymlinks=False):
                    stack.append(path)
                else:
                    yield path
            except RuntimeError as e:
                print(f"warning: skipping {path}: {e}", file=sys.stderr)


def help():
    print(f"Usage: {sys.argv[0]} <disk.qcow2> </path>", file=sys.stderr)
    sys.exit(1)

def main():
    if len(sys.argv) < 2:
        help()

    image_path = sys.argv[1]
    if image_path.lower().endswith('.iso'):
        help()

    g = guestfs.GuestFS(python_return_dict=True)
    g.add_drive_opts(image_path, format="qcow2", readonly=1)
    g.launch()

    try:
        ls = [ "/" ]
        if (len(sys.argv) > 2):
            ls = sys.argv[2:]
        mount_all_filesystems(g)
        for path in list_files(g, ls):
            print(path)
    finally:
        g.umount_all()
        g.close()


if __name__ == "__main__":
    main()