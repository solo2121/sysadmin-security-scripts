# llm01 — OWASP Top 10 for LLM Applications Training Lab

> **⚠️ SAFETY WARNING**
> This application intentionally contains vulnerable code paths for education. It runs
> **only** on the isolated `llm01` VM, on the lab's private network. It must never be
> exposed to the public internet or run on a production host. Every "vulnerable"
> response uses synthetic data only (`FAKE-ONLY-`, `LAB_SECRET_`, `SYNTHETIC-` markers) —
> no real secrets, credentials, or personal information ever appear in this app, and no
> dangerous action (shell execution, arbitrary file access, package installation) is ever
> actually performed. See [Safety Model](#safety-model) below.

```text
API address:            http://172.28.128.60:8000
Swagger/OpenAPI address: http://172.28.128.60:8000/docs
VM name:                 llm01
Hostname:                llm01.lab.local
IP address:              172.28.128.60  (override: LLM01_IP)
Required profile:        llm  (or full)
Required memory:         4096 MB  (override: LLM01_MEMORY)
Required CPUs:            4      (override: LLM01_CPUS)
Required provider:       libvirt (KVM/QEMU) or VirtualBox
```

## Quick Start

```bash
# Just llm01, using the base lab's Vagrantfile
cd labs/security/active-directory/base
LAB_PROFILE=llm vagrant up llm01

# llm01 alongside the rest of the AD lab
LAB_PROFILE=full vagrant up

# SSH in
LAB_PROFILE=llm vagrant ssh llm01

# Check the service
LAB_PROFILE=llm vagrant ssh llm01 -c "systemctl status llm-owasp-lab --no-pager"

# From the host, once the VM reports healthy
curl http://172.28.128.60:8000/health
open http://172.28.128.60:8000/docs   # Swagger UI (macOS `open`; use xdg-open on Linux)
```

## Taxonomy

This lab implements the **current OWASP Top 10 for LLM Applications (2025)**:
<https://genai.owasp.org/initiatives/top-10-for-llm-and-genai/>. `GET /owasp/categories`
returns this list from the running app itself, so the lab is self-documenting and can't
silently drift from the taxonomy it claims to implement.

| Category | Scenario | Module | Endpoints | Test |
|---|---|---|---|---|
| LLM01 | Prompt Injection | `app/scenarios/llm01_prompt_injection.py` | `POST /llm01/chat` | `test_llm01_*` |
| LLM02 | Sensitive Information Disclosure | `app/scenarios/llm02_sensitive_information.py` | `GET /llm02/debug`, `GET /llm02/echo-with-context` | `test_llm02_*` |
| LLM03 | Supply Chain | `app/scenarios/llm03_supply_chain.py` | `GET /llm03/manifest` | `test_llm03_*` |
| LLM04 | Data and Model Poisoning | `app/scenarios/llm04_data_poisoning.py` | `POST /llm04/ingest`, `GET /llm04/validate/{id}`, `GET /llm04/sample-poisoned-doc` | `test_llm04_*` |
| LLM05 | Improper Output Handling | `app/scenarios/llm05_improper_output.py` | `POST /llm05/render`, `POST /llm05/simulated-query` | `test_llm05_*` |
| LLM06 | Excessive Agency | `app/scenarios/llm06_excessive_agency.py` | `POST /llm06/agent-task` | `test_llm06_*` |
| LLM07 | System Prompt Leakage | `app/scenarios/llm07_prompt_leakage.py` | `POST /llm07/chat`, `POST /llm07/refund` | `test_llm07_*` |
| LLM08 | Vector and Embedding Weaknesses | `app/scenarios/llm08_vector_embedding.py` | `POST /llm08/rag-query` | `test_llm08_*` |
| LLM09 | Misinformation | `app/scenarios/llm09_misinformation.py` | `GET /llm09/ask` | `test_llm09_*` |
| LLM10 | Unbounded Consumption | `app/scenarios/llm10_unbounded_consumption.py` | `POST /llm10/generate` | `test_llm10_*` |

**Legacy / supplemental** (older OWASP revision categories or techniques now folded into
the categories above — clearly labeled, never presented as current): `GET
/legacy/model-theft`, `POST /legacy/insecure-plugin`, `POST
/legacy/indirect-prompt-injection` in `app/scenarios/legacy_supplemental.py`.

Every scenario endpoint's docstring documents: vulnerability description, educational
objective, safe/simulated behavior, an example request, the expected result, the
defensive mitigation, the logging/detection point, and its test case — read the module
source directly, or browse the same information interactively at `/docs`.

## Architecture

```text
llm-lab/
├── app/
│   ├── main.py                 # FastAPI app, router wiring, request-size/timing middleware
│   ├── config.py                # env-driven configuration, sandbox paths, limits
│   ├── models.py                # shared Pydantic request/response models
│   ├── safety.py                # command allowlist, sandboxed paths, redaction, rate limiting
│   └── scenarios/                # one module per OWASP category + legacy_supplemental.py
├── data/
│   ├── documents/                # synthetic trusted + poisoned RAG documents
│   ├── fake_secrets/             # synthetic-only fixtures (FAKE-ONLY- / LAB_SECRET_ / SYNTHETIC-)
│   └── sandbox/                  # the only path the app is ever allowed to read/write
├── tests/test_app.py             # pytest suite — 33 tests, no network/VM required
├── scripts/smoke_test.sh          # curl-based smoke test against the running VM
├── systemd/llm-owasp-lab.service  # hardened systemd unit installed on the VM
└── requirements.txt               # pinned: fastapi, uvicorn, pydantic
```

## Safety Model

Every control below is enforced in `app/safety.py`, not left to individual scenario
authors to remember:

- **No real shell execution, ever.** `simulate_command()` only recognizes a fixed
  allowlist (`id`, `whoami`, `pwd`, `uname`, `echo`) and returns hardcoded/derived output
  — it never calls `subprocess`, `os.system`, or `eval`. Anything else, including
  `rm -rf /`, is rejected and logged, not executed.
- **No arbitrary file access.** `resolve_sandbox_path()` resolves every user-supplied
  path against `data/sandbox/` and raises `HTTPException(400)` on any attempt to escape
  it (absolute paths, `..`, symlink tricks).
- **No unsafe deserialization.** The supply-chain (LLM03) scenario validates a manifest's
  pinning/hash metadata; it never unpickles or `eval`s anything.
- **No real secrets.** Every value returned anywhere in the API is prefixed
  `FAKE-ONLY-`, `LAB_SECRET_`, or `SYNTHETIC-`. A test (`test_llm02_secrets_are_synthetic_only`)
  asserts this.
- **No unbounded output.** `config.MAX_TEXT_LENGTH`, `MAX_OUTPUT_LENGTH`, and
  `MAX_REQUEST_BYTES` cap every request/response; LLM10's `/llm10/generate` clamps
  requested output size and never actually generates it.
- **Rate limiting + quotas.** In-memory per-client rate limiting
  (`RATE_LIMIT_REQUESTS` / `RATE_LIMIT_WINDOW_SECONDS`) and a per-key daily quota
  (`DAILY_QUOTA`), enforced before any "work" happens.
- **No outbound internet from the app.** Nothing in `app/` makes an HTTP request,
  installs a package, or resolves a DNS name at runtime.
- **OS-level defense in depth.** The systemd unit runs as an unprivileged `llmlab` user
  with `ProtectSystem=strict`, `ProtectHome=true`, and a single writable path
  (`data/sandbox`) — even a bug in the app can't write outside that directory.
- **Network isolation.** `llm01` sits on the lab's private, host-only/libvirt-isolated
  subnet like every other VM in this lab; it is provisioned with outbound internet
  access removed after package installation (see the Vagrantfile's `llm01` block).

## Testing Guide

```bash
# Local, in-process — no VM needed (what CI runs)
pip install -r labs/security/active-directory/base/llm-lab/requirements.txt --break-system-packages
pip install pytest httpx --break-system-packages
pytest labs/security/active-directory/base/llm-lab/tests/ -v

# Against the running VM, once it's up
LLM01_HOST=172.28.128.60 labs/security/active-directory/base/llm-lab/scripts/smoke_test.sh
```

The pytest suite (33 tests) covers: every scenario's vulnerable and defensive
behavior, the safety-module unit tests (command allowlist, sandbox-path traversal,
redaction, HTML encoding), input-size limits, rate limiting/quotas, and that
arbitrary-shell-execution and arbitrary-file-access attempts are refused rather than
silently succeeding.

## Defensive Controls Guide

Each scenario's `defensive_mode`/`enforce_authorization`/`redact`/`dry_run` parameter (see
the table above) demonstrates one concrete, working mitigation next to the vulnerable
default — instruction separation (LLM01), output redaction (LLM02), integrity hashing
(LLM04), output encoding (LLM05), an authorization allowlist (LLM06), moving business
logic out of the prompt (LLM07), authorization-aware retrieval filtering (LLM08),
citation/confidence requirements (LLM09), and bounded resource controls (LLM10) — so
learners can diff the two code paths directly instead of taking the fix on faith.

## Reset and Cleanup

```bash
# Reset in-memory scenario state (rate limits, ingested documents) — just restart the service
LAB_PROFILE=llm vagrant ssh llm01 -c "sudo systemctl restart llm-owasp-lab"

# Destroy just this VM
LAB_PROFILE=llm vagrant destroy llm01 -f
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `vagrant up llm01` says "machine not found" | `llm01` isn't in your active `LAB_PROFILE` | `LAB_PROFILE=llm vagrant up llm01` or `LAB_PROFILE=full vagrant up` |
| `curl` to port 8000 times out | Provisioning still running, or VM booted without network up yet | `LAB_PROFILE=llm vagrant ssh llm01 -c "systemctl status llm-owasp-lab"`; wait for `apt-get`/`pip` provisioning to finish |
| `systemctl status llm-owasp-lab` shows failed | Check `journalctl -u llm-owasp-lab -n 50 --no-pager` on the VM | Usually a venv/dependency issue — re-run `vagrant provision llm01` |
| `/docs` returns 404 | App didn't start (see above) | Same as above |

## Portfolio Note

This lab demonstrates: threat-modeling an LLM application against the current OWASP
taxonomy, building safety controls as a shared library rather than duplicating
allowlist/sandbox logic per scenario, keeping a training app's claims about its own
taxonomy self-verifying (`/owasp/categories`), and integrating a new intentionally
vulnerable service into an existing multi-VM lab without touching any of the other 10
VMs' provisioning.
