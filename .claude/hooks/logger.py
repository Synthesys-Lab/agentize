import os
import datetime

def logger(sid, msg):
    if os.getenv('HANDSOFF_DEBUG', '0').lower() in ['0', 'false', 'off', 'disable']:
        return
    os.makedirs('.tmp', exist_ok=True)
    with open('.tmp/hook-debug.log', 'a') as log_file:
        time = datetime.datetime.now().isoformat()
        log_file.write(f"[{time}] [{sid}] {msg}\n")