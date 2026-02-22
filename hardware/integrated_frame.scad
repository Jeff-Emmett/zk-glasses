// ============================================================
// ZK-Glasses — Stealth Integrated IR Frame
// Flush-mounted SMD LEDs behind IR-pass filter strips
// Looks like normal glasses — invisible except to cameras
// ============================================================
//
//  Design philosophy:
//    Like Meta Ray-Ban cameras — tiny components hidden in
//    the frame's natural geometry. A thin IR-pass filter strip
//    runs along the brow bar, looking like a decorative dark
//    accent line. Behind it: SMD IR LEDs on a flex PCB.
//
//  ┌──────────────────────────────────────────────────────┐
//  │  F5  = Preview  (fast, with colors + beams)          │
//  │  F6  = Render   (slow, for STL export)               │
//  │  Customizer panel for real-time parameter tweaks      │
//  └──────────────────────────────────────────────────────┘

include <common.scad>

// ╔═══════════════════════════════════════════════════════════╗
// ║  VIEW CONTROLS                                           ║
// ╚═══════════════════════════════════════════════════════════╝

/* [View] */
show_beams      = true;     // IR beam visualization (camera view)
show_filter     = true;     // IR-pass filter strip overlay
show_flex_pcb   = true;     // Internal flex PCB + SMD LEDs
show_internals  = true;     // Battery, MCU, etc.
cross_section   = false;    // Cutaway showing internal channels
exploded        = false;    // Exploded assembly view
print_layout    = false;    // Flat print-ready parts
camera_view     = false;    // Simulate how a camera sees it (bright beams)

// ╔═══════════════════════════════════════════════════════════╗
// ║  FACE MEASUREMENTS                                       ║
// ╚═══════════════════════════════════════════════════════════╝

/* [Face Dimensions] */
face_width       = 142;     // Total frame width
lens_width       = 50;      // Lens opening width
lens_height      = 36;      // Lens opening height
lens_corner_r    = 9;       // Corner radius (↑ = rounder)
bridge_gap       = 18;      // Nose bridge gap
nose_bridge_drop = 5;       // Bridge drop below lens center

/* [Temple Arms] */
temple_length    = 140;     // Temple arm length
temple_width     = 5.5;     // Temple width
temple_thickness = 4.0;     // Temple thickness
temple_angle     = 8;       // Outward splay
ear_bend_angle   = 22;      // Ear hook curl
ear_bend_start   = 108;     // Where bend begins

// ╔═══════════════════════════════════════════════════════════╗
// ║  FRAME STRUCTURE                                         ║
// ╚═══════════════════════════════════════════════════════════╝

/* [Frame] */
brow_thickness   = 8.0;     // Brow bar height (houses LED channel)
rim_thickness    = 3.5;     // Lower/side rim
frame_depth      = 7.0;     // Front-to-back depth
frame_fillet     = 1.2;     // Edge rounding

// ╔═══════════════════════════════════════════════════════════╗
// ║  STEALTH LED CONFIGURATION                               ║
// ╚═══════════════════════════════════════════════════════════╝

/* [IR LEDs (Stealth)] */
led_count_brow   = 4;       // SMD LEDs per side along brow
led_count_bridge = 1;       // Bridge LED (0 or 1)
led_count_temple = 2;       // LEDs per temple arm
led_pitch        = 10.0;    // Brow LED center-to-center
temple_led_pitch = 8.0;     // Temple LED spacing

// Filter strip dimensions
filter_width     = 3.5;     // Height of the IR filter window
filter_depth     = 0.6;     // Filter material thickness
filter_recess    = 0.3;     // How deep filter sits into frame

// Internal LED channel
channel_height   = 4.5;     // Internal cavity height
channel_depth    = 5.0;     // Internal cavity depth

// ╔═══════════════════════════════════════════════════════════╗
// ║  BATTERY & ELECTRONICS                                   ║
// ╚═══════════════════════════════════════════════════════════╝

/* [Battery] */
batt_length      = 30;
batt_width       = 10;
batt_thickness   = 4.0;

