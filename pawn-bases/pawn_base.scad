// Base for a folded paper pawn printed by Pawn Shop.
//
// The body is a squashed sphere, flat on the bottom and top. The paper sits in a slot that curves in a
// shallow arc, which stiffens plain printer paper so it stays upright. The base's label is raised in a
// flat spot sliced off the front and back, tilted so it reads from across the table.
//
// Open this file in OpenSCAD and choose Window › Customizer to set the size, label and curve, or build
// one base from the command line:
//   openscad -D 'size="large"' -D 'label="3"' -o pawn-base-large-3.stl pawn_base.scad

/* [Base] */

// The pawn's size: the base is 1", 2", 3" or 4" across.
size = "medium"; // [medium:Medium 1 inch, large:Large 2 inches, huge:Huge 3 inches, gargantuan:Gargantuan 4 inches]

// Raised on the front and back. Leave it empty for a blank base. One character is largest; longer labels are made smaller to fit.
label = "1";

// How far the slot curves, as a fraction of the pawn's width. More curve holds the paper stiffer.
slot_curvature = 0.08; // [0.02:0.01:0.15]

/* [Fit] */

// Width of the slot in mm. Two sheets of printer paper are about 0.2 mm; print slot_test.scad to pick a fit.
slot_width = 0.55; // [0.35:0.05:0.8]

/* [Hidden] */

// The slot runs this much past each edge of the pawn.
slot_overrun = 0.5;
// The lead-in at the top of the slot widens it by this much, over this height.
lead_in_widening = 1.2;
lead_in_height = 1.0;
// Raised labels stand this far proud of the flat spot, and sink this far into it so they fuse.
label_relief = 0.8;
label_embed = 0.2;
label_font = "Liberation Sans:style=Bold";

// Every base is this tall, and its slot this deep.
total_height = 11;
slot_depth = 6;

mm_per_point = 25.4 / 72;

$fa = 2;
$fs = 0.3;

// Per size:
//   base diameter (the sphere's width), the sphere's vertical half-height, the height of its center
//   above the bed, how steeply the flat spots face outward (the angle of their normal above the
//   horizontal), how deep they slice in, label height, and the pawn's width (in points, from Pawn
//   Shop's PawnSize). The wider bases are flatter domes, so their flat spots face further up to
//   leave room for the label.
function dimensions(name) =
    name == "medium" ? [25.4, 10.0, 3, 35, 1.40, 7.5, 81] :
    name == "large" ? [50.8, 12.5, 1, 45, 1.85, 10.0, 138] :
    name == "huge" ? [76.2, 12.5, 1, 55, 2.10, 12.0, 215] :
    name == "gargantuan" ? [101.6, 12.5, 1, 60, 2.40, 14.0, 288] :
    assert(false, str("pawn_base: unknown size \"", name, "\""));

dims = dimensions(size);
sphere_radius = dims[0] / 2;
sphere_half_height = dims[1];
sphere_center_height = dims[2];
flat_elevation = dims[3];
flat_depth = dims[4];
pawn_width = dims[6] * mm_per_point;

// A number given on the command line (-D label=3) works as well as text.
label_text = str(label);
// One character is full size; longer labels shrink so they still fit the flat spot.
label_height = dims[5] * min(1, 1.6 / (len(label_text) + 0.6));

slot_chord = pawn_width + 2 * slot_overrun;
slot_sagitta = slot_chord * slot_curvature;

// The front flat spot's outward normal, as [y, z]; the back one is the same turned 180°.
flat_normal = [-cos(flat_elevation), sin(flat_elevation)];
// Distance from the sphere's center to the plane that just touches it with that normal.
touching_distance = sqrt(pow(sphere_radius * flat_normal[0], 2) + pow(sphere_half_height * flat_normal[1], 2));
flat_distance = touching_distance - flat_depth;
// The middle of the front flat spot, as [y, z] above the bed. A plane slicing a squashed sphere
// leaves an ellipse centered on the line from the sphere's center to the point the plane would touch.
flat_center = [
    flat_distance * pow(sphere_radius, 2) * flat_normal[0] / pow(touching_distance, 2),
    sphere_center_height
        + flat_distance * pow(sphere_half_height, 2) * flat_normal[1] / pow(touching_distance, 2)
];
// Turns +Z to the front flat spot's normal, and +Y up its slope.
flat_tilt = [90 - flat_elevation, 0, 0];

pawn_base();

module pawn_base() {
    difference() {
        union() {
            body();
            labels();
        }
        slot();
    }
}

// The squashed sphere, sliced flat on the bottom, top, front and back.
module body() {
    difference() {
        intersection() {
            translate([0, 0, sphere_center_height])
                scale([1, 1, sphere_half_height / sphere_radius])
                    sphere(r = sphere_radius);
            translate([-sphere_radius, -sphere_radius, 0])
                cube([2 * sphere_radius, 2 * sphere_radius, total_height]);
        }
        flat_slice();
        rotate([0, 0, 180]) flat_slice();
    }
}

// Everything beyond the front flat spot's plane.
module flat_slice() {
    reach = 4 * sphere_radius;
    translate([0, 0, sphere_center_height])
        rotate(flat_tilt)
            translate([-reach / 2, -reach / 2, flat_distance])
                cube(reach);
}

module labels() {
    if (len(label_text) > 0) {
        flat_label();
        rotate([0, 0, 180]) flat_label();
    }
}

// The label centered in the front flat spot, its top pointing up the slope.
module flat_label() {
    translate([0, flat_center[0], flat_center[1]])
        rotate(flat_tilt)
            translate([0, 0, -label_embed])
                linear_extrude(label_embed + label_relief)
                    text(label_text, size = label_height, font = label_font,
                         halign = "center", valign = "center");
}

module slot() {
    slot_bottom = total_height - slot_depth;
    translate([0, 0, slot_bottom])
        linear_extrude(slot_depth + 1)
            arc_band(slot_chord, slot_sagitta, slot_width);
    lead_in(total_height);
}

// The top of the slot flares in 0.2 mm steps, one per print layer, to guide the paper in.
module lead_in(top) {
    steps = round(lead_in_height / 0.2);
    for (step = [1 : steps])
        translate([0, 0, top - lead_in_height + (step - 1) * lead_in_height / steps])
            linear_extrude(lead_in_height / steps + 1)
                arc_band(slot_chord, slot_sagitta, slot_width + lead_in_widening * step / steps);
}

// A band `width` wide along an arc that spans `chord` and bows `sagitta` toward +Y, centered on the origin.
module arc_band(chord, sagitta, width) {
    arc_radius = (chord * chord / 4 + sagitta * sagitta) / (2 * sagitta);
    intersection() {
        translate([0, sagitta / 2 - arc_radius])
            difference() {
                circle(r = arc_radius + width / 2, $fa = 0.5);
                circle(r = arc_radius - width / 2, $fa = 0.5);
            }
        translate([-chord / 2, -sagitta / 2 - width - 1])
            square([chord, sagitta + 2 * width + 2]);
    }
}
