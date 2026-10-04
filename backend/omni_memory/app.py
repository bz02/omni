from __future__ import annotations

from pathlib import Path
import asyncio
from contextlib import asynccontextmanager, suppress

from fastapi import APIRouter, Depends, FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import FileResponse, JSONResponse, Response
from fastapi.routing import APIRoute
from pydantic import BaseModel, ConfigDict, Field
from typing import Optional

from .auth import verify_session
from .models import ChatRequest, MemoryCreate, MemoryUpdate, SettingsUpdate
from .service import MemoryService
from .sync import SnapshotDelete, SnapshotPut
from .dating import DatingService, ProfilePut, MessagePut, ReportPut, PhotoPut, PhotoDelete, HistoryQuery, ChatRead, ChatSettings
from .connect import ConnectService, ProfilePut as ConnectPut, InviteCreate, InviteAccept, Token


class PrivateRoute(APIRoute):
    def get_route_handler(self):
        original = super().get_route_handler()

        async def handler(request: Request):
            # Bound chunked bodies as well as Content-Length before JSON parsing.
            from fastapi import HTTPException
            chunks, size = [], 0
            async for chunk in request.stream():
                size += len(chunk)
                limit = 2_097_152 if request.url.path in {"/v1/memory/snapshot", "/v1/dating/profile/photo"} else 131072
                if size > limit:
                    raise HTTPException(413, "This request is too large.")
                chunks.append(chunk)
            request._body = b"".join(chunks)
            try:
                response = await original(request)
            except RequestValidationError as error:
                # FastAPI's default errors echo rejected personal input values.
                response = JSONResponse(status_code=422, content={"detail": [
                    {"loc": value["loc"], "type": value["type"], "msg": "Invalid field."} for value in error.errors()
                ]})
            response.headers["Cache-Control"] = "no-store"
            return response
        return handler


