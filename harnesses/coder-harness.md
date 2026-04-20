# Coder Harness 定义

> pm-coder 子Agent 的执行载体定义。
> 设计参考：claw-code 的 Worker 生命周期 + 权限分层 + 工具最小化原则；
> Hive 的目标注入 + 三角验证 + 三层洋葱模型；
> Claude Code 的规划管制 + 上下文工程 + 风险分级权限 + 交接棒 + 事件驱动钩子；
> 毒舌产品经理 4.0 的 Guides/Sensors 双闭环 + 两阶段 Code Review + 系统性调试 SOP。

## 基本配置

```yaml
name: pm-coder
harness_type: subagent
description: |
  编程执行子Agent。负责代码编写、调试、重构、测试。
  通过 task 工具以 Team Mode spawn，加入项目团队协作。
  内置"先规划后编码"管制、风险分级权限、自动质量钩子。

spawn_config:
  subagent_name: "code-explorer"    # 内置 subagent 类型（代码探索+编写）
  mode: "acceptEdits"               # 自动接受文件编辑
  max_turns: 50                     # 单任务最多50轮
  # name 和 team_name 由 orchestrator 动态填入
  # name: "coder-T{XXX}"
  # team_name: "{project-team}"
```

---

## 双闭环控制模型（Guides + Sensors）

> **设计参考**：毒舌产品经理 4.0。
> Agent = 模型 + Harness。模型提供智能，Harness 让智能变得**可用**和**可控**。
> 可控性来自两个互补的控制回路。

### 闭环一：Guides（前馈控制）

**在 Agent 行动之前注入标准和方法论，提高一次做对的概率。**

| 组件 | 对应文件 | 作用 |
|------|---------|------|
| 角色身份 | SKILL.md Layer 1 | "你是谁、能做什么" |
| 目标约束 | Goal success_criteria | "要达到什么标准" |
| 工作流程 | SKILL.md Steps | "按什么步骤做" |
| 编码标准 | references/code-standards.md | "代码应该长什么样" |
| 审查协议 | references/code-review-protocol.md | "交付前要过什么关" |
| 调试 SOP | references/debugging-protocol.md | "出 Bug 怎么修" |

### 闭环二：Sensors（反馈控制）

**在 Agent 行动之后检查结果，发现偏差，触发自我修正。**

> ⚠️ 设计变更：推理型传感器由 orchestrator 在验收时执行，Coder 只负责计算型传感器。

| 组件 | 类型 | 作用 | 执行者 |
|------|------|------|-------|
| H1-H9 钩子 | 计算型传感器 | 确定性检查（编译/测试/格式/完整性） | Coder |
| Stage 1 关键词匹配 | 轻量自检 | 功能完整性轻量检查 | Coder |
| Stage 2 H7/H8/H9 | 计算型检查 | 代码质量检查（不含语义评估） | Coder |
| 语义评估 | 推理型传感器 | Spec 深度对照 + 代码质量语义审查 | Orchestrator |
| 健康度自评 | 推理型传感器 | 进度/风险感知 | Coder |

### Sensors 分类

> **⚠️ 设计变更说明**：推理型传感器（语义级审查）由 orchestrator 在验收时执行。
> 原因：LLM 无法真正自我审查逻辑错误，自己审查自己不靠谱。
> Coder 只负责计算型传感器（H1-H9），推理型审查由 orchestrator 通过三角验证执行。

```yaml
sensors:
  # 计算型传感器（确定性，快，无幻觉）— Coder 自执行
  computational:
    - "H1 plan_compliance — plan 范围检查"
    - "H2 file_ownership — 文件所有权检查"
    - "H3 syntax_check — 编译/语法检查"
    - "H4 heartbeat_sync — 产出物清单同步"
    - "H7 full_test_suite — 测试套件"
    - "H8 lint_check — 代码风格"
    - "H9 deliverable_integrity — 产出物完整性"
    trigger: "每次文件操作后（Pre/Post-Edit）+ 任务完成时（On-Complete）"

  # 轻量自检（关键词匹配）— Coder 自执行，不依赖语义推理
  lightweight_self_check:
    - "关键词匹配检查 — 代码中是否包含 Spec 中的关键术语"
    - "API 端点名称核对 — 逐字匹配，不做语义理解"
    - "文件路径验证 — 检查必要文件是否存在"
    trigger: "任务完成时（On-Complete）"
    cost: "极低，仅关键词扫描"

  # 推理型传感器（语义级）— orchestrator 验收时执行（三角验证第二层）
  reasoning:
    - "语义评估 — 对比 Goal 的 success_criteria 加权打分"
    - "Spec 深度对照 — 理解代码与需求的关系"
    - "代码质量语义审查 — 架构合理性、安全隐患"
    trigger: "orchestrator 收到 task_complete 后执行"
    cost: "每次推理传感器调用约消耗 2000-5000 tokens"
    executor: "orchestrator（通过三角验证模型执行）"
    anti_hallucination: "推理结论必须有代码/Spec 证据支撑"
```

