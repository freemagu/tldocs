# Claude API Migration Notes for TradeLens

## Overview

TradeLens currently uses OpenAI (gpt-5.2 / gpt-4o-mini) for two AI features. This document evaluates migrating to the Claude API (Anthropic SDK).

## Current AI Architecture

### Stack

```
ai_factory.py  →  tradesuite.common.ai.AIClient  →  OpenAI API
```

- **Config**: `etc/config.yml` under `openai:` section
- **API Key**: `OPENAI_API_KEY` environment variable
- **Models**: gpt-5.2 (reasoning), gpt-4o-mini (runtime/fast)

### Feature 1: Batch Ideas (`batch_ideas.py` — 2,170 LOC)

**What it does**: Parses freeform text (Discord snippets, notes, screenshots) into structured trade proposals (symbol, side, category, entry/TP/SL levels).

**Endpoints**:
- `POST /api/v1/ideas/batch/parse` — AI parses text into proposals
- `POST /api/v1/ideas/batch/create` — Create selected ideas with levels
- `POST /api/v1/ideas/batch/refine` — Multi-turn refinement of parsing results

**Current flow**:
1. User enters freeform text + optional screenshots in a modal
2. Backend builds multimodal prompt (text + images)
3. gpt-5.2 returns JSON with trade proposals
4. `validate_llm_response()` checks response structure
5. Frontend shows preview table for user to edit/confirm
6. Selected proposals are created as trade ideas

**Model**: gpt-5.2 (reasoning)

### Feature 2: AI Feedback (`ai_feedback.py` — 1,390 LOC)

**What it does**: Multi-turn conversational analysis of open/closed trades. Builds a server-side "Trade Snapshot" with pre-computed fields (WAEP, remaining qty, projections) and sends it as context.

**Endpoints**:
- `POST /api/v1/feedback-v2` — Main feedback endpoint with snapshot context
- `GET /api/v1/chat-history` — Retrieve conversation history
- `DELETE /api/v1/clear-chat` — Delete conversation thread

**Current flow**:
1. `ai_snapshot.py` builds a detailed trade snapshot (markdown text)
2. Snapshot includes: position state, open/filled/cancelled orders, P&L projections, management evolution narrative, state change digest
3. Snapshot is sent as system/context in each turn
4. Chat history is persisted in `trade_ai_chat` table
5. Supports multimodal (screenshot analysis)

**Models**: gpt-4o-mini (default), gpt-5.2 (reasoning)

### Supporting Code

| File | Purpose |
|------|---------|
| `ai_factory.py` (123 LOC) | Centralized model config, creates AIClient instances |
| `ai_snapshot.py` (1,025 LOC) | Pre-computes trade context for LLM consumption |
| `tradesuite.common.ai.AIClient` | Shared OpenAI wrapper |
| `tradesuite.common.ai.response.parse_json_object` | JSON parsing utility |

## Claude API Equivalents

### How the Claude API Works

Everything goes through `POST /v1/messages`. The API is stateless — you send the full conversation history each request.

```python
import anthropic

client = anthropic.Anthropic()  # uses ANTHROPIC_API_KEY env var

response = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=1024,
    messages=[{"role": "user", "content": "Hello!"}]
)

print(response.content[0].text)
```

**Key differences from OpenAI**:
- System prompt is a top-level `system=` parameter, not a message with `role: "system"`
- Response is in `response.content[0].text`, not `response.choices[0].message.content`
- Tool use returns `stop_reason: "tool_use"` instead of `finish_reason: "tool_calls"`
- Images use `type: "image"` content blocks (base64 or URL)

### Available Models

| Model | ID | Cost (in/out per 1M) | Best for |
|-------|----|---------------------|----------|
| Claude Opus 4.6 | `claude-opus-4-6` | $5 / $25 | Reasoning, analysis (replaces gpt-5.2) |
| Claude Sonnet 4.6 | `claude-sonnet-4-6` | $3 / $15 | Balanced speed/quality |
| Claude Haiku 4.5 | `claude-haiku-4-5` | $1 / $5 | Fast/cheap tasks (replaces gpt-4o-mini) |