def create_router(service: MemoryService, *, account_service=None, snapshot_service=None, allow_legacy_sessions: bool = False, dating_service=None) -> APIRouter:
    if account_service is None and not allow_legacy_sessions:
        from .accounts import AccountService
        from .sync import SnapshotService
        account_service = AccountService(service)
        snapshot_service = snapshot_service or SnapshotService(service)
    router = APIRouter(prefix="/v1", tags=["private-memory"], route_class=PrivateRoute)
    dating = dating_service or DatingService(service)
    connect = ConnectService(service)

    async def principal(request: Request):
        authorization = request.headers.get("Authorization", "")
        subject = account_service.assert_active(authorization) if account_service is not None else verify_session(authorization, service.secret, now=int(service.clock()))
        service.rate(subject)
        if account_service is not None:
            subject = await account_service.authorize(authorization)
        token = service.request_guard.set((lambda db: account_service.assert_active(authorization, db=db)) if account_service is not None else None)
        try:
            yield subject
        finally:
            service.request_guard.reset(token)

    @router.get("/connect")
    def connect_state(subject=Depends(principal)):
        return connect.state(subject)

    @router.put("/connect/profile")
    def connect_save(data: ConnectPut, subject=Depends(principal)):
        return connect.save(subject, data)

    @router.delete("/connect")
    def connect_erase(subject=Depends(principal)):
        return connect.erase(subject)

    @router.post("/connect/invitations")
    def connect_invite(data: InviteCreate, subject=Depends(principal)):
        return connect.create(subject, data)

    @router.delete("/connect/invitations/{identifier}")
    def connect_remove(identifier: str, subject=Depends(principal)):
        return connect.remove(subject, identifier)

    @router.get("/dating/profile")
    def dating_profile(subject=Depends(principal)):
        return dating.get(subject)

    @router.put("/dating/profile")
    def save_dating_profile(data: ProfilePut, subject=Depends(principal)):
        return dating.put(subject, data)

    @router.delete("/dating/profile")
    def delete_dating_profile(subject=Depends(principal)):
        return dating.delete(subject)

    @router.get("/dating/discover")
    def discover(subject=Depends(principal)):
        return dating.discover(subject)

    @router.post("/dating/profiles/{identifier}/like")
    def like_profile(identifier: str, subject=Depends(principal)):
        return dating.like(subject, identifier)

    @router.get('/dating/likes')
    def dating_likes(subject=Depends(principal)): return dating.likes(subject)

    @router.delete('/dating/profiles/{identifier}/like')
    def dating_unlike(identifier: str, subject=Depends(principal)): return dating.unlike(subject, identifier)

    @router.post('/dating/profiles/{identifier}/pass')
    def dating_pass(identifier: str, subject=Depends(principal)): return dating.pass_profile(subject, identifier)

    @router.put('/dating/profile/photo')
    def dating_upload_photo(data: PhotoPut, subject=Depends(principal)): return dating.put_photo(subject, data)

    @router.delete('/dating/profile/photo')
    def dating_remove_photo(data: PhotoDelete, subject=Depends(principal)): return dating.remove_photo(subject, data.expected_revision)

    @router.get('/dating/photos/{identifier}')
    def dating_get_photo(identifier: str, subject=Depends(principal)):
        return Response(dating.photo(subject, identifier), media_type='image/jpeg', headers={'Cache-Control':'no-store', 'X-Content-Type-Options':'nosniff'})

    @router.post("/dating/profiles/{identifier}/block")
    def block_profile(identifier: str, subject=Depends(principal)):
        return dating.block(subject, identifier)

    @router.post("/dating/profiles/{identifier}/report")
    def report_profile(identifier: str, data: ReportPut, subject=Depends(principal)):
        return dating.block(subject, identifier, data)

    @router.get("/dating/matches")
    def dating_matches(subject=Depends(principal)):
        return dating.matches(subject)

    @router.get("/dating/matches/{identifier}/messages")
    def dating_messages(identifier: str, subject=Depends(principal)):
        return dating.messages(subject, identifier)

    @router.post('/dating/matches/{identifier}/history')
    def chat_history(identifier: str, data: HistoryQuery, subject=Depends(principal)):
        return dating.messages(subject, identifier, data)

    @router.post('/dating/matches/{identifier}/read')
    def chat_read(identifier: str, data: ChatRead, subject=Depends(principal)):
        return dating.mark_read(subject, identifier, data)

    @router.patch('/dating/matches/{identifier}/settings')
    def chat_settings(identifier: str, data: ChatSettings, subject=Depends(principal)):
        return dating.chat_settings(subject, identifier, data)

    @router.post("/dating/matches/{identifier}/messages")
    def send_dating_message(identifier: str, data: MessagePut, subject=Depends(principal)):
        return dating.send(subject, identifier, data)

    @router.delete("/dating/matches/{identifier}")
    def unmatch(identifier: str, subject=Depends(principal)):
        return dating.unmatch(subject, identifier)

    # Static paths must precede /memory/{identifier}, including DELETE.
    if snapshot_service is not None:
        @router.get("/memory/snapshot")
        def get_snapshot(subject=Depends(principal)):
            return snapshot_service.get(subject)

        @router.put("/memory/snapshot")
        def put_snapshot(data: SnapshotPut, subject=Depends(principal)):
            return snapshot_service.put(subject, data)

        @router.delete("/memory/snapshot")
        def delete_snapshot(data: SnapshotDelete, subject=Depends(principal)):
            return snapshot_service.delete(subject, data.expected_revision)

    @router.get("/memory/settings")
    def settings(subject=Depends(principal)):
        return service.settings(subject)

    @router.patch("/memory/settings")
    def update_settings(data: SettingsUpdate, subject=Depends(principal)):
        return service.set_settings(subject, data.enabled)

    @router.get("/memory")
    def memories(subject=Depends(principal)):
        return service.memories(subject)

    @router.post("/memory", status_code=201)
    def add_memory(data: MemoryCreate, subject=Depends(principal)):
        return service.create_memory(subject, data)

    @router.patch("/memory/{identifier}")
    def update_memory(identifier: str, data: MemoryUpdate, subject=Depends(principal)):
        return service.update_memory(subject, identifier, data)

    @router.delete("/memory/{identifier}")
    def remove_memory(identifier: str, subject=Depends(principal)):
        return service.delete_memory(subject, identifier)

    @router.get("/conversations")
    def conversations(subject=Depends(principal)):
        return service.conversations(subject)

    @router.get("/conversations/{identifier}")
    def conversation(identifier: str, subject=Depends(principal)):
        return service.conversation(subject, identifier)

    @router.delete("/conversations/{identifier}")
    def remove_conversation(identifier: str, subject=Depends(principal)):
        return service.delete_conversations(subject, identifier)

    @router.delete("/conversations")
    def remove_conversations(subject=Depends(principal)):
        return service.delete_conversations(subject)

    @router.post("/chat")
    async def chat(data: ChatRequest, request: Request, subject=Depends(principal)):
        guard = (lambda db: account_service.assert_active(request.headers.get("Authorization", ""), db=db)) if account_service is not None else None
        return await service.chat(subject, data, request_guard=guard)

    @router.get("/account/export")
    def export(subject=Depends(principal)):
        result = service.export(subject)
        result["dating"] = dating.export(subject)
        result["connect"] = connect.state(subject)
        if snapshot_service is not None:
            result["memory_snapshot"] = snapshot_service.get(subject)
        return result

    @router.delete("/account/data")
    def erase(subject=Depends(principal)):
        if snapshot_service is not None:
            return snapshot_service.erase_all_data(subject)
        return service.erase(subject)

    if account_service is not None:
        @router.post("/auth/challenge")
        def challenge(request: Request):
            # Proxy headers are intentionally untrusted; deploy behind a configured proxy rate limiter too.
            return account_service.challenge(request.client.host if request.client else "unknown")

        @router.post("/auth/apple")
        async def sign_in(data: AppleLogin, request: Request):
            account_service.rate_auth(request.client.host if request.client else "unknown")
            return await account_service.sign_in(data.challenge_id, data.identity_token, authorization_code=data.authorization_code)

        @router.post("/auth/refresh")
        def refresh(data: RefreshSession, request: Request):
            account_service.rate_auth(request.client.host if request.client else "unknown")
            return account_service.refresh(data.refresh_token)

        @router.post("/auth/logout")
        def logout(data: RefreshSession, subject=Depends(principal)):
            return account_service.logout(subject, data.refresh_token)

        @router.get("/account/session")
        def session(subject=Depends(principal)):
            return account_service.session(subject)

        @router.post("/account/subscription")
        async def subscription(data: VerifySubscription, request: Request, subject=Depends(principal)):
            return await account_service.subscription(subject, data.signed_transaction, authorization=request.headers.get("Authorization", ""))

        @router.delete("/account")
        async def delete_account(subject=Depends(principal)):
            return await account_service.delete_account(subject)

    return router


