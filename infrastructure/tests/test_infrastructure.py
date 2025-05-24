# tests/test_infrastructure.py
import os
import sys
import subprocess
import time
import pytest
import shutil

# Ensure the project root is on PYTHONPATH so local packages can be imported
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

from config.config_loader import load_config
from orchestrator.orchestrator import Orchestrator

@pytest.fixture(scope="module")
def project_root():
    return os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))


def test_load_config(project_root):
    cfg = load_config(os.path.join(project_root, "config/examples/alice.yaml"))
    assert cfg.id == "alice"
    assert cfg.role == "alice"
    assert [n.id for n in cfg.neighbours] == ["server-1", "server-2", "server-3"]
    assert cfg.threshold == 3


def test_orchestrator_init(project_root):
    cfg = load_config(os.path.join(project_root, "config/examples/alice.yaml"))
    orch = Orchestrator(cfg)
    assert orch.node_id == "alice"
    assert orch.role == "alice"
    assert [n.id for n in orch.neighbours] == ["server-1", "server-2", "server-3"]
    assert orch.threshold == 3


def test_orchestrator_entry_point(project_root):
    env = os.environ.copy()
    existing = env.get("PYTHONPATH", "")
    env["PYTHONPATH"] = project_root + (os.pathsep + existing if existing else "")

    result = subprocess.run(
        [sys.executable,
         os.path.join(project_root, "orchestrator/orchestrator.py"),
         "-c", os.path.join(project_root, "config/examples/alice.yaml")],
        capture_output=True,
        text=True,
        cwd=project_root,
        env=env
    )
    assert result.returncode == 0
    output = (result.stdout or "") + (result.stderr or "")
    assert "INFO:orchestrator" in output


def test_docker_build_and_run(project_root):
    if not shutil.which("docker"):
        pytest.skip("Docker CLI not found, skipping Docker tests")
    sock = "/var/run/docker.sock"
    if os.path.exists(sock) and not os.access(sock, os.R_OK | os.W_OK):
        pytest.skip("No permission to access Docker socket, skipping Docker tests")

    build = subprocess.run(
        ["docker", "build", "-f",
         os.path.join(project_root, "orchestrator/Dockerfile"),
         "-t", "orch-test", project_root],
        capture_output=True,
        text=True,
    )
    assert build.returncode == 0, f"Docker build failed: {build.stderr}"

    run = subprocess.Popen(
        ["docker-compose", "up", "--build", "--abort-on-container-exit"],
        cwd=project_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )

    # Capture output until all services exit
    output_lines = []
    for line in run.stdout:
        output_lines.append(line)
    run.wait()
    full = "".join(output_lines)
    assert run.returncode == 0, f"End-to-end failed: {full}"
    # Verify Bob reconstructed dummy shares
    assert "Reconstructed shares: {'server-1': b'dummy', 'server-2': b'dummy', 'server-3': b'dummy'}" in full
