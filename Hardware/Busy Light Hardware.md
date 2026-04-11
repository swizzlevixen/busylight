# Busy Light Hardware

Light that I built for my office door, so that my partner could easily see if I was busy, concentrating, or free to talk. Controlled by [my macOS menu bar item app](https://github.com/swizzlevixen/busylight/)

## Components

I am linking to Amazon where I bought these myself. I may get a small kickback if you buy from these links.

- [ESP32s Development Board](https://amzn.to/3OdwR6I)
- [RGB LED Ring 12 x WS2912B](https://amzn.to/4sXTLxY)
- [RGB LED Stick 8 X WS2812B](https://amzn.to/4vsLBiY)
- [Anker 10,000mAh USB Power Bank](https://amzn.to/4ellkwy)
- A 3D-printed enclosure that hangs over the edge of the door — [my model](./Busy%20Light%20-%20Door%20Hook.3mf)
- (2) 3D-printed diffusers 3D-printed out of "clear" PLA or PETG — [my models](./Busy%20Light%20-%20Diffusers.3mf)

## Construction

The USB battery pack powers the board and the LEDs. It's plugged in to the USB-Micro connector, and the board steps it down to 3.3V. However, since we are running very few LEDs, you can draw 5V off the USB input via the ESP32 `VIN` connector.

- Ring LEDs `DI` goes to `GPIO3`, on the outside of the door
- Ring `DO` passes a wire back to `DI` on the LED stick, which is mounted on the inside — having the inside LEDs be further down the chain acts as a sort of rudimentary witness lamp, showing that connections are good and the ring outside is getting signal, even when the door is closed
- Ring and stick `GND` goes to `GND`
- Ring and stick `VIN` tap 5V from the ESP32 `VIN`

## Software

I used the ESPHome Builder integration in Home Assistant to set up the ESP32 to control the lights, and also to connect via WiFi to my HomeAssistant instance. The YAML setup is below.

The `on_boot:` section is mostly a little light show to show that the board had booted up and was ready for commands. 

The main function of the ESP32 is to run the [ESP32 RMT LED Strip](https://esphome.io/components/light/esp32_rmt_led_strip/) driver for the LEDs, which themn appear in Home Assistant as if they were an RGB-controllable light. I'm just using simple colors for now, but animated effects seem possible to program.

```
esphome:
  name: esphome-web-95d754
  friendly_name: Mark Busy Controller
  min_version: 2025.9.0
  name_add_mac_suffix: false
  on_boot:
    priority: -100 
    then:
      - light.turn_on:
          id: mark_busy_light
          brightness: 50%
          red: 100%
          green: 0%
          blue: 0%
      - delay: 1s
      - light.turn_off: mark_busy_light
      - delay: 1s
      - light.turn_on:
          id: mark_busy_light
          brightness: 50%
          red: 100%
          green: 75%
          blue: 0%
      - delay: 1s
      - light.turn_off: mark_busy_light
      - delay: 1s
      - light.turn_on:
          id: mark_busy_light
          brightness: 50%
          red: 0%
          green: 100%
          blue: 0%
      - delay: 1s
      - light.turn_off: mark_busy_light

      

esp32:
  variant: esp32
  framework:
    type: esp-idf

# Enable logging
logger:

# Enable Home Assistant API
api:

# Allow Over-The-Air updates
ota:
- platform: esphome

wifi:
  ssid: !secret wifi_ssid
  password: !secret wifi_password

light:
  - platform: esp32_rmt_led_strip
    rgb_order: GRB
    chipset: WS2812
    pin: GPIO3
    num_leds: 20
    name: "Mark Busy Light"
    id: mark_busy_light
    effects: 
      - addressable_rainbow:
          width: 12
```

It shows up as a lighting device in Home Assistant via ESPHome

I set up some scenes with Home Assistant, and they are very lightweight, but give [my macOS menu bar item app](https://github.com/swizzlevixen/busylight/) something to trigger.

Here is a sample one, that turns the LEDs red:

```
id: "1762181861985"
name: RED - Mark Office Busy
entities:
  light.esphome_web_95d754_mark_busy_light:
    effect_list:
      - None
      - Rainbow
    supported_color_modes:
      - rgb
    effect: None
    color_mode: rgb
    brightness: 128
    hs_color:
      - 352
      - 100
    rgb_color:
      - 255
      - 0
      - 34
    xy_color:
      - 0.689
      - 0.294
    friendly_name: Mark Busy Controller Mark Busy Light
    supported_features: 44
    state: "on"
icon: mdi:alarm-light
metadata: {}

```

That's it! Not too complex.