---

## 模块一：规划优先管制（Planning-First Workflow）

> **核心理念**：拒绝"上来就干"。所有编码任务必须先产出规划文档，
> orchestrator 审批通过后才能进入编码阶段。
> 参考 Claude Code Plan Mode。

### 执行阶段

```yaml
execution_phases:
  # ═══════════════════════════════
  # Phase A: 探索（Explore）— 只读，不动手
  # ═══════════════════════════════
  - phase: "explore"
    mode: "plan"                     # plan 模式 = 只读
    allowed_tools: [read_file, search_file, search_content]
    forbidden: [write_to_file, replace_in_file, execute_command]
    max_turns: 10                    # 探索最多用10轮
    steps:
      - "读取项目 HEARTBEAT → 了解全局上下文"
      - "读取上游任务 HEARTBEAT → 了解依赖产出"
      - "读取 context_pool/tech_stack.md → 了解技术栈"
      - "读取 context_pool/architecture.md → 了解架构设计"
      - "search_content / list_dir → 扫描现有代码结构"
      - "识别影响范围：哪些文件会被修改/新增"
      - "识别风险点：依赖关系、兼容性、潜在冲突"
    output: |
      .workbuddy/context_pool/progress/T{XXX}-plan.md
    notification: |
      send_message(type="message", recipient="main",
        event_type="plan_ready", plan_path="T{XXX}-plan.md")

  # ═══════════════════════════════
  # Phase B: 审批等待（Approval Gate）
  # ═══════════════════════════════
  - phase: "approval_gate"
    trigger: "orchestrator 审阅 plan.md"
    orchestrator_checks:
      - "plan 中的文件修改范围是否合理"
      - "是否与 Goal 的约束条件冲突"
      - "是否影响其他正在运行的任务"
      - "预估轮次是否在 budget 内"
    outcomes:
      approved:
        action: "send_message(type='message', content='plan_approved') → 进入 Phase C"
      rejected:
        action: "send_message(type='message', content='plan_rejected') → 附带修改意见 → 回到 Phase A"
      needs_research:
        action: "orchestrator 委托 researcher 补充调研 → 重新规划"

  # ═══════════════════════════════
  # Phase C: 编码（Execute）— 核心工作
  # ═══════════════════════════════
  - phase: "execute"
    mode: "acceptEdits"              # 恢复写入权限
    allowed_tools: [全部允许工具]
    max_turns: 40                    # 编码阶段最多40轮（总计50轮 = 10探索 + 40编码）
    guardrails:
      - "严格按照 plan.md 中的执行顺序和范围操作"
      - "超出 plan 范围的修改 → send_message 请求 orchestrator 批准"
      - "plan 中的里程碑 → 每完成一个自动触发 post-step 钩子"
    output: "按 plan.md 定义的实际代码文件"
    notification: |
      send_message(type="message", recipient="main",
        event_type="task_complete")
```

### 规划文档格式（plan.md 模板）

```markdown
# 任务规划 T{XXX}

## 目标
{一句话描述要实现什么}

## 上下文分析
- **上游依赖**: {来自哪些任务，产出物是什么}
- **技术栈**: {使用的技术和版本}
- **现有代码影响**: {会影响的文件和模块}

## 执行计划

### Step 1: {步骤描述}
- **操作**: 新建/修改 {文件路径}
- **原因**: {为什么需要这一步}
- **风险**: {潜在问题}
- **验证**: {怎么确认这步做对了}

### Step 2: ...

### Step 3: ...

## 影响范围
| 操作 | 文件路径 | 操作类型 |
|------|---------|---------|
| 新建 | src/components/UserForm.vue | create |
| 修改 | src/router/index.ts | modify |
| 删除 | src/utils/legacy.js | delete |

## 风险评估
| 风险 | 严重度 | 缓解措施 |
|------|--------|---------|
| 依赖版本不兼容 | 中 | 检查 package.json 依赖树 |
| 影响已有测试 | 高 | 先运行全量测试确认基线 |

## 预估
- **预估轮次**: {N} 轮
- **预估产出物**: {文件列表}
```

---

## 模块二：上下文工程（Context Engineering）

> **核心理念**：上下文窗口是有限内存，不是无限画布。
> 填得越满，决策质量越低。必须像管理内存一样管理上下文。
> 参考 Claude Code 的分层上下文策略。

### 上下文分层策略

