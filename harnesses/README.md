# Harness 定义目录

> Harness 是子Agent的**执行载体**，定义运行环境、绑定Skills、通信配置。
> 与 Skill（知识包/行为规范）互补：Skill 定义"怎么做"，Harness 定义"在哪做、用什么做"。

## 文件说明

| 文件 | 对应Agent | 说明 |
|------|----------|------|
| `orchestrator-harness.md` | pm-orchestrator | 主控器执行环境（工具绑定、通信配置、spawn规范） |
| `coder-harness.md` | pm-coder | 编程执行子Agent（spawn配置、prompt模板、通信协议） |
| `researcher-harness.md` | pm-researcher | 信息检索子Agent（spawn配置、prompt模板、通信协议） |
| `writer-harness.md` | pm-writer | 内容输出子Agent（spawn配置、prompt模板、通信协议） |

## 核心概念

```
┌──────────────────────────────────────────────────┐
│                    Harness                        │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐  │
│  │ 运行环境    │  │ Skill绑定   │  │ 通信配置    │  │
│  │ spawn参数   │  │ 加载优先级  │  │ HEARTBEAT  │  │
│  │ mode/turns │  │ 注入方式   │  │ send_msg   │  │
│  │ team_name  │  │ references │  │ recipient  │  │
│  └────────────┘  └────────────┘  └────────────┘  │
└──────────────────────────────────────────────────┘
         ↓ 绑定           ↓ 加载          ↓ 使用
┌────────────────┐ ┌──────────────┐ ┌──────────────┐
│  task 工具      │ │  SKILL.md    │ │  HEARTBEAT   │
│  (spawn子Agent) │ │  (行为规范)   │ │  (共享记忆)  │
└────────────────┘ └──────────────┘ └──────────────┘
```

## Skill vs Harness 的关系

| 维度 | Skill | Harness |
|------|-------|---------|
| **本质** | 知识包（SKILL.md） | 执行载体（运行环境） |
| **类比** | SOP手册 | 带工具箱的工作台 |
| **内容** | 角色定位、工作流程、输出模板 | spawn配置、工具绑定、通信协议、权限模式 |
| **文件** | `{agent}/SKILL.md` | `harnesses/{agent}-harness.md` |
| **注入方式** | 通过 prompt 或 use_skill | 通过 task 工具参数 |
| **生命周期** | 项目级（不随任务变化） | 任务级（每次spawn重新配置） |

## 设计原则

以下原则综合了 claw-code 和 Hive 的最佳实践：

### v1.1 原则（来自 claw-code）

| 原则 | 说明 |
|------|------|
| **状态机优先** | 每个子 Agent 有明确的生命周期状态（IDLE→SPAWNING→RUNNING→COMPLETED/BLOCKED/FAILED） |
| **事件优于文本** | Agent 间通信使用结构化事件，而非依赖自然语言解析 |
| **恢复优先于升级** | 已知失败模式先自动恢复一次，再考虑人工介入 |
| **部分成功是一等的** | 支持大部分完成但有瑕疵的中间态，带结构化降级报告 |
| **最小权限原则** | 每个 Agent 只授予完成任务所需的最少工具集 |
| **策略是可执行的** | 常见决策规则化，减少 ad-hoc 判断 |
| **证据驱动** | 每次恢复必须记录失败原因和恢复动作到 HEARTBEAT |

### v1.2 原则（来自 Hive）

| 原则 | 说明 |
|------|------|
| **Goal 是一等公民** | 目标不是字符串，而是结构化对象（加权标准 + 约束 + 上下文），贯穿全生命周期 |
| **三角验证** | 确定性规则 + 语义评估 + 人工判断，多信号收敛 = 可靠性 |
| **三层洋葱 Prompt** | Identity（静态）+ Narrative（动态）+ Focus（任务级），确保 Agent 不丢失上下文 |
| **渐进式披露** | Skill 按三层加载（Catalog → Instructions → Resources），控制 token 消耗 |
| **默认行为技能** | 6 个运行时行为技能自动注入，确保可预测的行为模式 |
| **条件路由** | 支持 On Success/On Failure/Conditional/Human Gate 四种边条件 |
| **预算意识** | 轮次和成本有上限，超预算时自动评估优先级并通知用户 |
| **演化改进** | 利用 HEARTBEAT 数据持续改进 Skill 和 Harness 规范 |

## 如何添加新Agent

1. 创建 `{agent}/SKILL.md` — 定义行为规范
2. 创建 `harnesses/{agent}-harness.md` — 定义执行载体
3. 在 `orchestrator-harness.md` 的子Agent Spawn 规范中引用
4. 在 `pm-orchestrator/SKILL.md` Phase 2 的任务类型映射表中注册
