#!/usr/bin/env python
"""Django's command-line utility for administrative tasks."""
import os
import sys


def main():
    """Run administrative tasks."""
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'lifelink.settings')
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        base_dir = os.path.dirname(os.path.abspath(__file__))
        candidates = [
            os.path.join(base_dir, 'venv', 'Scripts', 'python.exe'),
            os.path.join(base_dir, '..', 'lifelink-backend', 'venv', 'Scripts', 'python.exe'),
            os.path.join(base_dir, '..', '.venv', 'Scripts', 'python.exe'),
            os.path.join(base_dir, 'venv', 'bin', 'python'),
            os.path.join(base_dir, '..', 'lifelink-backend', 'venv', 'bin', 'python'),
            os.path.join(base_dir, '..', '.venv', 'bin', 'python'),
        ]
        target_py = next((p for p in candidates if os.path.isfile(p)), None)
        if target_py and os.path.abspath(sys.executable) != os.path.abspath(target_py):
            import subprocess
            sys.exit(subprocess.call([target_py] + sys.argv))
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed and "
            "available on your PYTHONPATH environment variable? Did you "
            "forget to activate a virtual environment?"
        ) from exc
    execute_from_command_line(sys.argv)


if __name__ == '__main__':
    main()
