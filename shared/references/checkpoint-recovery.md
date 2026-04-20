# 检查点与崩溃恢复方案（Checkpoint & Crash Recovery）

> 供 orchestrator 在处理崩溃恢复时参考的详细方案。
> 定义了检查点的创建、存储、恢复完整SOP。
> 需要时通过 `read_file` 渐进加载。

---

## 1. 检查点创建SOP

### 1.1 项目快照创建

```yaml
protocol: create_project_checkpoint
trigger: Phase完成 或 用户手动请求

preconditions:
  - 项目 HEARTBEAT 存在且可读
  - 至少有一个任务 HEARTBEAT 存在

steps:
  1. 读取当前状态
     - read_file 项目 HEARTBEAT.md
     - read_file 所有任务 HEARTBEAT（从项目看板获取路径列表）
  
  2. 生成文件索引
     - 遍历 context_pool/ 目录
     - 记录每个文件的路径、大小、最后修改时间
  
  3. 组装检查点JSON
     - 按检查点格式组装（参见 orchestrator-harness.md 检查点格式）
     - 注入元信息：时间、触发原因、版本号
  
  4. 写入检查点文件
     - write_to_file .workbuddy/checkpoints/project-phase{N}-v{seq}.json
  
  5. 清理旧检查点
     - 如超出保留上限 → 删除最旧的检查点
  
  6. 记录
     - replace_in_file 在项目 HEARTBEAT 变更日志追加
```

### 1.2 任务快照创建

```yaml
protocol: create_task_checkpoint
trigger: 子Agent到达里程碑 或 orchestrator主动创建

steps:
  1. read_file 目标任务 HEARTBEAT
  2. 列出该任务的产出物（从 HEARTBEAT 产出物清单提取）
  3. 组装任务检查点JSON
  4. write_to_file .workbuddy/checkpoints/task-{task_id}-v{seq}.json
  5. 清理旧版本（保留最新 5 个）
```

### 1.3 决策快照创建

```yaml
protocol: create_decision_checkpoint
trigger: 关键决策记录到项目 HEARTBEAT 后

steps:
  1. 从项目 HEARTBEAT 提取最新决策
  2. 快照决策前后的关键状态变化
  3. write_to_file .workbuddy/checkpoints/decision-{d_id}.json
```

---

## 2. 检查点存储规范

### 2.1 目录结构

```
.workbuddy/checkpoints/
├── project-phase4-v1.json       # Phase 4 完成时的项目快照
├── project-phase4-v2.json       # Phase 4 后期修正的项目快照
├── project-phase5-v1.json       # Phase 5 完成时的项目快照
├── task-T001-v1.json            # T001 第一个里程碑的快照
├── task-T001-v2.json            # T001 第二个里程碑的快照
├── task-T003-v1.json            # T003 第一个里程碑的快照
├── decision-D1.json             # 决策D1的快照
├── decision-D2.json             # 决策D2的快照
└── LATEST                       # 软链接/指向最新的项目快照
```

### 2.2 文件命名规则

```yaml
naming:
  project: "project-phase{N}-v{seq}.json"
  task: "task-{task_id}-v{seq}.json"
  decision: "decision-{d_id}.json"
  
  # seq 为自增序号（同类型同标识的递增）
  # 不使用时间戳，保持可读性
```

### 2.3 文件大小控制

```yaml
size_limits:
  max_project_checkpoint_size: "100KB"    # 项目快照
  max_task_checkpoint_size: "50KB"        # 任务快照
  max_decision_checkpoint_size: "10KB"    # 决策快照
  
  # 超过限制时的处理：
  # 1. 压缩 HEARTBEAT 内容（去除冗余信息）
  # 2. 产出物只记录路径和元信息，不包含内容
  # 3. context_pool 只记录索引，不包含全文
```

---

## 3. 崩溃检测与分类

### 3.1 崩溃类型矩阵

