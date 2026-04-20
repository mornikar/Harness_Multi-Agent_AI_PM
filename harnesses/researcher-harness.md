# Researcher Harness 定义

> pm-researcher 子Agent 的执行载体定义。
> 设计参考：claw-code 的 Worker 生命周期 + 权限分层 + 工具最小化原则；
> Hive 的目标注入 + 三角验证 + 三层洋葱模型。

## 基本配置

```yaml
name: pm-researcher
harness_type: subagent
description: |
  信息检索与分析子Agent。负责技术调研、竞品分析、方案选型。
  通过 task 工具以 Team Mode spawn，加入项目团队协作。

spawn_config:
  subagent_name: "code-explorer"    # 复用 code-explorer（支持文件探索+搜索）
  mode: "acceptEdits"
  max_turns: 40                     # 调研任务通常不需要太多轮次
  # name: "researcher-T{XXX}"
  # team_name: "{project-team}"

# 权限模式
permission_mode: "workspace-write"  # 可写工作空间文件

# 工具限制（最小权限原则）
allowed_tools:
  - read_file              # 读取文件
  - write_to_file          # 创建报告文件
  - replace_in_file        # 更新 HEARTBEAT
  - search_file            # 文件搜索
  - search_content         # 内容搜索
  - send_message           # 通信
  - web_search             # 互联网搜索（调研核心工具）
  - web_fetch              # 网页抓取（读取文档）
  # 注意：不授予 execute_command（调研不需要执行命令）
```

## Skill 加载策略（渐进式披露，参考 Hive）

| Skill | 路径 | 层级 | 加载时机 | 说明 |
|-------|------|------|---------|------|
| pm-researcher | `pm-researcher/SKILL.md` | Tier 1+2 | always | 核心行为规范 |
| pm-researcher report-templates | `pm-researcher/references/report-templates.md` | Tier 3 | on_demand | 调研报告模板参考 |
| Domain Skills | `~/.workbuddy/skills/{domain}/` | Tier 1+2 | 动态（Phase 3获取） | 如 web-search, github |
| recovery-recipes | `shared/references/recovery-recipes.md` | Tier 3 | on_failure | 恢复配方 |

## Skill 注入方式（三层 Prompt 洋葱，参考 Hive）

```markdown
# prompt 模板（orchestrator 按三层洋葱模型拼接后传给 task）

# ========== Layer 1: Identity ==========
你是 pm-researcher，AI产品经理团队的信息检索与分析专家。

## 成功标准（来自 Goal）
{从 context_pool/goal.md 提取与本任务相关的 success_criteria}
如：调研报告覆盖所有候选方案、结论有数据支撑、给出明确推荐

## 约束条件（来自 Goal）
{从 context_pool/goal.md 提取与本任务相关的 constraints}

## 第一步：读取你的 Skill 规范
请执行：read_file("pm-researcher/SKILL.md")
然后严格按照 SKILL.md 中的工作流程执行任务。

## 可用 Skills（Catalog）
{Tier 1 列表}

# ========== Layer 2: Narrative ==========
## 项目状态
{从 .workbuddy/HEARTBEAT.md 提取任务看板相关行}

## 产品定义
{从 .workbuddy/context_pool/product.md 提取}

## 需求清单
{从 .workbuddy/context_pool/requirements.md 提取}

# ========== Layer 3: Focus ==========
## 当前任务
任务ID: T{XXX}
类型: {调研类型}
描述: {调研目标}

## 输出要求
- 格式: Markdown调研报告
- 位置: .workbuddy/context_pool/progress/T{XXX}-report.md
- 必须包含: 推荐结论、风险评估、对下游任务的影响建议

## 记忆要求 ⭐
1. 启动时: read_file 读取项目HEARTBEAT.md
2. 启动时: read_file 读取 product.md 和 requirements.md
3. 启动时: write_to_file 创建 T{XXX}-heartbeat.md（必须在120秒内完成）
4. 发现关键信息时: replace_in_file 更新任务HEARTBEAT
5. 完成时: replace_in_file 更新状态为completed
6. 完成时: send_message(type="message", recipient="main", ...) 通知 orchestrator
7. 阻塞时: send_message(type="message", recipient="main", ...) 通知 orchestrator
8. 失败时: 先按恢复配方恢复，再通知 orchestrator

## 三角验证 ⭐（新增，参考 Hive）

### 信号1：确定性规则（自验证）
1. 推荐结论是否明确（不能模棱两可）
2. 信息来源是否标注时效性（🟢/🟡/🔴）
3. 是否覆盖了所有候选方案
4. 风险与注意事项是否列出
5. 对下游任务的影响是否明确
→ 自验证通过后 send_message(task_complete)

### 信号2：语义评估
- orchestrator 对比 Goal 的 success_criteria 评估调研质量
- 特别关注：结论是否有足够数据支撑、是否覆盖约束条件

### 信号3：人工判断
- 以下情况需人工确认：
  - 多个方案无明确优劣（需要用户决策）
  - 调研发现可能影响项目范围（需求变更风险）

## 可加载的参考资料（Tier 3，按需加载）
- pm-researcher/references/report-templates.md（报告模板）
- shared/references/recovery-recipes.md  （恢复配方，失败时加载）
```

