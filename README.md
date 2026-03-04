# 🦅 Phoenix — Give it life again.

**Phoenix** is a low-latency extension system. It allows you to use an old Android tablet (starting from Android 4.4 KitKat) as a secondary interface for your Mac. 

The project streams the Mac screen to the tablet via H.264 and sends events back to macOS via UDP, effectively turning an obsolete device into a modern productivity tool.

---
### 🛑 Project Status: Accomplished
I have officially reached my personal goal for this project: **low-latency screen streaming from Mac to an old tablet.** 
* This was tested and verified on a device with an **MTK (MediaTek) chipset**.
* **Usage Tip:** I personally use this as a **third monitor** by creating a virtual display with **BetterDisplay** on macOS and streaming that specific window/display to the tablet.
* **Maintenance:** Since the streaming works for my specific needs, **I will not be providing any further updates, fixes, or touch implementations.**

### ⚠️ Current Status: Touch Input Incomplete
**Important:** While the project handles video streaming successfully, the touch functionality is **very incomplete**. 
The code contains only a basic skeleton/draft for touch events. It is not functional and requires significant work to be implemented properly.

---

### 🚀 Getting Started

#### A — macOS Server (PhoenixServer)
1. **Requirements:** Xcode 13+, macOS with Screen Recording support.
2. **Run:** Open `PhoenixServer.xcodeproj`, build, and press **START PHOENIX**.
3. **Permissions:** You must enable **Screen Recording** and **Accessibility** in *System Settings → Privacy & Security*.

#### B — Android Client (PhoenixClient)
1. **Requirements:** Android Studio, target device with Android 4.4+ (API 19).
2. **Setup:** The app uses mDNS to find the Mac. If discovery fails, enter the IP manually.
3. **Connect:** Once connected, the tablet will display the Mac's screen.

---

### ⚙️ Manual Configuration (Crucial)
Since this project was built for personal use, some IP addresses are currently hardcoded. You **must** update them to match your own network:

1. **Server Side (macOS):** Open `PhoenixServer/Sources/Managers/ServerManager.swift` and replace the placeholder IP with your **Android Tablet's Local IP** (you can find this in your Tablet's Wi-Fi settings).
   
2. **Client Side (Android):** When you launch the app on your tablet, you will need to manually enter your **MacBook's Local IP** to establish the connection.

---

### 🛠 Troubleshooting
* **Discovery Fails:** Ensure both devices are on the same Wi-Fi.
* **Lag/Freeze:** UDP is fast but unstable on crowded Wi-Fi. If you experience lag, it's likely your Wi-Fi or bitrate settings. Fix it yourself, I'm done here! 😂

---

### 🌟 Credits & Acknowledgments
This project is a labor of love dedicated to giving old hardware a new purpose.

Development: 100% AI-generated. As a "non-developer", I directed the AI to write every line of code, handle logic, and fix bugs to bring my ideas to life.
  
Philosophy: Sharing this "AI-authored" experiment because if it solved a streaming problem for me, it might be the foundation you were looking for.
