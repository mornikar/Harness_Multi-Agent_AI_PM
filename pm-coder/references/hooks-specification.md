# 钩子规范（Hooks Specification）

> pm-coder 子Agent的确定性质量钩子详细规范。
> 参考 Claude Code 的 Hooks 系统。
> 钩子在 Agent 执行生命周期的关键节点自动触发，用确定性规则约束 AI 行为。
> 需要时通过 `read_file` 渐进加载。

---

## 1. 钩子架构

```yaml
architecture:
  # 钩子不是外部脚本，而是嵌入 Agent 行为规范的检查规则
  # Agent 在执行过程中按以下生命周期自动执行对应钩子

  lifecycle:
    ┌──────────────────────────────────────────────────┐
    │  Pre-Edit    →  编辑操作前检查                    │
    │      ↓                                            │
    │  [Execute]   →  实际执行文件操作                   │
    │      ↓                                            │
    │  Post-Edit   →  编辑操作后验证                    │
    │      ↓                                            │
    │  Post-Step   →  plan 步骤完成检查                 │
    │      ↓                                            │
    │  On-Complete →  任务完成前全面验证                 │
    └──────────────────────────────────────────────────┘
```

---

## 2. 钩子注册表

### 2.1 Pre-Edit 钩子（编辑前）

#### H1: 规划合规检查（plan_compliance_check）

```yaml
hook: H1
name: plan_compliance_check
trigger: "每次 write_to_file 或 replace_in_file 调用前"
purpose: "确保操作不超出 plan.md 定义的范围"
priority: HIGH
blocking: true  # 不通过则阻止操作

procedure:
  1. 检查当前操作的文件路径是否在 plan.md 的「影响范围」表中
  2. 如果在列表中 → ✅ 通过，继续操作
  3. 如果不在列表中：
     a. 判断操作类型：
        - write_to_file（新建）→ 判断是否属于合理的附属文件（如测试文件、类型定义）
          - 是 → ✅ 通过，追加到 plan.md 影响范围
          - 否 → ⚠️ 黄灯，send_message 通知 orchestrator
        - replace_in_file（修改）→ 🔴 红灯，必须通知 orchestrator
     b. 等待 orchestrator 响应
     c. approved → 继续
     d. rejected → 跳过操作

  exception:
    - "plan.md 尚未创建（Phase A 探索阶段）→ 跳过此钩子"
    - "orchestrator 明确授权范围外修改 → 跳过此钩子"

  cost:
    time: "< 1 轮（Agent 自检，无需工具调用）"
    tokens: "≈ 0 额外消耗"
```

#### H2: 文件所有权检查（file_ownership_check）

```yaml
hook: H2
name: file_ownership_check
trigger: "每次 replace_in_file 调用前"
purpose: "防止多 Agent 同时修改同一文件导致冲突"
priority: MEDIUM
blocking: true

procedure:
  1. read_file 项目 HEARTBEAT.md 的"文件索引"区域
  2. 查找目标文件的所有者标记
  3. 如果文件被标记为其他 Agent 所有：
     a. send_message(type="message", recipient="main",
        event_type="file_conflict_warning",
        target_file: "{path}",
        current_owner: "{agent_name}",
        my_task: "T{XXX}")
     b. 等待 orchestrator 协调
  4. 如果文件无所有者标记或标记为自己 → ✅ 通过

  exception:
    - "目标文件是 context_pool 中的共享文件 → 跳过（按共享协议处理）"
    - "orchestrator 已明确指定可以修改 → 跳过"

  cost:
    time: "1 轮（read_file）"
    tokens: "≈ 500 tokens/次"
```

---

### 2.2 Post-Edit 钩子（编辑后）

#### H3: 语法快速检查（syntax_check）

```yaml
hook: H3
name: syntax_check
trigger: "每次修改 .ts/.tsx/.js/.jsx/.vue/.py 文件后"
purpose: "立即捕获低级语法错误，防止错误累积"
priority: HIGH
blocking: true

procedure:
  1. 根据文件类型选择检查命令：
     - .ts/.tsx → `tsc --noEmit {file}` 或 `tsc --noEmit --skipLibCheck`
     - .py → `python -m py_compile {file}`
     - .js/.jsx/.vue → 跳过（无独立语法检查器），依赖 lint 钩子
  2. 执行检查命令
  3. 分析结果：
     - 无错误 → ✅ 通过
     - 有错误 → 分析错误信息 → 自动修复 → 重新检查
     - 3次仍不通过 → send_message(task_failed, error_kind="syntax", detail="{errors}")

  retry_policy:
    max_retries: 3
    backoff: "立即重试（语法错误通常可一次修复）"

  cost:
    time: "1-2 轮（execute_command + 分析）"
    tokens: "≈ 1500 tokens/次"

  optimization:
    # 批量编辑优化：连续修改多个文件时，延迟到最后一个修改完成后再检查
    batch_mode:
      trigger: "一次性修改 > 3 个文件"
      action: "所有文件修改完成后统一执行一次 tsc --noEmit（项目级检查）"
```

