# 🚀 AI PM Skills 快速入门指南

> 5分钟上手，让AI产品经理团队为你干活。

---

## 一、最小可行流程（5分钟上手）

你只需要说一句话，剩下的交给系统。

```
你："帮我做一个待办事项Web应用"
```

系统自动完成：

| 步骤 | 发生了什么 | 你需要做什么 |
|:----:|-----------|------------|
| ① | **orchestrator 自动触发** — 识别到"做一个"，加载 pm-orchestrator Skill | 无 |
| ② | **需求澄清** — orchestrator 向你确认产品类型、核心功能、技术偏好 | 回答几个问题 |
| ③ | **自动拆解+执行** — 拆成调研→设计→编码→文档等子任务，多个Agent并行干活 | 等待 |
| ④ | **关键节点确认** — 架构方案、最终交付 | 看一眼，点头或提意见 |
| ⑤ | **交付** — 代码+文档+测试，一步到位 | 验收 |

> **核心理念**：你是产品经理，AI是你的团队。你说需求，团队执行，你只在关键决策点介入。

---

## 二、第一次使用前的准备

### 环境检查清单

| # | 检查项 | 验证方法 | 预期结果 |
|---|--------|---------|---------|
| 1 | WorkBuddy/OpenClaw 已安装 | 打开 WorkBuddy 客户端 | 能正常对话 |
| 2 | 4个核心 Skill 目录存在 | 查看项目目录 | `pm-orchestrator/` `pm-coder/` `pm-researcher/` `pm-writer/` 各有 SKILL.md |
| 3 | ClawHub CLI 可用 | 终端执行 `clawhub list` | 返回已安装的 Skill 列表 |
| 4 | shared 目录完整 | 查看项目目录 | `shared/references/` 和 `shared/templates/` 存在 |
| 5 | Harness 定义存在 | 查看 `harnesses/` 目录 | 5个 .md 文件（含 README） |

### 目录结构速览

```
你的项目/
├── pm-orchestrator/       # 🎯 主控器（项目经理）
│   └── SKILL.md
├── pm-coder/              # 💻 编码专家（程序员）
│   ├── SKILL.md
│   └── references/        # 详细规范（按需加载）
├── pm-researcher/         # 🔍 调研专家（分析师）
│   ├── SKILL.md
│   └── references/
├── pm-writer/             # 📝 文档专家（技术写作）
│   ├── SKILL.md
│   └── references/
├── harnesses/             # ⚙️ 执行载体配置
├── shared/                # 📦 共享资源
│   ├── references/        # 恢复配方、默认技能、健康检查协议等
│   └── templates/         # HEARTBEAT模板等
└── ARCHITECTURE.md        # 架构详细文档
```

---

## 三、关键概念速查

### Skill vs Harness

| | Skill | Harness |
|-|-------|---------|
| **一句话** | SOP手册——"做什么、怎么做" | 工作台——"用什么工具、在哪做" |
| **类比** | 厨师的菜谱 | 厨房的灶台+锅碗瓢盆 |
| **文件** | `pm-coder/SKILL.md` | `harnesses/coder-harness.md` |
| **变不变** | 项目级，基本不变 | 任务级，每次 spawn 重新配置 |

### HEARTBEAT 是什么

**类比：周报。**

- 项目经理不看每一行 Git 提交（Chat History），只看每周周报（HEARTBEAT）
- 两级结构：
  - **项目级** `.workbuddy/HEARTBEAT.md` — 全局看板，orchestrator 维护
  - **任务级** `T001-heartbeat.md` — 各子Agent维护自己的任务进度
- 关键特性：**即使对话丢失，HEARTBEAT 也在**，Agent 重启后通过它恢复状态

### 三角验证是什么

**类比：老板-质检-客户三道验收。**

