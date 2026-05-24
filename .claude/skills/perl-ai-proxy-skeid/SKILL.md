---
name: perl-ai-proxy-skeid
description: Use when working with Langertha::Skeid LLM proxy - setup, OpenBao integration, customer keys, usage tracking, or service stack deployment
---

# Perl AI Proxy Skeid

## Overview

`Langertha::Skeid` is the LLM routing service / proxy with:
- Multi-node weighted routing
- OpenAI/Anthropic/Ollama proxy frontends
- Usage tracking (jsonlog, sqlite, postgresql)
- OpenBao KeyBroker for secure API key management

## Key Components

### KeyBroker::OpenBao

Secure API key management with AppRole auth:

```perl
my $broker = Langertha::Skeid::KeyBroker::OpenBao->new(
  addr        => $ENV{OPENBAO_ADDR} // 'http://127.0.0.1:8200',
  role_id     => $ENV{OPENBAO_ROLE_ID},
  secret_id   => $ENV{OPENBAO_SECRET_ID},
  renew_secs  => 300,  # renew every 5 minutes
);
```

Token lifecycle:
1. Container boot → AppRole login → stores `_renew_token`
2. First API call → `refresh()` → renew-self → stores `_client_token`
3. Token renewed every 5min via renew-self
4. If renewal fails → die → container restart

### Customer Keys

Keys stored in OpenBao at `secret/skeid/customer/<key-id>`:
- Request with `x-skeid-key-id: "alice"` → lookup Alice's key
- Key read per-request from OpenBao, never persisted to disk

### Node Config with api_key_ref

```yaml
nodes:
  - id: groq-main
    url: https://api.groq.com/openai/v1
    model: llama-3.3-70b-versatile
    engine: openai
    api_key_ref: secret/skeid/remote/groq
```

Skeid resolves `api_key_ref` via KeyBroker → OpenBao.

## Service Stack

Docker Compose: `examples/service/docker-compose.yml`

```bash
cd examples/service
docker compose up -d
```

Stack:
- **openbao** — Secrets Vault (AppRole auth, KV v2)
- **postgres** — Usage storage
- **skeid** — LLM Proxy

### ENV Variables

**OpenBao:**
- `OPENBAO_ADDR` — Default: http://openbao:8200
- `OPENBAO_ROLE_ID` — AppRole role_id
- `OPENBAO_SECRET_ID` — AppRole secret_id

**Skeid:**
- `SKEID_ADMIN_API_KEY` — Admin API key for /skeid/* routes
- `SKEID_USAGE_DB_PASSWORD` — PostgreSQL password
- `SKEID_REMOTE_KEY_REF` — OpenBao path for LLM provider key

### Init Script (init-skeid.sh)

Creates:
1. AppRole auth method
2. AppRole role "skeid-service"
3. Policy for secret/skeid/*
4. Customer keys (alice, bob, charlie, testuser123)
5. PostgreSQL schema

## Usage Tracking

### PostgreSQL Schema

File: `share/sql/usage_events.postgresql.sql`

```sql
CREATE TABLE usage_events (
  id BIGSERIAL PRIMARY KEY,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  request_id TEXT NOT NULL DEFAULT '',
  api_format TEXT NOT NULL DEFAULT '',
  endpoint TEXT NOT NULL DEFAULT '',
  api_key_id TEXT NOT NULL DEFAULT '',
  provider TEXT NOT NULL DEFAULT '',
  engine TEXT NOT NULL DEFAULT '',
  model TEXT NOT NULL DEFAULT '',
  node_id TEXT NOT NULL DEFAULT '',
  route_url TEXT NOT NULL DEFAULT '',
  status_code INTEGER NOT NULL DEFAULT 0,
  ok BOOLEAN NOT NULL DEFAULT FALSE,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  input_tokens INTEGER NOT NULL DEFAULT 0,
  output_tokens INTEGER NOT NULL DEFAULT 0,
  total_tokens INTEGER NOT NULL DEFAULT 0,
  tool_calls INTEGER NOT NULL DEFAULT 0,
  cost_input_usd NUMERIC(12, 6) NOT NULL DEFAULT 0,
  cost_output_usd NUMERIC(12, 6) NOT NULL DEFAULT 0,
  cost_total_usd NUMERIC(12, 6) NOT NULL DEFAULT 0,
  error_type TEXT NOT NULL DEFAULT '',
  error_message TEXT NOT NULL DEFAULT ''
);
```

### Query Usage

```bash
# Via CLI
docker compose exec skeid bin/skeid usage --json

# Direct SQL
docker compose exec postgres psql -U skeid -d skeid -c "SELECT * FROM usage_events ORDER BY id DESC LIMIT 10;"
```

## Shell Commands

```bash
# Start stack
docker compose -f examples/service/docker-compose.yml up -d

# Check status
docker compose -f examples/service/docker-compose.yml ps

# Logs
docker compose -f examples/service/docker-compose.yml logs -f skeid

# Restart after token failure
docker compose -f examples/service/docker-compose.yml restart skeid

# OpenBao status
docker compose -f examples/service/docker-compose.yml exec openbao bao status
```

## Common Tasks

### Add Customer Key

```bash
docker exec skeid-openbao sh -c "BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=<root_token> bao kv put secret/skeid/customer/newuser api_key=\"sk-newuser-key\" active=true"
```

### Check OpenBao Keys

```bash
docker exec skeid-openbao sh -c "BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=<root_token> bao kv list secret/skeid/customer/"
```

### Test with Customer Key

```bash
curl -X POST http://localhost:5591/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "x-skeid-key-id: alice" \
  -d '{"model": "llama-3.3-70b-versatile", "messages": [{"role": "user", "content": "Hello"}]}'
```