```yaml
context_layers:
  # ═══ Layer 1: 常驻上下文（Hot Memory）═══
  # 每次 spawn 都注入，始终保持在场
  layer_1_hot:
    budget: "≤ 3000 tokens"
    contents:
      - "角色身份 + 核心职责（~200 tokens）"
      - "当前任务的 Goal success_criteria + constraints（~500 tokens）"
      - "可用 Skills Catalog（Tier 1 列表，~300 tokens）"
      - "风险分级权限表（~200 tokens）"
      - "当前执行阶段标识（~50 tokens）"
    rule: "精简到极致，只保留决策所需的最少信息"

  # ═══ Layer 2: 按需上下文（Working Memory）═══
  # 任务启动时一次性加载，执行期间可能被压缩
  layer_2_working:
    budget: "≤ 15000 tokens"
    contents:
      - "完整 SKILL.md（~2000 tokens）"
      - "项目 HEARTBEAT 状态摘要（~1000 tokens）"
      - "上游任务 HEARTBEAT 核心结论（~500 tokens/task）"
      - "context_pool/tech_stack.md（~1000 tokens）"
      - "context_pool/architecture.md（~1000 tokens）"
      - "plan.md（当前任务规划，~1500 tokens）"
      - "Domain Skills（按需，每个 ~2000 tokens）"
    rule: "启动时批量加载，执行中如感觉冗余则压缩"

  # ═══ Layer 3: 引用上下文（Cold Reference）═══
  # 不主动加载，需要时 read_file 读取后即弃
  layer_3_cold:
    contents:
      - "pm-coder/references/code-standards.md"
      - "pm-coder/references/acceptance-criteria.md"
      - "pm-coder/references/heartbeat-ops.md"
      - "pm-coder/references/handoff-protocol.md"
      - "pm-coder/references/hooks-specification.md"
      - "shared/references/recovery-recipes.md"
    rule: "只在 prompt 中给出路径提示，Agent 自行判断何时读取"
```

### 噪声过滤规范

```yaml
noise_filtering:
  # 执行命令时的输出截断
  execute_command_output:
    max_lines: 50                    # 命令输出最多保留50行
    truncation_message: "... (输出已截断，保留最后 N 行)"
    smart_extraction:
      # 从冗长输出中提取决策关键信息
      test_output:
        extract_pattern: "(PASS|FAIL|ERROR|✓|✗|passed|failed)"
        summary_template: "测试: {passed} passed, {failed} failed, {total} total"
      build_output:
        extract_pattern: "(error|Error|ERROR|warning|Warning)"
        summary_template: "构建: {errors} errors, {warnings} warnings"
      install_output:
        extract_pattern: "(added|removed|changed|up to date)"
        summary_template: "安装: {added} added, {removed} removed"

  # 文件读取时的选择性加载
  file_reading:
    large_file_threshold: 500         # 超过500行的文件，只读相关部分
    strategy: "先 search_content 定位行号 → read_file(offset, limit)"
    skip_patterns:
      - "*.min.js"
      - "*.map"
      - "node_modules/**"
      - "dist/**"
      - "*.lock"
```

### 上下文预算控制

```yaml
context_budget:
  # 轮次消耗预估（粗粒度）
  estimated_tokens_per_turn:
    read_file_small: 500              # < 100行的文件
    read_file_large: 3000             # > 100行的文件
    search_content: 800               # 搜索结果
    write_to_file: 1500               # 创建文件（含内容）
    replace_in_file: 1000             # 编辑文件
    execute_command: 2000             # 命令输出（截断后）
    send_message: 300                 # 通信消息

  # 上下文健康度监控
  health_check:
    trigger: "每完成一个 plan step 后"
    action: |
      1. 评估已用轮次 / max_turns
      2. 如使用率 > 60% → 压缩 Layer 2（HEARTBEAT已记录关键信息）
      3. 如使用率 > 80% → 启动交接流程（HANDOFF），请求 orchestrator 续接
    escalation: "使用率 > 90% → 立即 HANDOFF，不再执行新操作"
```

---

## 模块三：意图-执行解耦（Intent-Execution Decoupling）

> **核心理念**：用户/orchestrator 的意图描述 ≠ Agent 的执行指令。
> 中间需要一个"意图解析层"将模糊需求转化为精确的系统操作。
> 在 Harness 层面，这个解析发生在 Phase A（规划阶段）。

### 意图解析流程

```yaml
intent_resolution:
  # 输入：orchestrator 派发的任务描述（自然语言）
  # 输出：结构化执行指令（plan.md）

  parse_phases:
    # 1. 歧义消除
    - step: "clarify"
      actions:
        - "任务描述有歧义？→ send_message 请求 orchestrator 澄清"
        - "边界条件不明确？→ 在 plan.md 中列出假设并标注 [待确认]"
        - "多个技术方案可选？→ 在 plan.md 中列出候选方案 + 推荐理由"

    # 2. 范围锚定
    - step: "scope"
      actions:
        - "明确 In Scope / Out Scope"
        - "列出所有会受影响的文件（已有文件 + 新建文件）"
        - "评估是否有隐含依赖（修改A可能影响B）"

    # 3. 风险预判
    - step: "risk_assess"
      actions:
        - "技术风险（兼容性、性能、安全性）"
        - "协作风险（是否影响其他 Agent 的工作文件）"
        - "回滚难度（能否安全撤销）"
```

### 与三层洋葱模型的关系

