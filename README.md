# 🦅 Phoenix — Give it life again.

> **Turn an obsolete Android device into a modern productivity tool.**

**Phoenix** is a low-latency screen streaming system that turns an old Android tablet, starting from **Android 4.4 KitKat**, into a secondary display and input interface for a Mac.

The macOS server captures the screen, encodes it using **H.264**, and streams the video to the Android client over **UDP**. The client can then display the Mac's screen on otherwise obsolete hardware.

The project was built primarily as a personal experiment and proof of concept, with a focus on making old hardware useful again.

---

## 🛑 Project Status

**Status: Accomplished for my needs**
**Maintenance: None planned**

Phoenix has reached the goal I originally set for it: **low-latency screen streaming from a Mac to an old Android tablet**.

The streaming system has been tested successfully on an **MTK/MediaTek-based device**.

This repository is therefore best considered a **finished personal project / experimental foundation**, rather than an actively maintained application.

### Current limitations

* 🖥️ **Screen streaming:** Working
* ⚡ **Low-latency H.264 streaming:** Working
* 📡 **UDP transport:** Working
* 🔎 **mDNS discovery:** Implemented
* 👆 **Touch input:** Incomplete
* 🔧 **Active development:** No

The touch input implementation currently consists only of a basic skeleton and is **not functional**. Implementing proper touch support would require additional development.

I do not currently plan to continue development, fix issues, or implement the missing input functionality.

### 💡 How I use it

I use Phoenix as a **third monitor**.

On macOS, I create a virtual display using [BetterDisplay](https://github.com/waydabber/BetterDisplay), then stream that display to the Android tablet.

This makes it possible to turn an old tablet into a surprisingly useful extra screen without needing modern hardware.

---

## ⚙️ Configuration

Phoenix was originally built for personal use, so some configuration is still fairly manual.

### 1. Configure the macOS server

Open:

```text
PhoenixServer/Sources/Managers/ServerManager.swift
```

Find the hardcoded destination IP address and replace it with the **local IP address of your Android tablet**.

You can find the tablet's IP address in its Wi-Fi/network settings.

### 2. Configure the Android client

Launch Phoenix on the Android tablet.

The client attempts to discover the Mac automatically using **mDNS**. If discovery does not work, enter the **Mac's local IP address manually**.

Both devices must be connected to the same local network.

---

## 🚀 Getting Started

### A. macOS Server — PhoenixServer

#### Requirements

* macOS
* Xcode 13 or later
* A Mac capable of screen capture
* Local network connection to the Android device

#### Permissions

macOS needs permission to capture and interact with the screen.

Go to:

**System Settings → Privacy & Security**

and grant the application the required:

* **Screen Recording**
* **Accessibility**

permissions.

#### Running the server

1. Open `PhoenixServer.xcodeproj` in Xcode.
2. Build the project.
3. Launch the application.
4. Press **START PHOENIX**.
5. Start the Android client.

---

### B. Android Client — PhoenixClient

#### Requirements

* Android Studio
* Android 4.4 KitKat or newer
* **API 19+**
* Wi-Fi connection to the same local network as the Mac

#### Running the client

1. Open the `PhoenixClient` project in Android Studio.
2. Build and install the application on the tablet.
3. Launch Phoenix.
4. Let the app attempt mDNS discovery.
5. If discovery fails, enter the Mac's local IP address manually.
6. Once connected, the Mac's screen should appear on the tablet.

---

## 🛠️ Troubleshooting

### The Mac cannot find the tablet

Make sure:

* Both devices are connected to the **same Wi-Fi network**.
* The tablet's local IP is correct.
* The macOS server is running.
* The required macOS permissions have been granted.

### The tablet cannot discover the Mac

mDNS discovery can fail depending on the network configuration.

Try entering the Mac's local IP address manually.

Also check that the router does not isolate wireless clients from each other.

### The stream is laggy or freezes

Phoenix uses **UDP** because low latency is more important here than guaranteed packet delivery.

On a congested or unreliable Wi-Fi network, this can result in:

* dropped frames
* visual artifacts
* freezing
* increased latency

In other words, sometimes the ancient tablet is innocent and the Wi-Fi router is the actual criminal.

---

## 🧠 Why Phoenix?

The original idea was simple:

**What if an old Android tablet could become useful again?**

Rather than letting obsolete hardware sit in a drawer, Phoenix gives it a very specific job: becoming an inexpensive secondary display for a Mac.

It is not intended to compete with commercial remote-desktop or display-extension solutions. It is a small, experimental project built around one particular goal.

And for that goal, it works.

---

## 🌟 Credits & Philosophy

Phoenix is a personal experiment in **repurposing obsolete hardware**.

### Development

The entire project was **AI-generated**.

I am not a developer. I directed AI tools to design the architecture, write the code, implement the networking and streaming logic, and troubleshoot the project until it reached the state described above.

That is also part of the reason why the code may not follow conventional software-engineering practices.

This repository is therefore shared less as an example of perfect code and more as an **AI-assisted experiment that actually became a working project**.

### Philosophy

Old hardware does not necessarily have to become e-waste just because its original software ecosystem has moved on.

Sometimes all it needs is a completely unreasonable amount of networking code to become a third monitor. 🦅

If Phoenix is useful to you, feel free to build on it, modify it, or use it as a starting point for something better.

---

## 📄 License

See the repository's license file for the applicable license terms.