| 验证层 | 类比 | 谁来做 | 做什么 |
|--------|------|--------|--------|
| 确定性规则 | 质检员量尺寸 | 子Agent自验证 | 格式检查、编译通过、测试通过 |
| 语义评估 | 老板看成品 | orchestrator | 对比成功标准打分，≥80%才算过 |
| 人工判断 | 客户签字 | 你 | 关键决策确认、最终交付审批 |

> 三层信号都通过，才算真正完成。任何一层不通过都会被打回。

---

## 四、orchestrator 内部流程图

```
用户说需求
    │
    ▼
┌──────────────────────────────────┐
│ Phase 1: 需求澄清                │ 👤 用户介入：确认需求范围
│ · 意图识别 / 范围界定 / 约束提取  │
│ · 构建 Goal（成功标准+约束条件）   │
└──────────────┬───────────────────┘
               ▼
┌──────────────────────────────────┐
│ Phase 2: 任务拆解 + Skills分析   │
│ · 拆解为独立子任务（T001, T002…） │
│ · 分析依赖关系 + 所需Skills       │
└──────────────┬───────────────────┘
               ▼
┌──────────────────────────────────┐
│ Phase 3: Skills管理              │
│ · 本地检查 → ClawHub搜索 → 安装   │
│ · 都没有 → 动态生成（兜底）        │
└──────────────┬───────────────────┘
               ▼
┌──────────────────────────────────┐
│ Phase 4: 团队创建 + 上下文池初始化 │
│ · team_create 建立通信通道        │
│ · 创建 HEARTBEAT + 上下文池文件   │
└──────────────┬───────────────────┘
               ▼
┌──────────────────────────────────┐
│ Phase 5: 子Agent调度             │ 👤 用户介入：架构审批（可选）
│ · 按依赖层级分批并行spawn         │
│ · 编码任务先规划(plan)→审批→再编码 │
│ · 策略引擎自动监控（超时/恢复/解除）│
└──────────────┬───────────────────┘
               ▼
┌──────────────────────────────────┐
│ Phase 6: 上下文同步 + 结果收集    │
│ · 接收子Agent完成/阻塞通知        │
│ · 三角验证（自验证→语义评估→人工）  │ 👤 用户介入：关键验收点
│ · 自动解除下游阻塞 → 派发下一批   │
└──────────────┬───────────────────┘
               ▼
┌──────────────────────────────────┐
│ Phase 7: 结果整合与交付          │ 👤 用户介入：最终交付确认
│ · 整合各子Agent输出              │
│ · 一致性检查 + 冲突解决           │
│ · shutdown 子Agent + team_delete │
└──────────────┬───────────────────┘
               ▼
┌──────────────────────────────────┐
│ Phase 7.5: 项目复盘（可选）       │
│ · 扫描问题 → 识别模式 → 经验沉淀  │
│ · 更新 lessons-learned / 策略    │
└──────────────────────────────────┘

👤 = 用户需要介入的节点
```

---

## 五、子Agent协作示例

### 场景：待办事项Web应用

用户说："帮我做一个待办事项Web应用，Vue3，支持增删改查。"

#### 任务拆解

| 任务ID | 描述 | 负责Agent | 依赖 |
|--------|------|----------|------|
| T001 | 技术调研（Vue3生态+最佳实践） | pm-researcher | - |
| T002 | 架构设计 | pm-orchestrator | T001 |
| T003 | 前端开发 | pm-coder | T002 |
| T004 | 后端开发 | pm-coder | T002 |
| T005 | 文档编写 | pm-writer | T003, T004 |

#### 执行时序

```
时间线 ──────────────────────────────────────────────────→

批次1:  [T001 技术调研]
              │
              ▼ T001完成，send_message(task_complete)
              
批次2:  [T002 架构设计]
              │
              ▼ T002完成
              
批次3:  [T003 前端开发] ║ [T004 后端开发]     ← 并行执行
              │                    │
              ▼ T003完成           ▼ T004完成
              
批次4:  [T005 文档编写]
              │
              ▼ T005完成
              
交付 ← 整合所有产出物
```