// ── Derived ──────────────────────────────────────────────────
total_leds   = (led_count_brow + led_count_temple) * 2 + led_count_bridge;
half_bridge  = bridge_gap / 2;
lens_cx      = half_bridge + lens_width / 2;
brow_y       = lens_height / 2 + brow_thickness / 2;
filter_y     = lens_height / 2 + brow_thickness * 0.35;  // centered in brow
ex           = exploded ? 30 : 0;

// Total brow LED span (for filter strip length)
brow_led_span    = led_pitch * (led_count_brow - 1);
filter_length_side = brow_led_span + led_pitch;  // per side
filter_length_total = face_width - 12;            // nearly full width

// ══════════════════════════════════════════════════════════════
//  FRAME FRONT — 2D profile
// ══════════════════════════════════════════════════════════════

module frame_front_2d() {
    difference() {
        union() {
            // Left lens surround
            translate([-lens_cx, 0])
                offset(r = rim_thickness)
                    rounded_rect_2d(lens_width, lens_height, lens_corner_r);
            // Right lens surround
            translate([lens_cx, 0])
                offset(r = rim_thickness)
                    rounded_rect_2d(lens_width, lens_height, lens_corner_r);
            // Bridge
            translate([0, lens_height/2 - nose_bridge_drop])
                square([bridge_gap + rim_thickness * 1.5, rim_thickness * 2],
                       center = true);
            // Thickened brow bar — the key structural element
            translate([0, lens_height/2 + brow_thickness/2 - 0.5])
                square([face_width + 2, brow_thickness], center = true);
        }
        // Lens openings
        translate([-lens_cx, 0])
            rounded_rect_2d(lens_width, lens_height, lens_corner_r);
        translate([lens_cx, 0])
            rounded_rect_2d(lens_width, lens_height, lens_corner_r);
    }
}

// ══════════════════════════════════════════════════════════════
//  FRAME FRONT — 3D with LED channels and filter slots
// ══════════════════════════════════════════════════════════════

module frame_front_3d() {
    color(CLR_FRAME)
        difference() {
            // Base frame shape
            minkowski() {
                linear_extrude(height = frame_depth - frame_fillet * 2,
                               center = true)
                    offset(delta = -frame_fillet)
                        frame_front_2d();
                sphere(r = frame_fillet, $fn = 16);
            }

            // ── Filter slot (front face) ──
            // A narrow horizontal groove across the brow bar front
            // The IR filter strip press-fits into this slot
            translate([0, filter_y, frame_depth/2 - filter_recess])
                cube([filter_length_total, filter_width, filter_depth * 2],
                     center = true);

            // ── Internal LED channel ──
            // Runs the full width of brow bar, behind the filter slot
            // Houses the flex PCB strip with SMD LEDs
            translate([0, filter_y, 0])
                cube([filter_length_total - 4, channel_height, channel_depth],
                     center = true);

            // ── Wire channels from brow to temples ──
            for (sx = [-1, 1])
                translate([sx * (face_width/2 - 2), filter_y, 0])
                    rotate([0, 90, 0])
                        cylinder(d = 2.2, h = 15, center = true, $fn = 16);

            // ── Temple LED slots (near hinges) ──
            for (sx = [-1, 1])
                for (i = [0 : led_count_temple - 1]) {
                    tx = sx * (face_width/2 + 2 + i * temple_led_pitch);
                    translate([tx, 0, frame_depth/2 - filter_recess])
                        cube([3.8, 3.2, filter_depth * 2], center = true);
                    // Cavity behind
                    translate([tx, 0, 0])
                        cube([4.5, 4.0, channel_depth], center = true);
                }

            // ── Bridge LED slot ──
            if (led_count_bridge > 0)
                translate([0, lens_height/2 - nose_bridge_drop,
                           frame_depth/2 - filter_recess]) {
                    cube([3.8, 3.2, filter_depth * 2], center = true);
                    translate([0, 0, -channel_depth/2])
                        cube([4.5, 4.0, channel_depth], center = true);
                }

            // ── Flex PCB insertion slot (side of brow bar) ──
            // The strip slides in from the temple end
            for (sx = [-1, 1])
                translate([sx * (filter_length_total/2 + 1), filter_y, 0])
                    cube([4, 4.5, 1.0], center = true);
        }
}

// ══════════════════════════════════════════════════════════════
//  IR-PASS FILTER STRIPS — the stealth magic
//  Looks like a subtle dark accent line on the frame
//  Actually transmits 940nm IR while blocking visible light
// ══════════════════════════════════════════════════════════════

