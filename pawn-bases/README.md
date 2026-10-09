# Pawn Bases

3D-printable bases for the folded paper pawns that Pawn Shop prints on plain printer paper. Each base is a
squashed sphere, flat on the bottom and top. The slot curves in a shallow arc, which stiffens the paper so it
stands straight instead of wilting, and is wide enough for both layers of the folded strip. Each size comes
ready to print in four bases labeled 1–4, plus a blank one for named enemies or player characters. The label
is raised in a flat spot sliced off the front and back, tilted up from the table so it reads from across the
table.

| Size       | Base          | Label  | Label face tilt | Pawn width |
|------------|---------------|--------|-----------------|------------|
| Medium     | 1" (25.4 mm)  | 7.5 mm | 55° from table  | 28.6 mm    |
| Large      | 2" (50.8 mm)  | 10 mm  | 45° from table  | 48.7 mm    |
| Huge       | 3" (76.2 mm)  | 12 mm  | 35° from table  | 75.8 mm    |
| Gargantuan | 4" (101.6 mm) | 14 mm  | 30° from table  | 101.6 mm   |

Every base is 11 mm tall. The wider bases are flatter domes, so their label faces tilt further toward the
ceiling to leave room for a big label.

A pawn is about as wide as its base or wider, so the slot runs out through both sides of the base. Paizo
prints no gargantuan pawns; that size is for Pawn Shop's custom pawns.

## Printing

1. Print `stl/slot-test.stl` first. Push a folded pawn into each slot and pick the narrowest one that takes
   the paper without crushing it.
2. If that isn't 0.55, make your own bases with that slot width (see below).
3. Print the bases from `stl/`, flat side down. Use 0.2 mm layers and no supports. The curve under the widest
   point is gentle enough to print without them.

For contrast, run a paint pen or a dry brush over the raised labels.

## Making your own

Open `pawn_base.scad` in [OpenSCAD](https://openscad.org) and choose Window › Customizer. The Base tab sets:

- **size:** medium, large, huge or gargantuan.
- **label:** the text raised on the front and back, such as a number, a letter or a name; leave it empty for
  a blank base. One character is largest; longer labels are made smaller to fit.
- **slot_curvature:** how far the slot curves, as a fraction of the pawn's width (0.08 unless you change it).
  More curve holds the paper stiffer.

The Fit tab sets **slot_width**, from the slot test. Press F6 to render, then File › Export › Export as STL.
The same settings work in other customizers that read OpenSCAD's Customizer comments, such as Thingiverse's.

From the command line:

```sh
openscad -D 'size="large"' -D 'label="3"' -o pawn-base-large-3.stl pawn_base.scad
```

Rendering takes a while, because the rounded body is slow to render.
