"""
eraAI server for the era browser.

Exposes an OpenAI-compatible Chat Completions endpoint, which is what the browser's
eraAI panel talks to:

    POST /v1/chat/completions   {"model": ..., "messages": [...], "stream": true}

Plug your own model into `generate()` below; everything else (HTTP, streaming,
auth) is handled here.

Run:
    pip install -r requirements.txt
    python server.py                      # http://127.0.0.1:8000/v1
    ERA_API_KEY=secret python server.py   # require "Authorization: Bearer secret"
"""

from __future__ import annotations

import json
import os
import time
import uuid
from collections.abc import Iterator

import uvicorn
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.responses import JSONResponse, StreamingResponse
from pydantic import BaseModel

API_KEY = os.environ.get("ERA_API_KEY", "")
MODEL_NAME = os.environ.get("ERA_MODEL", "era")


class Message(BaseModel):
    role: str  # "system" | "user" | "assistant"
    content: str


class ChatRequest(BaseModel):
    model: str = MODEL_NAME
    messages: list[Message]
    stream: bool = False


def generate(messages: list[Message]) -> Iterator[str]:
    """Yield the answer piece by piece.

    `messages[0]` is the system prompt; when "send page content" is enabled in the
    browser it also contains the page title, URL, selected text and page text.
    The last message is the user's question.

    Replace this demo with a call to eraAI, e.g.:
        for token in era_model.stream(messages):
            yield token
    """
    question = messages[-1].content if messages else ""
    has_page = bool(messages) and messages[0].role == "system" and "Page content" in messages[0].content
    reply = (
        "Hi! I'm the eraAI demo server. "
        f"You asked: “{question[:200]}”. "
        + ("I received the page content. " if has_page else "")
        + "Plug your model into generate() in eraAI-server/server.py."
    )
    for word in reply.split(" "):
        yield word + " "
        time.sleep(0.02)


def check_api_key(authorization: str | None = Header(default=None)) -> None:
    if API_KEY and authorization != f"Bearer {API_KEY}":
        raise HTTPException(status_code=401, detail={"message": "Invalid API key"})


app = FastAPI(title="eraAI")


@app.get("/v1/models", dependencies=[Depends(check_api_key)])
def list_models() -> dict:
    return {"object": "list", "data": [{"id": MODEL_NAME, "object": "model", "owned_by": "era"}]}


@app.post("/v1/chat/completions", dependencies=[Depends(check_api_key)])
def chat_completions(request: ChatRequest):
    completion_id = f"chatcmpl-{uuid.uuid4().hex}"
    created = int(time.time())

    if not request.stream:
        text = "".join(generate(request.messages))
        return JSONResponse({
            "id": completion_id,
            "object": "chat.completion",
            "created": created,
            "model": request.model,
            "choices": [{"index": 0, "message": {"role": "assistant", "content": text}, "finish_reason": "stop"}],
        })

    def events() -> Iterator[str]:
        def chunk(delta: dict, finish_reason: str | None = None) -> str:
            payload = {
                "id": completion_id,
                "object": "chat.completion.chunk",
                "created": created,
                "model": request.model,
                "choices": [{"index": 0, "delta": delta, "finish_reason": finish_reason}],
            }
            return f"data: {json.dumps(payload, ensure_ascii=False)}\n\n"

        yield chunk({"role": "assistant"})
        try:
            for piece in generate(request.messages):
                yield chunk({"content": piece})
        except Exception as error:  # surface model errors in the browser panel
            yield f"data: {json.dumps({'error': {'message': str(error)}})}\n\n"
            return
        yield chunk({}, finish_reason="stop")
        yield "data: [DONE]\n\n"

    return StreamingResponse(events(), media_type="text/event-stream")


if __name__ == "__main__":
    uvicorn.run(app, host=os.environ.get("ERA_HOST", "127.0.0.1"), port=int(os.environ.get("ERA_PORT", "8000")))