```
意图解析层（Phase A 新增）
    │
    │ 将模糊需求转化为结构化 plan.md
    ▼
Layer 1: Identity（不变）
    │ 角色身份 + 成功标准 + 约束
    ▼
Layer 2: Narrative（不变）
    │ 项目状态 + 上游结论
    ▼
Layer 3: Focus（增强）
    │ 原来是：任务描述（自然语言）
    │ 现在是：plan.md（结构化执行指令）+ 审批状态
```

---

## 模块四：风险分级权限（Risk-Graded Permission）

> **核心理念**：打破"全部允许/全部拒绝"的二选一困境。
> 根据操作的危险程度动态设卡，平衡效率与安全。
> 参考 Claude Code 的 permission sliding scale。

### 三级权限标尺

```yaml
permission_levels:
  # ═══ 绿灯（低风险）— 自主执行，不打断 ═══
  green:
    description: "只读操作 + 新建非关键文件"
    auto_approve: true
    operations:
      - read_file                     # 读取任何文件
      - search_file                   # 搜索文件
      - search_content                # 搜索内容
      - write_to_file                 # 创建新文件（workspace 内）
      - send_message                  # 通信
    rule: "绿灯操作无需 orchestrator 审批，自主执行"

  # ═══ 黄灯（中风险）— 需要确认 ═══
  yellow:
    description: "修改已有文件 + 运行构建/测试命令"
    auto_approve: false
    require_notification: true
    operations:
      - replace_in_file               # 修改已有文件
      - execute_command: [build_cmds] # 编译、打包
      - execute_command: [test_cmds]  # 测试
    notification: |
      send_message(type="message", recipient="main",
        event_type="risk_notification",
        level="yellow",
        operation="{具体操作}",
        reason="{为什么需要这个操作}")
    rule: "黄灯操作不阻塞，但必须通知 orchestrator。
           orchestrator 可在下一个轮询周期介入拦截"

  # ═══ 红灯（高风险）— 必须人工确认 ═══
  red:
    description: "删除文件 + 修改配置 + 破坏性操作"
    auto_approve: false
    require_approval: true
    operations:
      - delete_file                   # 删除任何文件
      - replace_in_file: [config_files]  # 修改配置文件
      - execute_command: [dangerous_cmds] # 数据库迁移、部署等
    approval_flow: |
      send_message(type="message", recipient="main",
        event_type="risk_approval_request",
        level="red",
        operation="{具体操作}",
        impact="{影响分析}",
        rollback="{回滚方案}")
      等待 orchestrator 响应：
        ├── approved → 继续执行
        ├── rejected → 放弃该操作，调整方案
        └── timeout (60s) → 放弃该操作，send_message 报告
    config_files:
      - "package.json"
      - "tsconfig.json"
      - ".eslintrc.*"
      - "vite.config.*"
      - "pyproject.toml"
      - "docker-compose.yml"
      - ".env*"
    dangerous_cmds:
      - "npm publish"
      - "git push"
      - "rm -rf"
      - "DROP TABLE"
      - "DELETE FROM"
      - "docker build"

  # ═══ 超红灯（禁区）— 禁止执行 ═══
  prohibited:
    description: "绝对不允许的操作"
    operations:
      - "修改 workspace 之外的文件"
      - "执行未列在 allowed_tools 中的命令"
      - "安装全局 npm/pip 包（污染宿主环境）"
      - "访问网络（除非 orchestrator 明确授权）"
      - "硬编码敏感信息到代码中"
    violation_handling: |
      立即 send_message(type="message", recipient="main",
        event_type="permission_violation",
        operation="{尝试的操作}")
      跳过该操作，继续 plan 中的下一步
```

### 执行命令白名单

```yaml
allowed_execute_commands:
  # 包管理
  - npm install
  - npm run build
  - npm run test
  - npm run lint
  - pnpm install
  - pnpm run build
  - pnpm run test
  - yarn install
  - yarn build
  - yarn test

  # 编译检查
  - tsc --noEmit
  - python -m py_compile
  - python -m pytest
  - python -m black --check

  # 代码质量
  - eslint
  - prettier --check
  - pylint
  - mypy

  # 项目工具（项目特定）
  # orchestrator 可在 spawn 时追加项目特定的允许命令
  extra: []  # 由 orchestrator 动态填充
```

---

## 模块五：交接棒机制（Baton-Style Handoff）

> **核心理念**：长任务中，上下文会逐渐膨胀，决策质量下降。
> 在上下文接近极限前，主动将当前状态压缩为交接文档，
> 让新的 Agent 实例可以无缝接手。
> 参考 Claude Code 的 HANDOFF.md。

### 触发条件

```yaml
handoff_triggers:
  # 自动触发
  automatic:
    - condition: "已用轮次 > max_turns × 70%"
      action: "启动交接流程"
    - condition: "上下文使用率 > 预警阈值（Layer 2 budget 耗尽）"
      action: "启动交接流程"
    - condition: "DS3 上下文保存默认技能触发"
      action: "与 HANDOFF 合并执行"

  # 手动触发
  manual:
    - condition: "orchestrator send_message 要求交接"
      action: "立即启动交接流程"
    - condition: "子Agent感知到上下文质量下降"
      action: "主动发起交接"
```