## 通信配置

```yaml
communication:
  heartbeat_path: ".workbuddy/context_pool/progress/T{XXX}-heartbeat.md"
  project_heartbeat: ".workbuddy/HEARTBEAT.md"
  
  notify_on:
    - event: complete
      message: |
        【task_complete】T{XXX} | pm-researcher | 100%
        推荐结论: {核心推荐}
        产出物: {报告路径}
        对下游影响: {哪些下游任务可以启动}
    - event: blocked
      message: |
        【task_blocked】T{XXX} | pm-researcher
        原因: {信息不足/方向不明确}
        已有阶段性结论: {已收集到的信息}
        需要: {需要什么信息或决策}
    - event: partial_success
      message: |
        【task_partial_success】T{XXX} | pm-researcher
        已完成: {已调研的方案}
        未完成: {缺少信息的方案}
        建议: {是否基于已有信息给出推荐}
  
  recipient: "main"
```

## 适用任务类型

| 任务类型 | 典型场景 | 额外Skills | 预估轮次 |
|---------|---------|-----------|---------|
| tech_research | 技术框架调研选型 | web-search, github | 40 |
| competitive | 竞品分析 | web-search | 30 |
| feasibility | 可行性评估 | web-search | 30 |
| api_research | API文档查阅 | - | 25 |
| best_practice | 最佳实践收集 | web-search | 30 |

---

## 模块一：上下文工程（Context Engineering）

> **设计参考**：Claude Code 的分层上下文策略，适配调研任务的轻量版。
> **核心理念**：调研任务的核心风险是"信息过载"——搜索结果太多、上下文被无关信息填满。
> 必须像管理内存一样管理上下文。

### 上下文分层策略

```yaml
context_layers:
  # ═══ Layer 1: 常驻上下文（Hot Memory）═══
  # 每次 spawn 都注入，始终保持在场
  layer_1_hot:
    budget: "≤ 2000 tokens"
    contents:
      - "角色身份 + 核心职责（~200 tokens）"
      - "当前调研目标（~100 tokens）"
      - "Goal success_criteria（~300 tokens）"
      - "调研维度清单（~200 tokens）"
      - "可用 Skills Catalog（~200 tokens）"
    rule: "精简到极致，只保留决策所需的最少信息"

  # ═══ Layer 2: 工作上下文（Working Memory）═══
  # 任务启动时一次性加载，执行期间可能被压缩
  layer_2_working:
    budget: "≤ 10000 tokens"
    contents:
      - "完整 SKILL.md（~1500 tokens）"
      - "项目 HEARTBEAT 状态摘要（~800 tokens）"
      - "product.md（产品定义，~500 tokens）"
      - "requirements.md（需求清单，~800 tokens）"
      - "上游任务 HEARTBEAT 核心结论（~500 tokens/task）"
      - "Domain Skills（按需加载，每个 ~2000 tokens）"
    rule: "启动时批量加载，执行中感觉冗余则压缩"

  # ═══ Layer 3: 冷引用（Cold Reference）═══
  # 不主动加载，需要时 read_file 读取后即弃
  layer_3_cold:
    contents:
      - "pm-researcher/references/report-templates.md"
      - "shared/references/recovery-recipes.md"
      - "上游完整产出物（按需读取）"
    rule: "只在 prompt 中给出路径提示，Agent 自行判断何时读取"
```