| 崩溃类型 | 检测方式 | 严重度 | 影响范围 | 恢复复杂度 |
|---------|---------|--------|---------|-----------|
| **子Agent失联** | HEARTBEAT 停止更新 > 15min | MEDIUM | 单任务 | LOW |
| **子Agent上下文溢出** | 收到 context_overflow 事件 | LOW | 单任务 | LOW |
| **子Agent逻辑死循环** | 进度为0但HEARTBEAT频繁更新 | MEDIUM | 单任务 | MEDIUM |
| **orchestrator会话中断** | 用户重新发起对话 | HIGH | 全项目 | MEDIUM |
| **多Agent级联失败** | 多个子Agent同时FAILED | HIGH | 多任务 | HIGH |
| **团队通道丢失** | send_message 连续失败 3 次 | HIGH | 全项目 | MEDIUM |
| **文件系统异常** | read_file/write_to_file 失败 | CRITICAL | 全项目 | HIGH |

### 3.2 崩溃检测算法

```yaml
crash_detection:
  # 综合信号判断
  signals:
    heartbeat_stale:
      weight: 0.3
      threshold: ">15min无更新"
      
    message_silence:
      weight: 0.2
      threshold: ">10min无任何消息"
      
    progress_stagnant:
      weight: 0.2
      threshold: "连续2次检查进度未变"
      
    error_spike:
      weight: 0.3
      threshold: "恢复台账错误数 > 3"
  
  # 崩溃判定
  crash_score = sum(signal_weight * is_triggered)
  crash_score >= 0.7 → 确认崩溃，启动恢复
  crash_score >= 0.4 → 高风险，加强监控
```

---

## 4. 恢复执行SOP

### 4.1 子Agent恢复

```yaml
protocol: recover_subagent
trigger: 单子Agent崩溃检测

steps:
  1. 诊断
     - 确定崩溃类型（参考崩溃类型矩阵）
     - read_file 最近的任务检查点
  
  2. 评估损失
     - 对比检查点中的进度 vs HEARTBEAT最后记录的进度
     - 列出自上次检查点以来的增量工作
     - 评估是否可以恢复
  
  3. 恢复执行
     - send_message(shutdown_request, recipient="{crashed_agent}")
     - 等待确认（30秒超时后强制继续）
     - 从检查点恢复任务 HEARTBEAT：
       write_to_file(任务HEARTBEAT, content=检查点snapshot)
     - 重新 spawn 子Agent：
       task(prompt="{从检查点恢复的上下文}")
  
  4. 验证
     - 等待新子Agent创建 HEARTBEAT
     - 确认进度正确恢复
     - 重新计算健康度
  
  5. 记录
     - 更新项目 HEARTBEAT 恢复台账
     - 记录数据损失评估
```

### 4.2 orchestrator恢复

```yaml
protocol: recover_orchestrator
trigger: orchestrator会话中断，用户重新发起对话

steps:
  1. 发现恢复入口
     - 用户消息包含项目标识（项目名称或 workspace）
     - 或用户明确说"继续上次的项目"
  
  2. 读取项目状态
     - read_file .workbuddy/HEARTBEAT.md
     - read_file .workbuddy/checkpoints/ 中最新的项目快照
     - 对比两者，以更完整者为准
  
  3. 重建上下文
     - 从 HEARTBEAT/检查点 恢复：
       - 项目目标（Goal）
       - 当前阶段
       - 各任务状态
       - 待处理决策
     - read_file context_pool/ 关键文件补充细节
  
  4. 评估并继续
     - 检查是否有 RUNNING 状态的子Agent
     - 如有 → 执行存活检查
     - 如子Agent仍活跃 → 恢复调度
     - 如子Agent已失联 → 按子Agent恢复协议处理
  
  5. 向用户报告
     - 简要说明恢复情况
     - 列出当前状态和下一步
```

### 4.3 全面崩溃恢复

```yaml
protocol: full_crash_recovery
trigger: 多Agent级联失败 或 系统级异常

steps:
  1. 紧急止损
     - 标记所有 RUNNING 任务为 INTERRUPTED
     - 如团队通道仍可用 → broadcast 通知所有Agent暂停
     - 如团队通道不可用 → 直接进入恢复
  
  2. 数据保全
     - 读取最近的项目快照
     - 验证 context_pool 文件完整性
     - 列出所有可恢复的状态
  
  3. 全面回滚
     - 以最近的项目检查点为准
     - 重写项目 HEARTBEAT
     - 重写所有受影响任务的 HEARTBEAT
  
  4. 重建团队
     - team_delete（清理残留）
     - team_create（新建团队通道）
  
  5. 逐步恢复任务
     - 按依赖顺序重新 spawn 子Agent
     - 从检查点恢复每个任务的上下文
     - 每个恢复的任务执行存活检查
  
  6. 全面验证
     - 确认所有恢复任务的 HEARTBEAT 正常更新
     - 重新计算所有任务的健康度
     - 执行一次全量约束合规检查
  
  7. 向用户报告
     - 恢复摘要：恢复了什么、丢失了什么
     - 当前项目状态
     - 潜在风险
```