class AppleLogin(BaseModel):
    model_config = ConfigDict(extra="forbid")
    challenge_id: str = Field(min_length=36, max_length=36)
    identity_token: str = Field(min_length=1, max_length=16384)
    authorization_code: Optional[str] = Field(default=None, min_length=1, max_length=4096)


class RefreshSession(BaseModel):
    model_config = ConfigDict(extra="forbid")
    refresh_token: str = Field(min_length=1, max_length=4096)


class VerifySubscription(BaseModel):
    model_config = ConfigDict(extra="forbid")
    signed_transaction: str = Field(min_length=1, max_length=32768)


def create_app(service: MemoryService | None = None, *, managed_accounts: bool = True, account_service=None, dating_service=None) -> FastAPI:
    service = service or MemoryService.from_env()
    snapshots = None
    if managed_accounts:
        from .accounts import AccountService
        from .sync import SnapshotService
        account_service = account_service or AccountService(service)
        snapshots = SnapshotService(service)
    elif account_service is not None:
        raise ValueError("Account service requires managed accounts.")
    @asynccontextmanager
    async def lifespan(app):
        async def cleanup():
            while True:
                def purge_expired():
                    with service.db() as db:
                        db.execute("DELETE FROM connect_invites WHERE expires<=?", (service.clock(),))
                await asyncio.to_thread(purge_expired)
                await asyncio.sleep(3600)
        task = asyncio.create_task(cleanup())
        try:
            yield
        finally:
            task.cancel()
            with suppress(asyncio.CancelledError):
                await task

    app = FastAPI(lifespan=lifespan, title="Omni Account Memory", version="0.2.0", description="Account memory service. Production requires Apple and model credentials, TLS and a persistent private database.")

    @app.exception_handler(HTTPException)
    async def private_http_error(request: Request, error: HTTPException):
        return JSONResponse(status_code=error.status_code, content={"detail": error.detail}, headers={**(error.headers or {}), "Cache-Control": "no-store"})

    @app.get("/health", include_in_schema=False)
    def health():
        # Liveness only; never publish keys, user counts, paths or environment configuration.
        return {"status": "ok"}

    public_directory = Path(__file__).resolve().parent / "public"
    public_headers = {
        "Cache-Control": "public, max-age=3600",
        "Content-Security-Policy": "default-src 'none'; style-src 'self'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
        "Referrer-Policy": "no-referrer",
        "X-Content-Type-Options": "nosniff",
    }

    @app.get("/support", include_in_schema=False)
    def support_page():
        return FileResponse(public_directory / "support.html", media_type="text/html", headers=public_headers)

    @app.get("/privacy", include_in_schema=False)
    def privacy_page():
        return FileResponse(public_directory / "privacy.html", media_type="text/html", headers=public_headers)

    @app.get("/public/style.css", include_in_schema=False)
    def public_stylesheet():
        return FileResponse(public_directory / "style.css", media_type="text/css", headers=public_headers)

    connect = ConnectService(service)
    public_connect = APIRouter(prefix="/connect/api", route_class=PrivateRoute)

    def public_rate():
        # Bounded global bucket: no visitor identities or invitation secrets in rate-limit rows.
        service.rate("connect-public", "api")

    @public_connect.post("/open", dependencies=[Depends(public_rate)])
    def open_invitation(data: Token):
        return connect.open(data.token)

    @public_connect.post("/accept", dependencies=[Depends(public_rate)])
    def accept_invitation(data: InviteAccept):
        return connect.accept(data)

    @public_connect.post("/report", dependencies=[Depends(public_rate)])
    def read_report(data: Token):
        return connect.receipt(data.token)

    @public_connect.post("/revoke", dependencies=[Depends(public_rate)])
    def revoke_report(data: Token):
        return connect.receipt(data.token, revoke=True)

    app.include_router(public_connect)
    connect_headers = {**public_headers, "Cache-Control": "no-store",
        "Content-Security-Policy": "default-src 'none'; style-src 'self'; script-src 'self'; connect-src 'self'; base-uri 'none'; form-action 'self'; frame-ancestors 'none'"}

    @app.get("/connect", include_in_schema=False)
    def connect_page():
        return FileResponse(public_directory / "connect.html", media_type="text/html", headers=connect_headers)

    @app.get("/public/connect.js", include_in_schema=False)
    def connect_script():
        return FileResponse(public_directory / "connect.js", media_type="application/javascript", headers=connect_headers)

    @app.get("/public/connect.css", include_in_schema=False)
    def connect_style():
        return FileResponse(public_directory / "connect.css", media_type="text/css", headers=connect_headers)

    app.include_router(create_router(service, account_service=account_service, snapshot_service=snapshots, allow_legacy_sessions=not managed_accounts, dating_service=dating_service))
    return app