module filter_strips() {
    // Main brow bar filter — continuous strip
    translate([0, filter_y, frame_depth/2 - filter_recess/2])
        ir_filter_strip(
            length = filter_length_total - 1,
            width = filter_width - 0.2,
            thickness = filter_depth
        );

    // Temple LED filters (small individual pieces)
    for (sx = [-1, 1])
        for (i = [0 : led_count_temple - 1]) {
            tx = sx * (face_width/2 + 2 + i * temple_led_pitch);
            translate([tx, 0, frame_depth/2 - filter_recess/2])
                ir_filter_strip(length = 3.4, width = 2.8,
                                thickness = filter_depth);
        }

    // Bridge filter
    if (led_count_bridge > 0)
        translate([0, lens_height/2 - nose_bridge_drop,
                   frame_depth/2 - filter_recess/2])
            ir_filter_strip(length = 3.4, width = 2.8,
                            thickness = filter_depth);
}

// ══════════════════════════════════════════════════════════════
//  FLEX PCB + SMD LEDs — hidden inside the brow bar
// ══════════════════════════════════════════════════════════════

module internal_led_assembly() {
    // Left brow flex strip
    translate([-(half_bridge + filter_length_side/2 + 4),
               filter_y, 0])
        rotate([0, 0, 0])
            flex_pcb_strip(
                length = filter_length_side + 4,
                led_count = led_count_brow,
                led_pitch = led_pitch
            );

    // Right brow flex strip
    translate([(half_bridge + filter_length_side/2 + 4),
               filter_y, 0])
        rotate([0, 0, 0])
            flex_pcb_strip(
                length = filter_length_side + 4,
                led_count = led_count_brow,
                led_pitch = led_pitch
            );

    // Bridge LED (single SMD)
    if (led_count_bridge > 0)
        translate([0, lens_height/2 - nose_bridge_drop, 0])
            ir_led_smd(show_beam = false);

    // Temple LEDs
    for (sx = [-1, 1])
        for (i = [0 : led_count_temple - 1]) {
            tx = sx * (face_width/2 + 2 + i * temple_led_pitch);
            translate([tx, 0, 0])
                ir_led_smd(show_beam = false);
        }
}

// ══════════════════════════════════════════════════════════════
//  IR BEAM VISUALIZATION — what cameras see
// ══════════════════════════════════════════════════════════════

module ir_beams() {
    beam_alpha = camera_view ? 0.12 : 0.04;
    beam_color = camera_view
        ? [1.0, 1.0, 1.0, 0.15]   // white bloom (camera saturated)
        : [0.55, 0.0, 1.0, beam_alpha];  // faint purple

    // Brow bar beams — wide wash from the filter strip
    for (sx = [-1, 1])
        for (i = [0 : led_count_brow - 1]) {
            x = sx * (half_bridge + 8 + i * led_pitch);
            translate([x, filter_y, frame_depth/2])
                color(beam_color)
                    // Wide angle SMD beam (±60°)
                    cylinder(d1 = filter_width, d2 = 90, h = 70, $fn = 24);
        }

    // Bridge beam
    if (led_count_bridge > 0)
        translate([0, lens_height/2 - nose_bridge_drop, frame_depth/2])
            color(beam_color)
                cylinder(d1 = 3, d2 = 60, h = 50, $fn = 24);

    // Temple beams
    for (sx = [-1, 1])
        for (i = [0 : led_count_temple - 1]) {
            tx = sx * (face_width/2 + 2 + i * temple_led_pitch);
            translate([tx, 0, frame_depth/2])
                color(beam_color)
                    cylinder(d1 = 3, d2 = 50, h = 45, $fn = 24);
        }
}

// ══════════════════════════════════════════════════════════════
//  NOSE BRIDGE
// ══════════════════════════════════════════════════════════════

module nose_assembly() {
    for (sx = [-1, 1]) {
        color(CLR_SILVER)
            translate([sx * 5, -lens_height/2 + nose_bridge_drop, 0])
                rotate([20, 0, sx * 15])
                    cylinder(d = 1.2, h = 14, $fn = 12);
        translate([sx * 7, -lens_height/2 + nose_bridge_drop - 10,
                   frame_depth/2 + 2])
            rotate([30, sx * 10, 0])
                nose_pad();
    }
}