### 噪声过滤规范

```yaml
noise_filtering:
  # 搜索结果截断
  search_results:
    max_results: 10                    # 最多保留前 10 条最相关结果
    summary_per_result: 200            # 每条结果最多 200 字摘要
    extract_fields:
      - "标题"
      - "来源网站"
      - "发布时间"
      - "核心结论摘要"
    truncation_indicator: "...（还有其他结果）"

  # 网页内容选择性加载
  web_content:
    strategy: |
      1. 先读取摘要/目录，判断是否与调研目标相关
      2. 如相关 → 读取完整内容
      3. 如不相关 → 跳过并记录原因
    skip_patterns:
      - "广告内容"
      - "评论区"
      - "无关导航菜单"
      - "页脚版权信息"

  # 大文件阈值
  large_file_threshold: 300            # 超过 300 行的文档，只读相关部分
  strategy: "先 search_content 定位 → read_file(offset, limit)"
```

### 上下文预算控制

```yaml
context_budget:
  estimated_tokens_per_turn:
    read_file_small: 500               # < 100 行的文件
    read_file_large: 2000              # > 100 行的文件
    search_content: 800                # 搜索结果
    web_fetch: 3000                    # 网页抓取（截断后）
    write_to_file: 1500                # 创建文件

  health_check:
    trigger: "每完成一个调研维度后"
    action: |
      1. 评估已用轮次 / max_turns（默认 40）
      2. 如使用率 > 60% → 压缩 Layer 2
      3. 如使用率 > 75% → 启动交接流程
    escalation: "使用率 > 90% → 立即交接，不再执行新操作"
```

---

## 模块二：调研质量钩子（Research Quality Hooks）

> **设计参考**：Coder Harness 的事件驱动钩子系统，适配调研任务。
> **核心理念**：用确定性检查规则约束调研质量，确保报告的完整性、一致性和时效性。

### 钩子定义

```yaml
hooks:
  # ═══ 步骤完成钩子（Post-Step Hooks）═══
  post_step:
    - name: "source_freshness_check"
      trigger: "每完成一个调研维度后"
      description: "检查信息来源时效性"
      check: |
        1. 标注每条关键信息的来源时效
        2. 🟢 绿色：1 年内（最新官方文档/论文）
        3. 🟡 黄色：1-3 年（较新，需标注可能过时）
        4. 🔴 红色：3 年以上（明显过时，标注警告）
        5. ⚪ 灰色：无法确定（标注未知）
      action: |
        在 HEARTBEAT 的"阶段性发现"区标注时效标签

    - name: "dimension_coverage_check"
      trigger: "每个调研维度完成后"
      description: "检查是否覆盖了所有候选方案"
      check: |
        1. 对照 plan.md 中的调研维度清单
        2. 确认每个维度都有实质性内容
        3. 如有遗漏 → 补充搜索或标注"待进一步调研"
      action: |
        replace_in_file 更新 HEARTBEAT 进度

    - name: "claim_verification"
      trigger: "报告中提出重要结论后"
      description: "重要结论必须有证据支撑"
      check: |
        1. 性能数据 → 必须有基准测试/官方数据
        2. 功能对比 → 必须有官方文档/实际测试
        3. 风险评估 → 必须有案例/公开事故报告
      on_failure: |
        标注"⚠️ 结论待验证"，避免误导下游

  # ═══ 任务完成钩子（Completion Hooks）═══
  on_complete:
    - name: "report_completeness_gate"
      trigger: "生成报告后、发送 task_complete 前"
      description: "报告完整性门禁"
      check: |
        1. 是否包含推荐结论（不能只列选项不给建议）
        2. 是否包含风险评估（每个方案至少一条风险）
        3. 是否包含下游影响建议（对其他任务的影响）
        4. 是否覆盖所有调研维度
        5. 重要数据是否标注来源和时效
      on_failure: |
        1. 缺失项 → 补充内容
        2. 如信息不足 → send_message(task_partial_success)
        3. 明确标注未覆盖的维度

    - name: "terminology_consistency_check"
      trigger: "报告完成后"
      description: "术语一致性检查"
      check: |
        1. 同一概念是否使用统一术语（如"前端"而非混用"前端/前台"）
        2. 技术术语是否拼写正确
        3. 版本号是否与官方一致
      action: |
        如发现不一致 → 自动修正并标注"术语已统一"

    - name: "citation_completeness"
      trigger: "报告完成后"
      description: "引用完整性检查"
      check: |
        1. 报告中标注的每个来源是否有完整引用
        2. 来源 URL 是否有效
        3. 发布时间是否标注
      action: |
        如有缺失 → 补充引用信息
```

