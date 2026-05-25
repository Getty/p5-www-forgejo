---
name: hi-agent-architecture
description: HI agent hierarchy (Queen/Princess/Worker/Drone), Role::Caste, RBAC scoping, NATS messaging, MCP integration patterns
---

<oneliner>
HI's agent architecture uses a beehive metaphor with four agent types sharing infrastructure via Role::Caste, differentiated by RBAC scope and purpose.
</oneliner>

<agent-hierarchy>
## Agent Hierarchy

```
Management Layer (Chat-Assistenten, Langertha-based):
  Queen      Platform-level. Cluster oversight, debugging, monitoring.
  Princess   Per-tenant. Workspace/project/volume management.
  Worker     Per-user. UI helper, sets up Drones and data types.

Execution Layer (Custom Agents, runtime-agnostic):
  Drone      Per-task. Does the actual work. Pluggable runtime.
```

**Key principle:** Queen/Princess/Worker are NOT executors. They are management assistants that help humans oversee and configure the platform. The real work is done by Drones.
</agent-hierarchy>

<role-caste>
## Role::Caste — Shared Agent Infrastructure (DB-free)

All HI agents compose `HI::Role::Caste` (Moo::Role). This provides **pure infrastructure** — completely database-free. Agent identity comes from constructor parameters, not DB rows.

### Constructor Parameters

```perl
has loop           => (is => 'ro', required => 1);  # IO::Async::Loop
has agent_key      => (is => 'ro', required => 1);  # e.g. 'queen', 'princess'
has model_key      => (is => 'ro', required => 1);  # e.g. 'anthropic/claude-sonnet'
has mission        => (is => 'ro', default => '');   # System prompt
has max_iterations => (is => 'ro', default => 10);   # Raider iterations
has namespaces     => (is => 'ro', default => ['hi-broodnest']);
has proxy_url      => (is => 'ro', default => $ENV{HI_SKEID_URL} || 'http://openai:8000/v1');
has tenant_key     => (is => 'ro', default => undef); # For tenant-scoped agents
```

### What Role::Caste provides

- **HI::Engine** pointed at Skeid proxy with per-agent attribution (`x-skeid-key-id`)
- **Langertha::Raider** loop for autonomous AI reasoning
- **MCP::K8s** server exposing configured namespaces
- `skeid_key_id()` → `t:{tenant}/a:{agent}` attribution string
- `raid_f($message)` → run a Raider loop
- `clear_history()` → reset Raider conversation

### Usage

```perl
my $queen = HI::Queen->new(
    loop      => $loop,
    model_key => 'anthropic/claude-sonnet',
    # agent_key defaults to 'queen', mission/namespaces have Queen-specific defaults
);

my $princess = HI::Princess->new(
    loop       => $loop,
    model_key  => 'anthropic/claude-sonnet',
    tenant_key => 'dev',
    # agent_key defaults to 'princess', namespaces scoped to hi-tenant-dev-*
);
```

**What Role::Caste does NOT include:**
- Database access (only Drone has a `row` attribute)
- Which MCP servers to use (each class decides)
- RBAC / ServiceAccount (K8s deployment config)
- Agent runtime (Langertha, Claude Code, etc.)
- Scope-specific logic
</role-caste>

<rbac-scoping>
## RBAC Scoping

Nobody touches the bare `hi` namespace — it's sacred infrastructure. All agents use the **same K8s MCP server** — RBAC on the ServiceAccount controls what each agent can see/do:

| Agent | Namespace Access | Read | Write |
|-------|-----------------|------|-------|
| Queen | `hi-*` (all hi- prefixed) | Full read | None |
| Princess | `hi-tenant-{key}-*` | Full | Full |
| Worker | None by default | None | None |
| Worker | Explicit grants only | Per-user | Per-user |
| Drone | Target namespace | As configured | As configured |

