# 默认技能规范（Default Skills，参考 Hive）

> 所有子Agent共享的运行时行为技能，编码到每次 spawn 的 prompt 中。
> 与 Domain Skills（vue3、electron 等）不同，默认技能是**行为纪律**，不是领域知识。
> 参考 Hive 的 6 个默认技能，适配 AI_PM_Skills 的 Markdown 规范。

---

## 概述

默认技能通过 **4 个注入点** 编织到每个子 Agent 的执行过程中：

| 注入点 | 时机 | 说明 |
|--------|------|------|
| **系统提示注入** | 子 Agent spawn 时 | 附加到 prompt 的 Layer 1 Identity |
| **迭代边界回调** | 子 Agent 自验证时 | 质量检查、进度评估 |
| **节点完成钩子** | 子 Agent 完成任务时 | 完整性检查、交接摘要 |
| **阶段转换钩子** | orchestrator 切换批次时 | 上下文传递、笔记持久化 |

---

## 默认技能列表

### DS1: 结构化笔记（hive.note-taking → pm-note-taking）

**目的**：防止 Agent 在长任务中丢失跟踪。

**行为规范**：
- 每完成一个子步骤，用 `replace_in_file` 更新 HEARTBEAT 的进度区
- 笔记格式：`- [x] {子步骤描述}（{HH:mm}）`
- 未完成的子步骤：`- [ ] {子步骤描述}`
- 遇到阻塞：`- [!] {阻塞描述} ← 需要什么`

**注入方式**：系统提示注入（Layer 1）

---

### DS2: 任务进度追踪（hive.colony-progress-tracker → pm-progress-tracker）

**目的**：防止任务跳过、重复或静默丢弃。

**行为规范**：
- 任务启动时：在 HEARTBEAT 创建任务概览区（目标、步骤、预计产出物）
- 每个步骤标记状态：✅完成 / 🔄进行中 / ⏳待执行 / ⚠️阻塞 / ❌失败
- 完成时：HEARTBEAT 的状态必须更新为 completed（不可停留在 running）
- 产出物：列出所有生成的文件路径

**注入方式**：迭代边界回调 + 节点完成钩子

---

### DS3: 上下文保存（hive.context-preservation → pm-context-preservation）

**目的**：在上下文窗口快满时主动保存关键信息。

**行为规范**：
- 感觉上下文快满时（输出被截断、或遇到 context_overflow 恢复配方）
- 立即将当前状态 + 核心结论压缩写入 HEARTBEAT
- 压缩清单：
  - [ ] 目标和当前状态
  - [ ] 产出物路径
  - [ ] 未完成步骤
  - [ ] 关键决策
  - [ ] 阻塞项
- 通知 orchestrator：`send_message(task_blocked, reason="context_overflow")`

**注入方式**：系统提示注入（Layer 1）

**预警阈值**：当 max_turns 已使用 40% 时，在 HEARTBEAT 标注进度警告。

---

### DS4: 质量自我评估（hive.quality-monitor → pm-quality-monitor）

**目的**：定期自我评估输出质量，不等到最后才发现问题。

**行为规范**：
- 每完成一个主要子步骤后，快速自检：
  - 这一步的产出是否满足验收标准的某个维度？
  - 是否引入了新的风险或问题？
  - 上游依赖的信息是否正确使用？
- 如果发现问题：立即修正，不要累积到最后
- 如果发现无法解决的问题：send_message 通知 orchestrator

**注入方式**：迭代边界回调

---

### DS5: 错误恢复协议（hive.error-recovery → pm-error-recovery）

**目的**：工具调用失败时遵循结构化恢复协议。

**行为规范**：
- 遇到失败时，先查阅 `shared/references/recovery-recipes.md`
- 按对应配方的步骤执行
- 最多重试 1 次
- 恢复失败 → send_message 通知 orchestrator（附完整错误信息）
- 所有恢复尝试记录到 HEARTBEAT 的"遇到的问题"区

**注入方式**：系统提示注入（Layer 1）

> 注：这个默认技能已有独立的 recovery-recipes.md 文件。默认技能规范是确保每个 Agent 都知道"失败时先查恢复配方"。

---

### DS6: 一致性守卫（pm-consistency-guard，AI_PM_Skills 原创）

**目的**：确保子Agent产出物与项目约束保持一致。

**行为规范**：
- 开始任务前：read_file 读取 `context_pool/goal.md` 的约束条件
- 执行过程中：任何可能违反约束的操作（如使用被禁止的技术栈）必须先 send_message 请求 orchestrator 确认
- 完成时：自验证步骤中包含一致性检查
- 发现不一致：立即修正，不可传递给下游

**注入方式**：系统提示注入（Layer 1）+ 节点完成钩子

---

## 默认技能配置

orchestrator 可按任务调整默认技能的启用状态：

```yaml
# 在 orchestrator 的 spawn 配置中
default_skills:
  pm-note-taking:          { enabled: true }
  pm-progress-tracker:     { enabled: true }
  pm-context-preservation: { enabled: true, warn_at_usage_ratio: 0.4 }
  pm-quality-monitor:      { enabled: true }
  pm-error-recovery:       { enabled: true }
  pm-consistency-guard:    { enabled: true }

# 禁用所有默认技能（调试时使用）
# default_skills: { _all: { enabled: false } }
```

## 与 Domain Skills 的关系

| 维度 | 默认技能 | Domain Skills |
|------|---------|--------------|
| **加载方式** | orchestrator 自动注入 prompt | Agent 运行时自主读取或配置预激活 |
| **作用** | 行为纪律（怎么做） | 领域知识（做什么） |
| **范围** | 所有子Agent共享 | 按任务类型匹配 |
| **可覆盖** | 是（orchestrator 可禁用） | 否（Agent 必须遵守） |
| **示例** | pm-error-recovery, pm-quality-monitor | vue3, fastapi, notion |