// ══════════════════════════════════════════════════════════════
//  TEMPLE ARM — clean with hidden wire channel
// ══════════════════════════════════════════════════════════════

module temple_arm() {
    color(CLR_FRAME)
        difference() {
            union() {
                // Main section
                minkowski() {
                    cube([ear_bend_start - 2,
                          temple_width - 1, temple_thickness - 0.5],
                         center = true);
                    sphere(r = 0.5, $fn = 12);
                }
                // Ear bend
                translate([ear_bend_start/2, 0, 0])
                    rotate([0, ear_bend_angle, 0])
                        translate([(temple_length - ear_bend_start)/2, 0, 0])
                            minkowski() {
                                cube([temple_length - ear_bend_start - 2,
                                      temple_width - 1,
                                      temple_thickness - 0.5],
                                     center = true);
                                sphere(r = 0.5, $fn = 12);
                            }
                // Battery bulge (subtle thickening at tip)
                translate([ear_bend_start/2, 0, 0])
                    rotate([0, ear_bend_angle, 0])
                        translate([(temple_length - ear_bend_start)/2 + 5,
                                   0, 0])
                            minkowski() {
                                cube([batt_length + 2, batt_width + 1,
                                      batt_thickness], center = true);
                                sphere(r = 1.0, $fn = 12);
                            }
            }

            // Wire channel (full length)
            rotate([0, 90, 0])
                cylinder(d = 1.8, h = ear_bend_start + 10,
                         center = true, $fn = 12);

            // Battery cavity
            translate([ear_bend_start/2, 0, 0])
                rotate([0, ear_bend_angle, 0])
                    translate([(temple_length - ear_bend_start)/2 + 5,
                               0, 0.5])
                        cube([batt_length - 2, batt_width - 2,
                              batt_thickness - 0.5], center = true);

            // Charge port (bottom of battery area, very discreet)
            translate([ear_bend_start/2, 0, 0])
                rotate([0, ear_bend_angle, 0])
                    translate([(temple_length - ear_bend_start)/2 + 5,
                               0, -(batt_thickness/2 + 1)])
                        cube([9, 3.2, 4], center = true);

            // Button recess (tiny, inner face of temple)
            translate([5, -(temple_width/2 + 0.5), 0])
                cube([4, 2, 2.5], center = true);
        }
}

// ══════════════════════════════════════════════════════════════
//  HINGE
// ══════════════════════════════════════════════════════════════

module hinge_block() {
    color(CLR_FRAME)
        difference() {
            minkowski() {
                cube([8, 4, frame_depth - 1], center = true);
                sphere(r = 0.5, $fn = 12);
            }
            cylinder(d = 1.5, h = frame_depth + 2,
                     center = true, $fn = 16);
        }
    color(CLR_SILVER)
        cylinder(d = 1.2, h = frame_depth + 1,
                 center = true, $fn = 12);
}

// ══════════════════════════════════════════════════════════════
//  TEMPLE INTERNALS
// ══════════════════════════════════════════════════════════════

module temple_electronics() {
    // Battery
    tip_x = ear_bend_start/2;
    translate([tip_x, 0, 0])
        rotate([0, ear_bend_angle, 0])
            translate([(temple_length - ear_bend_start)/2 + 5, 0, 1])
                rotate([0, 0, 90])
                    lipo_battery(l = batt_length - 4,
                                 w = batt_width - 4,
                                 h = batt_thickness - 1.5);

    // Tiny MCU (one temple only)
    translate([15, 0, 0.5])
        scale(0.5)
            attiny85_dip8();
}

// ══════════════════════════════════════════════════════════════
//  FULL ASSEMBLY
// ══════════════════════════════════════════════════════════════

module full_assembly() {

    // ── Frame front ──
    translate([0, 0, ex * 0.3])
        frame_front_3d();

    // ── IR-pass filter strips ──
    if (show_filter)
        translate([0, 0, ex * 0.5])
            filter_strips();

    // ── Internal flex PCB + SMD LEDs ──
    if (show_flex_pcb)
        translate([0, 0, ex * 0.15])
            internal_led_assembly();