**Key rules:**
- `hi` namespace = off-limits to ALL agents (sacred infrastructure)
- Queen gets `hi-*` (read-only) — sees everything prefixed `hi-` but can't write
- Princess gets `hi-tenant-{key}-*` — her tenant + workspace namespaces (read/write)
- All management agents run in `hi-broodnest`, never in the namespace they manage
</rbac-scoping>

<queen>
## Queen — Platform Observer

- **Purpose:** Observer and advisor. Watches over the cluster, reports on health, helps admins understand what's happening.
- **Runs in:** `hi` namespace
- **RBAC:** Read-only on all `hi-*` namespaces (no access to bare `hi`)
- **MCP:** K8s MCP (read-only via RBAC) + Queen MCP ("big switches": cluster health check, tenant CRUD)
- **Chat:** Via Beekeeper admin UI over NATS
- **Code-defined:** `agent_key='queen'`, `mission=$DEFAULT_MISSION`, `max_iterations=15`
- **Future:** Approve/deny resource requests from tenants

The Queen does NOT manage infrastructure — Beekeeper handles deployments. The Queen observes, reports anomalies proactively, and provides the few "big switch" MCP tools (tenant lifecycle, health checks) on admin request.
</queen>

<princess>
## Princess — Tenant Manager

- **Purpose:** Helps tenant admin manage workspaces, projects, volumes
- **Runs in:** `hi-broodnest` (not tenant namespace — prevents self-destruction)
- **RBAC:** `hi-tenant-{key}-*` (tenant namespace + all workspace namespaces, read/write)
- **MCP:** K8s MCP (scoped via RBAC)
- **Chat:** Via Colony for tenant admins
- **Code-defined:** `agent_key='princess'`, `tenant_key` required, namespaces auto-discovered
- **Safety:** Dangerous operations require user confirmation
- **Lifecycle:** Created automatically when tenant is created
- **Workspace Princess:** Optional via `permanent_princess` flag on Workspace

A manager, not an executor. Creates workspaces, deploys projects, manages volumes — but always with human oversight for destructive operations.
</princess>

<worker>
## Worker — User Assistant (formerly Bee)

- **Purpose:** Personal AI assistant per user in Colony web desktop
- **Runs in:** `hi-broodnest`
- **RBAC:** No K8s access by default. Only explicit grants.
- **MCP:** UI/Widget tools, Agent-Builder tools, Data-Type tools
- **Chat:** Bee chat window in Colony + standalone mobile URL
- **Desktop integration:** Can open widgets programmatically in user's Colony desktop
- **Lifecycle:** Started on user login, stopped on logout/timeout

The Worker is a **meta-agent** — it helps users set up Drones:
1. Create a JsonSchema (data type definition)
2. Create a Document (container for objects)
3. Generate/configure an MCP server for CRUD on that type
4. Deploy a Drone that uses the MCP to fill the Document with data

The Worker itself does NOT do the work — it helps the user create the infrastructure for Drones to do it.
</worker>

<drone>
## Drone — Custom Execution Agent

- **Purpose:** Does the actual work. Deployed per task/project.
- **Runs in:** Target namespace (workspace namespace, NOT hi-broodnest)
- **RBAC:** Scoped to target namespace
- **MCP:** Custom MCP servers (data CRUD, volumes, project-specific tools)
- **Runtime:** Pluggable — NOT tied to Langertha

### Drone Types

| Type | Runtime | Use Case |
|------|---------|----------|
| `HI::Drone::Langertha` | Langertha Raider | Autonomous tool-calling agent |
| `HI::Drone::ClaudeCode` | Claude Code + WebUI | Code development, DevOps |
| `HI::Drone::Hermes` | Hermes Agent | Alternative agent framework |
| Future types | Any | Extensible |

### What ALL Drones share (via Role::Caste):
- MCP server configuration
- Volume mounts
- K8s deployment (namespace, ServiceAccount, RBAC)
- NATS connectivity (status reports, commands)
- JsonSchema/Document access

### DevCode as Drone

