
# 📘 System Monitor - Project Documentation

## 1\. Project Overview

**System Monitor** is a cross-platform, real-time hardware monitoring dashboard. It replicates the visual style of the **Windows 11 Task Manager** but runs as a web application.

It is designed to be **hardware-agnostic**, meaning it works equally well on a Windows Gaming PC, a Linux Server, or a MacBook, automatically adapting the interface to show the relevant hardware (e.g., detecting multiple GPUs or different Disk types).

-----

## 2\. Architecture & How It Works

This project uses a **Split-Architecture** design to bypass the limitations of Docker containers.

### The Problem

Docker containers are isolated environments. A Node.js server running inside Docker cannot easily "see" the host computer's CPU temperature, specific GPU model, or exact process count. It only sees the virtualized resources assigned to the container.

### The Solution: The "Spy File" Method

We split the application into two distinct parts that communicate via a **Shared Volume**.

```text
[ HOST MACHINE (Windows/Linux/Mac) ]       [ DOCKER CONTAINER ]
       |                                           |
       |  1. Spy Script (spy.ps1/sh)               |  3. Node.js Server
       |     Gather Hardware Stats                 |     Read JSON File
       |             |                             |           |
       |             v                             |           v
       |    [ SHARED FOLDER: ./data ] <--------> [ VOLUME: /app/data ]
       |             |
       |     Writes: stats.json
       |
```

### 3\. The Workflow

1.  **Data Collection (The Spy):**
      * A native script runs directly on your OS (PowerShell for Windows, Bash for Linux/macOS).
      * It queries the OS every second using low-level commands (e.g., `Get-WmiObject`, `nvidia-smi`, `top`, `sysctl`).
      * It formats this data into a clean JSON structure.
2.  **Data Transmission (The Handshake):**
      * The script writes the JSON data to `data/stats.json`.
      * It also appends a historical record to `data/history.csv` for long-term logging.
3.  **Data Visualization (The Dashboard):**
      * The Docker container runs a Node.js Express server.
      * The server's API (`/api/stats`) reads the `stats.json` file from the shared volume.
      * The frontend (`script.js`) polls this API every 1000ms and updates the DOM and Canvas charts.

-----

## 4\. Technical Details

### 📂 File Structure Breakdown

| File | Purpose |
| :--- | :--- |
| **`spy.ps1`** | **Windows Data Collector.** Uses WMI and Performance Counters to grab deep system stats (Temp, Speed, Threads). |
| **`spy.sh`** | **Linux Data Collector.** Parses `top`, `free`, and `df` outputs. Uses `nvidia-smi` if available. |
| **`spy_mac.sh`** | **macOS Data Collector.** Uses `sysctl` and `vm_stat` to gather Apple-specific hardware metrics. |
| **`server.js`** | **The Backend.** A lightweight Express server. It handles `CORS` and serves the static frontend. |
| **`public/script.js`** | **The Frontend Logic.** Handles the 60-second polling history, draws the HTML Canvas graphs, and manages the Sidebar navigation. |
| **`public/style.css`** | **The Styling.** Contains the CSS variables for the Dark Mode "Mica" theme, Grid Layouts, and Flexbox structures. |
| **`docker-compose.yml`** | **The Glue.** Defines how the Docker container should run and **crucially maps the `./data` folder** so both sides can see it. |

### 🔍 Key Features

#### 1\. Hardware Auto-Detection

The application does not have hardcoded limits.

  * **Dynamic Lists:** The frontend accepts arrays for Disks and GPUs. If you plug in a USB drive or add a second Graphics Card, the UI automatically generates a new card and sidebar item for it.
  * **Driver Awareness:** It detects if a GPU is NVIDIA (using `nvidia-smi`) or Intel/AMD (using OS Counters) and switches retrieval methods automatically.

#### 2\. Robust Error Handling

  * **Clamp Logic:** All percentages are passed through a clamp function (0-100) to prevent sensor glitches from breaking graphs.
  * **Safe Reads:** The scripts use atomic write operations (writing to `.tmp` then moving to `.json`) to prevent the web server from reading a "half-written" file, which would cause crashing.

#### 3\. Modern Visualization

  * **Canvas Graphs:** Instead of simple CSS width bars, the project uses HTML5 Canvas to draw historical line charts with gradient fills (`ctx.createLinearGradient`).
  * **Responsive Grid:** The "Stats Grid" at the bottom of the dashboard uses CSS Grid (`repeat(auto-fit, minmax(...))`) to perfectly reflow data points based on screen size.

-----

## 5\. Limitations & Permissions

  * **CPU Temperature:**
      * **Windows:** Requires the Spy Script to be run as **Administrator** to access the WMI Thermal Zone.
      * **macOS:** Standard scripts cannot read Apple Silicon thermal sensors (requires sudo/kernel extensions).
  * **GPU Usage:**
      * **Windows:** Highly accurate for NVIDIA. Good estimation for Intel/AMD via "3D Engine" counters.
      * **Linux/macOS:** Detailed GPU usage is often driver-locked or requires root access, so generic usage might default to 0% if `nvidia-smi` is absent.

-----

## 6\. Historical Logging

Data is saved to `data/history.csv` in the following format:
`Timestamp, CPU%, RAM%, Disk%, MaxGPU%`

You can import this file into Excel, Google Sheets, or PowerBI to analyze system performance over hours or days.