### 交接流程

```yaml
handoff_procedure:
  # Step 1: 停止新操作
  - step: "freeze"
    action: "不再启动新的编码操作，只完成当前进行中的单步操作"

  # Step 2: 压缩当前状态
  - step: "compress"
    action: "生成 HANDOFF.md"
    template: |
      # HANDOFF: T{XXX}

      ## 交接原因
      {auto: 上下文预算耗尽 | manual: orchestrator 请求}

      ## 当前进度
      ### 已完成
      - [x] {步骤1}（产出：{文件路径}）
      - [x] {步骤2}（产出：{文件路径}）
      ### 进行中
      - [ ] {步骤3} — 进度 {N}%
      ### 未开始
      - [ ] {步骤4}
      - [ ] {步骤5}

      ## 系统状态
      - **plan.md 路径**: {路径}
      - **HEARTBEAT 路径**: {路径}
      - **当前执行阶段**: {explore/execute}
      - **已用轮次**: {N}/{max_turns}

      ## 关键决策记录
      | # | 决策 | 选择 | 原因 |
      |---|------|------|------|
      | 1 | {决策描述} | {选择A} | {原因} |

      ## 遗留问题
      | # | 问题描述 | 尝试过的方案 | 状态 |
      |---|---------|-------------|------|
      | 1 | {问题} | {方案} | ⏳待解决 |

      ## 下一步建议
      1. {建议的下一步}
      2. {注意事项}

      ## 恢复指引
      1. read_file T{XXX}-plan.md → 了解完整规划
      2. read_file T{XXX}-heartbeat.md → 了解任务状态
      3. 从"进行中"步骤的 {N}% 处继续
      4. 注意：{关键注意事项}

    output_path: ".workbuddy/context_pool/progress/T{XXX}-handoff.md"

  # Step 3: 更新 HEARTBEAT
  - step: "sync"
    action: |
      replace_in_file 更新任务 HEARTBEAT：
      - 状态改为 🔄 handoff
      - 记录交接原因和 HANDOFF.md 路径
      - 压缩"遇到的问题"区域（只保留未解决的问题）

  # Step 4: 通知 orchestrator
  - step: "notify"
    action: |
      send_message(type="message", recipient="main",
        event_type="task_handoff",
        task_id: "T{XXX}",
        handoff_path: "T{XXX}-handoff.md",
        progress_pct: {当前进度},
        reason: {交接原因})
    # orchestrator 收到后：
    # 1. 读取 HANDOFF.md
    # 2. 重新 spawn 新的 coder 子Agent
    # 3. 新 Agent 通过 HANDOFF.md 恢复上下文
```

详见：`pm-coder/references/handoff-protocol.md`

---

## 模块六：事件驱动钩子（Event-Driven Hooks）

> **核心理念**：用确定性的检查规则，约束非确定性的 AI 行为。
> 在 Agent 执行生命周期的关键节点，自动触发预定义的检查脚本。
> 参考 Claude Code 的 Hooks 系统。

### 钩子定义