DevCode (`devcode/`) is already a `HI::Drone::ClaudeCode` in practice — a container image + MCP + volumes. Currently hardcoded as special case for self-development. Future: deployable as standard Drone type per workspace/project.
</drone>

<nats-subjects>
## NATS Subject Conventions

```
hi.channel.{channel_id}.messages    Chat messages (user/assistant)
hi.channel.{channel_id}.events      Status events (processing, done, error)
hi.channel.{channel_id}.control     Control commands (clear, cancel)
hi.admin.{action}                   Admin requests to Beekeeper
hi.node.{hostname}.metrics          Node metrics from DaemonSet
hi.cluster.status                   Cluster status broadcast
```

Future expansion for agent hierarchy:
```
hi.queen.*                          Queen-specific subjects
hi.tenant.{key}.princess.*          Princess-specific per tenant
hi.tenant.{key}.user.{id}.worker.* Worker-specific per user
hi.drone.{id}.*                     Drone lifecycle/status
```
</nats-subjects>

<mcp-tool-pattern>
## MCP Tool Definition Pattern

```perl
use MCP::Server;

my $server = MCP::Server->new(name => 'tool-name', version => '1.0');

$server->tool(
    name        => 'action_name',
    description => 'What this tool does',
    input_schema => {
        type       => 'object',
        properties => {
            param => { type => 'string', description => 'Param description' },
        },
        required => ['param'],
    },
    code => sub {
        my ($tool, $args) = @_;
        # $tool is MCP::Tool instance, NOT your class
        # $args is parsed JSON arguments hash

        my $result = do_work($args->{param});

        return $tool->text_result($result);       # Success
        # or
        return $tool->text_result($error, 1);     # Error (is_error=1)
    },
);
```

**Important:** Handler signature is `sub ($self, $args)` where `$self` is the MCP::Tool instance. Use `$self->text_result("text")` — it's an instance method.
</mcp-tool-pattern>

<raider-pattern>
## Langertha Raider Pattern (for Queen/Princess/Worker)

```perl
# Role::Caste builds the Raider automatically from constructor params:
# - proxy_url → HI::Engine url
# - model_key → HI::Engine model
# - skeid_key_id() → attribution header
# - mission → Raider system prompt
# - max_iterations → Raider loop limit

# Direct usage (Role::Caste handles construction):
my $result = await $agent->raid_f($user_message);

# Manual engine construction (for custom MCP servers):
my $engine = HI::Engine->new(
    url          => $self->proxy_url,
    model        => $self->model_key,
    api_key      => 'skeid',
    skeid_key_id => $self->skeid_key_id,
    mcp_servers  => [$self->_mcp_k8s, $custom_mcp],
);

my $raider = Langertha::Raider->new(
    engine         => $engine,
    mission        => $self->mission,
    max_iterations => $self->max_iterations,
);

# Run raid (async)
my $result = await $raider->raid_f($user_message);

# Result handling
$result->is_question  # Agent asked a question
$result->is_abort     # Agent aborted
$result->content      # Response text
"$result"             # Stringified response

# History management
$raider->add_history('user', $content);    # Replay DB history
$raider->clear_history;                    # Reset session

# Metrics
$raider->metrics->{iterations}
```
</raider-pattern>

<data-type-flow>
## Data Type & Document Object Flow

The Worker helps users create data pipelines:

```
1. Worker creates JsonSchema (data type definition in DB)
2. Worker creates Document (container, lives in Folder)
3. MCP server generated for CRUD on DocumentObject rows
4. Drone deployed with MCP server → fills Document with objects

Colony shows:
  Virtual Filesystem → Folder → Document → click "file"
  → Custom lister widget for the JsonSchema type
  → Shows DocumentObject records
```

DB tables involved:
- `json_schema` — Type definitions (JSON Schema format)
- `document` — Container for objects (belongs to Folder)
- `document_object` — Individual records conforming to a JsonSchema
</data-type-flow>
