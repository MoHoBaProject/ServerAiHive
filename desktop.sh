#!/usr/bin/env bash
# Virtual desktop for first logins: Xvfb :99 + openbox + x11vnc (localhost only) + noVNC on port 6080.
# Usage: bash desktop.sh start | stop
cd "$(dirname "$0")"
mkdir -p data
PASSFILE="data/vnc.pass"
RES="1280x800x24"

stop() {
  pkill -f "websockify.*6080" 2>/dev/null
  pkill -x x11vnc 2>/dev/null
  pkill -x openbox 2>/dev/null
  pkill -f "Xvfb :99" 2>/dev/null
  echo "STOPPED"
}

start() {
  if [ ! -f "$PASSFILE" ]; then
    echo "Choose a VNC password (only the first 8 characters count):"
    read -r -s PW
    echo
    x11vnc -storepasswd "$PW" "$PASSFILE" >/dev/null 2>&1
    chmod 600 "$PASSFILE"
  fi
  pgrep -f "Xvfb :99" >/dev/null || (nohup Xvfb :99 -screen 0 "$RES" >data/xvfb.log 2>&1 &)
  sleep 1
  pgrep -x openbox >/dev/null || (DISPLAY=:99 nohup openbox >data/openbox.log 2>&1 &)
  pgrep -x x11vnc >/dev/null || (nohup x11vnc -display :99 -rfbauth "$PASSFILE" -localhost -forever -shared -rfbport 5900 >data/x11vnc.log 2>&1 &)
  pgrep -f "websockify.*6080" >/dev/null || (nohup websockify --web /usr/share/novnc 6080 localhost:5900 >data/novnc.log 2>&1 &)
  sleep 2
  IP=$(hostname -I | awk '{print $1}')
  echo "READY: open  http://$IP:6080/vnc.html  on the phone (same Wi-Fi) and press Connect"
}

case "$1" in
  start) start ;;
  stop) stop ;;
  *) echo "usage: bash desktop.sh start | stop" ;;
esac
