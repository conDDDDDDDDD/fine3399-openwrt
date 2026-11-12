#!/usr/bin/env python3
"""Generate a git-style patch that adds new files to an OpenWrt build tree."""

import argparse
import os


def read_text(path):
    with open(path, "r", encoding="utf-8", newline="") as f:
        data = f.read()
    return data.replace("\r\n", "\n")


def add_new_file(out, rel, content):
    lines = content.split("\n")
    if lines and lines[-1] == "":
        lines.pop()

    out.append("diff --git a/%s b/%s" % (rel, rel))
    out.append("new file mode 100644")
    out.append("--- /dev/null")
    out.append("+++ b/%s" % rel)
    out.append("@@ -0,0 +1,%d @@" % len(lines))
    out.extend("+" + line for line in lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", required=True,
                        help="directory that local source paths are relative to")
    parser.add_argument("--out", required=True, help="patch file to write")
    parser.add_argument("pairs", nargs="+", metavar="LOCAL:DEST",
                        help="local source file and its path inside the target tree")
    args = parser.parse_args()

    out = []
    for pair in args.pairs:
        local, dest = pair.split(":", 1)
        add_new_file(out, dest, read_text(os.path.join(args.base, local)))

    outdir = os.path.dirname(args.out)
    if outdir:
        os.makedirs(outdir, exist_ok=True)
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
