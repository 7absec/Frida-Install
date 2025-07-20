# 📦 Frida_install.ps1

PowerShell automation script for installing Frida on Windows and pushing Frida server to a connected Android device via ADB.

---

## ⚙️ Features

- Auto-detects architecture and downloads appropriate Frida server
- Allows install, update, or specific version selection
- Handles previously installed versions
- Extracts `.xz` files using 7-Zip
- Pushes `frida-server` to `/data/local/tmp/` on the Android device
- Makes server executable and launches it via `adb shell`
- Offers modular, well-commented code structure

---

## 🚀 How to Use

### 1. Clone the Repo
```powershell
git clone https://github.com/yourname/Frida-Installer.git
cd Frida-Installer
```

### 2. Run the Script
```powershell
.\Frida_install.ps1
```

Choose from the menu:

```
[1] Install Frida
[2] Update Frida to latest
[3] Install specific version
```

You will be prompted to:
- Select Frida **client** version
- Select Frida **server** version

It downloads, renames (with version), pushes and starts the server.

---

## 📥 Requirements

- PowerShell (Windows)
- ADB (Android Debug Bridge) in PATH
- Python 3 and pip
- 7-Zip installed and in PATH

Ensure USB debugging is enabled on your Android device and it's connected.

---

## 🔧 Troubleshooting

- ❌ *“Cannot bind to 127.0.0.1:27042”* — likely the Frida server is already running. Kill the process or use `Portfrida.bat`.
- ❌ *“Permission denied”* — check device root access and SELinux status.

---

## 🔁 Restarting Frida Server (Portfrida.bat)

Use this helper script if the server crashes or port is stuck:

```bat
.\CustomFScripts\Portfrida.bat
```

It will:
- Check if port 27042 is in use
- Kill the process if necessary
- Restart the appropriate `frida-server-*` binary

---

## 🛡️ Install Burp Suite CA Certificate on Android (Pushcrt.py)

To capture and inspect HTTPS traffic from the Android device using [Burp Suite](https://portswigger.net/burp), you need to install its **CA certificate** into the Android system certificate store.

This step requires root access on the Android device.

---

### ✅ How Pushcrt.py Works

`Pushcrt.py` automates the following:

1. Extracts Burp's certificate (`cacert.der` or similar)
2. Converts it to Android-compatible format (`.0` hashed name)
3. Pushes it to `/system/etc/security/cacerts/` using `adb root` and `remount`
4. Sets correct permissions (`644`)
5. Reboots device (or prompts you to do so)

---

### 🧪 Usage

1. Export Burp Suite's certificate in **DER format**:
   - Burp > Proxy > Options > *Import / Export CA Cert* > Export as DER

2. Run the Python script:

```bash
python Pushcrt.py -i cacert.der
```

- `-i`: Path to the input DER certificate

3. The script will:
   - Convert it using `openssl`
   - Compute certificate hash
   - Push and set permissions
   - Suggest a reboot if required

---

### 📋 Requirements

- `adb` (with root access)
- Python 3.x
- `openssl` in PATH
- Device should have `/system` writable (use `adb remount` or Magisk)

---

### 📎 Example Output

```
[*] Certificate hash: 9a5ba575.0
[*] Pushing cert to /system/etc/security/cacerts/...
[*] Setting permissions...
[✓] Done. Reboot your device to apply the changes.
```

---

### ⚠️ Note

- Android 7+ uses **certificate pinning**, which may require **Frida hooks** to bypass in many apps.
- This only works for **system-level apps** to trust Burp. For user apps with pinned certs, refer to Frida TLS unpinning scripts.

---

### 📁 Bonus: Combine with Frida

You can chain this with `Frida_install.ps1` in a single automation pipeline:

```bash
.\Frida_install.ps1
python Pushcrt.py -i cacert.der
```

---

## 📜 License
MIT

---

## 👨‍💻 Credits
- @yourusername (Frida automation)
- Community contributors
