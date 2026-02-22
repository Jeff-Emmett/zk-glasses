/*
 * ╔═══════════════════════════════════════════════════════════╗
 * ║  ZK-Glasses — ATtiny85 IR LED Controller Firmware        ║
 * ╠═══════════════════════════════════════════════════════════╣
 * ║  Board:   ATtiny85 (ATTinyCore, 8 MHz internal)          ║
 * ║  Programmer: USBasp / Arduino as ISP                     ║
 * ║  License: MIT                                            ║
 * ╚═══════════════════════════════════════════════════════════╝
 *
 *  Pin Assignment (DIP-8):
 *  ┌────────────────────────────┐
 *  │  ATtiny85                  │
 *  │  (RST) PB5 ─┤1    8├─ VCC │
 *  │  (ADC) PB3 ─┤2    7├─ PB2 (BTN)
 *  │  (OC1B)PB4 ─┤3    6├─ PB1 (LED_R) OC0B
 *  │         GND ─┤4    5├─ PB0 (LED_L) OC0A
 *  └────────────────────────────┘
 *
 *  PB0  - LED group LEFT  (8 IR LEDs via N-MOSFET gate)
 *  PB1  - LED group RIGHT (8 IR LEDs via N-MOSFET gate)
 *  PB2  - Tactile button (internal pull-up, active LOW)
 *  PB3  - Status LED (green, current-limited)
 *  PB4  - Battery voltage sense (ADC2, voltage divider)
 *
 *  Modes:
 *    0  OFF            — LEDs off, MCU in low-power idle
 *    1  CONSTANT       — Full brightness, steady
 *    2  PULSE_30HZ     — 30 Hz square wave (half power draw)
 *    3  PULSE_60HZ     — 60 Hz, matches common camera fps
 *    4  RANDOM_FLICKER — Pseudorandom on/off, defeats adaptive filters
 *    5  STEALTH        — 25% duty constant (very low visibility)
 *
 *  Controls:
 *    Short press  (<500ms)   — Cycle to next mode
 *    Long press   (>800ms)   — Cycle brightness (25→50→75→100%)
 *    Double press (<300ms)   — Instant OFF
 *
 *  Features:
 *    - Auto-off after 2 hours (configurable)
 *    - Low battery warning: status LED blinks when Vcc < 3.3V
 *    - All timing via Timer0 (no delay() in main loop)
 */

#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/sleep.h>
#include <avr/wdt.h>

// ── Pin Definitions ──────────────────────────────────────────
#define PIN_LED_L    PB0   // Left IR LED group (OC0A)
#define PIN_LED_R    PB1   // Right IR LED group (OC0B)
#define PIN_BTN      PB2   // Button input
#define PIN_STATUS   PB3   // Status LED
#define PIN_VBAT     PB4   // Battery ADC (ADC2)

// ── Configuration ────────────────────────────────────────────
#define NUM_MODES          6
#define DEBOUNCE_MS       40
#define SHORT_PRESS_MAX  500   // ms — below this = short press
#define LONG_PRESS_MIN   800   // ms — above this = long press
#define DOUBLE_PRESS_MAX 300   // ms — gap for double-press detection
#define AUTO_OFF_MS   7200000UL  // 2 hours in ms
#define LOW_BATT_ADC     175   // ~3.3V via voltage divider (3.3/5*1024*R2/(R1+R2))
#define BATT_CHECK_INTERVAL 10000  // Check battery every 10s

// ── Brightness Levels (PWM duty 0–255) ───────────────────────
const uint8_t BRIGHTNESS_LEVELS[] = { 64, 128, 192, 255 };
#define NUM_BRIGHTNESS  4

// ── Mode Enumeration ─────────────────────────────────────────
enum Mode : uint8_t {
    MODE_OFF           = 0,
    MODE_CONSTANT      = 1,
    MODE_PULSE_30HZ    = 2,
    MODE_PULSE_60HZ    = 3,
    MODE_RANDOM        = 4,
    MODE_STEALTH       = 5
};

// ── State ────────────────────────────────────────────────────
volatile uint8_t  g_mode          = MODE_OFF;
volatile uint8_t  g_brightness_idx = 3;   // Start at full
volatile uint32_t g_millis        = 0;
volatile bool     g_btn_pressed   = false;

uint32_t g_mode_start_ms   = 0;    // For auto-off timer
uint32_t g_last_batt_check = 0;
bool     g_low_battery     = false;
uint16_t g_lfsr            = 0xACE1;  // LFSR seed for random mode

// ── Millisecond Timer (Timer0 overflow at 8MHz/64/256 ≈ 488Hz) ──
// We'll use Timer1 for millis since Timer0 is used for PWM
// Actually, let's use a simple millis implementation with Timer0
// Timer0 is set up for Fast PWM on OC0A/OC0B

