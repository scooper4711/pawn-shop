// A block of curved slots in several widths. Print it, try a folded pawn in each, and copy the
// width that grips best into slot_width in pawn_base.scad.

use <pawn_base.scad>

slot_widths = [0.35, 0.45, 0.55, 0.65, 0.75];

block_height = 8;
slot_depth = 6;
slot_chord = 24;
slot_sagitta = slot_chord * 0.08;
row_pitch = 10;
label_width = 14;
label_size = 3.5;
label_relief = 0.6;
margin = 2;
label_font = "Liberation Sans:style=Bold";

$fa = 2;
$fs = 0.3;

block_length = label_width + slot_chord + 2 * margin;
block_depth = len(slot_widths) * row_pitch;

slot_test();

module slot_test() {
    difference() {
        cube([block_length, block_depth, block_height]);
        for (row = [0 : len(slot_widths) - 1])
            translate([label_width + margin + slot_chord / 2, row_center(row), block_height - slot_depth])
                linear_extrude(slot_depth + 1)
                    arc_band(slot_chord, slot_sagitta, slot_widths[row]);
    }
    for (row = [0 : len(slot_widths) - 1])
        translate([margin, row_center(row), block_height])
            linear_extrude(label_relief)
                text(str(slot_widths[row]), size = label_size, font = label_font, valign = "center");
}

function row_center(row) = (row + 0.5) * row_pitch;
