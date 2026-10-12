# eraAI server

A small FastAPI server that exposes your model to the era browser through the
OpenAI-compatible Chat Completions API.

```sh
pip install -r requirements.txt
python server.py                      # http://127.0.0.1:8000/v1
ERA_API_KEY=secret python server.py   # require an API key (set the same key in era → Settings → eraAI)
```

Environment variables: `ERA_HOST` (default `127.0.0.1`), `ERA_PORT` (`8000`),
`ERA_MODEL` (`era`), `ERA_API_KEY` (empty = no auth).

## Plugging in eraAI

Replace the demo body of `generate(messages)` in `server.py` with a call to your model and
`yield` the answer piece by piece (tokens, words or the whole text at once).

`messages` is a list of `{role, content}`:

| # | role | content |
|---|------|---------|
| 0 | `system` | System prompt from era's settings, plus — when page sharing is on — the page title, URL, selected text and page text (up to 15 000 characters) |
| 1…n-1 | `user` / `assistant` | Previous messages of the conversation (up to 20) |
| n | `user` | The question |

## Protocol

Request (sent by era):

```json
POST /v1/chat/completions
Authorization: Bearer <api key>        (only if set)
{"model": "era", "stream": true, "messages": [{"role": "system", "content": "…"}, {"role": "user", "content": "…"}]}
```

Streaming response (`text/event-stream`):

```
data: {"choices": [{"delta": {"content": "Hel"}}]}
data: {"choices": [{"delta": {"content": "lo"}}]}
data: [DONE]
```

A non-streaming JSON response `{"choices": [{"message": {"content": "Hello"}}]}` is accepted too.
Errors can be sent as `{"error": {"message": "…"}}` (as a JSON body or as an SSE event) and are shown in the panel.
