# STABL/HotStuff Benchmark Environment

[English Version](#english-version)

这是一个基于 STABL (Simulation of Tolerant and Adversarial Blockchain Large-scale environments) 框架的实验环境，用于在受控的分布式 Docker 网络中，对基于 HotStuff 的共识协议实现进行注入故障、可扩展性及吞吐量/延迟性能的评估。

该项目集成并编排了以下主要组件（基于 Git Submodule）：
*   **[Minion](minion)**: 基于 Perl 的自动化部署和测试编排工具，负责处理集群调度、代码编译、网络故障注入 (`tc netem`) 以及结果收集。
*   **[Diablo](diablo)**: 一个分布式的区块链性能测试（Benchmarking）工具，负责向网络节点分发高吞吐量的事务（Transactions）。
*   **[HotStuff (relab)](hotstuff)**: `relab/hotstuff` 的 Go 语言实现版本，用于基线性能及基础故障模式的验证。
*   **[asonnino-hotstuff](asonnino-hotstuff)**: DiemBFT 核心使用的 2-chain HotStuff 变体的 Rust 开源实现。

## 主要特性

1.  **自动化多节点 Docker 部署**: 利用 `docker-compose.yml` 快速拉起本地测试网络（默认 N=10，支持 N=22/31/61 等），具备 `NET_ADMIN` 权限用于网络故障模拟。
2.  **故障注入测试 (Fault Injection)**:
    *   `crash`: 节点崩溃并在随后恢复重启。
    *   `crash-no-recovery`: 节点永久性崩溃（例如 $f=3$ 或 $f=4$）。
    *   `partition`: 网络分区（100% 丢包），并在一定时间后恢复。
    *   `byzantine` (冗余客户端): 测试安全客户端将事务广播到 $t_B+1$ 个副本的能力。
3.  **多目标实现适配**: 提供了对 `relab/hotstuff` 和 `asonnino-hotstuff` 的支持，包含原生的 Diablo 适配器 (`nasonninohotstuff`) 以及观察者脚本 (Observer) 以对齐事务确认语义。
4.  **性能可视化**: 提供 `plot_results.py` 等脚本处理结果压缩包，自动绘制包含故障发生点与恢复点在内的 TPS 与 Latency 折线图。

---

# English Version

This is an experimental environment based on the STABL (Simulation of Tolerant and Adversarial Blockchain Large-scale environments) framework. It is designed to evaluate HotStuff-based consensus protocol implementations under fault injection, scalability, and throughput/latency performance within a controlled distributed Docker network.

This project integrates and orchestrates the following main components (via Git Submodules):
*   **[Minion](minion)**: A Perl-based automated deployment and test orchestration tool. It handles cluster scheduling, code compilation, network fault injection (`tc netem`), and result collection.
*   **[Diablo](diablo)**: A distributed blockchain benchmarking tool responsible for distributing high-throughput transactions to the network nodes.
*   **[HotStuff (relab)](hotstuff)**: The Go implementation of `relab/hotstuff`, used for baseline performance and basic fault mode verification.
*   **[asonnino-hotstuff](asonnino-hotstuff)**: The open-source Rust implementation of the 2-chain HotStuff variant used at the core of DiemBFT.

## Key Features

1.  **Automated Multi-Node Docker Deployment**: Quickly spins up a local test network (default N=10, supporting N=22/31/61, etc.) using `docker-compose.yml`, equipped with `NET_ADMIN` capabilities for network fault simulation.
2.  **Fault Injection**:
    *   `crash`: Nodes crash and subsequently recover/restart.
    *   `crash-no-recovery`: Permanent node crashes (e.g., $f=3$ or $f=4$).
    *   `partition`: Network partition (100% packet loss), recovering after a specific duration.
    *   `byzantine` (redundant clients): Evaluates the ability of secure clients to broadcast transactions to $t_B+1$ replicas.
3.  **Multi-Implementation Adaptation**: Provides support for both `relab/hotstuff` and `asonnino-hotstuff`, including native Diablo adapters (`nasonninohotstuff`) and observer scripts to align transaction confirmation semantics.
4.  **Performance Visualization**: Includes scripts like `plot_results.py` to process result archives, automatically generating TPS and Latency line charts that highlight fault injection and recovery timelines.