### 钩子执行顺序

```
调研维度搜索（web_search / web_fetch）
    │
    ▼
每维度完成后
    ├──→ post_step: source_freshness_check（标注时效）
    ├──→ post_step: dimension_coverage_check（检查覆盖）
    └──→ post_step: claim_verification（验证重要结论）

所有维度调研完成
    │
    ▼
报告生成
    │
    ├──→ on_complete: report_completeness_gate
    ├──→ on_complete: terminology_consistency_check
    └──→ on_complete: citation_completeness
         │
         ▼
    全部通过 → send_message(task_complete)
    有失败 → 补充/修复 → 重新检查
```

---

## 模块三：交接棒机制（Baton-Style Handoff）

> **设计参考**：Coder Harness 的 HANDOFF 协议，适配调研任务的轻量版。
> **核心理念**：大型调研任务中可能需要交接，确保新 Agent 能无缝接手。

### 触发条件

```yaml
handoff_triggers:
  automatic:
    - condition: "已用轮次 > max_turns × 75%"
      action: "启动交接流程"
    - condition: "调研覆盖度 < 50% 但上下文接近极限"
      action: "启动交接流程"

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
    action: "不再启动新的调研操作，只完成当前维度"

  # Step 2: 压缩当前状态
  - step: "compress"
    action: "生成 HANDOFF.md"
    template: |
      # HANDOFF: T{XXX} 调研任务

      ## 交接原因
      {auto: 上下文预算耗尽 | manual: orchestrator 请求}

      ## 当前进度
      ### 已完成维度
      - [x] {维度1}：{核心结论摘要}
      - [x] {维度2}：{核心结论摘要}
      ### 进行中
      - [ ] {维度3} — 进度 {N}%
      ### 未开始
      - [ ] {维度4}
      - [ ] {维度5}

      ## 系统状态
      - **HEARTBEAT 路径**: {路径}
      - **已用轮次**: {N}/{max_turns}
      - **已收集来源数**: {N} 条

      ## 关键发现记录
      | # | 发现 | 来源 | 时效 |
      |---|------|------|------|
      | 1 | {发现描述} | {来源} | 🟢/🟡/🔴 |

      ## 遗留问题
      | # | 问题 | 状态 |
      |---|------|------|
      | 1 | {问题} | ⏳待解决 |

      ## 下一步建议
      1. {建议}
      2. {注意事项}

      ## 恢复指引
      1. read_file T{XXX}-heartbeat.md → 了解任务状态
      2. 继续未完成的维度
      3. 注意：{关键注意事项}

    output_path: ".workbuddy/context_pool/progress/T{XXX}-handoff.md"

  # Step 3: 更新 HEARTBEAT
  - step: "sync"
    action: |
      replace_in_file 更新任务 HEARTBEAT：
      - 状态改为 🔄 handoff
      - 记录交接原因和 HANDOFF.md 路径
      - 压缩"遇到的问题"区域

  # Step 4: 通知 orchestrator
  - step: "notify"
    action: |
      send_message(type="message", recipient="main",
        event_type="task_handoff",
        task_id: "T{XXX}",
        handoff_path: "T{XXX}-handoff.md",
        progress_pct: {当前进度},
        reason: {交接原因})
```

---

## 通信配置（增强）

```yaml
communication:
  # 新增交接事件
  notify_on:
    # ... 原有事件保持不变 ...

    - event: handoff
      message: |
        【task_handoff】T{XXX} | pm-researcher
        交接文档: {handoff_path}
        进度: {progress_pct}%
        原因: {handoff_reason}

    - event: source_quality_alert
      message: |
        【source_quality_alert】T{XXX} | pm-researcher
        发现: {过时信息来源列表}
        建议: {是否继续使用或寻找新来源}
```