#### 实际调用示例

**1. orchestrator 创建团队：**
```
team_create(team_name="todo-app-team", description="待办事项Web应用开发")
```

**2. orchestrator spawn T001（调研）：**
```
task(
  subagent_name="code-explorer",
  name="researcher-T001",
  team_name="todo-app-team",
  mode="acceptEdits",
  max_turns=40,
  prompt="你是 pm-researcher...（含Skill路径+任务描述+记忆要求）"
)
```

**3. T001 完成后通知 orchestrator：**
```
send_message(
  type="message",
  recipient="main",
  summary="T001 技术调研完成",
  content="""
    【task_complete】T001 | pm-researcher | 100%
    
    产出物: context_pool/progress/T001-report.md
    推荐结论: Vue3 + Pinia + Vite，后端 Node.js + Express
  """
)
```

**4. orchestrator spawn T003+T004（并行编码）：**
```
# 两个 task() 在同一轮调用中发出，并行执行
task(name="coder-T003", team_name="todo-app-team", ...)  # 前端
task(name="coder-T004", team_name="todo-app-team", ...)  # 后端
```

**5. T003 编码完成（含规划审批流程）：**
```
# Phase A: 探索 → 输出 plan.md → send_message(plan_ready)
# Phase B: 等待 orchestrator 审批
# Phase C: 编码 → 钩子自动验证 → send_message(task_complete)
```

**6. 全部完成，清理：**
```
send_message(type="shutdown_request", recipient="coder-T003", content="任务完成")
send_message(type="shutdown_request", recipient="writer-T005", content="任务完成")
team_delete()  # 清理团队资源
```

---

## 六、故障排查

### 1. 子Agent 失败了怎么办？

| 情况 | 系统自动处理 | 如果自动处理也失败 |
|------|------------|------------------|
| 编译失败 | Coder 分析错误→修复→重试（最多2次） | 通知 orchestrator → 升级给你 |
| 工具调用报错 | 等待5秒→重试1次 | 通知 orchestrator |
| 上下文溢出 | 自动压缩到 HEARTBEAT → 请求重启 | 你确认重启 |
| 网络超时 | 等待→重试 | 通知 orchestrator |

**恢复优先级**：系统先自动恢复1次 → 失败才通知你 → 你决定下一步。

### 2. 上下文溢出怎么办？

系统内置 **HANDOFF（交接棒）机制**：

```
子Agent 感知上下文快满
    │
    ├── 冻结：停止新操作
    ├── 压缩：生成 HANDOFF.md（已做什么/正在做什么/下一步建议）
    ├── 同步：更新 HEARTBEAT
    └── 通知：send_message(task_handoff) → orchestrator
    
orchestrator 收到后：
    ├── 读取 HANDOFF.md
    ├── 重新 spawn 新的 Agent
    └── 新 Agent 从断点无缝接手
```

**你不需要做任何事**，系统自动完成交接。

### 3. Skills 安装失败怎么办？

| 阶段 | 失败 | 回退方案 |
|------|------|---------|
| ClawHub 搜索无结果 | 远程仓库没有这个 Skill | 动态生成临时 Skill（基于任务描述自动创建） |
| ClawHub 安装失败 | 网络问题/版本冲突 | 重试1次，仍失败则动态生成 |
| 动态生成也不行 | 极端情况 | 通知你手动处理 |

**三层兜底**：ClawHub安装 → 动态生成 → 人工介入。

### 4. 其他常见问题

| 问题 | 原因 | 解决方案 |
|------|------|---------|
| 子Agent卡住不动 | 可能是任务描述有歧义 | 检查 HEARTBEAT 的阻塞项，orchestrator 会自动超时升级 |
| 两个Agent改了同一个文件 | 文件所有权未明确 | orchestrator 在任务拆解时分配文件所有权，冲突时自动合并 |
| 调研结论格式不统一 | 不同Agent输出格式差异 | 系统统一使用结构化消息信封 + 调研报告模板 |
| 项目预算快用完 | 轮次消耗超过80% | 策略引擎自动预警，低优先级任务标记为 DEFERRED |

