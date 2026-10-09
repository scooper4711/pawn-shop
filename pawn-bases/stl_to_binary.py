#!/usr/bin/env python3
"""Rewrites ASCII STL files as binary STL, which is about a fifth of the size.

OpenSCAD 2021.01 exports only ASCII STL.
"""
import struct
import sys
from pathlib import Path


def main(paths):
    for path in map(Path, paths):
        path.write_bytes(binary_stl(read_facets(path)))


def read_facets(path):
    """The facets in an ASCII STL file, each a normal followed by three vertices."""
    facets, current = [], []
    for line in path.read_text().splitlines():
        words = line.split()
        if words[:2] == ["facet", "normal"]:
            current = [tuple(map(float, words[2:5]))]
        elif words[:1] == ["vertex"]:
            current.append(tuple(map(float, words[1:4])))
        elif words[:1] == ["endfacet"]:
            facets.append(current)
    if not facets:
        raise ValueError(f"stl_to_binary: no facets in {path}")
    return facets


def binary_stl(facets):
    header = b"pawn-bases".ljust(80, b"\0")
    body = b"".join(struct.pack("<12fH", *[value for point in facet for value in point], 0) for facet in facets)
    return header + struct.pack("<I", len(facets)) + body


if __name__ == "__main__":
    main(sys.argv[1:])