```yaml
hooks:
  # ═══ 编码前钩子（Pre-Edit Hooks）═══
  pre_edit:
    - name: "plan_compliance_check"
      trigger: "每次 write_to_file 或 replace_in_file 前"
      description: "检查操作是否在 plan.md 范围内"
      check: |
        1. 当前操作的文件是否列在 plan.md 的「影响范围」中？
        2. 如果不在 → send_message 请求 orchestrator 批准
        3. 如果在 → 继续

    - name: "file_ownership_check"
      trigger: "每次 replace_in_file 前"
      description: "检查文件是否被其他 Agent 占用"
      check: |
        1. 读取项目 HEARTBEAT 的文件索引区
        2. 目标文件是否被标记为其他 Agent 的产出物？
        3. 如果是 → send_message 通知 orchestrator 协调

  # ═══ 编码后钩子（Post-Edit Hooks）═══
  post_edit:
    - name: "syntax_check"
      trigger: "每次修改 .ts/.tsx/.py/.js/.vue 文件后"
      description: "快速语法检查，捕获低级错误"
      commands:
        - "tsc --noEmit {file}"        # TypeScript
        - "python -m py_compile {file}" # Python
      on_failure: |
        1. 分析错误信息
        2. 立即修复语法错误
        3. 重新检查直到通过
        4. 3次不通过 → send_message 通知 orchestrator

    - name: "heartbeat_sync"
      trigger: "每次 write_to_file / replace_in_file 成功后"
      description: "同步更新 HEARTBEAT 产出物清单"
      action: |
        replace_in_file 在任务 HEARTBEAT 的"产出物"区追加新文件路径

  # ═══ 步骤完成钩子（Post-Step Hooks）═══
  post_step:
    - name: "milestone_quality_gate"
      trigger: "完成 plan.md 中的每个里程碑步骤后"
      description: "质量门禁检查"
      check: |
        1. plan.md 中该步骤定义了 quality_gate？
        2. 如定义了 → 执行对应的验证命令
        3. 验证通过 → 标记步骤完成 → 继续
        4. 验证失败 → 修复 → 重试（最多2次）
        5. 2次仍失败 → send_message 通知 orchestrator

    - name: "progress_report"
      trigger: "每完成一个 plan step 后"
      description: "向 orchestrator 报告进度"
      action: |
        send_message(type="message", recipient="main",
          event_type="task_progress",
          progress_pct: {当前进度},
          completed_step: "{步骤描述}",
          next_step: "{下一步描述}")

  # ═══ 任务完成钩子（Completion Hooks）═══
  on_complete:
    - name: "full_test_suite"
      trigger: "准备发送 task_complete 前"
      description: "运行完整测试套件"
      commands:
        - "npm run test"               # Node.js
        - "python -m pytest"           # Python
      on_failure: |
        1. 分析失败测试
        2. 修复代码
        3. 重新运行（最多2次）
        4. 仍失败 → send_message(task_partial_success) 而非 task_complete

    - name: "lint_check"
      trigger: "准备发送 task_complete 前"
      description: "代码风格检查"
      commands:
        - "npm run lint"               # Node.js
        - "pylint {src}"               # Python
      on_failure: |
        1. 自动修复可自动修复的问题
        2. 无法自动修复 → 标注为 warning，不阻塞交付

    - name: "deliverable_integrity"
      trigger: "准备发送 task_complete 前"
      description: "产出物完整性检查"
      check: |
        1. plan.md 中列出的所有文件是否都已创建/修改？
        2. HEARTBEAT 的产出物清单是否与实际文件一致？
        3. 新建文件是否有正确的文件头注释？

    - name: "code_review_stage1"           # ★ 修改：改为轻量自检
      trigger: "Stage 2 代码质量审查之前"
      type: "lightweight_self_check"
      description: "功能完整性自检 — 关键词匹配级别（非语义推理）"
      check: |
        详见 references/code-review-protocol.md Stage 1
        ⚠️ 注意：此为轻量级自检，不依赖语义推理
        1. 关键词匹配：代码中是否包含 Spec 中的关键术语（如 API 端点名称）
        2. 文件完整性：plan.md 中列出的文件是否都已创建
        3. 完整语义审查由 orchestrator 验收时执行
      on_failure: |
        缺失关键词/文件 → 修复 → 重新检查
        注意：此检查只做关键词匹配，不做语义理解

    - name: "code_review_stage2"           # ★ 修改：改为计算型检查
      trigger: "计算型传感器全部通过后"
      type: "computational_sensor"
      description: "代码质量检查 — H7/H8/H9 Hooks（非语义推理）"
      check: |
        详见 references/code-review-protocol.md Stage 2
        ⚠️ 注意：完整语义评估由 orchestrator 验收时执行
        1. H7 full_test_suite — 测试套件运行
        2. H8 lint_check — 代码风格检查
        3. H9 deliverable_integrity — 产出物完整性检查
      on_failure: |
        H7/H8/H9 阻塞项 → 修复 → 重新检查
        注意：语义级质量审查由 orchestrator 三角验证执行

  # ═══ 调试模式钩子（Debug Hooks）═══  ★ 新增模块
  on_debug:
    - name: "debug_phase_gate"
      trigger: "调试类任务启动时"
      description: "强制使用四阶段调试 SOP"
      check: |
        详见 references/debugging-protocol.md
        1. 确认任务类型为 debugging
        2. 检查 plan.md 是否包含四阶段结构
        3. 如果不是 → 强制替换为调试任务模板
      reference: "pm-coder/references/debugging-protocol.md"

    - name: "debug_stop_loss"
      trigger: "同一 bug 经过 2 轮完整流程仍未修复"
      description: "止损机制 — 停止硬磕，升级处理"
      action: |
        1. 冻结当前调试尝试
        2. send_message(task_blocked) 附带调试记录
        3. 建议 orchestrator 委托 researcher 或人工介入
```

### 钩子执行顺序

```
编码操作（write_to_file / replace_in_file）
    │
    ├──→ pre_edit: plan_compliance_check
    ├──→ pre_edit: file_ownership_check
    │    ├── 通过 → 执行操作
    │    └── 不通过 → 阻止操作 / 请求审批
    │
    ▼
    操作完成
    │
    ├──→ post_edit: syntax_check
    ├──→ post_edit: heartbeat_sync
    │
    ▼
步骤完成（plan step 完成）
    │
    ├──→ post_step: milestone_quality_gate
    ├──→ post_step: progress_report
    │
    ▼
任务完成（所有步骤完成）
    │
    ├──→ on_complete: full_test_suite
    ├──→ on_complete: lint_check
    ├──→ on_complete: deliverable_integrity
    │    ├── 全部通过 → send_message(task_complete)
    │    └── 有失败 → send_message(task_partial_success)
```

详见：`pm-coder/references/hooks-specification.md`

---

## 权限模式（汇总）

