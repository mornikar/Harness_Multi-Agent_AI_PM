<div align="center">

# AI-PM Multi-Agent Skill System

**v3.1 Ironforge** — 业内自创 Skill+Harness 双轨架构 · 多Agent协作开发框架

**知识包（Skill）与执行载体（Harness）彻底解耦** — 行为规范平台无关，运行配置按需适配

[![Release](https://img.shields.io/github/v/release/mornikar/Harness_Multi-Agent_AI_PM?label=Release&color=blue)](https://github.com/mornikar/Harness_Multi-Agent_AI_PM/releases/latest)
[![License](https://img.shields.io/github/license/mornikar/Harness_Multi-Agent_AI_PM?label=License)](https://github.com/mornikar/Harness_Multi-Agent_AI_PM/blob/main/LICENSE)
[![Skills](https://img.shields.io/badge/Skills-10+%E2%80%A2Engine-1A8CFF?label=Skills)](./pm-core/)
[![Architecture](https://img.shields.io/badge/Architecture-3_Layer-FF6B35?label=Architecture)](#三层架构)
[![Platform](https://img.shields.io/badge/Platform-Agnostic-2EA043?label=Platform)](./pm-core/platform-adapter.md)
[![Ironforge](https://img.shields.io/badge/Ironforge-Enterprise_Engineering-E23E57?label=Ironforge)](#v31-ironforge-三大支柱)

</div>

---

## 为什么这个架构不同？

> **现有的多Agent框架**大多把"Agent该做什么"和"Agent在哪跑"混在一起——换平台就得重写，加Agent就得复制粘贴，出问题了只能靠Agent自觉。
>
> **AI-PM v3.1 Ironforge** 首创 **Skill + Harness 双轨架构**，将行为规范与执行载体彻底解耦，并通过 Ironforge 企业工程化框架将软约束锻造成硬骨架：

| 传统多Agent框架 | AI-PM v3.1 Ironforge |
|:---|:---|
| 行为规范和平台配置耦合 | **Skill（知识包）与 Harness（执行载体）彻底分离** |
| 换平台 = 重写全部 Agent | 行为规范层**平台无关**，只改 Harness 适配层 |
| 加 Agent = 复制粘贴大量重复配置 | **base/ 公共层 + 特化层**，改一处生效全局 |
| 安全靠 prompt 告诉 Agent 不要做 | **三层权限强制执行**：物理阻断 > 逻辑拦截 > 行为自律 |
| 崩溃了靠 Agent 自己理解恢复 | **确定性检查点恢复** + 三级熔断 + 幂等性保障 |
| 心跳是给人看的 Markdown | **HEARTBEAT v2**：机器可解析 + 人可阅读双格式 |
| 每个 Agent 必须走全流程 | **能力驱动**：每个 Skill 可独立运行，编排是可选组合 |
| 上下文要么全有要么全无 | **三级自适应**：FULL / PARTIAL / MINIMAL 按需降级 |

---

## 三层架构

```
┌─────────────────────────────────────────────────────────────┐
│                  Layer 0 · pm-core（内核层）                  │
│                                                             │
│  上下文协议 · 生命周期 · 通信 · 恢复 · 平台抽象              │
│  🔒 安全：权限框架 + 敏感信息防护 + 审计日志                 │
│  🛡️ 稳定：检查点回滚 + 三级熔断 + 幂等性                    │
│  📊 可观测：HEARTBEAT v2 + 指标 + 追踪                      │
│                                                             │
│  所有 Skill 自动继承，无需显式配置                            │
├─────────────────────────────────────────────────────────────┤
│                Layer 1 · Skills（能力层）                     │
│                                                             │
│  10 个独立 Skill，每个可单独运行或被委托调用                  │
│  每个Skill有三模式工作流：MINIMAL / PARTIAL / FULL           │
│  ★ 行为规范（SKILL.md）平台无关，不绑定任何AI平台            │
│                                                             │
│  pm-orchestrator  ·  pm-backlog-manager  ·  pm-analyst      │
│  pm-planner       ·  pm-designer         ·  pm-runner       │
│  pm-coder         ·  pm-researcher       ·  pm-writer       │
│  web-design-engineer（独立挂载，pm-coder 可委托）            │
├─────────────────────────────────────────────────────────────┤
│              Layer 2 · Orchestrations（编排层）               │
│                                                             │
│  预定义编排模板，按需组合 Skills                              │
│  code-only · research-only · analysis-only · doc-only        │
│  full-pipeline · custom（用户自定义）                        │
└─────────────────────────────────────────────────────────────┘
```

## Skill + Harness 双轨架构

> **核心创新**：将 Agent 的"做什么"和"在哪跑"彻底分离，实现**知识复用**与**平台适配**的完全解耦。

```
┌──────────────────────────────────────────────────────────────┐
│                        双轨架构                               │
│                                                              │
│   Skill 轨道（知识包）              Harness 轨道（执行载体）   │
│   ┌───────────────────┐           ┌───────────────────┐     │
│   │ SKILL.md          │           │ 运行环境配置        │     │
│   │ 行为规范          │  ← 绑定 ─  │ spawn配置          │     │
│   │ 工作流程          │           │ 工具绑定            │     │
│   │ 输出模板          │           │ 通信协议            │     │
│   │ 禁止事项          │           │ 权限级别            │     │
│   │ references/       │           │ Skill加载策略       │     │
│   └───────────────────┘           └───────────────────┘     │
│        ↓ 平台无关                    ↓ 平台相关              │
│   写一次，所有平台可用           换平台只改这里               │
└──────────────────────────────────────────────────────────────┘
```

| 维度 | Skill（知识包） | Harness（执行载体） |
|------|----------------|-------------------|
| **本质** | SOP 手册 | 带工具箱的工作台 |
| **类比** | 烹饪菜谱 | 厨房设备配置 |
| **定义内容** | 角色定位、工作流程、输出模板、禁止事项 | spawn配置、工具绑定、通信协议、Skill加载策略 |
| **文件位置** | `{skills_root}/pm-{name}/SKILL.md` | `harnesses/{agent}-harness.md` |
| **平台绑定** | ❌ **无**（v3 平台无关） | ✅ **有**（适配特定AI平台） |
| **生命周期** | 项目级（不随任务变化） | 任务级（每次创建子Agent重新配置） |

### Harness 分层架构（v3.1 Ironforge 核心改造）

```
harnesses/
├── base/                  ← 公共层（7个文件，所有Agent共享）
│   ├── permission-framework.md      # 权限强制执行
│   ├── security-hooks.md            # 安全钩子
│   ├── audit-logging.md             # 审计日志
│   ├── checkpoint-protocol.md       # 检查点协议
│   ├── handoff-protocol.md          # 交接棒协议
│   ├── context-engineering.md       # 上下文工程
│   └── observability-config.md      # 可观测性配置
│
├── coder-harness.md       ← 特化层（只写Agent独有逻辑）
├── runner-harness.md      ← 继承base + 特化逻辑
└── ... 其余7个同理
```

**改造前后对比**：

| 指标 | 改造前 | 改造后 |
|------|--------|--------|
| 单个 Harness 代码量 | ~1055行 | ~100行（特化层） |
| 总代码量 | ~3000行（大量重复） | ~2100行（零重复） |
| 安全策略更新 | 改9个文件 | 改 `base/security-hooks.md` 1处 |
| 新增 Agent | 复制+删减 | 新建特化层，自动继承 base/ |

## v3.1 Ironforge 三大支柱

> **Ironforge（铁炉堡）** — 把软约束锻造成硬骨架。从"告诉Agent不要做"升级为"让Agent做不到"。

<table>
<tr>
<td width="33%" valign="top">

### 🔒 Fortify · 安全加固

**约束可执行**：每条安全规则必须有物理阻断机制

| 层 | 机制 | 强度 |
|---|------|------|
| 平台物理层 | spawn mode + blocked_tools | 最高（不可绕过） |
| Harness逻辑层 | 黄灯操作通知 + 拦截窗口 | 中（有监督） |
| SKILL.md行为层 | 编码规范·禁止事项 | 低（兜底） |
| 敏感信息防护 | 写入前正则扫描 | — |
| 审计日志 | JSONL + trace_id | — |

</td>
<td width="33%" valign="top">

### 🛡️ Stabilize · 稳定性加固

**故障可恢复**：每个步骤都有检查点，崩溃后确定性恢复

| 机制 | 关键设计 |
|------|---------|
| 检查点协议 | 3类检查点 + hash校验 |
| 三级熔断 | Agent→任务→项目 |
| 幂等性规范 | 0匹配=跳过 + pre_check |

> orchestrator 最严格（1次/15min熔断），只读Agent检查点少

</td>
<td width="33%" valign="top">

### 📊 Observe · 可观测性加固

**操作可追溯**：每个操作都有结构化记录

| 机制 | 关键设计 |
|------|---------|
| HEARTBEAT v2 | YAML + Markdown 双格式 |
| 指标收集 | C/G/H 三类指标 |
| 分布式追踪 | trace_id 贯穿全链路 |
| 自动监控 | 5条告警规则 |

</td>
</tr>
</table>

## 高解耦设计

### 能力驱动，而非流程驱动

> v3 核心变革：**每个 Skill 可独立运行**，编排是可选的组合层，不是强制的流程链。

| 使用方式 | 适用场景 | 示例 |
|------|---------|------|
| **单Skill** | 改Bug、调研、写文档 | "帮我改个Bug" → pm-coder |
| **预定义编排** | 需求分析、PRD | "梳理需求+拆解" → analysis-only |
| **全链路编排** | 完整项目开发 | "从0做个App" → full-pipeline |
| **自定义编排** | 灵活组合 | 自定义 YAML 编排模板 |

### 上下文自适应（三级降级）

| 等级 | 条件 | 行为 |
|------|------|------|
| **FULL** | 所有前置文档齐全 | 严格对齐，按流程验收 |
| **PARTIAL** | 部分文档存在 | 对齐已有，缺失从用户推导 |
| **MINIMAL** | 无前置文档 | 直接接收用户指令，轻量运行 |

### 平台抽象层

行为规范层（SKILL.md、pm-core/、orchestrations/）**不绑定任何特定AI平台**：

| 路径变量 | 说明 | 映射示例 |
|---------|------|---------|
| `{context_root}` | 项目上下文根目录 | `.workbuddy/`、`.cursor/`、`.cline/` |
| `{skills_root}` | Skills 安装目录 | `~/.workbuddy/skills/`、项目级 skills/ |

> 详见 [`pm-core/platform-adapter.md`](./pm-core/platform-adapter.md)

## 架构概览（全链路模式）

```
┌──────────────────────────────────────────────────────────────┐
│                   orchestrator 职责分层                        │
│                                                               │
│  【核心】上下文同步 · 结果收集 · 监听                          │
│  【全局】阶段切换 · 打回路由 · 用户交互 · 复盘                 │
│  【不做】需求/拆解/Skills/调度/编码/文档                       │
└──────────────────────────────┬───────────────────────────────┘
                               │
   ┌───────────────────────────┼──────────────────────────┐
   ▼                           ▼                          ▼
┌────────────┐          ┌────────────┐          ┌────────────┐
│  Phase 0   │          │  Phase 1   │          │  Phase 2   │
│  需求池管理 │────────→ │  分析→拆解  │────────→ │  原型设计   │
│  +MVP定义  │          │            │          │  （并行）   │
│  backlog   │          │ analyst    │          │ designer   │
│  -manager  │          │ → planner  │          │ （方向指标）│
└────────────┘          └─────┬──────┘          └─────┬──────┘
                              │                       │
                              │    ┌──────────────────┘
                              ▼    ▼
                       ┌────────────┐          ┌────────────┐
                       │  Phase 3   │          │  Phase 4   │
                       │  架构→开发  │────────→ │  打回循环   │
                       │  runner    │          │  orchestr.  │
                       │  → agents  │          │  最小回退   │
                       └─────┬──────┘          └─────┬──────┘
                             │                       │
                             ▼                       ▼
                       ┌────────────┐          ┌────────────┐
                       │  Phase 5   │          │  使用者     │
                       │  整合交付   │────────→ │  人工验收   │
                       └────────────┘          └────────────┘
```

## Skill 角色

| Skill | 核心职责 | 触发词 | 阶段 |
|-------|---------|--------|------|
| **pm-orchestrator** | 上下文同步 · 阶段切换 · 打回路由 | 开发、实现、搭建 | 全局 |
| **pm-backlog-manager** | 需求池管理 · 优先级排序 · MVP定义 | 需求池、优先级、MVP | P0 |
| **pm-analyst** | 需求澄清 · 约束提取 · Goal构建 | 需求澄清、范围确认 | P1 |
| **pm-planner** | 颗粒化拆解 · 依赖DAG · Skills分析 | 任务拆解、模块化、规划 | P1 |
| **pm-designer** | 原型设计 · 组件树 · 交互流程 | 原型设计、UI、线框图 | P2 |
| **pm-runner** | 调度执行 · 策略引擎 · 健康监控 | 调度、执行、运行 | P3 |
| **pm-coder** | 编码 · 调试 · 重构 · 测试 | 编码、实现、开发、调试 | P3 |
| **pm-researcher** | 技术调研 · 竞品分析 · 方案选型 | 调研、对比、选型 | P3 |
| **pm-writer** | PRD · 技术文档 · API文档 · CHANGELOG | 文档、PRD、撰写 | P3 |
| **web-design-engineer** | 视觉设计工程 · 反AI陈词滥调 · oklch | 网页设计、UI美化、配色 | P3 |

## 核心特性

<details>
<summary><b>Guides/Sensors 双闭环控制模型</b></summary>

Agent = 模型 + Harness。**Guides（前馈控制）** 在行动前注入标准，**Sensors（反馈控制）** 在行动后检查结果：

- **Guides 前馈**：SKILL.md + Goal 标准 + code-standards + review-protocol — 提高"一次做对"的概率
- **Sensors 反馈（计算型）**：H1-H9 Hooks + 关键词匹配 — Coder 自执行，确定性检查
- **Sensors 反馈（推理型）**：语义评估 + Spec 深度对照 — Orchestrator 验收时执行

> 详见：[`harnesses/coder-harness.md`](./harnesses/coder-harness.md)

</details>

<details>
<summary><b>三层 Prompt 洋葱模型</b></summary>

子 Agent 的上下文 = 三层叠加，确保始终知道"我是谁、做了什么、现在做什么"：

| 层 | 内容 | 特点 |
|---|------|------|
| Layer 1 — Identity | SKILL.md + Goal（角色定位、职责、约束） | 静态，永不改变 |
| Layer 2 — Narrative | HEARTBEAT + context_pool（项目状态、已完成阶段） | 每次启动自动拼接 |
| Layer 3 — Focus | orchestrator 的任务描述（具体任务、验收标准） | 每次切换任务时替换 |

</details>

<details>
<summary><b>推理验证点（Reasoning Checkpoints）</b></summary>

在关键决策节点，Agent 必须暂停推理、输出显式验证步骤，防止"想当然"错误沿链路放大。10 个 RC 覆盖 Phase 0~5。

</details>

<details>
<summary><b>协作奖励模型</b></summary>

评估 Agent 贡献时，不只看个体产出质量，还看其对团队协作的正外部性：个体质量 50% + 协作外部性 50% + 惩罚项。

</details>

<details>
<summary><b>经验积累四级分类</b></summary>

L1 微模式（项目级）→ L2 规则强化（全局策略引擎）→ L3 Skill增强（SKILL.md/references/）→ L4 独立Skill（全局可用）。经验孵化期→验证期→固化期→淘汰期全生命周期管理。

</details>

<details>
<summary><b>第二阶段并行</b></summary>

Phase 1 完成后，Phase 2 和 Phase 3 **同时开始**。Phase 3 不等 Phase 2 完成；原型定型后切换为对齐原型开发。减少等待时间，开发与原型设计并行推进。

</details>

<details>
<summary><b>模块化验收 + 打回循环</b></summary>

- 验收以模块为单位（非任务级）
- 跨阶段打回由 orchestrator 决策，"最小必要回退点"
- pm-runner 只能上报，不能自行决定打回
- 自动化验收标准：代码质量 + 功能验证 + 集成验证

</details>

<details>
<summary><b>上下文池（Context Pool）</b></summary>

全局共享项目上下文，细粒度访问权限（读写/只读/不可见），支持版本化变更追踪和数据一致性保障。

</details>

## 目录结构

```
AI_PM_SKills/
├── README.md                          # 本文件
├── ARCHITECTURE.md                    # 架构详细说明
├── ARCHITECTURE_SPEC.md               # 架构说明书
├── ENTERPRISE_FRAMEWORK.md            # Ironforge 企业工程化框架
├── QUICKSTART.md                      # 快速开始
├── SYSTEM_ANALYSIS.md                 # 系统分析
│
├── pm-core/                           # 🧠 内核层（Layer 0）
│   ├── SKILL.md
│   ├── context-protocol.md            # 上下文自适应协议
│   ├── agent-lifecycle.md             # Agent 生命周期规范
│   ├── platform-adapter.md            # 平台抽象层（★ 关键创新）
│   ├── security/                      # 🔒 安全（v3.1 Ironforge）
│   │   ├── permission-framework.md
│   │   ├── secrets-protection.md
│   │   └── audit-protocol.md
│   ├── stability/                     # 🛡️ 稳定（v3.1 Ironforge）
│   │   ├── checkpoint-protocol.md
│   │   ├── circuit-breaker.md
│   │   └── idempotency.md
│   ├── observability/                 # 📊 可观测（v3.1 Ironforge）
│   │   ├── heartbeat-v2.md
│   │   ├── metrics-protocol.md
│   │   └── trace-protocol.md
│   ├── references/
│   └── templates/
│
├── pm-orchestrator/                   # 主控器 Skill
├── pm-backlog-manager/                # 需求池管理 Skill
├── pm-analyst/                        # 需求澄清 Skill
├── pm-planner/                        # 任务拆解 Skill
├── pm-designer/                       # 原型设计 Skill
├── pm-runner/                         # 调度执行 Skill
├── pm-coder/                          # 编码执行 Skill
├── pm-researcher/                     # 信息检索 Skill
├── pm-writer/                         # 文档输出 Skill
├── web-design-engineer/               # 🎨 视觉设计工程（v3.1 新增）
│
├── orchestrations/                    # 🔄 编排模板（Layer 2）
│   ├── code-only.yaml
│   ├── research-only.yaml
│   ├── analysis-only.yaml
│   ├── doc-only.yaml
│   ├── full-pipeline.yaml
│   └── custom/
│
├── harnesses/                         # ⚙️ Harness 执行载体（★ 双轨架构）
│   ├── base/                          # 公共层（v3.1，7个文件）
│   ├── orchestrator-harness.md
│   ├── ...-harness.md                 # 各 Agent 特化层
│   └── web-design-engineer-harness.md
│
└── scripts/                           # 工具脚本
```

## 安装使用

```powershell
# 复制到用户级 Skills 目录
Copy-Item -Path "AI_PM_SKills\pm-*" `
  -Destination "{skills_root}\" -Recurse -Force
```

> 路径映射见 [`pm-core/platform-adapter.md`](./pm-core/platform-adapter.md)

直接对 AI 说出需求即可：

- "帮我做一个记账App" → 全链路编排
- "帮我改个Bug" → pm-coder 独立运行
- "调研下XX技术" → pm-researcher 独立运行
- "排一下需求优先级" → pm-backlog-manager 独立运行

## 扩展开发

<details>
<summary>添加新的子 Agent</summary>

1. 创建 `pm-{agent-name}/SKILL.md`（行为规范 — 平台无关）
2. 创建 `pm-{agent-name}/standalone-prompt.md`（独立运行 prompt）
3. 在 `harnesses/` 下创建 `{agent-name}-harness.md`（特化层 — 只写差异，自动继承 base/）
4. 在 `pm-runner/SKILL.md` 中注册
5. 更新 `orchestrations/` 相关编排模板
6. 更新本 README 的 Skill 角色表

> ★ Skill 和 Harness 独立维护，互不影响

</details>

<details>
<summary>适配新的 AI 平台</summary>

1. 在 `pm-core/platform-adapter.md` 中添加路径映射
2. 在 `harnesses/` 下创建适配新平台的 Harness 文件
3. **SKILL.md 和 pm-core/ 无需修改**（已平台无关）

> ★ 这就是双轨架构的价值：换平台只动 Harness，Skill 层零改动

</details>

## 版本历史

| 版本 | 日期 | 变更摘要 |
|------|------|---------|
| **v3.1** | 2026-04-24 | **Ironforge 企业工程化**：Skill+Harness双轨 + base/公共层 + 安全/稳定/可观测三大支柱 + web-design-engineer |
| **v3.0** | 2026-04-23 | **高解耦架构**：能力驱动 + Skill独立运行 + 三层架构 + 上下文自适应 + 平台无关 |
| **v2.1** | 2026-04-23 | 架构优化：Phase 0 + 第二阶段并行 + 原型方向指标 + 自动化验收 |
| **v2.0** | 2026-04-22 | 架构重构：五阶段 + 三段式解耦 + 4个新Agent + Harness方向盘 |
| **v1.0** | 2026-04-20 | 初始版本：7阶段流程 + 4个核心Agent |

> 详见 [Releases](https://github.com/mornikar/Harness_Multi-Agent_AI_PM/releases)

## 许可证

[MIT License](./LICENSE)
