// ============================================================
// ZK-Glasses — Snap-On IR Clip Module
// Clips onto any existing glasses temple arm
// ============================================================
//
//  ┌──────────────────────────────────────────────────────┐
//  │  RENDER INSTRUCTIONS                                 │
//  │  F5  = Quick preview (colors, transparency)          │
//  │  F6  = Full render (slow, for STL export)            │
//  │  F7  = Export STL                                    │
//  │                                                      │
//  │  Toggle variables below for different views:          │
//  │  • show_beams   = IR beam visualization              │
//  │  • show_temple  = phantom glasses arm                │
//  │  • exploded     = exploded assembly view             │
//  │  • cross_section = cutaway internal view             │
//  │  • show_electronics = ATtiny + MOSFETs + wiring      │
//  └──────────────────────────────────────────────────────┘

include <common.scad>

// ── View Toggles ─────────────────────────────────────────────
show_beams       = true;    // Show purple IR beam cones
show_temple      = true;    // Show transparent phantom glasses arm
exploded         = false;   // Exploded assembly view
cross_section    = false;   // Cutaway to show internals
show_electronics = true;    // Show ATtiny, MOSFETs, wires

// ── Glasses Temple Parameters (measure yours!) ───────────────
temple_w     = 5.0;     // Width of your glasses temple arm
temple_h     = 2.8;     // Thickness of temple arm
temple_len   = 140;     // Length (for phantom display)

// ── Clip Parameters ──────────────────────────────────────────
clip_len     = 52;      // Length of main clip body
clip_wall    = 2.0;     // Shell thickness
clip_tol     = 0.4;     // Tolerance around temple
grip_lip     = 0.6;     // Inward lip for snap retention

// ── LED Array ────────────────────────────────────────────────
led_count    = 5;       // LEDs along top of each clip
led_pitch    = 9.0;     // Center-to-center spacing
led_dia      = 3.0;     // 3mm LEDs
led_fwd_tilt = 12;      // Forward tilt angle (toward cameras)
led_out_tilt = 5;       // Slight outward splay

// ── Battery Pod ──────────────────────────────────────────────
batt_l       = 38;      // Battery compartment length
batt_w       = 22;      // Battery compartment width
batt_h       = 8;       // Battery compartment height

// ── Bridge Connector ─────────────────────────────────────────
bridge_w     = 3.0;     // Width of brow connector strip
bridge_h     = 2.5;     // Height of connector

// ── Derived ──────────────────────────────────────────────────
clip_inner_w = temple_w + clip_tol * 2;
clip_inner_h = temple_h + clip_tol * 2;
clip_outer_w = clip_inner_w + clip_wall * 2;
clip_outer_h = clip_inner_h + clip_wall + 5;  // extra height above for LEDs
ex = exploded ? 25 : 0;  // exploded offset

// ══════════════════════════════════════════════════════════════
//  CLIP BODY — main structural piece
// ══════════════════════════════════════════════════════════════
module clip_body() {
    difference() {
        // Outer shell — rounded block
        minkowski() {
            cube([clip_len - 2, clip_outer_w - 2, clip_outer_h - 1],
                 center = true);
            sphere(r = 1.0, $fn = 16);
        }

        // Temple channel (open at bottom for snap-on)
        translate([0, 0, -1])
            cube([clip_len + 2, clip_inner_w, clip_inner_h + 2],
                 center = true);

        // Bottom slot opening (narrower than channel for snap fit)
        translate([0, 0, -(clip_outer_h/2)])
            cube([clip_len + 2, clip_inner_w - grip_lip * 2, clip_wall + 2],
                 center = true);

        // LED sockets (angled holes through top)
        for (i = [0 : led_count - 1]) {
            x = -(led_pitch * (led_count - 1) / 2) + i * led_pitch;
            translate([x, 0, clip_outer_h / 2 - 1])
                rotate([-led_fwd_tilt, 0, 0])
                    cylinder(d = led_dia + 0.4, h = 12, $fn = 24);
        }

        // Wire channel (horizontal bore through body)
        translate([0, 0, clip_outer_h / 2 - 3.5])
            rotate([0, 90, 0])
                cylinder(d = 2.0, h = clip_len + 4, center = true, $fn = 16);

        // Wire exit holes at each end
        for (sx = [-1, 1])
            translate([sx * (clip_len/2 + 0.5), 0, clip_outer_h / 2 - 3.5])
                sphere(d = 3.0, $fn = 16);
    }
}

