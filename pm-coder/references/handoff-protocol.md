# 交接协议（Handoff Protocol）

> pm-coder 子Agent的会话交接规范。
> 参考 Claude Code 的 HANDOFF.md 机制。
> 当上下文接近极限或需要切换会话时，按此协议生成结构化交接文档。

---

## 1. 交接原则

```yaml
principles:
  proactive: "主动交接优于被动崩溃"
  structured: "交接文档结构化，接手方可直接执行"
  complete: "关键信息零丢失，宁可冗余不可遗漏"
  verifiable: "接手方通过文档即可恢复工作，无需猜测"
  atomic: "交接是一个原子操作——要么完成，要么回退，不存在半交接状态"
```

---

## 2. 触发条件

### 自动触发

| 条件 | 阈值 | 说明 |
|------|------|------|
| 轮次耗尽 | 已用轮次 > max_turns × 70% | 上下文预算预警 |
| 上下文膨胀 | Agent 感知到响应质量下降 | 如输出被截断、重复操作 |
| DS3 触发 | 上下文保存默认技能触发 | 与 HANDOFF 流程合并执行 |

### 手动触发

| 条件 | 触发者 | 说明 |
|------|--------|------|
| orchestrator 请求 | orchestrator | send_message(type="handoff_request") |
| 预估超时 | coder Agent | 编码前发现 plan 复杂度远超预估 |
| 意外中断 | coder Agent | 遇到无法自动恢复的系统性问题 |

---

## 3. 交接流程 SOP

```
检测到触发条件
    │
    ├── Step 1: 冻结（Freeze）
    │   ├── 停止启动新操作
    │   ├── 等待当前进行中的操作完成
    │   └── 标记: HEARTBEAT 状态 → 🔄 handoff
    │
    ├── Step 2: 压缩（Compress）
    │   ├── 回顾当前会话的所有操作
    │   ├── 提取关键决策和结论
    │   ├── 过滤噪声（调试日志、试探性操作）
    │   └── 生成 HANDOFF.md
    │
    ├── Step 3: 同步（Sync）
    │   ├── replace_in_file 更新任务 HEARTBEAT
    │   │   ├── 状态: 🔄 handoff
    │   │   ├── 交接原因
    │   │   ├── HANDOFF.md 路径
    │   │   └── 压缩"遇到的问题"（只保留未解决的）
    │   └── replace_in_file 更新 plan.md（标记已完成/未完成步骤）
    │
    └── Step 4: 通知（Notify）
        └── send_message(type="message", recipient="main",
              event_type="task_handoff",
              task_id, handoff_path, progress_pct, reason)
```

---

## 4. HANDOFF.md 模板