---

## 七、文件结构速查

### 核心文件

| 文件 | 用途 |
|------|------|
| `ARCHITECTURE.md` | 系统架构详细说明（技术参考） |
| `QUICKSTART.md` | 本文件（快速入门） |
| `README.md` | 项目简介 |

### Skill 定义

| 文件 | 用途 |
|------|------|
| `pm-orchestrator/SKILL.md` | 主控器行为规范（Phase 1-7 全流程SOP） |
| `pm-coder/SKILL.md` | 编码专家行为规范 |
| `pm-researcher/SKILL.md` | 调研专家行为规范 |
| `pm-writer/SKILL.md` | 文档专家行为规范 |

### Harness 定义（执行载体）

| 文件 | 用途 |
|------|------|
| `harnesses/README.md` | Skill vs Harness 概念说明 |
| `harnesses/orchestrator-harness.md` | 主控器运行环境配置 |
| `harnesses/coder-harness.md` | 编码Agent运行环境配置（含6大策略） |
| `harnesses/researcher-harness.md` | 调研Agent运行环境配置 |
| `harnesses/writer-harness.md` | 文档Agent运行环境配置 |

### 共享资源

| 文件 | 用途 |
|------|------|
| `shared/references/recovery-recipes.md` | 失败恢复配方（8种失败类型+恢复步骤） |
| `shared/references/default-skills.md` | 6个默认运行时行为技能 |
| `shared/references/health-check-protocols.md` | 四层健康检查协议 |
| `shared/references/checkpoint-recovery.md` | 检查点与崩溃恢复方案 |
| `shared/references/message-protocol.md` | Agent间通信协议规范 |
| `shared/templates/heartbeat-template.md` | HEARTBEAT初始化模板 |

### 运行时生成（.workbuddy/）

| 文件 | 用途 | 维护者 |
|------|------|--------|
| `.workbuddy/HEARTBEAT.md` | 项目级记忆看板 | orchestrator |
| `.workbuddy/context_pool/goal.md` | 结构化目标定义 | orchestrator |
| `.workbuddy/context_pool/product.md` | 产品定义 | orchestrator |
| `.workbuddy/context_pool/requirements.md` | 需求清单 | orchestrator |
| `.workbuddy/context_pool/tech_stack.md` | 技术栈决策 | orchestrator/researcher |
| `.workbuddy/context_pool/architecture.md` | 架构设计 | orchestrator |
| `.workbuddy/context_pool/decisions.md` | 关键决策记录 | orchestrator |
| `.workbuddy/context_pool/progress/T{XXX}-heartbeat.md` | 各任务进度记忆 | 子Agent |
| `.workbuddy/context_pool/shared/` | 子Agent共享数据 | 各Agent |
| `.workbuddy/checkpoints/` | 检查点快照（崩溃恢复用） | orchestrator |

---

## 八、进阶阅读

想深入了解？按以下顺序阅读：

1. **`ARCHITECTURE.md`** — 完整架构设计（数据流、状态机、通信协议）
2. **`harnesses/orchestrator-harness.md`** — 主控器详细配置（策略引擎、健康检查、检查点恢复）
3. **`harnesses/coder-harness.md`** — 编码Agent六大策略（规划管制、上下文工程、风险权限、交接棒、钩子）
4. **`shared/references/message-protocol.md`** — Agent间通信协议规范
5. **`shared/references/recovery-recipes.md`** — 失败恢复配方

---

> 💡 **一句话总结**：你说需求 → orchestrator 拆解 → 多个Agent并行执行 → 你在关键点确认 → 交付。中间出了问题，系统先自己恢复，恢复不了再找你。