### 4.4 恢复后验证清单

```markdown
## 恢复后必须确认的事项

- [ ] 所有 INTERRUPTED 任务已恢复为 RUNNING 或 COMPLETED
- [ ] 每个 RUNNING 任务的 HEARTBEAT 在正常更新
- [ ] context_pool 文件索引与实际文件一致
- [ ] 团队通信通道正常（send_message 可达）
- [ ] Goal 的 constraints 无新增违规
- [ ] 预算消耗在预期范围内
- [ ] 下游任务不会被恢复影响（数据一致性）
```

---

## 5. 检查点回滚

### 5.1 回滚场景

| 场景 | 回滚目标 | 影响范围 |
|------|---------|---------|
| 架构决策后发现方向错误 | 回滚到决策前的项目检查点 | 全项目 |
| 子Agent严重偏离任务 | 回滚到该任务的上一个里程碑检查点 | 单任务 |
| 集成测试发现严重问题 | 回滚到集成前的项目检查点 | 多任务 |
| 用户要求"重来" | 回滚到用户指定的检查点 | 按需 |

### 5.2 回滚执行

```yaml
protocol: rollback_to_checkpoint
trigger: orchestrator 决策 或 用户请求

steps:
  1. 选择目标检查点
     - list_dir .workbuddy/checkpoints/ → 列出可用检查点
     - 用户指定 或 orchestrator 推荐最近稳定检查点
  
  2. 预览影响
     - 对比目标检查点与当前状态
     - 列出将被回滚的变更：
       - 新增的文件（可能需要保留或删除）
       - 修改的文件（恢复到旧版本）
       - 新增的决策（可能需要撤销）
     - 评估数据损失
  
  3. 如需用户确认
     - 展示预览报告
     - 等待用户批准（特别是全项目回滚）
  
  4. 执行回滚
     - 从检查点恢复 HEARTBEAT（项目和所有任务）
     - 恢复 context_pool 文件（如检查点包含内容）
     - 清理回滚后无效的产出物
  
  5. 重建
     - 标记回滚后需要重新执行的任务
     - 重新 spawn 子Agent
  
  6. 记录
     - 在项目 HEARTBEAT 变更日志追加回滚记录
     - 包含：回滚原因、目标检查点、损失评估
```

---

## 6. 与 WorkBuddy 原生恢复的协作

```yaml
native_recovery_cooperation:
  # WorkBuddy 的会话恢复机制（Session Recovery）是第一道防线
  # 本检查点机制是第二道防线
  
  # 协作规则：
  layer_1_native:
    scope: "WorkBuddy 平台级别"
    mechanism: "自动保存/恢复会话上下文"
    limitation: "依赖平台实现，不同环境行为可能不同"
    use_when: "子Agent单体会话中断（上下文满、超时）"
  
  layer_2_checkpoint:
    scope: "AI_PM_Skills 项目级别"
    mechanism: "结构化 JSON 快照 + HEARTBEAT"
    advantage: "跨平台、跨环境、可控、支持回滚"
    use_when: "orchestrator中断、多Agent异常、需要精确回滚"
  
  # 协作流程：
  recovery_order: |
    1. 首先尝试 WorkBuddy 原生恢复（最快）
    2. 原生恢复失败或不完整 → 读取检查点补充
    3. 检查点也无法恢复 → 人工介入（第三道防线）
    
  # 设计原则：
  design_principle: |
    "不信任单一恢复路径"。
    即使 WorkBuddy 恢复成功，orchestrator 也应对比
    HEARTBEAT 验证恢复完整性。
    检查点机制确保系统具备自力更生的恢复能力。
```
