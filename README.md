<p align="center">
  <img src="screenshots/logo.png" alt="Bulkhead Logo" width="380" />
</p>

<h1 align="center">🚀 Bulkhead — Flutter Docker Manager for Linux 🐳</h1>

<p align="center">
  <a href="https://flutter.dev"><img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter" alt="Flutter" /></a>
  <a href="https://archlinux.org"><img src="https://img.shields.io/badge/Platform-Linux%20Desktop-FCC624?logo=linux" alt="Platform" /></a>
  <a href="https://www.docker.com"><img src="https://img.shields.io/badge/Docker-Native%20Unix%20Socket-2496ED?logo=docker" alt="Docker" /></a>
  <a href="https://riverpod.dev"><img src="https://img.shields.io/badge/Riverpod-2.x-3C873A" alt="Riverpod" /></a>
  <a href="https://github.com/ahmadteeb/Bulkhead/releases"><img src="https://img.shields.io/github/v/release/ahmadteeb/Bulkhead?color=FF6F00&logo=github" alt="GitHub Release" /></a>
</p>

**Bulkhead** is a state-of-the-art desktop Linux Docker Engine manager built with **Flutter Desktop**. It provides high-performance, real-time container administration, multi-container Compose stack management, local image registry inspection, persistent volume control, virtual network topology visualization, embedded interactive terminal emulation, container volume file browsing with upload/download capabilities, and single-click system storage optimization.

---

## ✨ Key Highlights

- ⚡ **100% Real-Time Event-Driven (Zero Polling Overhead)**: Listens continuously to the Docker Engine socket stream (`/events`) to instantly refresh containers, images, volumes, networks, and compose stacks without background timers or screen flickering.
- 🔌 **Direct Native Unix Socket Connection**: Connects directly to `/var/run/docker.sock` over Unix domain sockets using HTTP/1.1 chunked response demuxing, bypassing external daemon proxy layers.
- 💻 **Embedded Interactive Container Terminal (`xterm`)**: Native terminal emulator with PTY allocation (`script` wrapper), shell selector (`/bin/bash`, `/bin/sh`, `zsh`, `ash`), ANSI escape code stripping, normalized `\r\n` line endings, right-click context menu (**Copy Output**, **Paste Stdin**), and external terminal launcher.
- 📁 **Container Volume File Browser & File Manager**: Explore container volumes, root file systems, and bind mounts. Features **Back (`<`)** & **Forward (`>`)** directory history navigation, **Upload File** (`docker cp`), and **Download File/Folder** to host system folders. Accessible from container details and the Volumes page.
- 🚀 **Full Docker Compose CLI Integration**: Manage multi-container application stacks (`docker compose up -d`, `down`, `restart`, `down -v --remove-orphans`). Includes a Deploy Stack wizard with an inline `docker-compose.yml` editor.
- 📦 **Multi-Selection & Bulk Actions**: Select multiple containers, images, volumes, or networks with Select-All header checkboxes to perform batch operations (Start, Stop, Restart, Delete).
- 📜 **Dual-Mode Log Telemetry & Demuxing**: Real-time stdout/stderr log streaming supporting both TTY and non-TTY multiplexed stream frames with auto-scrolling and log text copying.
- 🏷️ **Unified Status Badge System**: Standardized status badge colors (`AppColors.success` green for all running stack & container states) and responsive sizing across all screens.
- 🧹 **1-Click Storage Optimization**: Dynamic progress bars calculated from `docker system df` metrics with a single-click **System Prune All** button to reclaim unused disk space.
- 🎨 **Modern Dark & Light Themes**: Dark mode interface designed according to `#111316` surface specifications, paired with crisp `Hanken Grotesk` headings and `JetBrains Mono` code telemetry.

---

## 🖼️ Feature Tour & Screenshots

### 📊 1. Dashboard Overview
Inspect real-time system metrics, active container slots, `docker system df` storage usage bars, 1-click **Prune System**, and live Docker Engine `/events` stream telemetry.

![Dashboard Overview](screenshots/dashboard.png)

---

### 📦 2. Containers Management
Monitor and filter container instances (All, Running, Stopped). Perform multi-selection bulk operations or click **Run Container** to deploy new containers with custom port bindings and environment variables.

![Containers Management](screenshots/containers.png)

---

### 💻 3. Embedded Interactive Terminal & Container Telemetry
Deep dive into container telemetry with stdout/stderr log streaming, **Embedded Exec Terminal** (`xterm` with TTY shell selection and right-click copy/paste), **Volume File Browser**, raw Docker inspect JSON view, environment variables, port mappings, and host volume mounts.

![Container Detail & Telemetry](screenshots/container_detail.png)

---

### 🚀 4. Docker Compose Stacks
Deploy and manage multi-container Compose applications. View service health, stream service terminal logs, edit `docker-compose.yml` directly, and perform full stack lifecycle controls (**Up**, **Down**, **Restart**, **Purge/Delete**).

![Compose Stacks Management](screenshots/compose.png)

---

### 🖼️ 5. Local Image Registry
Inspect locally stored Docker images, view repository tags and sizes, execute **Run Container from Image**, perform bulk image deletion, and use the real-time layer progress terminal in **Pull Image**.

![Image Registry](screenshots/images.png)

---

### 💾 6. Volume Storage Points & File Explorer
Manage persistent storage volumes, inspect host mountpoints and drivers, browse attached volume file systems with **Back/Forward** history and **Upload/Download** options, create new volumes, prune unused volume points, and perform multi-selection deletion.

![Volume Storage Points](screenshots/volumes.png)

---

### 🌐 7. Virtual Networks Topology
Visualize virtual bridge, host, overlay, and macvlan networks. Inspect subnets, gateways, attached container IDs, and create custom networks.