// ══════════════════════════════════════════════════════════════
//  BATTERY POD — sits behind the ear
// ══════════════════════════════════════════════════════════════
module battery_pod() {
    difference() {
        // Outer shell
        minkowski() {
            cube([batt_l - 3, batt_w - 3, batt_h - 1], center = true);
            sphere(r = 1.5, $fn = 16);
        }
        // Battery cavity
        translate([0, 0, 1])
            cube([batt_l - 4, batt_w - 4, batt_h], center = true);

        // Charge port cutout (USB-C, one end)
        translate([-(batt_l/2), 0, 0])
            rotate([0, 90, 0])
                rounded_rect_extrude(9.5, 3.5, 1.0, 6);

        // Wire exit (connects to clip)
        translate([batt_l/2, 0, batt_h/2 - 2])
            rotate([0, 90, 0])
                cylinder(d = 2.5, h = 4, center = true, $fn = 16);

        // Slide switch cutout (top)
        translate([-8, 0, batt_h/2])
            cube([10, 4.5, 4], center = true);
    }
}

// Helper for charge port cutout
module rounded_rect_extrude(w, h, r, depth) {
    linear_extrude(depth)
        offset(r = r) offset(delta = -r)
            square([w - 2*r, h - 2*r], center = true);
}

// ══════════════════════════════════════════════════════════════
//  BROW BRIDGE — connects left and right clips
// ══════════════════════════════════════════════════════════════
module brow_bridge(span = 20) {
    // Flexible strip that goes across the nose bridge area
    color(CLR_FRAME)
        difference() {
            minkowski() {
                cube([span, bridge_w - 1, bridge_h - 0.5], center = true);
                sphere(r = 0.5, $fn = 12);
            }
            // Wire channel
            rotate([0, 90, 0])
                cylinder(d = 1.5, h = span + 4, center = true, $fn = 12);
        }
}

// ══════════════════════════════════════════════════════════════
//  FULL ASSEMBLY — single side (mirrored for both)
// ══════════════════════════════════════════════════════════════
module clip_assembly_side(side = "left") {
    mirror_x = (side == "right") ? 1 : 0;

    mirror([mirror_x, 0, 0]) {
        // ── Clip body ──
        translate([0, 0, ex])
            color(CLR_FRAME)
                clip_body();

        // ── LEDs in sockets ──
        for (i = [0 : led_count - 1]) {
            x = -(led_pitch * (led_count - 1) / 2) + i * led_pitch;
            translate([x, 0, clip_outer_h / 2 - 1 + ex * 1.5])
                rotate([-led_fwd_tilt, 0, 0])
                    ir_led_3mm(show_beam = show_beams);
        }

        // ── Battery pod (behind clip) ──
        translate([clip_len/2 + batt_l/2 + 3, 0, -ex * 0.3])
            color(CLR_FRAME)
                battery_pod();

        // ── Battery inside pod ──
        translate([clip_len/2 + batt_l/2 + 3, 0, 1 - ex * 0.1])
            lipo_battery(l = batt_l - 6, w = batt_w - 6, h = batt_h - 4);

        // ── Slide switch ──
        translate([clip_len/2 + batt_l/2 + 3 - 8, 0, batt_h/2 + 0.5 - ex * 0.2])
            slide_switch();

        // ── Phantom temple arm ──
        if (show_temple)
            translate([20, 0, 0])
                phantom_temple(length = temple_len, width = temple_w, height = temple_h);

        // ── Electronics (inside clip body) ──
        if (show_electronics) {
            // ATtiny85
            translate([10, 0, clip_outer_h / 2 - 5 + ex * 0.8])
                rotate([0, 0, 90])
                    attiny85_dip8();

            // MOSFETs
            translate([-5, 2, clip_outer_h / 2 - 5 + ex * 0.6])
                mosfet_sot23();
            translate([-5, -2, clip_outer_h / 2 - 5 + ex * 0.6])
                mosfet_sot23();

            // Button (on outer face of clip)
            translate([-15, clip_outer_w/2 + 1, 0])
                rotate([90, 0, 0])
                    tact_button();
        }
    }
}

// ══════════════════════════════════════════════════════════════
//  MAIN ASSEMBLY
// ══════════════════════════════════════════════════════════════

// Left clip
translate([-40, 0, 0])
    clip_assembly_side("left");

// Right clip
translate([40, 0, 0])
    clip_assembly_side("right");

// Brow bridge connector
translate([0, 0, clip_outer_h / 2 + ex * 0.8])
    brow_bridge(span = 60);

// ── Optional cross section ──
if (cross_section) {
    // Cut away front half to show internals
    translate([0, 50, 0])
        cube([200, 100, 100], center = true);
}

// ══════════════════════════════════════════════════════════════
//  PRINTABLE PARTS (uncomment one at a time for STL export)
// ══════════════════════════════════════════════════════════════

// For 3D printing, render each part flat on the build plate:

// !clip_body();                          // Print 2×
// !battery_pod();                        // Print 2×
// !brow_bridge(span = 60);              // Print 1×

// Print settings:
//   Material: PETG (flexibility + heat resistance)
//   Layer height: 0.16mm
//   Infill: 30% gyroid
//   Supports: Yes (for LED socket overhangs)
//   Wall count: 3
//   Brim: Yes (small footprint parts)
