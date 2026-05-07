import tkinter as tk
from tkinter import simpledialog, messagebox
import json
import os
import sys
import platform
import time
import logging
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, HTTPServer
from datetime import datetime

# ─────────────────────────────────────────
#  PATHS — PyInstaller + normal mode safe
# ─────────────────────────────────────────
def resource_path(filename):
    if hasattr(sys, '_MEIPASS'):
        return os.path.join(sys._MEIPASS, filename)
    return os.path.join(os.path.abspath("."), filename)

def writable_path(filename):
    if getattr(sys, 'frozen', False):
        return os.path.join(os.path.dirname(sys.executable), filename)
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), filename)

CONFIG_FILE = writable_path("config.json")
STATE_FILE  = writable_path("state.json")
LOG_FILE    = writable_path("attempts.log")

# ─────────────────────────────────────────
#  LOGGING
# ─────────────────────────────────────────
logging.basicConfig(
    filename=LOG_FILE,
    level=logging.INFO,
    format="%(asctime)s - %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

# ─────────────────────────────────────────
#  CONFIG (minimal for free version)
# ─────────────────────────────────────────
DEFAULT_CONFIG = {
    "pin": "1234",
    "max_attempts": 3,
    "cooldown_seconds": 1800,
}

def load_config():
    if not os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, "w") as f:
            json.dump(DEFAULT_CONFIG, f, indent=2)
        return DEFAULT_CONFIG.copy()
    with open(CONFIG_FILE, "r") as f:
        cfg = json.load(f)
    for k, v in DEFAULT_CONFIG.items():
        cfg.setdefault(k, v)
    return cfg

config = load_config()

# ─────────────────────────────────────────
#  STATE
# ─────────────────────────────────────────
def load_state():
    if not os.path.exists(STATE_FILE):
        return {"count": 0, "last_time": 0, "total": 0}
    with open(STATE_FILE, "r") as f:
        return json.load(f)

def save_state(s):
    with open(STATE_FILE, "w") as f:
        json.dump(s, f)

state = load_state()

# ─────────────────────────────────────────
#  SYSTEM LOCK
# ─────────────────────────────────────────
def lock_system():
    os_name = platform.system()
    logging.info("System lock triggered")
    if os_name == "Windows":
        os.system("rundll32.exe user32.dll,LockWorkStation")
    elif os_name == "Linux":
        os.system("loginctl lock-session")
    elif os_name == "Darwin":
        os.system('osascript -e \'tell application "System Events" to keystroke "q" using {command down, control down, option down}\'')

# ─────────────────────────────────────────
#  REGISTER ATTEMPT
# ─────────────────────────────────────────
def register_attempt():
    global state
    now = time.time()

    if now - state["last_time"] > config["cooldown_seconds"]:
        state["count"] = 0

    state["count"]  += 1
    state["total"]  += 1
    state["last_time"] = now
    save_state(state)

    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    logging.info(f"Incognito attempt #{state['count']} (total: {state['total']})")

    counter_label.config(text=str(state["count"]))
    total_label.config(text=f"Total all-time: {state['total']}")
    last_label.config(text=f"Last: {ts}")

    if state["count"] >= config["max_attempts"]:
        status_label.config(text="⚠️ Limit reached! Locking...", fg="#e53935")
        root.after(1500, lock_system)
    else:
        remaining = config["max_attempts"] - state["count"]
        status_label.config(
            text=f"⚠️ Attempt logged! {remaining} left before lock.",
            fg="#f57c00"
        )

    # Show upgrade nudge every 3 attempts
    if state["total"] % 3 == 0:
        root.after(2000, show_upgrade_nudge)

# ─────────────────────────────────────────
#  HTTP SERVER
# ─────────────────────────────────────────
class IncognitoHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.path == "/incognito":
            root.after(0, register_attempt)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")

    def log_message(self, format, *args):
        pass

def start_server():
    server = HTTPServer(("127.0.0.1", 8765), IncognitoHandler)
    server.serve_forever()

# ─────────────────────────────────────────
#  PIN PROTECTION
# ─────────────────────────────────────────
def prompt_pin(action_label="proceed"):
    pin = simpledialog.askstring(
        "PIN Required",
        f"Enter your parent PIN to {action_label}:",
        show="*",
        parent=root
    )
    return pin == config["pin"]

def on_close():
    if prompt_pin("close Incognito Guard"):
        logging.info("App closed by parent (PIN verified)")
        if tray_icon:
            tray_icon.stop()
        root.destroy()
    else:
        messagebox.showerror("Access Denied", "Incorrect PIN.")

def hide_window():
    root.withdraw()