![Virtual Networks Topology](screenshots/networks.png)

---

### ⚙️ 8. System Settings & Connection Configuration
Configure local Docker Unix domain socket paths (`/var/run/docker.sock`), test socket permissions, and switch theme modes (**Dark**, **Light**, **System Default**).

![Settings Screen](screenshots/settings.png)

---

## 🛠️ Feature Matrix Summary

| Area | Feature & Capability |
|---|---|
| **Real-Time Engine Sync** | 100% event-driven sync via `/events` socket stream; zero polling timers. |
| **Containers** | List, filter, start, stop, restart, remove, multi-select bulk actions, run new container modal. |
| **Interactive Terminal** | `xterm: ^4.0.0` emulator, Linux PTY allocation (`script`), `/bin/bash`/`/bin/sh`/`zsh` shells, right-click context menu, clean ANSI escape filter, external terminal launcher. |
| **Volume File Manager** | Browse attached container volumes & host mountpoints, Back/Forward navigation stack, Upload host files (`docker cp`), Download files & directories (`docker cp`). |
| **Container Telemetry** | Dual-mode stdout/stderr live logs, raw Inspect JSON viewer, environment variable table, port mapping table. |
| **Compose Stacks** | List stacks, Up/Down/Restart/Delete, Deploy Stack wizard, inline YAML editor, service log stream, unified green status badges. |
| **Images** | Inspect tags/sizes, Pull Image modal with terminal progress, Run Container from Image, Prune unused images. |
| **Volumes** | List mountpoints, create volume modal, remove, multi-select delete, Prune unused volumes, integrated File Browser. |
| **Networks** | List network topology, driver selector (`bridge`, `host`, `overlay`, `macvlan`), subnet/gateway inspector. |
| **Storage Optimization** | Dynamic `docker system df` usage bars, 1-click **Prune System** (`docker system prune -a --volumes`). |

---

## ⚙️ Installation & Getting Started

### 📋 Prerequisites

- **OS**: Linux (Arch Linux, Ubuntu 22.04+, Debian, Fedora, Manjaro).
- **Docker Engine**: Installed & running locally (`/var/run/docker.sock`).
- **Permissions**: Current user must belong to the `docker` usergroup:
  ```bash
  sudo usermod -aG docker $USER
  newgrp docker
  ```

---

### 📦 Installation Options

Choose the installation method for your Linux distribution from [GitHub Releases](https://github.com/ahmadteeb/Bulkhead/releases):

#### 🌀 Ubuntu / Debian / Linux Mint / Pop!_OS (`.deb`)
Download `bulkhead_<version>_amd64.deb` and install via `apt`:
```bash
sudo apt update
sudo apt install ./bulkhead_1.0.0_amd64.deb
```

#### 🎩 Fedora / RHEL / CentOS / OpenSUSE (`.rpm`)
Download `bulkhead-<version>-1.x86_64.rpm` and install via `dnf` or `rpm`:
```bash
sudo dnf install ./bulkhead-1.0.0-1.x86_64.rpm
# or
sudo rpm -i ./bulkhead-1.0.0-1.x86_64.rpm
```

#### 🏹 Arch Linux / Manjaro / EndeavourOS (`yay` / `pacman`)
Install directly from the Arch User Repository (AUR):
```bash
yay -S bulkhead-bin
```

#### 📦 Portable Linux Zip Archive (`.zip`)
Download `bulkhead-linux-x64.zip`, extract, and run anywhere:
```bash
unzip bulkhead-linux-x64.zip -d ~/bulkhead
cd ~/bulkhead
./bulkhead
```

*(Optional Desktop Launcher for Portable ZIP)*:
```bash
mkdir -p ~/.local/share/applications
cat <<EOF > ~/.local/share/applications/bulkhead.desktop
[Desktop Entry]
Name=Bulkhead
Comment=Flutter Docker Manager for Linux
Exec=$HOME/bulkhead/bulkhead
Icon=$HOME/bulkhead/data/flutter_assets/assets/icon.png
Terminal=false
Type=Application
Categories=Development;System;
EOF
```

---

### 🚀 Building & Running from Source

```bash
# 1. Clone the repository
git clone https://github.com/ahmadteeb/Bulkhead.git
cd Bulkhead

# 2. Install Dependencies
flutter pub get

# 3. Run Static Analysis & Unit Tests
flutter analyze
flutter test

# 4. Run Desktop Application locally
flutter run -d linux

# 5. Build Release Linux Desktop Bundle
flutter build linux --release
```

---

## 🏗️ Technical Architecture

- **UI Framework**: Flutter Desktop (Linux X11/Wayland GTK runner).
- **State Management**: Riverpod 2.x (`StateNotifierProvider`, `StreamProvider`, `FutureProvider`).
- **Terminal Emulator**: `xterm: ^4.0.0` with Linux PTY pseudo-terminal allocation (`script -q -c "docker exec -it ..."`).
- **File Manager**: `file_picker` package paired with `docker cp` process execution.
- **Packaging Pipeline**: GitHub Actions automated `.deb` (Debian/Ubuntu), `.rpm` (Fedora/RHEL), `.zip` (Portable Linux), and AUR `PKGBUILD`.
- **Socket I/O**: Custom `DockerSocketConnection` implementing HTTP/1.1 over Unix Domain Sockets (`Socket.connect(InternetAddress('/var/run/docker.sock', InternetAddressType.unix), 0)`).
- **Stream Demuxing**: 8-byte multiplexing header demuxer parsing `stdout` (stream type `1`) and `stderr` (stream type `2`) from Docker container log streams.
- **Typography**: Google Fonts (`Hanken Grotesk` headings, `JetBrains Mono` telemetry).

---

## 📄 License

Distributed under the MIT License. See `LICENSE` for details.
