# 🦅 Phoenix — Give it life again.

> **Turn an obsolete Android device into a modern productivity tool.**

**Phoenix** is a low-latency extension system that allows you to use an old Android tablet (starting from Android 4.4 KitKat) as a secondary interface for your Mac. The project streams the Mac screen to the tablet via H.264 and sends events back to macOS via UDP.

---

## 🛑 Project Status & Disclaimer

**Status: Accomplished (for my needs) | Maintenance: None**

I have officially reached my personal goal for this project: **low-latency screen streaming from Mac to an old tablet** (tested and verified on an MTK/MediaTek chipset). 

* **Pro Tip:** I personally use this as a **third monitor** by creating a virtual display with [BetterDisplay](https://github.com/waydabber/BetterDisplay) on macOS and streaming that specific window/display to the tablet.
* **⚠️ Touch Input is Incomplete:** While video streaming works great, touch functionality is **very incomplete**. The code contains only a basic skeleton/draft for touch events. It is not functional and requires significant work.
* **No Updates:** Since the streaming works perfectly for my specific setup, **I will not be providing any further updates, fixes, or touch implementations.**

---

## ⚙️ Manual Configuration (Crucial Step)

Since this project was built for personal use, some IP addresses are currently hardcoded. You **must** update them to match your local network before compiling:

1.  **Server Side (macOS):** Open `PhoenixServer/Sources/Managers/ServerManager.swift` and replace the placeholder IP with your **Android Tablet's Local IP** (you can find this in your tablet's Wi-Fi settings).
2.  **Client Side (Android):** When you launch the app on your tablet, you will need to manually enter your **MacBook's Local IP** to establish the connection.

---

## 🚀 Getting Started

### A. macOS Server (PhoenixServer)
1.  **Requirements:** Xcode 13+ and a Mac with Screen Recording support.
2.  **Permissions:** Go to *System Settings → Privacy & Security* and grant **Screen Recording** and **Accessibility** permissions to the app.
3.  **Run:** Open `PhoenixServer.xcodeproj`, build the project, and press **START PHOENIX**.

### B. Android Client (PhoenixClient)
1.  **Requirements:** Android Studio and a target device running Android 4.4+ (API 19).
2.  **Setup & Connect:** The app uses mDNS to find the Mac. If discovery fails, enter the Mac's IP manually (as explained in the Configuration section). Once connected, the tablet will display the Mac's screen.

---

## 🛠 Troubleshooting

* **Discovery Fails:** Ensure both devices are connected to the exact same Wi-Fi network.
* **Lag or Freezing:** UDP is fast but unstable on crowded Wi-Fi networks. If you experience lag, it's likely due to your Wi-Fi router or bitrate settings. *Fix it yourself, I'm done here!* 😂

---

## 🌟 Credits & Philosophy

This project is a labor of love dedicated to giving old hardware a new purpose.

**Development:** 100% AI-generated. As a "non-developer", I directed the AI to write every line of code, handle logic, and fix bugs to bring my ideas to life.

**Philosophy:** I'm sharing this "AI-authored" experiment because if it solved a streaming problem for me, it might just be the foundation you are looking for to build something even better.
