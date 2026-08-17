import psutil

for p in psutil.process_iter(['pid', 'name', 'cmdline', 'cwd']):
    if 'python' in p.info['name'].lower() and p.info['cmdline'] and 'run_server.py' in p.info['cmdline']:
        print(f"PID: {p.info['pid']}")
        print(f"CWD: {p.info['cwd']}")
        print(f"CMD: {p.info['cmdline']}")
