"""Offline checks for the Web chatbot integration, without calling Noupe."""

from pathlib import Path
import shutil
import subprocess

import pytest


ROOT = Path(__file__).resolve().parents[2]
EMBED = "https://www.noupe.com/embed/01a1485505b070008c24740628322f437e85.js"


def test_single_chatbot_embed_loads_close_guard_first():
    html = (ROOT / "web" / "index.html").read_text(encoding="utf-8")
    assert html.count(EMBED) == 1
    assert html.count('src="chatbot-close-guard.js"') == 1
    assert html.index('src="chatbot-close-guard.js"') < html.index(EMBED)


def test_chatbot_close_regressions():
    node = shutil.which("node")
    if node is None:
        pytest.skip("Optional JS contract checks require Node; no network/install used")
    result = subprocess.run(
        [node, "--test", "test/chatbot_close_guard.test.cjs"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
