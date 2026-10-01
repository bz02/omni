import asyncio
import json
from concurrent.futures import ThreadPoolExecutor

import httpx
import pytest
from fastapi import HTTPException
from omni_memory.service import MemoryService
from omni_memory.provider import ResponsesResponder


def test_budget_is_atomic_across_concurrent_requests(tmp_path):
    service = MemoryService(tmp_path / 'data' / 'memory.db', secret='synthetic-secret-32-characters-long')
    service.model_budget.limit = 500_000
    def reserve(_):
        try:
            return service.model_budget.reserve(250_000)
        except HTTPException as error:
            assert error.status_code == 429
            return None
    with ThreadPoolExecutor(max_workers=4) as pool:
        assert sum(value is not None for value in pool.map(reserve, range(4))) == 2


def test_real_adapter_settles_usage_and_keeps_private_context_stateless(tmp_path):
    captured = []
    def transport(request):
        captured.append(json.loads(request.content))
        return httpx.Response(200, json={'status':'completed','usage':{'input_tokens':1000,'output_tokens':100},
            'output':[{'type':'message','content':[{'type':'output_text','text':json.dumps({'reply':'A symbolic reading.'})}]}]})
    responder = ResponsesResponder(api_key='synthetic-not-real', model='gpt-4.1-mini-2025-04-14', transport=httpx.MockTransport(transport))
    service = MemoryService(tmp_path / 'data' / 'memory.db', secret='synthetic-secret-32-characters-long', responder=responder)
    result = asyncio.run(responder.respond('My horoscope', [{'kind':'profile','text':'My Sun sign is Leo.'}], []))
    assert result['content'] == 'A symbolic reading.'
    assert captured[0]['store'] is False
    context = json.loads(captured[0]['input'][0]['content'][0]['text'])
    assert context['context'] == [{'kind':'profile','text':'My Sun sign is Leo.'}]
    assert len(context['server_date_utc']) == 10
    with service.db() as db:
        assert db.execute('SELECT SUM(amount) FROM model_budget').fetchone()[0] == 560
        assert db.execute('SELECT COUNT(*) FROM messages').fetchone()[0] == 0


def test_unknown_usage_keeps_reservation_and_unreviewed_model_cannot_spend(tmp_path):
    service = MemoryService(tmp_path / 'data' / 'memory.db', secret='synthetic-secret-32-characters-long')
    reservation = service.model_budget.reserve(250_000)
    service.model_budget.settle_chat(reservation, {'input_tokens': -1, 'output_tokens': 100})
    with service.db() as db:
        assert db.execute('SELECT amount FROM model_budget').fetchone()[0] == 250_000
    responder = ResponsesResponder(api_key='synthetic-not-real', model='unreviewed-model', budget=service.model_budget)
    with pytest.raises(HTTPException) as error:
        asyncio.run(responder.respond('Hello', [], []))
    assert error.value.status_code == 503