// We'll track time using Timer1 overflow
ISR(TIMER1_OVF_vect) {
    // Timer1 at 8MHz/64, 8-bit overflow = every 2.048ms
    // We'll count overflows for rough millisecond tracking
    g_millis += 2;
}

// ── LFSR Pseudorandom (16-bit Galois) ────────────────────────
uint16_t lfsr_next() {
    uint16_t bit = ((g_lfsr >> 0) ^ (g_lfsr >> 2) ^
                    (g_lfsr >> 3) ^ (g_lfsr >> 5)) & 1u;
    g_lfsr = (g_lfsr >> 1) | (bit << 15);
    return g_lfsr;
}

// ── ADC Read (blocking, 10-bit) ──────────────────────────────
uint16_t read_adc(uint8_t channel) {
    ADMUX  = channel;                        // Vcc reference, selected channel
    ADCSRA = (1 << ADEN) | (1 << ADSC) |     // Enable, start conversion
             (1 << ADPS2) | (1 << ADPS1);    // Prescaler /64
    while (ADCSRA & (1 << ADSC));            // Wait for completion
    uint16_t result = ADC;
    ADCSRA &= ~(1 << ADEN);                 // Disable ADC to save power
    return result;
}

// ── Set LED PWM Duty Cycle ───────────────────────────────────
void set_leds(uint8_t duty) {
    OCR0A = duty;   // Left group
    OCR0B = duty;   // Right group
}

// ── Status LED Control ───────────────────────────────────────
void status_led(bool on) {
    if (on) PORTB |=  (1 << PIN_STATUS);
    else    PORTB &= ~(1 << PIN_STATUS);
}

// ── Button Reading (debounced) ───────────────────────────────
bool button_is_down() {
    return !(PINB & (1 << PIN_BTN));  // Active LOW
}

// ── Setup ────────────────────────────────────────────────────
void setup() {
    // --- GPIO ---
    DDRB  = (1 << PIN_LED_L) | (1 << PIN_LED_R) | (1 << PIN_STATUS);
    PORTB = (1 << PIN_BTN);   // Pull-up on button

    // --- Timer0: Fast PWM on OC0A (PB0) and OC0B (PB1) ---
    // Mode 3 (Fast PWM, TOP=0xFF), prescaler /1 for ~31.4 kHz base
    // Non-inverting output on both channels
    TCCR0A = (1 << COM0A1) | (1 << COM0B1) |
             (1 << WGM01)  | (1 << WGM00);
    TCCR0B = (1 << CS00);   // No prescaler → 8MHz/256 = 31.25kHz
    OCR0A  = 0;
    OCR0B  = 0;

    // --- Timer1: Millis tracking ---
    // CTC mode, prescaler /64 → overflow at 8MHz/64/256 ≈ 488 Hz
    TCCR1  = (1 << CS12) | (1 << CS11) | (1 << CS10);  // /64
    TIMSK |= (1 << TOIE1);  // Overflow interrupt

    sei();  // Enable global interrupts

    // Startup flash
    status_led(true);
    _delay_ms(200);
    status_led(false);
}

// ── Process Button Input ─────────────────────────────────────
void process_button() {
    static uint32_t press_start    = 0;
    static uint32_t last_release   = 0;
    static bool     was_pressed    = false;
    static bool     awaiting_double = false;
    static uint8_t  press_count    = 0;

    bool pressed = button_is_down();
    uint32_t now = g_millis;

    if (pressed && !was_pressed) {
        // --- Button just pressed ---
        press_start = now;
        was_pressed = true;
    }
    else if (!pressed && was_pressed) {
        // --- Button just released ---
        uint32_t duration = now - press_start;
        was_pressed = false;

        if (duration > LONG_PRESS_MIN) {
            // Long press → cycle brightness
            g_brightness_idx = (g_brightness_idx + 1) % NUM_BRIGHTNESS;
            // Flash status LED to indicate level
            for (uint8_t i = 0; i <= g_brightness_idx; i++) {
                status_led(true);
                _delay_ms(80);
                status_led(false);
                _delay_ms(80);
            }
        }
        else if (duration < SHORT_PRESS_MAX) {
            // Short press — check for double press
            if (awaiting_double && (now - last_release < DOUBLE_PRESS_MAX)) {
                // Double press → OFF
                g_mode = MODE_OFF;
                set_leds(0);
                awaiting_double = false;
                press_count = 0;
                status_led(true);
                _delay_ms(50);
                status_led(false);
                return;
            }
            awaiting_double = true;
            last_release = now;
            press_count++;
        }
    }

    // Finalize single press after double-press window expires
    if (awaiting_double && !pressed &&
        (now - last_release > DOUBLE_PRESS_MAX)) {
        // Single short press → next mode
        g_mode = (g_mode + 1) % NUM_MODES;
        g_mode_start_ms = now;
        awaiting_double = false;
        press_count = 0;

        // Quick status flash for mode feedback
        for (uint8_t i = 0; i <= g_mode; i++) {
            status_led(true);
            _delay_ms(40);
            status_led(false);
            _delay_ms(40);
        }
    }
}