    // ── IR beams ──
    if (show_beams)
        translate([0, 0, ex * 0.5])
            ir_beams();

    // ── Nose pads ──
    nose_assembly();

    // ── Hinges + Temples ──
    for (side = [-1, 1]) {
        hinge_x = side * (face_width / 2 + 2);

        translate([hinge_x, 0, 0])
            hinge_block();

        translate([hinge_x + side * ear_bend_start / 2,
                   0, -ex * 0.2])
            rotate([0, 0, side * temple_angle])
                translate([side * 5, 0, 0]) {
                    temple_arm();
                    if (show_internals)
                        temple_electronics();
                }
    }
}

// ══════════════════════════════════════════════════════════════
//  PRINT LAYOUT
// ══════════════════════════════════════════════════════════════

module print_parts() {
    // Frame front (flat on back)
    translate([0, 0, frame_depth/2])
        rotate([90, 0, 0])
            frame_front_3d();
    // Left temple
    translate([0, -55, temple_thickness/2])
        temple_arm();
    // Right temple
    translate([0, -75, temple_thickness/2])
        temple_arm();
}

// ══════════════════════════════════════════════════════════════
//  RENDER
// ══════════════════════════════════════════════════════════════

if (print_layout) {
    print_parts();
} else if (cross_section) {
    difference() {
        full_assembly();
        // Cut front half to expose LED channel
        translate([0, 0, 50 + frame_depth/2 - 1])
            cube([300, 300, 100], center = true);
    }
} else {
    full_assembly();
}

// ── Info overlay ──
color("White")
    translate([0, -lens_height - 15, 0])
        linear_extrude(0.1)
            text(str("ZK-Glasses Stealth — ", total_leds,
                     " SMD IR LEDs @ 940nm"),
                 size = 3.5, halign = "center",
                 font = "Liberation Mono");

color("Gray")
    translate([0, -lens_height - 22, 0])
        linear_extrude(0.1)
            text(str("Frame: ", face_width,
                     "mm  |  IR filter: Wratten 87C equiv"),
                 size = 2.8, halign = "center",
                 font = "Liberation Mono");

color([0.55, 0, 1], 0.4)
    translate([0, -lens_height - 28, 0])
        linear_extrude(0.1)
            text("Invisible to eyes — visible only to cameras",
                 size = 2.5, halign = "center",
                 font = "Liberation Mono:style=Italic");

// ══════════════════════════════════════════════════════════════
//  NOTES
// ══════════════════════════════════════════════════════════════
//
//  STEALTH DESIGN:
//    The brow bar has a thin horizontal slot cut into its
//    front face. An IR-pass filter strip (Kodak Wratten 87C
//    or Hoya IR-85) press-fits into this slot. It looks like
//    a subtle dark decorative accent line — completely normal.
//
//    Behind the filter: a flex PCB strip with SMD IR LEDs
//    (OSRAM SFH 4726AS or similar, 940nm, PLCC-2 package).
//    Each LED is 3.5 × 2.8 × 1.9mm — invisible from outside.
//
//    The 940nm wavelength is completely invisible to human
//    eyes (no red glow), but cameras see bright white spots.
//
//  IR-PASS FILTER OPTIONS:
//    - Kodak Wratten 87C gel: cheapest, ~$5, can be cut to size
//    - Hoya IR-85 glass: durable, optical quality, ~$20
//    - Lee 87C polyester: thin, flexible, press-fits easily
//    - 3D print in dark PLA, thin enough to pass some IR
//
//  ASSEMBLY:
//    1. 3D print frame (PETG, matte black)
//    2. Solder SMD LEDs to flex PCB strip
//    3. Slide flex strip into brow bar channel
//    4. Route wires through temple channels
//    5. Press-fit IR filter strips into front slots
//    6. Insert batteries into temple tips
//    7. Snap in charge port, button, MCU
//
//  PRINT SETTINGS:
//    Material:  PETG matte black (or Nylon PA12)
//    Layer:     0.12mm (fine detail for filter slot)
//    Infill:    40% gyroid
//    Walls:     4 perimeters (structural around channels)
//    Supports:  Tree, touching buildplate only
//    Post:      Light sanding, optional soft-touch paint
//
// ══════════════════════════════════════════════════════════════