# ─────────────────────────────────────────
#  UPGRADE NUDGE
# ─────────────────────────────────────────
def show_upgrade_nudge():
    win = tk.Toplevel(root)
    win.title("Get Email Alerts")
    win.geometry("360x220")
    win.resizable(False, False)
    win.configure(bg="#1a1a2e")
    win.lift()

    hdr = tk.Frame(win, bg="#e53935", pady=10)
    hdr.pack(fill="x")
    tk.Label(hdr, text="📧 Did you know?", font=("Arial", 13, "bold"),
             bg="#e53935", fg="white").pack()

    tk.Label(win,
             text=f"Your child has tried incognito {state['total']} times.\n"
                  f"Upgrade to Pro and get an instant email\n"
                  f"every time it happens — wherever you are.",
             font=("Arial", 10), bg="#1a1a2e", fg="#e8e8f0",
             justify="center").pack(pady=16)

    tk.Button(win, text="⭐ Get Pro — $19.99",
              command=lambda: [win.destroy(),
                               webbrowser.open("https://incognitoguard.lemonsqueezy.com/checkout/buy/b7351fda-e079-400f-84c3-180ef346ccd7")],
              bg="#e53935", fg="white", font=("Arial", 11, "bold"),
              padx=12, pady=6, relief="flat").pack(pady=4)

    tk.Button(win, text="Maybe later", command=win.destroy,
              bg="#37474f", fg="white", relief="flat",
              padx=10, pady=4).pack()

# ─────────────────────────────────────────
#  TRAY + UI
# ─────────────────────────────────────────
root = tk.Tk()
root.title("Incognito Guard Free")
root.geometry("340x400")
root.resizable(False, False)
root.configure(bg="#1a1a2e")

root.withdraw()  # start hidden in tray

tray_icon = None

def setup_tray():
    global tray_icon
    try:
        import pystray
        from PIL import Image as PILImage
        try:
            img = PILImage.open(resource_path("icon48.png")).resize((64, 64))
        except Exception:
            img = PILImage.new("RGB", (64, 64), color=(255, 62, 94))

        menu = pystray.Menu(
            pystray.MenuItem("Open Incognito Guard", lambda: root.after(0, root.deiconify), default=True),
            pystray.MenuItem("Get Pro", lambda: webbrowser.open("https://incognitoguard.lemonsqueezy.com/checkout/buy/b7351fda-e079-400f-84c3-180ef346ccd7")),
            pystray.Menu.SEPARATOR,
            pystray.MenuItem("Quit (PIN required)", lambda: root.after(0, on_close)),
        )
        tray_icon = pystray.Icon("IncognitoGuard", img, "Incognito Guard — Monitoring", menu)
        threading.Thread(target=tray_icon.run, daemon=True).start()
    except ImportError:
        root.deiconify()

setup_tray()

# Header
header = tk.Frame(root, bg="#e53935", pady=12)
header.pack(fill="x")
tk.Label(header, text="🛡 Incognito Guard", font=("Arial", 15, "bold"),
         bg="#e53935", fg="white").pack()
tk.Label(header, text="Free Version — Parental Control Monitor", font=("Arial", 9),
         bg="#e53935", fg="#ffcdd2").pack()

# Body
body = tk.Frame(root, bg="#1a1a2e", pady=10)
body.pack(fill="both", expand=True)

tk.Label(body, text="Attempts This Session",
         font=("Arial", 10), bg="#1a1a2e", fg="#aaa").pack(pady=(10, 0))

counter_label = tk.Label(body, text=str(state["count"]),
                          font=("Arial", 48, "bold"), bg="#1a1a2e", fg="#ef5350")
counter_label.pack()

total_label = tk.Label(body, text=f"Total all-time: {state['total']}",
                        font=("Arial", 9), bg="#1a1a2e", fg="#777")
total_label.pack()

last_ts = datetime.fromtimestamp(state["last_time"]).strftime("%Y-%m-%d %H:%M:%S") \
    if state["last_time"] else "Never"
last_label = tk.Label(body, text=f"Last: {last_ts}",
                       font=("Arial", 9), bg="#1a1a2e", fg="#777")
last_label.pack(pady=(2, 4))

status_label = tk.Label(body, text="✅ Monitoring...",
                          font=("Arial", 10), bg="#1a1a2e", fg="#66bb6a")
status_label.pack()

# Upgrade banner
upgrade_frame = tk.Frame(body, bg="#2a1a1a", pady=8, padx=12)
upgrade_frame.pack(fill="x", padx=12, pady=8)
tk.Label(upgrade_frame, text="📧 Want email alerts when this happens?",
         font=("Arial", 9), bg="#2a1a1a", fg="#ffcdd2").pack()
tk.Button(upgrade_frame, text="⭐ Upgrade to Pro — $19.99",
          command=lambda: webbrowser.open("https://incognitoguard.lemonsqueezy.com/checkout/buy/b7351fda-e079-400f-84c3-180ef346ccd7"),
          bg="#e53935", fg="white", font=("Arial", 9, "bold"),
          relief="flat", padx=8, pady=4).pack(pady=4)

# Footer
footer = tk.Frame(root, bg="#1a1a2e", pady=8)
footer.pack(fill="x")
tk.Button(footer, text="Hide to Tray", command=hide_window,
          bg="#37474f", fg="white", relief="flat", padx=12, pady=5).pack(side="right", padx=12)

root.protocol("WM_DELETE_WINDOW", hide_window)

threading.Thread(target=start_server, daemon=True).start()

root.mainloop()