#### H4: HEARTBEAT 同步（heartbeat_sync）

```yaml
hook: H4
name: heartbeat_sync
trigger: "每次 write_to_file 或 replace_in_file 成功后"
purpose: "实时同步产出物清单到 HEARTBEAT"
priority: LOW
blocking: false  # 非阻塞，异步执行

procedure:
  1. 判断操作类型：
     - write_to_file（新建）→ append 到 HEARTBEAT "产出物"清单
     - replace_in_file（修改已有文件）→ 更新对应条目的时间戳
  2. replace_in_file 更新任务 HEARTBEAT

  optimization:
    # 避免频繁更新：连续多次文件操作时，合并为一次更新
    debounce:
      trigger: "10秒内多次文件操作"
      action: "最后一次操作完成后统一更新一次"

  cost:
    time: "1 轮（replace_in_file）"
    tokens: "≈ 800 tokens/次"
```

---

### 2.3 Post-Step 钩子（步骤完成后）

#### H5: 里程碑质量门禁（milestone_quality_gate）

```yaml
hook: H5
name: milestone_quality_gate
trigger: "完成 plan.md 中定义了 quality_gate 的步骤后"
purpose: "确保每个里程碑的产出物质量达标"
priority: HIGH
blocking: true

procedure:
  1. read_file plan.md → 获取当前步骤的 quality_gate 定义
  2. 根据 quality_gate 类型执行验证：

     gate_types:
       - type: "command"
         example: "npm run test -- --grep 'UserService'"
         action: execute_command → 检查退出码

       - type: "file_exists"
         example: "src/core/index.ts"
         action: read_file 检查文件是否存在且非空

       - type: "compile_pass"
         example: "tsc --noEmit"
         action: execute_command → 检查无编译错误

       - type: "test_pass_rate"
         example: "测试通过率 ≥ 80%"
         action: execute_command → 解析测试输出计算通过率

       - type: "manual_review"
         example: "需要人工审查架构设计"
         action: send_message(request_human_review) → 等待

  3. 结果处理：
     - 全部 gate 通过 → 标记步骤 ✅ → 继续
     - 部分 gate 失败 → 修复 → 重试（最多2次）
     - 2次仍失败 → send_message(task_blocked, reason="quality_gate_failed")

  cost:
    time: "2-5 轮（取决于 gate 复杂度）"
    tokens: "≈ 2000-5000 tokens/步骤"
```

#### H6: 进度报告（progress_report）

```yaml
hook: H6
name: progress_report
trigger: "每完成一个 plan step 后"
purpose: "保持 orchestrator 对进度的可见性"
priority: MEDIUM
blocking: false

procedure:
  1. 计算当前进度：已完成步骤数 / 总步骤数 × 100
  2. send_message(type="message", recipient="main",
       event_type="task_progress",
       progress_pct: "{N}%",
       completed_step: "{步骤描述}",
       next_step: "{下一步描述}")

  optimization:
    # 与 orchestrator 健康检查对齐
    align_with_health_check:
      "orchestrator 的 L2 进度检查依赖此进度报告"
      "确保进度百分比准确反映实际完成度"

  cost:
    time: "1 轮（send_message）"
    tokens: "≈ 300 tokens/次"
```

---

### 2.4 On-Complete 钩子（任务完成前）

#### H7: 完整测试套件（full_test_suite）

```yaml
hook: H7
name: full_test_suite
trigger: "准备发送 task_complete 前（所有 plan 步骤完成）"
purpose: "确保全部代码变更不破坏已有功能"
priority: CRITICAL
blocking: true

procedure:
  1. 确定测试命令：
     - Node.js 项目: `npm run test` 或 `npx vitest run`
     - Python 项目: `python -m pytest` 或 `python -m pytest -x`
  2. 执行完整测试套件
  3. 分析结果：
     - 全部通过 → ✅ 继续
     - 有失败测试 → 分析失败原因：
       a. 本次修改引入 → 修复代码 → 重新运行
       b. 已有失败（修改前就存在）→ 记录到 HANDOFF/HEARTBEAT → 不阻塞
       c. 测试环境问题 → send_message(task_blocked)

  retry_policy:
    max_retries: 2
    backoff: "立即重试（修复后应立即验证）"

  fallback:
    "项目无测试 → 跳过此钩子，在 task_complete 中标注 'no_tests'"

  cost:
    time: "2-5 轮（执行 + 分析）"
    tokens: "≈ 3000-8000 tokens"
```

