# FreeToon for ToonStore 🚀

> **Breathe new life into your Toon!**  
> Install and switch to **FreeToon** directly from your stock screen with a single tap. 100% reversible, zero risk.

---

## ✨ What is FreeToon?

**FreeToon** is a next-generation, ultra-fast, open-source UI and firmware replacement for both **Toon 1** and **Toon 2**. Built from the ground up using **LVGL** in pure C, FreeToon completely replaces the aging, resource-heavy stock Qt interface with a modern, fluid, and battery-smooth experience.

Whether you have a Toon 1 that is struggling with sluggish menus or a Toon 2 you want to unlock the full potential of, FreeToon makes your wall thermostat feel like a brand-new device.

---

## 🌟 Why Switch to FreeToon?

### ⚡ Blazing Fast Performance
* **Instant Touch Response**: Say goodbye to sluggish lag. LVGL is designed specifically for embedded microcontrollers, running at a fluid frame rate with minimal CPU and memory consumption.
* **Revives Toon 1**: Turns the classic Toon 1 into a fast, snappy daily driver.

### 🎨 Modern & Customizable
* **Sleek Dark & Light Themes**: Modern, high-contrast layouts that look great day and night.
* **Modular Homescreen & Dim Screens**: Choose what you see. Dynamic dim screens with customizable clocks, height-adaptive agenda calendars, and live weather.
* **Dedicated Full-Screen Modals**:Buienradar rain maps, full Afvalkalender pickup schedules with stream icons, and nice energy statistics.

### 🔌 Next-Level Smart Home Integrations
* **In-App Marketplace**: Download and manage community apps and plugins (e.g. Sonos, Temperatuurlogger and more (to come)) on the fly without restarting the UI.
* **Energy Monitoring**: Native support for HomeWizard P1 meter, ESPHome, Domoticz, and Home Assistant.
* **OpenTherm Bridge**: Live boiler diagnostics (water flow, return temp, burner state) without affecting the thermostat’s native heating curve.
* **100% Local & Cloud-Independent**: No subscriptions, no telemetry, no dependence on external cloud servers.

### 🛡️ 100% Reversible (Dual-Boot Peace of Mind)
* **Boot Picker**: At every cold boot, an optional 10-second countdown lets you choose between FreeToon and the stock Eneco GUI.
* **Switch Back Anytime**: You can revert back to the classic GUI whenever you want from the FreeToon Settings menu (tile UI-Modus). In the Enenco Gui you can use this app to start Freetone (and close qt-gui)
* **Low disk space usage** : the Freetoon gui is just a few Mb's on your disk

---

## 📱 What does this ToonStore App do?

Previously, testing or installing FreeToon required SSH commands and terminal knowledge. **This app changes that:**

1. **One-Click Installation**: Checks if FreeToon is installed on your Toon. If not, it safely downloads and installs the latest verified release for your hardware model.
2. **Instant UI Switch**: Smoothly stops the stock `qt-gui` and launches FreeToon without having to pull the plug.
3. **Safe & Hands-Free**: Automatically configures system startup (`/etc/inittab`) and keeps your Toon reachable over the network at all times.

---

## 📲 How to Use

1. Open **ToonStore** on your Toon.
2. Search for **FreeToon** and install it. Once the Qt Qui has rebooted put Freetoon on an empty tile.
3. Open the **FreeToon** app from this tile.
4. Tap **Start or Install FreeToon**. (depending whether it is already installed or not)
5. Sit back and watch your Toon transform into FreeToon within seconds!

---

## 🔄 How to Switch Back to Stock Qt-GUI

Want to go back to the standard interface? It's just as simple:

* **From FreeToon Settings**: Go to `Instellingen` ➔ `Systeem & UI` ➔ `Overschakelen naar standaard UI`.
* **From the Boot Screen**: Tap `qt-gui` during the 10-second boot picker countdown after a reboot.

---

## 📟 Compatibility

| Model | Hardware | Status | Notes |
|---|---|---|---|
| **Toon 1** | i.MX27 ARM9 (800×480) |  Full Support | Smooth 16bpp rendering, dramatic speed improvement |
| **Toon 2** | i.MX6 SoloX (1024×600) |  Full Support | Ultra-crisp UI, virtually no response times to click events |

---