### Thinking (Reasoning)

Claude Opus 4.6 supports "adaptive thinking" — Claude reasons internally before answering:

```python
response = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=16000,
    thinking={"type": "adaptive"},
    messages=[{"role": "user", "content": "Analyze this trade..."}]
)
```

This replaces the need for a separate "reasoning model" — Opus 4.6 with adaptive thinking handles both fast and deep analysis.

## Migration Analysis

### Batch Ideas → Claude Structured Outputs

**Current pain point**: `validate_llm_response()` manually checks JSON structure. Malformed responses need error handling.

**Claude solution**: `messages.parse()` with Pydantic models guarantees schema compliance. The response is either valid or a refusal — no malformed JSON.

```python
from pydantic import BaseModel
from typing import List, Optional

class TradeProposal(BaseModel):
    symbol: str
    side: str              # LONG, SHORT
    category: str          # swing, scalp, etc.
    entry_price: Optional[float]
    targets: List[float]
    stop_loss: Optional[float]
    confidence: float
    reasoning: str

class BatchParseResult(BaseModel):
    proposals: List[TradeProposal]
    unparsed_text: Optional[str]

response = client.messages.parse(
    model="claude-opus-4-6",
    max_tokens=4096,
    system="You parse freeform trading text into structured proposals...",
    messages=[{"role": "user", "content": freeform_text}],
    output_format=BatchParseResult,
)

result = response.parsed_output  # Validated BatchParseResult
```

**Benefits**:
- Eliminates `validate_llm_response()` entirely
- Type-safe access to parsed fields
- No JSON parsing errors to handle

**Multimodal (screenshots)**: Works the same way — pass images as content blocks:

```python
messages=[{
    "role": "user",
    "content": [
        {"type": "image", "source": {"type": "base64", "media_type": "image/png", "data": b64_data}},
        {"type": "text", "text": "Parse the trade ideas from this screenshot"}
    ]
}]
```

### AI Feedback → Claude with Prompt Caching

**Current pain point**: The trade snapshot (from `ai_snapshot.py`) is large and sent every turn. This is expensive with repeated context.

**Claude solution**: Prompt caching saves up to 90% on repeated context:

```python
response = client.messages.create(
    model="claude-opus-4-6",
    max_tokens=4096,
    thinking={"type": "adaptive"},
    system=[{
        "type": "text",
        "text": trade_snapshot_markdown,
        "cache_control": {"type": "ephemeral"}  # Cached for 5 min
    }],
    messages=chat_history
)
```

First turn pays full price for the snapshot. Subsequent turns within 5 minutes pay ~10% for the cached portion. This is significant given the snapshot can be 1,000+ tokens.

**Multi-turn conversation management**: The API is stateless (same as OpenAI). You already persist chat history in `trade_ai_chat` — just load and send it each turn.

### AI Factory Changes

Current `ai_factory.py` maps purposes to models:

| Purpose | Current | Claude Equivalent |
|---------|---------|-------------------|
| `"default"` | gpt-4o-mini | claude-haiku-4-5 |
| `"runtime"` | gpt-4o-mini | claude-haiku-4-5 |
| `"reasoning"` | gpt-5.2 | claude-opus-4-6 (with adaptive thinking) |

New factory would look like:

```python
import anthropic

def get_ai_client(purpose="default"):
    client = anthropic.Anthropic()  # Uses ANTHROPIC_API_KEY

    model_map = {
        "default": "claude-haiku-4-5",
        "runtime": "claude-haiku-4-5",
        "reasoning": "claude-opus-4-6",
    }

    return client, model_map.get(purpose, "claude-haiku-4-5")
```

## What Would NOT Change

- `ai_snapshot.py` — The snapshot builder is model-agnostic (outputs markdown text). No changes needed.
- `trade_ai_chat` table — Chat history storage is model-agnostic. May want to add a column for `model` if not already present.
- Frontend — The frontend sends text/screenshots and receives text. The API contract between frontend and backend stays the same.
- The overall architecture pattern (factory → client → API → structured response → database).