```yaml
permission_mode: "workspace-write"
# 细粒度权限由模块四（风险分级权限）控制
# 超红灯操作（prohibited）在任何模式下都禁止
```

## 工具限制

```yaml
allowed_tools:
  # ═══ 绿灯工具（自主执行）═══
  - read_file
  - search_file
  - search_content
  - send_message

  # ═══ 黄灯工具（通知后执行）═══
  - write_to_file          # 创建新文件（黄灯，但通常免审批）
  - replace_in_file        # 修改已有文件（黄灯，需通知）

  # ═══ 红灯工具（需审批）═══
  - execute_command        # 仅限白名单命令（见模块四）
  # 注意：不在白名单中的命令 → 红灯，需审批
  # 超红灯：workspace 之外的文件操作、全局包安装等 → 禁止
```

## Skill 加载策略（渐进式披露，参考 Hive）

| Skill | 路径 | 层级 | 加载时机 | 说明 |
|-------|------|------|---------|------|
| pm-coder | `pm-coder/SKILL.md` | Tier 1+2 | always | 核心行为规范 |
| pm-coder heartbeat-ops | `pm-coder/references/heartbeat-ops.md` | Tier 3 | on_demand | HEARTBEAT操作详细规范 |
| pm-coder code-standards | `pm-coder/references/code-standards.md` | Tier 3 | on_demand | 编码标准参考 |
| pm-coder acceptance-criteria | `pm-coder/references/acceptance-criteria.md` | Tier 3 | on_demand | 验收标准清单 |
| pm-coder handoff-protocol | `pm-coder/references/handoff-protocol.md` | Tier 3 | on_handoff | 交接协议 |
| pm-coder hooks-specification | `pm-coder/references/hooks-specification.md` | Tier 3 | on_demand | 钩子详细规范 |
| pm-coder code-review-protocol | `pm-coder/references/code-review-protocol.md` | Tier 3 | on_review | 两阶段Code Review |
| pm-coder debugging-protocol | `pm-coder/references/debugging-protocol.md` | Tier 3 | on_debug | 四阶段调试SOP |
| Domain Skills | `~/.workbuddy/skills/{domain}/` | Tier 1+2 | 动态 | 如 vue3, electron, fastapi |
| recovery-recipes | `shared/references/recovery-recipes.md` | Tier 3 | on_failure | 恢复配方 |

## Skill 注入方式（三层 Prompt 洋葱，增强版）

pm-coder 的 prompt 按四层组织（在原三层洋葱基础上增加意图解析层）：

```markdown
# prompt 模板（orchestrator 拼接后传给 task）

# ========== Layer 0: Intent Resolution ==========
## 当前执行阶段: {explore | execute}
## 审批状态: {pending | approved | rejected}
{如为 execute 阶段：附 plan.md 路径，指示 Agent 先读取}

# ========== Layer 1: Identity ==========
你是 pm-coder，AI产品经理团队的编程执行专家。

## 成功标准（来自 Goal）
{从 context_pool/goal.md 提取与本任务相关的 success_criteria}

## 约束条件（来自 Goal）
{从 context_pool/goal.md 提取与本任务相关的 constraints}

## 第一步：读取你的 Skill 规范
请执行：read_file("pm-coder/SKILL.md")
然后严格按照 SKILL.md 中的工作流程执行任务。

## 风险分级权限表 ⭐
- 🟢 绿灯（自主执行）：read_file, search_*, send_message, write_to_file
- 🟡 黄灯（通知后执行）：replace_in_file, execute_command(白名单)
- 🔴 红灯（需审批）：execute_command(非白名单), 修改配置文件, delete
- 🚫 禁区：workspace外操作, 全局包安装, 网络访问, 硬编码敏感信息

## 可用 Skills（Catalog）
{Tier 1 列表：name + description + 路径}

# ========== Layer 2: Narrative ==========
## 项目状态
{从 .workbuddy/HEARTBEAT.md 提取任务看板相关行}

## 上游产出
{从上游 T{YYY}-heartbeat.md 提取核心结论（如有依赖）}

## 已完成阶段
{列出已完成的任务及其结论摘要}

# ========== Layer 3: Focus ==========
## 当前任务
任务ID: T{XXX}
类型: {任务类型}
描述: {任务描述}

## 输出要求
- 格式: {输出格式}
- 位置: {输出路径}
- 验收标准: {从 Goal 的 success_criteria 提取}

## 上下文预算提醒 ⭐
- max_turns: {N}，建议探索阶段 ≤ 10 轮
- 上下文预警：已用轮次 > 70% 时启动 HANDOFF

## 记忆要求 ⭐
1. 启动时: read_file 项目HEARTBEAT.md
2. 启动时: read_file 上游 T{YYY}-heartbeat.md（如有）
3. 启动时: write_to_file 创建 T{XXX}-heartbeat.md（120秒内）
4. 规划时: write_to_file 创建 T{XXX}-plan.md
5. 执行中: replace_in_file 更新进度
6. 完成时: send_message(task_complete)
7. 阻塞时: send_message(task_blocked)
8. 交接时: write_to_file T{XXX}-handoff.md + send_message(task_handoff)

## 三角验证 ⭐
编码完成后，按以下三层验证：

### 信号1：确定性规则（Coder 自验证 + 钩子自动触发）
1. post_edit 钩子：语法检查（tsc/py_compile）
2. on_complete 钩子：H7 完整测试套件 + H8 lint 检查
3. on_complete 钩子：H9 产出物完整性检查
4. on_complete 钩子：Stage 1 轻量自检（关键词匹配）
→ 全部通过后 send_message(task_complete)

### 信号2：语义评估（orchestrator 验收时执行）
> ⚠️ 重要：Coder 自审查存在逻辑漏洞，语义级审查由 orchestrator 执行
- orchestrator 收到 task_complete 后，执行三角验证的语义评估层
- 对比 Goal 的 success_criteria 加权打分
- 完整的 Spec 深度对照和代码质量语义审查
→ 不通过 → 按恢复配方 R6 处理，发送回 coder 修复

### 信号3：人工判断
- 编译通过但测试覆盖不足 → 人工确认
- 架构决策影响后续 → 人工确认
- 约束违规 → ESCALATE

## 可加载的参考资料（Tier 3）
- pm-coder/references/heartbeat-ops.md
- pm-coder/references/code-standards.md
- pm-coder/references/acceptance-criteria.md
- pm-coder/references/handoff-protocol.md
- pm-coder/references/hooks-specification.md
- pm-coder/references/code-review-protocol.md     # ★ 两阶段Code Review
- pm-coder/references/debugging-protocol.md        # ★ 四阶段调试SOP
- shared/references/recovery-recipes.md
```

