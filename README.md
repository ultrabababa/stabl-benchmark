# STABL Benchmark — HotStuff Fault-Injection Evaluation

A completed benchmark-integration project for evaluating an existing 2-chain HotStuff implementation under controlled faults. The project adapts the STABL/Diablo workflow to `asonnino-hotstuff`, separates mempool admission from consensus commitment, automates local multi-node experiments, and analyzes behavior under crash and network-partition scenarios.

> Scope: this project extends existing benchmarking/orchestration frameworks and an existing consensus implementation. It does **not** claim to implement HotStuff or STABL from scratch.

## What was implemented

- **Native Diablo adapter for `asonnino-hotstuff`**
  - deterministic 9-byte interaction payloads;
  - length-prefixed TCP submission to the Rust mempool;
  - HTTP polling through a commit-status bridge;
  - `submit` is recorded after successful mempool admission, while `commit` is reported only after matching consensus-commit evidence is observed.
- **Fault-aware experiment lifecycle in Minion**
  - permanent crash (`crash-no-recovery`);
  - crash followed by recovery (`crash`);
  - network partition using Linux `tc/netem`;
  - reproducible Docker topologies and setup files for N=10, N=22, N=31, and N=61 experiments.
- **Analysis and visualization tooling**
  - planned / submitted / committed / aborted / error accounting from `results.json`;
  - committed-to-submitted and committed-to-planned completion ratios;
  - average, P50, P90, and P99 commit latency;
  - submitted/committed throughput over time and fault-oriented plotting utilities.

The formal project evaluation also included STABL's redundant-client Byzantine Node Tolerance setup. That experiment measures the cost/behavior of the secure-client fan-out policy; it should not be read as evidence of a retained malicious-validator experiment.

## System flow

```text
Minion orchestrator
    |
    +-- deploy / start / stop / collect over SSH
    +-- schedule crash / recovery / tc-netem faults
    |
Diablo Primary -> Diablo Secondaries
                     |
                     | deterministic payload
                     v
              asonnino adapter
                     |
                     | framed TCP
                     v
              HotStuff mempool
                     |
                     v
                 consensus
                     |
                     | committed-batch evidence
                     v
            Commit-Status Bridge
                     |
                     | HTTP status polling
                     v
              Diablo result events
                     |
                     v
          analysis / plots / summaries
```

The important measurement boundary is deliberate: a successful socket write proves **admission**, not **consensus commitment**.

## Repository structure and ownership boundary

| Path | Role | Project-specific work |
| --- | --- | --- |
| `minion/` | STABL experiment orchestration | deployment adapters, fault lifecycle, observer integration, scale-specific setup/compose files, analysis/plotting utilities |
| `diablo/` | distributed workload generation | `nasonninohotstuff` adapter and commit-status integration |
| `asonnino-hotstuff/` | existing Rust 2-chain HotStuff implementation | small benchmark/fault-enablement changes; consensus protocol itself is upstream work |
| `hotstuff/` | existing Go HotStuff implementation | benchmark-oriented integration/fixes; protocol implementation is upstream work |
| `docker-compose.yml` | local N=10 lab topology | chain/client/builder/runner network |
| `docs/RUNBOOK.md` | historical experiment runbook | commands, troubleshooting notes, and recorded observations from development/evaluation |

The four component directories are Git submodules and are pinned deliberately. Clone recursively so the exact integration versions are checked out.

## Reproduce the local environment

Prerequisites: Linux (or a Linux VM), Docker with the Compose plugin, Git, and OpenSSH client tools.

```bash
git clone --recurse-submodules https://github.com/ultrabababa/stabl-benchmark.git
cd stabl-benchmark
git submodule update --init --recursive
```

Generate a local SSH key pair used only inside the benchmark Docker network. Both files are intentionally ignored by Git.

```bash
ssh-keygen -t ed25519 -N '' -f stabl_key
chmod 600 stabl_key
```

Build the images in order because the runner image is based on `stabl-node:latest`:

```bash
docker build -t stabl-node:latest -f Dockerfile .
docker build -t stabl-runner:latest -f Dockerfile.runner .
```

Start the root N=10 topology:

```bash
docker compose up -d --no-build
docker compose ps
```

Scaled N=22/N=31/N=61 topologies, benchmark commands, fault-run examples, troubleshooting, and analysis commands are preserved in [`docs/RUNBOOK.md`](docs/RUNBOOK.md).

Typical result analysis is performed from the Minion submodule:

```bash
cd minion
python3 analyze_results.py <result-archive.results.tar.gz>
```

## Evaluation scope

The project was used for controlled local experiments at N=10, N=22, N=31, and N=61 with scale-specific operating points. Fault runs include permanent crash, recoverable crash, and network partition; analysis focuses on delivered work, latency distribution, and the shape of recovery/degradation rather than only fault-free peak throughput.

Important limitations:

- experiments ran in Docker on a single host/VM rather than one physical/cloud host per validator;
- larger committees encountered host/network capacity effects such as socket/neighbor-table pressure;
- N=31/N=61 used a more conservative mempool-selection policy than smaller configurations, so cross-scale results are not a strict one-variable scalability benchmark;
- the workload uses a small synthetic payload and does not model application execution or state growth;
- the retained formal evaluation used one long run per configuration, so reported values are descriptive observations rather than statistical estimates;
- commit observation is log/HTTP-bridge based and adds polling granularity to measured latency.

## Project status

The implementation and evaluation are complete. This repository is kept as the final reproducible integration/benchmark artifact; cleanup changes do not alter reported formal experiment data.
