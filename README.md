# 🦅 Phoenix — Give it life again.

**Phoenix** is a low-latency extension system. It allows you to use an old Android tablet (starting from Android 4.4 KitKat) as a secondary interface for your Mac. 

The project streams the Mac screen to the tablet via H.264 and sends touch events back to macOS via UDP, effectively turning an obsolete device into a modern productivity tool.

---

### 🏗 Architecture & Workflow

1. **Discovery (mDNS/Bonjour):** The server publishes a `_phoenix._udp` service. The client automatically finds the Mac's IP.
2. **Video Stream (UDP 5554):** The server captures the screen using VideoToolbox (H.264 Annex-B) and sends it to the client.

### ⚠️ Current Status: Touch Input (Incomplete)
**Important:** While the project handles video streaming successfully, the touch functionality is **very incomplete**. 
The code contains only a basic skeleton/draft for touch events. It is not functional and requires significant work to be implemented properly.

### 🛑 Project Status: Accomplished
I have officially reached my personal goal for this project: **low-latency screen streaming from Mac to an old tablet.** This was tested and verified on a device with an **MTK (MediaTek) chipset**. 
* **Maintenance:** Since the streaming works for my specific needs, **I will not be providing any further updates, fixes, or touch implementations.**

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

### 🛠 Troubleshooting
* **Discovery Fails:** Ensure both devices are on the same Wi-Fi. Check if your router blocks multicast/mDNS.
* **Lag/Freeze:** UDP is fast but unstable on crowded Wi-Fi. If you experience lag, it's likely your Wi-Fi or bitrate settings. Fix it yourself, I'm done here! 😂

---

### 🌟 Credits & Acknowledgments
This project is a labor of love dedicated to giving old hardware a new purpose.

Development: 100% AI-generated. As a "non-developer", I directed the AI to write every line of code, handle logic, and fix bugs to bring my ideas to life.
Philosophy: Sharing this "AI-authored" experiment because if it solved a streaming problem for me, it might be the foundation you were looking for.
