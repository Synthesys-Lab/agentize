"""Shared logging helper for the server module."""

import os
import sys
from datetime import datetime


def _log(msg: str, level: str = "INFO") -> None:
    """Log with timestamp and source location.

    Args:
        msg: Message to log
        level: Log level (INFO or ERROR)
    """
    frame = sys._getframe(1)
    filename = os.path.basename(frame.f_code.co_filename)
    lineno = frame.f_lineno
    func = frame.f_code.co_name
    timestamp = datetime.now().strftime("%y-%m-%d-%H:%M:%S")

    output = f"[{timestamp}] [{level}] [{filename}:{lineno}:{func}] {msg}"
    print(output, file=sys.stderr if level == "ERROR" else sys.stdout)