```markdown
# HANDOFF: T{XXX} — {任务简述}

## 元信息

| 字段 | 值 |
|------|-----|
| 任务ID | T{XXX} |
| 交接时间 | {YYYY-MM-DD HH:mm} |
| 交接原因 | {auto: 上下文预算耗尽 | manual: orchestrator请求 | timeout: 预估超时} |
| 已用轮次 | {N} / {max_turns} |
| 前置文档 | plan.md: {path} · HEARTBEAT: {path} |

---

## 当前进度

### ✅ 已完成

| # | 步骤 | 产出物 | 验证状态 | 备注 |
|---|------|--------|---------|------|
| 1 | {步骤描述} | `{file_path}` | ✅ 通过 | {备注} |
| 2 | {步骤描述} | `{file_path}` | ✅ 通过 | {备注} |

### 🔄 进行中

| # | 步骤 | 进度 | 当前状态 | 恢复要点 |
|---|------|------|---------|---------|
| 3 | {步骤描述} | {N}% | {编码中/测试中/调试中} | {从哪里继续} |

### ⏳ 未开始

| # | 步骤 | 依赖 | 预估轮次 |
|---|------|------|---------|
| 4 | {步骤描述} | 依赖步骤3 | {N} |
| 5 | {步骤描述} | 无 | {N} |

---

## 关键决策记录

| # | 决策点 | 选择 | 备选方案 | 决策原因 |
|---|--------|------|---------|---------|
| 1 | {描述} | {方案A} | {方案B, C} | {原因} |
| 2 | {描述} | {方案B} | {方案A} | {原因} |

---

## 技术上下文

### 当前代码状态
- **分支/版本**: {git branch or version}
- **新增文件**: `{path1}`, `{path2}`
- **修改文件**: `{path1}`, `{path2}`
- **已安装依赖**: {新增的 npm/pip 包}

### 潜在冲突点
- `{文件A} 可能与 T{YYY} 的产出冲突`
- `{配置变更} 需要与 orchestrator 确认`

### 环境注意事项
- `{某个环境变量需要设置}`
- `{某个服务需要运行中}`

---

## 遗留问题

| # | 问题描述 | 严重度 | 尝试方案 | 状态 | 建议 |
|---|---------|--------|---------|------|------|
| 1 | {问题} | 高/中/低 | {方案} | ⏳待解决/🔄处理中 | {建议} |

---

## 恢复指引

> 接手 Agent 请按以下步骤恢复工作：

### 1. 加载上下文
```
read_file("{plan_path}")       → 了解完整规划
read_file("{heartbeat_path}")  → 了解任务状态
```

### 2. 验证文件状态
```
检查 HANDOFF.md 中列出的所有产出物是否存在
如文件缺失 → 从 HEARTBEAT 恢复台账判断是否需要重新创建
```

### 3. 恢复执行
```
从"进行中"步骤的当前进度继续
特别注意"恢复要点"列中的提示
```

### 4. 注意事项
- {关键注意事项1}
- {关键注意事项2}

---

## 对 orchestrator 的建议

- {是否需要调整预算}
- {是否需要协调其他 Agent}
- {是否需要人工介入某个遗留问题}
```

---

## 5. 接手流程 SOP

orchestrator 收到 task_handoff 后的恢复流程：

```
orchestrator 收到 task_handoff
    │
    ├── Step 1: 读取交接文档
    │   └── read_file(T{XXX}-handoff.md)
    │
    ├── Step 2: 评估恢复策略
    │   ├── 进度 > 80% 且遗留问题少 → 续接（spawn 新 Agent）
    │   ├── 进度 30-80% → 续接，但调整预算
    │   ├── 进度 < 30% 且问题多 → 重新规划
    │   └── 关键文件损坏 → 从检查点恢复
    │
    ├── Step 3: 重新 spawn
    │   └── task(spawn 新 coder Agent)
    │       prompt 中注入：
    │       - Layer 0: Intent Resolution
    │         "当前阶段: execute（从 HANDOFF 恢复）"
    │         "HANDOFF 文档: T{XXX}-handoff.md"
    │       - Layer 2: Narrative
    │         从 HANDOFF.md 提取"当前进度"和"关键决策记录"
    │       - Layer 3: Focus
    │         "从步骤{N}的{进度}%处继续"
    │
    └── Step 4: 验证恢复
        ├── 新 Agent 读取 HANDOFF.md
        ├── 验证文件完整性
        ├── 从断点继续执行
        └── send_message(task_progress) 确认恢复成功
```

---

## 6. 交接失败处理

| 失败场景 | 原因 | 处理策略 |
|---------|------|---------|
| HANDOFF.md 生成失败 | 上下文已完全溢出 | 依赖 HEARTBEAT 最后一次更新恢复 |
| 接手 Agent 无法理解 | 交接文档信息不足 | orchestrator 补充上下文后重新 spawn |
| 交接后文件冲突 | 其他 Agent 在交接期间修改了文件 | 读取最新版本 → 智能合并 |
| 多次交接循环 | 任务过于复杂，反复交接 | orchestrator 拆分为多个子任务 |

---

## 7. 交接与检查点的关系

```
交接 ≠ 检查点快照

交接（HANDOFF）:
  目的：Agent 会话间传递工作状态
  触发：上下文预算耗尽
  内容：结构化的工作状态 + 恢复指引
  粒度：单个任务

检查点快照（Checkpoint）:
  目的：崩溃恢复 + 项目级回滚
  触发：里程碑完成 / Phase 完成
  内容：完整的 HEARTBEAT + 产出物清单
  粒度：项目 / 任务 / 决策

两者可以叠加：
  交接时自动创建任务级检查点
  确保即使交接也失败，仍可通过检查点恢复
```
