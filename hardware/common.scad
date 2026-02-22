// ============================================================
// ZK-Glasses — Common Components Library
// Shared modules for clip-on and integrated frame variants
// ============================================================
//
// Usage:  include <common.scad>
//
// All dimensions in millimeters.
// Default preview resolution — bump to 128 for final render.

$fn = 64;

// ──────────────────────────────────────────────
//  Color palette (consistent across all files)
// ──────────────────────────────────────────────
CLR_FRAME    = [0.22, 0.22, 0.24];      // matte charcoal
CLR_LED_BODY = [0.12, 0.08, 0.18, 0.7]; // dark tinted epoxy
CLR_LED_BEAM = [0.55, 0.0, 1.0, 0.06];  // faint purple IR viz
CLR_SILVER   = [0.78, 0.78, 0.80];
CLR_GOLD     = [0.83, 0.69, 0.22];
CLR_PCB      = [0.05, 0.35, 0.12];
CLR_BATTERY  = [0.30, 0.50, 0.72];
CLR_RUBBER   = [0.15, 0.15, 0.15];
CLR_WIRE_R   = [0.7, 0.1, 0.1];
CLR_WIRE_B   = [0.1, 0.1, 0.1];
CLR_IR_FILTER= [0.08, 0.04, 0.10, 0.92]; // near-black IR-pass filter
CLR_FLEX_PCB = [0.15, 0.12, 0.02];        // dark gold flex PCB
CLR_SMD_LED  = [0.10, 0.10, 0.12];        // tiny dark SMD body

// ──────────────────────────────────────────────
//  2D helper — rounded rectangle
// ──────────────────────────────────────────────
module rounded_rect_2d(w, h, r) {
    offset(r = r)
        offset(delta = -r)
            square([w, h], center = true);
}

// ──────────────────────────────────────────────
//  SMD IR LED — OSRAM SFH 4726AS style
//  940nm, PLCC-2 (3.5 × 2.8 × 1.9 mm)
//  Flush-mountable, nearly invisible in frame
// ──────────────────────────────────────────────
module ir_led_smd(show_beam = false) {
    // Tiny SMD body — barely visible
    color(CLR_SMD_LED) {
        cube([3.5, 2.8, 1.9], center = true);
        // Lens window (top face, recessed)
        color([0.06, 0.03, 0.08, 0.85])
            translate([0, 0, 0.9])
                cube([2.8, 2.0, 0.15], center = true);
    }
    // Solder pads
    color(CLR_SILVER) {
        translate([-1.4, 0, -0.95])
            cube([0.8, 2.0, 0.1], center = true);
        translate([ 1.4, 0, -0.95])
            cube([0.8, 2.0, 0.1], center = true);
    }
    // IR beam — wider angle than through-hole (±60°)
    if (show_beam) {
        color([0.55, 0.0, 1.0, 0.04])
            translate([0, 0, 1.5])
                cylinder(d1 = 2, d2 = 80, h = 60, $fn = 32);
    }
}

// ──────────────────────────────────────────────
//  Flex PCB LED Strip
//  Thin flexible circuit with SMD LEDs pre-soldered
//  Slides into channel inside the brow bar
// ──────────────────────────────────────────────
module flex_pcb_strip(length = 100, led_count = 6, led_pitch = 12) {
    // Flex substrate (0.2mm thick, like a ribbon cable)
    color(CLR_FLEX_PCB)
        cube([length, 4.0, 0.2], center = true);

    // Copper traces (decorative)
    color([0.72, 0.55, 0.15], 0.3)
        for (dy = [-1, 1])
            translate([0, dy * 1.2, 0.12])
                cube([length - 2, 0.4, 0.04], center = true);

    // SMD LEDs on the strip
    for (i = [0 : led_count - 1]) {
        x = -(led_pitch * (led_count - 1) / 2) + i * led_pitch;
        translate([x, 0, 1.05])
            ir_led_smd(show_beam = false);
    }

    // Connector tail (one end)
    color(CLR_FLEX_PCB)
        translate([length/2 + 5, 0, 0])
            cube([12, 3, 0.2], center = true);
    // Connector pins
    color(CLR_GOLD)
        translate([length/2 + 10, 0, 0])
            cube([2, 4, 0.8], center = true);
}