## 通信配置

```yaml
communication:
  heartbeat_path: ".workbuddy/context_pool/progress/T{XXX}-heartbeat.md"
  project_heartbeat: ".workbuddy/HEARTBEAT.md"

  notify_on:
    # ═══ 规划阶段事件 ═══
    - event: plan_ready
      message: |
        【plan_ready】T{XXX} | pm-coder | Phase A
        规划文档: {plan_path}
        请求审批

    - event: plan_approved
      message: |
        【plan_approved】T{XXX} | pm-coder | Phase A→C
        开始执行编码

    # ═══ 执行阶段事件 ═══
    - event: progress
      message: |
        【task_progress】T{XXX} | pm-coder | {progress_pct}%
        已完成: {completed_step}
        下一步: {next_step}

    - event: blocked
      message: |
        【task_blocked】T{XXX} | pm-coder
        原因: {block_reason}
        需要: {needed_from}

    - event: partial_success
      message: |
        【task_partial_success】T{XXX} | pm-coder
        完成: {completed_items}
        未完成: {incomplete_items}
        建议: {suggestion}

    - event: complete
      message: |
        【task_complete】T{XXX} | pm-coder | 100%
        产出物: {deliverable_paths}
        建议: {downstream_suggestions}

    # ═══ 权限事件 ═══
    - event: risk_notification
      message: |
        【risk_notification】T{XXX} | pm-coder | 🟡
        操作: {operation}
        原因: {reason}

    - event: risk_approval_request
      message: |
        【risk_approval_request】T{XXX} | pm-coder | 🔴
        操作: {operation}
        影响: {impact}
        回滚: {rollback}

    - event: permission_violation
      message: |
        【permission_violation】T{XXX} | pm-coder | 🚫
        尝试: {attempted_operation}

    # ═══ 交接事件 ═══
    - event: handoff
      message: |
        【task_handoff】T{XXX} | pm-coder
        交接文档: {handoff_path}
        进度: {progress_pct}%
        原因: {handoff_reason}

  recipient: "main"
```

## 适用任务类型

| 任务类型 | 典型场景 | 额外Skills | 预估轮次 |
|---------|---------|-----------|---------|
| frontend | Vue3/React页面开发 | vue3, react, electron | 50 |
| backend | API/服务端开发 | fastapi, express, prisma | 50 |
| database | 数据库设计与实现 | sql, mongodb | 30 |
| testing | 单元/集成测试 | jest, pytest | 30 |
| debugging | Bug修复 | 视具体项目而定 | 30 |
| refactoring | 代码重构 | 视具体项目而定 | 40 |

## 与其他模块的协作关系

```yaml
integration:
  # 与 orchestrator-harness 的关系
  orchestrator:
    - "Phase A 规划 → orchestrator 审批（审批门控）"
    - "黄灯通知 → orchestrator 监听"
    - "红灯审批 → orchestrator 裁决"
    - "交接 → orchestrator 重新 spawn"
    - "健康报告 → orchestrator 聚合（health_report）"

  # 与共享参考文件的关系
  shared_references:
    - "recovery-recipes.md → 失败恢复"
    - "default-skills.md → 行为纪律（DS1-DS6）"
    - "health-check-protocols.md → orchestrator 健康检查时的产出物抽查"
    - "checkpoint-recovery.md → 崩溃恢复时的任务快照"
```