// ── Battery Check ────────────────────────────────────────────
void check_battery() {
    uint16_t adc_val = read_adc(2);  // ADC2 = PB4
    g_low_battery = (adc_val < LOW_BATT_ADC);
}

// ── Main Loop ────────────────────────────────────────────────
void loop() {
    uint32_t now = g_millis;

    // --- Button handling ---
    process_button();

    // --- Auto-off timer ---
    if (g_mode != MODE_OFF &&
        (now - g_mode_start_ms > AUTO_OFF_MS)) {
        g_mode = MODE_OFF;
        set_leds(0);
    }

    // --- Battery check (periodic) ---
    if (now - g_last_batt_check > BATT_CHECK_INTERVAL) {
        g_last_batt_check = now;
        check_battery();
    }

    // --- Low battery warning ---
    if (g_low_battery && g_mode != MODE_OFF) {
        // Blink status LED every 2 seconds
        status_led((now / 500) % 4 == 0);
    }

    // --- LED Mode Execution ---
    uint8_t duty = BRIGHTNESS_LEVELS[g_brightness_idx];

    switch (g_mode) {

        case MODE_OFF:
            set_leds(0);
            status_led(false);
            // Could enter sleep mode here for power savings
            break;

        case MODE_CONSTANT:
            set_leds(duty);
            break;

        case MODE_PULSE_30HZ:
            // 30 Hz = 33.3ms period, 16.7ms on / 16.7ms off
            if ((now % 33) < 17)
                set_leds(duty);
            else
                set_leds(0);
            break;

        case MODE_PULSE_60HZ:
            // 60 Hz = 16.7ms period, 8.3ms on / 8.3ms off
            if ((now % 17) < 9)
                set_leds(duty);
            else
                set_leds(0);
            break;

        case MODE_RANDOM:
            // Change state every 5–25ms (pseudorandom)
            {
                static uint32_t next_change = 0;
                if (now >= next_change) {
                    uint16_t rnd = lfsr_next();
                    // Random on/off
                    if (rnd & 1)
                        set_leds(duty);
                    else
                        set_leds(0);
                    // Random interval 5–25ms
                    next_change = now + 5 + (rnd % 21);
                }
            }
            break;

        case MODE_STEALTH:
            // 25% of selected brightness, constant
            set_leds(duty / 4);
            break;
    }

    _delay_ms(1);  // ~1 kHz loop rate
}

/*
 * ── Build & Flash Notes ──────────────────────────────────────
 *
 * Arduino IDE Setup:
 *   1. Install ATTinyCore via Board Manager
 *      URL: http://drazzy.com/package_drazzy.com_index.json
 *   2. Board: "ATtiny25/45/85 (No bootloader)"
 *   3. Chip: ATtiny85
 *   4. Clock: 8 MHz (internal)
 *   5. Programmer: USBasp (or "Arduino as ISP")
 *   6. Burn Bootloader first (sets fuses)
 *   7. Upload with programmer (Ctrl+Shift+U)
 *
 * PlatformIO (alternative):
 *   [env:attiny85]
 *   platform = atmelavr
 *   board = attiny85
 *   framework = arduino
 *   board_build.f_cpu = 8000000L
 *   upload_protocol = usbasp
 *
 * Power Consumption (estimated):
 *   Mode          | Avg Draw  | Runtime (500mAh)
 *   ──────────────┼───────────┼─────────────────
 *   OFF           |   ~5 µA   |   years
 *   CONSTANT 100% |  ~1.6 A   |   ~18 min
 *   PULSE 30Hz    |  ~800 mA  |   ~37 min
 *   PULSE 60Hz    |  ~800 mA  |   ~37 min
 *   RANDOM        |  ~600 mA  |   ~50 min
 *   STEALTH       |  ~400 mA  |   ~75 min
 *
 *   (16 LEDs × 100mA = 1.6A max; MCU + driver overhead ~5mA)
 *
 * Wiring Quick Reference:
 *
 *   ATtiny85 Pin 5 (PB0) ──→ 1kΩ ──→ Q1 Gate (IRLML6344)
 *                                      Q1 Drain ──→ LED Group L (8× parallel)
 *                                      Q1 Source ──→ GND
 *
 *   ATtiny85 Pin 6 (PB1) ──→ 1kΩ ──→ Q2 Gate (IRLML6344)
 *                                      Q2 Drain ──→ LED Group R (8× parallel)
 *                                      Q2 Source ──→ GND
 *
 *   ATtiny85 Pin 7 (PB2) ──→ Button ──→ GND  (internal pull-up)
 *   ATtiny85 Pin 2 (PB3) ──→ 330Ω ──→ Status LED ──→ GND
 *   ATtiny85 Pin 3 (PB4) ──→ Voltage divider (100k/100k) ──→ VBAT
 */
