# \ud83d\udce6 Frida_install.ps1

PowerShell automation script for installing Frida on Windows and pushing Frida server to a connected Android device via ADB.

---

## \u2699\ufe0f Features

- Auto-detects architecture and downloads appropriate Frida server
- Allows install, update, or specific version selection for both client and server
- Handles previously installed versions
- Extracts `.xz` files using 7-Zip
- Pushes `frida-server` to `/data/local/tmp/` on the Android device
- Makes server executable and launches it via `adb shell`
- Modular, well-commented code structure

---

## \ud83d\ude80 How to Use

### 1. Clone the Repo
```powershell
git clone https://github.com/7absec/Frida-Installer.git
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

## \ud83d\uddd3 Requirements

- PowerShell (Windows)
- ADB (Android Debug Bridge) in PATH
- Python 3 and pip
- 7-Zip installed and in PATH

Ensure USB debugging is enabled on your Android device and it's connected.

---

## \ud83d\udd27 Troubleshooting

- \u274c *\u201cCannot bind to 127.0.0.1:27042\u201d* \u2014 likely the Frida server is already running. Kill the process or use `Portfrida.bat`.
- \u274c *\u201cPermission denied\u201d* \u2014 check device root access and SELinux status.

---

## \ud83d\udd00 Restarting Frida Server (Portfrida.bat)

Use this helper script if the server crashes or port is stuck:
```bat
.\CustomFScripts\Portfrida.bat
```
It will:
- Check if port 27042 is in use
- Kill the process if necessary
- Restart the appropriate `frida-server-*` binary

---

## \ud83d\udee1\ufe0f Install Burp Suite CA Certificate on Android (Pushcrt.py)

To capture and inspect HTTPS traffic from the Android device using [Burp Suite](https://portswigger.net/burp), you need to install its **CA certificate** into the Android system certificate store.

> \u26a0\ufe0f This step requires root access on the Android device.

You can find the script here: [Pushcrt.py GitHub Repository](https://github.com/7absec/Pushcrt)

---

### \u2705 How Pushcrt.py Works

`Pushcrt.py` automates the following:

1. Extracts Burp's certificate (`cacert.der` or similar)
2. Converts it to Android-compatible format (`.0` hashed name)
3. Pushes it to `/system/etc/security/cacerts/` using `adb root` and `remount`
4. Sets correct permissions (`644`)
5. Suggests a reboot

---

### \ud83e\uddea Usage

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

### \ud83d\udccb Requirements

- `adb` (with root access)
- Python 3.x
- `openssl` in PATH
- Device should have `/system` writable (use `adb remount` or Magisk)

---

### \ud83d\udccc Example Output
```bash
[*] Certificate hash: 9a5ba575.0
[*] Pushing cert to /system/etc/security/cacerts/...
[*] Setting permissions...
[\u2713] Done.
```

---

### \u26a0\ufe0f Note

- Android 7+ uses **certificate pinning**, which may require **Frida hooks** to bypass in many apps.
- This only works for **system-level apps** to trust Burp. For user apps with pinned certs, refer to Frida TLS unpinning scripts.

---

### \ud83d\udcc1 Bonus: Combine with Frida

You can chain this with `Frida_install.ps1` in a single automation pipeline:
```bash
.\Frida_install.ps1
python Pushcrt.py -i cacert.der
```

---

## \ud83d\udcdc License
MIT