// ──────────────────────────────────────────────
//  IR-Pass Filter Strip
//  Looks opaque black to human eyes, but
//  transmits 940nm IR light freely.
//  (Kodak Wratten 87C equivalent)
// ──────────────────────────────────────────────
module ir_filter_strip(length = 100, width = 4.0, thickness = 0.5) {
    color(CLR_IR_FILTER)
        cube([length, width, thickness], center = true);
}

// ──────────────────────────────────────────────
//  3mm Through-Hole IR LED  (TSAL6200 style)
// ──────────────────────────────────────────────
module ir_led_3mm(show_beam = false) {
    // Epoxy body + dome
    color(CLR_LED_BODY) {
        cylinder(d = 3.0, h = 4.5);
        translate([0, 0, 4.5])
            sphere(d = 3.0);
        // Flange
        cylinder(d = 3.6, h = 0.8);
    }
    // Anode / cathode leads
    color(CLR_SILVER) {
        translate([ 1.27/2, 0, -6])
            cylinder(d = 0.45, h = 6, $fn = 8);
        translate([-1.27/2, 0, -6])
            cylinder(d = 0.45, h = 6, $fn = 8);
    }
    // IR beam cone (visual only)
    if (show_beam) {
        color(CLR_LED_BEAM)
            translate([0, 0, 5.5])
                cylinder(d1 = 2.5, d2 = 45, h = 70);
    }
}

// ──────────────────────────────────────────────
//  5mm Through-Hole IR LED
// ──────────────────────────────────────────────
module ir_led_5mm(show_beam = false) {
    color(CLR_LED_BODY) {
        cylinder(d = 5.0, h = 6.0);
        translate([0, 0, 6.0])
            sphere(d = 5.0);
        cylinder(d = 5.8, h = 1.0);
    }
    color(CLR_SILVER) {
        translate([ 1.27, 0, -8])
            cylinder(d = 0.45, h = 8, $fn = 8);
        translate([-1.27, 0, -8])
            cylinder(d = 0.45, h = 8, $fn = 8);
    }
    if (show_beam) {
        color(CLR_LED_BEAM)
            translate([0, 0, 7.0])
                cylinder(d1 = 4, d2 = 55, h = 80);
    }
}

// ──────────────────────────────────────────────
//  LiPo Battery Cell
// ──────────────────────────────────────────────
module lipo_battery(l = 35, w = 20, h = 5.5) {
    color(CLR_BATTERY)
        minkowski() {
            cube([l - 2, w - 2, h - 1], center = true);
            sphere(r = 0.5, $fn = 16);
        }
    // JST connector tab
    color(CLR_GOLD)
        translate([l/2 + 1, 0, 0])
            cube([3, 5, 1.2], center = true);
    // Label
    color("White")
        translate([0, 0, h/2 + 0.01])
            linear_extrude(0.1)
                text("3.7V 500mAh", size = 2.5,
                     halign = "center", valign = "center");
}

// ──────────────────────────────────────────────
//  TP4056 USB-C Charge Board  (25 × 14 mm)
// ──────────────────────────────────────────────
module tp4056_board() {
    // PCB
    color(CLR_PCB) {
        cube([25.4, 14.2, 1.2], center = true);
        // Copper pads (bottom hint)
        translate([0, 0, -0.7])
            cube([24, 13, 0.05], center = true);
    }
    // USB-C receptacle
    color(CLR_SILVER)
        translate([-12.2, 0, 1.0])
            minkowski() {
                cube([5, 7.5, 2.0], center = true);
                sphere(r = 0.3, $fn = 12);
            }
    // TP4056 IC
    color("DimGray")
        translate([3, 0, 0.9])
            cube([5, 4, 1.2], center = true);
    // Inductor
    color([0.25, 0.25, 0.25])
        translate([9, 0, 1.0])
            cylinder(d = 4, h = 2, center = true, $fn = 16);
    // Charging LED (red)
    color("Red", 0.8)
        translate([0, 5.5, 0.8])
            cube([1.6, 0.8, 0.6], center = true);
    // Done LED (green)
    color("Lime", 0.8)
        translate([0, -5.5, 0.8])
            cube([1.6, 0.8, 0.6], center = true);
}

