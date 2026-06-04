# Commands

## VMware Ubuntu 24.04 VM Setup For N=61

Use a native Linux VM for N=61. WSL2 + Docker Desktop can exhaust the ARP neighbor table under N=61 all-to-all container networking, which shows up as SSH timeouts and Diablo secondary connection timeouts.

### Host Packages

Run on the Ubuntu VM host:

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl git openssh-client docker.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"
```

Log out and log back in, or run:

```bash
newgrp docker
docker ps
```

If `docker ps` still says permission denied, temporarily prefix Docker commands with `sudo`.

### Clone And Prepare Repo

```bash
git clone --recurse-submodules https://github.com/ultrabababa/stabl-benchmark.git
cd stabl-benchmark
git checkout main
git pull
git submodule update --init --recursive
```

Create the local SSH key pair used inside the Docker test network. The private key is intentionally ignored by Git and must not be committed.

```bash
ssh-keygen -t ed25519 -N '' -f stabl_key
chmod 600 stabl_key
```

`stabl_key.pub` is copied into `stabl-node` as `authorized_keys`; `stabl_key` is copied into `stabl-runner` as `/home/ubuntu/.ssh/id_rsa`.

### Build Images

Do not use `docker compose ... up --build` for these generated N=31/N=61 compose files. `Dockerfile.runner` depends on the local `stabl-node:latest` image, and Compose may build the two images in parallel.

Build in order from the repository root:

```bash
docker build -t stabl-node:latest -f Dockerfile .
docker build -t stabl-runner:latest -f Dockerfile.runner .
```

If Docker reports permission denied, rerun with `sudo` or fix the Docker group login.

### Start N=61 Containers

Start the N=61 network from the repository root:

```bash
docker compose -f minion/docker-compose-n61.yml up -d --no-build
docker compose -f minion/docker-compose-n61.yml ps
```

Use `--no-build` because the images were already built in the correct order. Avoid `--project-directory .` for this startup command because the compose file has a relative runner volume:

```yaml
volumes:
  - ../:/project
```

With `-f minion/docker-compose-n61.yml`, that mounts the repository root into the runner container as `/project`.

### Verify SSH

```bash
docker exec minion-runner-1 ssh -T -o ConnectTimeout=5 ubuntu@10.30.10.1 true
docker exec minion-runner-1 ssh -T -o ConnectTimeout=5 ubuntu@10.30.20.1 true
docker exec minion-runner-1 ssh -T -o ConnectTimeout=5 ubuntu@10.30.30.2 true
```

If this fails with host-key prompts, use:

```bash
docker exec minion-runner-1 ssh -T \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  -o ConnectTimeout=5 \
  ubuntu@10.30.20.1 true
```

If it fails with `Permission denied (publickey)`, rebuild both images after regenerating `stabl_key` / `stabl_key.pub`, then recreate the compose network:

```bash
docker compose -f minion/docker-compose-n61.yml down
docker build -t stabl-node:latest -f Dockerfile .
docker build -t stabl-runner:latest -f Dockerfile.runner .
docker compose -f minion/docker-compose-n61.yml up -d --no-build
```

### Run N=61 Quick Verify

Run Minion inside the runner container so paths and SSH identity match the Docker network:

```bash
docker exec -it minion-runner-1 bash
cd /project/minion
rm -f /tmp/minion-ssh.ubuntu@10.30.*:22.sock

ASONNINO_HOTSTUFF_CLIENT_MEMPOOL_MODE=single \
MINION_DIABLO_WAIT_TIMEOUT_SEC=300 \
NODE_COUNT=61 \
./bin/middleware \
  setups/hotstuff-quick-verify-n61.yaml \
  setups/setup-61.txt \
  asonnino-hotstuff none 0 1 \
  2>&1 | tee /tmp/n61_quick_verify_$(date +%Y%m%d-%H%M%S).log
```

After a successful build/deploy once, rerun the quick verify with `--skip-build`:

```bash
ASONNINO_HOTSTUFF_CLIENT_MEMPOOL_MODE=single \
MINION_DIABLO_WAIT_TIMEOUT_SEC=300 \
NODE_COUNT=61 \
./bin/middleware \
  setups/hotstuff-quick-verify-n61.yaml \
  setups/setup-61.txt \
  asonnino-hotstuff none 0 1 \
  --skip-build
```

### Fix `failed to prepare build` / asdf Clone Errors

Symptom:

```text
Cloning into '/home/ubuntu/.asdf'...
fatal: unable to access 'https://github.com/asdf-vm/asdf.git/': GnuTLS recv error (-54): Error in the pull function.
./bin/middleware: failed to prepare build
```

This happens in the builder container (`10.30.30.2`) while cloning `asdf` from GitHub. It is usually a transient container-to-GitHub TLS/network failure. It can also leave a partial `/home/ubuntu/.asdf` directory behind.

First pull the latest repo because `prepare-build` now cleans partial asdf state and retries:

```bash
cd ~/stabl-benchmark
git pull
git submodule update --init --recursive
```

Then clear the partial asdf directory in the builder and rerun:

```bash
docker exec minion-builder-1 rm -rf /home/ubuntu/.asdf /home/ubuntu/.config/asdf-direnv