#### H8: Lint 检查（lint_check）

```yaml
hook: H8
name: lint_check
trigger: "准备发送 task_complete 前"
purpose: "确保代码风格符合项目规范"
priority: MEDIUM
blocking: false  # lint 警告不阻塞交付

procedure:
  1. 确定命令：
     - Node.js: `npm run lint` 或 `npx eslint {src} --max-warnings 0`
     - Python: `pylint {src}` 或 `ruff check {src}`
  2. 执行检查
  3. 分析结果：
     - 无警告 → ✅ 通过
     - 有警告 → 尝试自动修复（eslint --fix / black / ruff --fix）
     - 自动修复后仍有警告 → 记录到 HEARTBEAT，不阻塞交付

  cost:
    time: "1-3 轮"
    tokens: "≈ 2000 tokens"
```

#### H9: 产出物完整性检查（deliverable_integrity）

```yaml
hook: H9
name: deliverable_integrity
trigger: "准备发送 task_complete 前"
purpose: "确保 plan 中承诺的所有产出物都已交付"
priority: HIGH
blocking: true

procedure:
  1. read_file plan.md → 提取「影响范围」表
  2. 逐项检查：
     a. 新建文件（create）→ read_file 确认存在且非空
     b. 修改文件（modify）→ read_file 确认修改存在
     c. 删除文件（delete）→ search_file 确认已删除
  3. 对比 HEARTBEAT 产出物清单 → 确保一致
  4. 结果：
     - 全部一致 → ✅ 通过
     - 有遗漏 → 补充创建 → 重新检查
     - 无法创建 → send_message(task_partial_success)

  cost:
    time: "2-4 轮（多次 read_file）"
    tokens: "≈ 3000 tokens"
```

---

## 3. 钩子执行策略

### 3.1 性能优化

```yaml
optimization_rules:
  # 批量合并
  batch_edit:
    description: "连续修改多个文件时，合并 pre/post 钩子"
    trigger: "一次性修改 > 3 个文件"
    strategy: |
      pre_edit: 合并为一次 plan 合规检查
      post_edit: 合并为一次 tsc --noEmit（项目级）

  # 并行执行
  parallel:
    description: "无依赖关系的钩子并行执行"
    example: "lint_check 和 deliverable_integrity 可以并行"

  # 跳过规则
  skip_rules:
    - "Phase A 探索阶段 → 跳过所有 post-edit 和 post-step 钩子"
    - "测试文件修改 → 语法检查 + lint 可跳过"
    - "配置文件修改 → 测试套件钩子可跳过"
    - "orchestrator 明确指示跳过 → 跳过指定钩子"
```

### 3.2 钩子失败升级矩阵

| 钩子 | 失败影响 | 升级策略 |
|------|---------|---------|
| H1 plan_compliance | 阻止操作 | send_message → orchestrator 裁决 |
| H2 file_ownership | 阻止操作 | send_message → orchestrator 协调 |
| H3 syntax_check | 阻止继续 | 自动修复（3次）→ task_failed |
| H4 heartbeat_sync | 非阻塞 | 记录警告，下次操作补同步 |
| H5 milestone_gate | 阻止下一步 | 修复（2次）→ task_blocked |
| H6 progress_report | 非阻塞 | 记录警告 |
| H7 test_suite | 降级交付 | 修复（2次）→ task_partial_success |
| H8 lint_check | 非阻塞 | 记录警告 → 继续交付 |
| H9 deliverable_integrity | 阻止完成 | 补充创建 → task_partial_success |

---

## 4. 钩子与 orchestrator 健康检查的协作

```yaml
collaboration:
  # coder 钩子产出 → orchestrator 健康检查输入
  data_flow:
    - "H6 progress_report → orchestrator L2 进度检查的数据源"
    - "H5 milestone_gate 结果 → orchestrator L3 产出质量检查的输入"
    - "H3/H7/H8 检查结果 → HEARTBEAT '遇到的问题' 区 → orchestrator 错误计数因子"
    - "H1 plan_compliance 违规 → orchestrator L4 约束合规检查信号"
```
