"""Public help pages must work without granting access to account data."""

import pytest
from fastapi.testclient import TestClient

from omni_memory.app import create_app
from omni_memory.service import MemoryService


@pytest.fixture
def client(tmp_path):
    # No model, Apple credentials, or personal records are needed for these pages.
    service = MemoryService(tmp_path / "memory.db", secret="synthetic-public-route-tests-52948-XYza")
    return TestClient(create_app(service, managed_accounts=False))


@pytest.mark.parametrize("path", ["/support", "/privacy"])
def test_public_help_pages_and_styles_load_without_authentication(client, path):
    response = client.get(path)
    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/html")
    assert '<html lang="en">' in response.text
    assert 'href="/public/style.css"' in response.text
    assert 'href="mailto:seatrial.ai@gmail.com"' in response.text
    assert "Xiaobo Zhang" in response.text
    assert "<script" not in response.text
    assert response.headers["x-content-type-options"] == "nosniff"
    assert response.headers["referrer-policy"] == "no-referrer"
    assert "default-src 'none'" in response.headers["content-security-policy"]
    stylesheet = client.get("/public/style.css")
    assert stylesheet.status_code == 200
    assert stylesheet.headers["content-type"].startswith("text/css")


def test_public_files_do_not_expose_private_routes_or_arbitrary_files(client):
    assert client.get("/v1/memory").status_code == 401
    assert client.get("/v1/account/export").status_code == 401
    assert client.get("/public/app.py").status_code == 404
    assert client.get("/public/privacy.html").status_code == 404
    assert client.post("/support", json={"message": "not a public inbox"}).status_code == 405