docker exec -it minion-runner-1 bash
cd /project/minion
rm -f /tmp/minion-ssh.ubuntu@10.30.*:22.sock

ASONNINO_HOTSTUFF_CLIENT_MEMPOOL_MODE=single \
MINION_DIABLO_WAIT_TIMEOUT_SEC=300 \
NODE_COUNT=61 \
./bin/middleware \
  setups/hotstuff-quick-verify-n61.yaml \
  setups/setup-61.txt \
  asonnino-hotstuff none 0 1
```

If it fails repeatedly at GitHub access, test from the builder:

```bash
docker exec -it minion-builder-1 bash -lc '
git ls-remote https://github.com/asdf-vm/asdf.git HEAD
'
```

If that command fails, fix VM/container outbound network or retry after the network stabilizes. Do not use `--skip-build` until the first full build has completed successfully.

### Use The VM Host Proxy From Containers

If the VM host can access GitHub or `proxy.golang.org` only through a local proxy, the Docker containers will not automatically inherit it. A host proxy bound only to `127.0.0.1` is especially not visible from containers because container `127.0.0.1` is the container itself.

First find the Docker bridge gateway visible from the builder:

```bash
GW=$(sudo docker exec stabl-benchmark-builder-1 sh -lc "ip route | awk '/default/ {print \$3}'")
echo "$GW"
```

Use the actual container name from `sudo docker ps` if your compose project is not named `stabl-benchmark`.

Make sure the proxy application on the VM host listens on LAN / `0.0.0.0`, not only `127.0.0.1`. Then test from the builder. Replace `7892` with the actual proxy port:

```bash
sudo docker exec stabl-benchmark-builder-1 bash -lc \
  "curl -I -x http://$GW:7892 https://proxy.golang.org"
```

If that test succeeds, persist proxy variables for Minion remote scripts. `prepare-build` and the apt build helper load `~/.minion-env`, so these variables are visible even when commands are started through SSH:

```bash
sudo docker exec stabl-benchmark-builder-1 bash -lc "cat > /home/ubuntu/.minion-env <<EOF
HTTP_PROXY=http://$GW:7892
HTTPS_PROXY=http://$GW:7892
http_proxy=http://$GW:7892
https_proxy=http://$GW:7892
NO_PROXY=localhost,127.0.0.1,10.30.0.0/16
no_proxy=localhost,127.0.0.1,10.30.0.0/16
GOPROXY=https://proxy.golang.org,direct
EOF
chown ubuntu:ubuntu /home/ubuntu/.minion-env"
```

Verify through the same SSH path used by Minion:

```bash
sudo docker exec stabl-benchmark-runner-1 ssh -T \
  -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null \
  ubuntu@10.30.30.2 \
  '. ~/.minion-env; env | grep -i proxy; curl -I https://proxy.golang.org'
```

If Go already cached a failed toolchain download, clear it before rerunning:

```bash
sudo docker exec stabl-benchmark-builder-1 rm -rf \
  /home/ubuntu/go/pkg/mod/cache/download/golang.org/toolchain \
  /home/ubuntu/.cache/go-build
```

### Fix `tar: diablo: Cannot stat`

Symptom:

```text
tar: diablo: Cannot stat: No such file or directory
./bin/middleware: failed to create diablo-src.tar.gz
```

This means Minion could not find the `diablo` source directory while packaging build inputs. In a normal clone the sources are sibling submodules of `minion`, so the runner must see:

```text
/project/diablo
/project/hotstuff
/project/asonnino-hotstuff
/project/minion
```

First pull the latest repo because `middleware` now searches both `minion/diablo` and `../diablo`:

```bash
cd ~/stabl-benchmark
git pull
git submodule update --init --recursive
```

Then verify the runner mount and submodules:

```bash
docker exec minion-runner-1 bash -lc '
cd /project/minion
pwd
ls -ld ../diablo ../hotstuff ../asonnino-hotstuff
'
```

If `/project/diablo` is missing, the host clone is incomplete:

```bash
cd ~/stabl-benchmark
git submodule update --init --recursive
```

If `/project` is not the repository root, recreate the network without `--project-directory .`:

```bash
docker compose -f minion/docker-compose-n61.yml down
docker compose -f minion/docker-compose-n61.yml up -d --no-build
```

### Cleanup And Recreate Network

```bash
docker compose -f minion/docker-compose-n61.yml down
rm -f /tmp/minion-ssh.ubuntu@10.30.*:22.sock
docker compose -f minion/docker-compose-n61.yml up -d --no-build
```

## N=31 HotStuff Baseline

Use single-mempool mode for the N=31 baseline. The old default round-robin mode fans out submissions across all 31 mempool endpoints and caused client-to-mempool TCP timeouts.

```bash
cd /mnt/d/project/minion
rm -f /tmp/minion-ssh.ubuntu@10.30.*:22.sock