## What Would Change

| File | Change | Effort |
|------|--------|--------|
| `ai_factory.py` | Swap AIClient for anthropic.Anthropic() | Small |
| `batch_ideas.py` | Use `messages.parse()` + Pydantic, remove `validate_llm_response()` | Medium |
| `ai_feedback.py` | Swap message format, add cache_control on snapshot | Medium |
| `config.yml` | Add `anthropic:` section, ANTHROPIC_API_KEY | Small |
| `requirements.txt` | Add `anthropic` package | Trivial |

## Claude API vs Agent SDK — Which to Use?

**Claude API (anthropic SDK)** — Use this. Both features are structured API calls with known inputs/outputs. You control the flow.

**Agent SDK** — Not needed. The Agent SDK is for when Claude needs to autonomously read files, browse the web, run shell commands, and decide its own trajectory. Your use cases are:
- Text in → structured data out (Batch Ideas)
- Context + question in → analysis out (AI Feedback)

These are workflow-tier, not agent-tier.

## Key Claude API Features Relevant to TradeLens

| Feature | What it does | Where it helps |
|---------|-------------|----------------|
| Structured Outputs | Guaranteed JSON schema compliance via Pydantic | Batch Ideas — eliminates validation code |
| Prompt Caching | 90% cost reduction on repeated context | AI Feedback — trade snapshot is repeated every turn |
| Adaptive Thinking | Built-in reasoning mode | AI Feedback — deep trade analysis |
| Vision | Native image understanding | Both — screenshot analysis |
| Streaming | Token-by-token output | AI Feedback — faster perceived response time |

## Cost Comparison (Rough)

Assuming ~2K input tokens (snapshot) + ~500 output tokens per AI Feedback turn:

| Model | Input cost | Output cost | Per turn |
|-------|-----------|-------------|----------|
| gpt-4o-mini | ~$0.0003 | ~$0.0006 | ~$0.0009 |
| claude-haiku-4-5 | ~$0.002 | ~$0.0025 | ~$0.0045 |
| gpt-5.2 | varies | varies | varies |
| claude-opus-4-6 | ~$0.01 | ~$0.0125 | ~$0.0225 |
| claude-opus-4-6 (cached) | ~$0.001 | ~$0.0125 | ~$0.0135 |

Prompt caching makes Opus 4.6 significantly cheaper on repeated-context workloads like multi-turn chat.

## Migration Path

### Phase 1: Parallel Setup
1. Add `anthropic` to requirements
2. Add `anthropic:` config section to `config.yml`
3. Create a Claude-specific factory alongside existing OpenAI factory
4. Test both backends with the same prompts on real trade data

### Phase 2: Batch Ideas Migration
1. Define Pydantic models for trade proposals
2. Replace OpenAI call with `messages.parse()`
3. Remove `validate_llm_response()` — Pydantic handles it
4. Test with real freeform text inputs
5. Compare quality: Claude vs GPT-5.2 on the same inputs

### Phase 3: AI Feedback Migration
1. Add prompt caching on trade snapshot
2. Swap message format
3. Add streaming for better UX
4. Test multi-turn conversations
5. Compare analysis quality on real trades

### Phase 4: Cleanup
1. Remove OpenAI dependency (if fully migrated)
2. Update `ai_factory.py` to only support Claude
3. Update config.yml

## Open Questions

1. **Quality comparison**: Is Claude Opus 4.6 better than GPT-5.2 at trade analysis? Need to test with real snapshots.
2. **Dual support**: Keep both OpenAI and Claude as options? Or fully migrate?
3. **Cost**: Is the prompt caching savings worth the migration effort?
4. **Streaming**: AI Feedback currently returns complete responses. Worth adding streaming for UX?
5. **Common AIClient**: The shared `tradesuite.common.ai.AIClient` wraps OpenAI. Should we make it provider-agnostic, or create a separate Claude wrapper?

---

*Generated: 2026-03-04*