// ──────────────────────────────────────────────
//  ATtiny85 — DIP-8 Package
// ──────────────────────────────────────────────
module attiny85_dip8() {
    // Body
    color([0.18, 0.18, 0.20]) {
        cube([9.6, 6.35, 3.3], center = true);
        // Orientation notch
        translate([-4.8, 0, 1.65])
            rotate([0, 90, 0])
                cylinder(d = 2.0, h = 0.5, $fn = 16);
    }
    // Dot marker
    color("White")
        translate([-3.5, -2.0, 1.66])
            cylinder(d = 0.8, h = 0.05, $fn = 12);
    // Pins (4 per side, 2.54 mm pitch)
    color(CLR_SILVER)
        for (i = [0:3]) {
            // Bottom pins
            translate([-3.81 + i * 2.54, -3.8, -1.2])
                cube([0.5, 1.5, 0.25]);
            // Top pins
            translate([-3.81 + i * 2.54,  2.3, -1.2])
                cube([0.5, 1.5, 0.25]);
        }
}

// ──────────────────────────────────────────────
//  N-MOSFET — SOT-23 Package  (IRLML6344)
// ──────────────────────────────────────────────
module mosfet_sot23() {
    color([0.18, 0.18, 0.20])
        cube([2.9, 1.6, 1.1], center = true);
    color(CLR_SILVER) {
        // Gate, Source (bottom side)
        translate([-0.95, -1.3, 0])
            cube([0.4, 0.8, 0.15], center = true);
        translate([ 0.95, -1.3, 0])
            cube([0.4, 0.8, 0.15], center = true);
        // Drain (top side)
        translate([0, 1.3, 0])
            cube([0.4, 0.8, 0.15], center = true);
    }
}

// ──────────────────────────────────────────────
//  Tactile Push Button  (6 × 6 mm)
// ──────────────────────────────────────────────
module tact_button() {
    color([0.15, 0.15, 0.17]) {
        cube([6, 6, 3.5], center = true);
    }
    // Button cap
    color([0.3, 0.3, 0.32])
        translate([0, 0, 2.0])
            cylinder(d = 3.5, h = 1.0, $fn = 24);
    // Pins
    color(CLR_SILVER)
        for (dx = [-3.25, 3.25])
            for (dy = [-2.25, 2.25])
                translate([dx, dy, -2.5])
                    cube([0.6, 0.6, 1.5], center = true);
}

// ──────────────────────────────────────────────
//  Slide Switch  (8 × 3 mm)
// ──────────────────────────────────────────────
module slide_switch() {
    color([0.12, 0.12, 0.14])
        cube([8.5, 3.6, 3.5], center = true);
    // Slider knob
    color(CLR_SILVER)
        translate([1.5, 0, 2.0])
            cube([3, 1.5, 1.2], center = true);
    // Pins
    color(CLR_SILVER)
        for (dx = [-2.54, 0, 2.54])
            translate([dx, 0, -2.5])
                cylinder(d = 0.8, h = 2, $fn = 8);
}

// ──────────────────────────────────────────────
//  Wire Channel (hull between point list)
// ──────────────────────────────────────────────
module wire_channel(pts, d = 1.5) {
    for (i = [0 : len(pts) - 2])
        hull() {
            translate(pts[i])   sphere(d = d, $fn = 12);
            translate(pts[i+1]) sphere(d = d, $fn = 12);
        }
}

// ──────────────────────────────────────────────
//  Nose Pad (soft rubber)
// ──────────────────────────────────────────────
module nose_pad() {
    color(CLR_RUBBER)
        minkowski() {
            scale([1, 0.6, 1])
                sphere(d = 8, $fn = 24);
            cube([0.5, 0.5, 0.5], center = true);
        }
}

// ──────────────────────────────────────────────
//  Barrel Hinge (5-barrel, 2.5 mm pin)
// ──────────────────────────────────────────────
module barrel_hinge(open_angle = 0) {
    barrel_d = 3.0;
    barrel_h = 2.8;
    pin_d    = 1.2;

    color(CLR_SILVER) {
        // 5 interlocking barrels
        for (i = [0:4])
            translate([0, 0, i * barrel_h])
                cylinder(d = barrel_d, h = barrel_h - 0.2, $fn = 20);
        // Pin
        translate([0, 0, -0.5])
            cylinder(d = pin_d, h = 5 * barrel_h + 1, $fn = 12);
    }
}

// ──────────────────────────────────────────────
//  Quick phantom glasses temple (for context)
// ──────────────────────────────────────────────
module phantom_temple(length = 140, width = 5, height = 2.5) {
    color([0.6, 0.6, 0.65], 0.3) {
        // Straight section
        cube([length, width, height], center = true);
        // Ear hook curve
        translate([length/2, 0, 0])
            rotate([0, -25, 0])
                cube([30, width, height], center = true);
    }
}