ASONNINO_HOTSTUFF_CLIENT_MEMPOOL_MODE=single \
MINION_DIABLO_WAIT_TIMEOUT_SEC=300 \
NODE_COUNT=31 \
./bin/middleware \
  setups/hotstuff-quick-verify-n31.yaml \
  setups/setup-31.txt \
  asonnino-hotstuff none 0 1 \
  2>&1 | tee /tmp/n31_single_mempool_$(date +%Y%m%d-%H%M%S).log
```

Analyze the newest result archive:

```bash
python3 analyze_results.py "$(ls -t asonnino-hotstuff-1-5-31-none-0-1_*.results.tar.gz | head -1)"
```

Expected quick-verify baseline result at the current 10 TPS workload:

```text
Planned Interactions: 300
Submitted:            300
Committed:            300
Aborted:              0
Errors:               0
```

## N=31 TPS Sweep

Keep `ASONNINO_HOTSTUFF_CLIENT_MEMPOOL_MODE=single` enabled, then change `setups/hotstuff-quick-verify-n31.yaml` one step at a time:

```yaml
workloads:
  - number: 5
    client:
      behavior:
        - interaction: !transfer { from: *account, to: *account }
          load:
            0: 2
            30: 2
```

Total TPS is `number * load`.

```text
10 TPS  = number 5, load 2
20 TPS  = number 5, load 4
40 TPS  = number 5, load 8
80 TPS  = number 5, load 16
100 TPS = number 5, load 20
```

Run each step with the same baseline command above. Stop when `Errors > 0` or `Committed < Submitted`; the previous zero-error step is the stable N=31 throughput bound.

Latest 100 TPS single-mempool run:

```text
asonnino-hotstuff-1-5-31-none-0-1_2026-05-31-17-47-48.results.tar.gz
Planned:   2995
Submitted: 2995
Committed: 2995
Errors:    0
Latency:   avg 2536.2 ms, p50 1013.2 ms, p90 8026.0 ms, p99 12040.6 ms
```

Interpretation: N=31 can complete the 100 TPS target load in single-mempool mode, but the per-second submitted curve is bursty. Use this as evidence of successful completion at target load, not as evidence of perfectly smooth 100 TPS pacing.

## N=31 Long Benchmark

`setups/hotstuff-benchmark-n31.yaml` is an 800-second benchmark at 80 TPS (`5 * 16`). It is not equivalent to the 100 TPS quick-verify run.

```bash
cd /mnt/d/project/minion

ASONNINO_HOTSTUFF_CLIENT_MEMPOOL_MODE=single \
MINION_DIABLO_WAIT_TIMEOUT_SEC=1800 \
NODE_COUNT=31 \
./bin/middleware \
  setups/hotstuff-benchmark-n31.yaml \
  setups/setup-31.txt \
  asonnino-hotstuff none 0 1 \
  --skip-build
```

Observed result at 200 TPS:

```text
asonnino-hotstuff-1-5-31-none-0-1_2026-05-31-18-19-47.results.tar.gz
Planned:   160000
Submitted: 160000
Committed: 84267
Errors:    62393
```

Interpretation: the adapter can submit the full 200 TPS workload in single-mempool mode, but the chain/confirmation path does not remain stable for an 800-second run. Use 100 TPS as the validated completed-load result until a long-run TPS sweep establishes a higher stable bound.

## N=31 Crash-No-Recovery

Fault-injection observer runs require:

- observer primary port `5001` in `script/local/deploy-diablo-observer.pm`;
- fault-mode startup order `chain -> Diablo primary -> observers -> Diablo secondaries`.

```bash
cd /mnt/d/project/minion

ASONNINO_HOTSTUFF_CLIENT_MEMPOOL_MODE=single \
MINION_DIABLO_WAIT_TIMEOUT_SEC=1800 \
NODE_COUNT=31 \
./bin/middleware \
  setups/hotstuff-benchmark-n31.yaml \
  setups/setup-31.txt \
  asonnino-hotstuff crash-no-recovery 10 1 \
  --skip-build
```

If the observer still exits, inspect one chain node:

```bash
docker exec minion-chain31-1 bash -lc '
cat /home/ubuntu/deploy/diablo-observer/primary
tail -120 /home/ubuntu/deploy/diablo-observer/err
'
```

Also verify the Diablo primary listener:

```bash
docker exec minion-client1-1 bash -lc '
ps -ef | grep "[d]iablo primary" || true
ss -ltnp 2>/dev/null | grep ":5001" || true
'
```

## Failure Reproduction

To intentionally reproduce the old N=31 failure mode, omit `ASONNINO_HOTSTUFF_CLIENT_MEMPOOL_MODE=single` so the adapter uses round-robin endpoint selection. The observed bad run was:

```text
asonnino-hotstuff-1-5-31-none-0-1_2026-05-31-13-08-43.results.tar.gz
Planned:   300
Submitted: 60
Committed: 42
Errors:    240
```

The dominant log signature was repeated Diablo secondary submit-stage failures:

```text
dial 10.30.10.x:250xx failed: dial tcp 10.30.10.x:250xx: i/o timeout
```
