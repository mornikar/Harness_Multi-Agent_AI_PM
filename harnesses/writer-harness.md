# Writer Harness 定义

> pm-writer 子Agent 的执行载体定义。
> 设计参考：claw-code 的 Worker 生命周期 + 权限分层 + 工具最小化原则；
> Hive 的目标注入 + 三角验证 + 三层洋葱模型。

## 基本配置

```yaml
name: pm-writer
harness_type: subagent
description: |
  内容输出子Agent。负责PRD、技术文档、用户手册、CHANGELOG等文档撰写。
  通过 task 工具以 Team Mode spawn，加入项目团队协作。

spawn_config:
  subagent_name: "code-explorer"    # 复用 code-explorer（支持文件读写+搜索）
  mode: "acceptEdits"
  max_turns: 35                     # 文档撰写通常轮次较少
  # name: "writer-T{XXX}"
  # team_name: "{project-team}"

# 权限模式
permission_mode: "workspace-write"  # 可写工作空间文件

# 工具限制（最小权限原则）
allowed_tools:
  - read_file              # 读取文件（核心：读取上游产出物）
  - write_to_file          # 创建文档文件
  - replace_in_file        # 更新 HEARTBEAT
  - search_file            # 文件搜索
  - search_content         # 内容搜索
  - send_message           # 通信
  # 注意：不授予 web_search / execute_command（文档撰写不需要）
```

## Skill 加载策略（渐进式披露，参考 Hive）

| Skill | 路径 | 层级 | 加载时机 | 说明 |
|-------|------|------|---------|------|
| pm-writer | `pm-writer/SKILL.md` | Tier 1+2 | always | 核心行为规范 |
| pm-writer doc-templates | `pm-writer/references/doc-templates.md` | Tier 3 | on_demand | 文档模板参考 |
| Domain Skills | `~/.workbuddy/skills/{domain}/` | Tier 1+2 | 动态（Phase 3获取） | 如 docx, notion, pptx |
| recovery-recipes | `shared/references/recovery-recipes.md` | Tier 3 | on_failure | 恢复配方 |

## Skill 注入方式（三层 Prompt 洋葱，参考 Hive）

```markdown
# prompt 模板（orchestrator 按三层洋葱模型拼接后传给 task）

# ========== Layer 1: Identity ==========
你是 pm-writer，AI产品经理团队的内容输出专家。

## 成功标准（来自 Goal）
{从 context_pool/goal.md 提取与本任务相关的 success_criteria}
如：文档与代码一致、结构完整、技术细节准确

## 约束条件（来自 Goal）
{从 context_pool/goal.md 提取与本任务相关的 constraints}
如：文档格式规范、术语一致性

## 第一步：读取你的 Skill 规范
请执行：read_file("pm-writer/SKILL.md")
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

## 决策记录
{从 .workbuddy/context_pool/decisions.md 提取}

## 上游任务结论
{从上游 T{YYY}-heartbeat.md 提取核心结论}

# ========== Layer 3: Focus ==========
## 当前任务
任务ID: T{XXX}
类型: {文档类型}
描述: {文档目标}

## 输出要求
- 格式: {输出格式}
- 位置: {输出路径}
- 一致性约束: 文档内容必须与上游Agent产出物保持一致

## 记忆要求 ⭐
1. 启动时: read_file 读取项目HEARTBEAT.md
2. 启动时: read_file 读取上游任务 T{YYY}-heartbeat.md（获取素材路径）
3. 启动时: read_file 读取 product.md, requirements.md, decisions.md
4. 启动时: write_to_file 创建 T{XXX}-heartbeat.md（必须在120秒内完成）
5. 完成章节时: replace_in_file 更新任务HEARTBEAT进度
6. 完成时: replace_in_file 更新状态为completed
7. 完成时: send_message(type="message", recipient="main", ...) 通知 orchestrator
8. 阻塞时: send_message(type="message", recipient="main", ...) 通知 orchestrator
9. 失败时: 先按恢复配方恢复，再通知 orchestrator

## 三角验证 ⭐（新增，参考 Hive）

### 信号1：确定性规则（自验证）
1. 一致性检查：技术细节与上游Agent产出物一致
2. 完整性检查：模板要求的章节/表格/示例是否齐全
3. 准确性检查：引用的信息来源是否正确
4. 格式检查：Markdown语法正确、标题层级正确
→ 自验证通过后 send_message(task_complete)

### 信号2：语义评估
- orchestrator 对比 Goal 的 success_criteria 评估文档质量
- 特别关注：技术准确性、与上游产出物一致性

### 信号3：人工判断
- 以下情况需人工确认：
  - 文档涉及对外发布（用户手册、PRD）
  - 文档内容涉及安全/隐私相关描述

## 可加载的参考资料（Tier 3，按需加载）
- pm-writer/references/doc-templates.md（文档模板）
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
        【task_complete】T{XXX} | pm-writer | 100%
        产出物: {文档路径}
        字数: {字数统计}
        待补充: {需要后续补充的内容（如有）}
    - event: blocked
      message: |
        【task_blocked】T{XXX} | pm-writer
        原因: {上游技术方案未确定/缺少API规范}
        缺少素材: {缺少什么}
        建议: {哪个上游Agent应该补充}
    - event: partial_success
      message: |
        【task_partial_success】T{XXX} | pm-writer
        已完成: {已撰写完成的章节}
        待补充: {缺少素材无法完成的章节}
        建议: {是否接受部分交付}
  
  recipient: "main"
```

## 适用任务类型

| 任务类型 | 典型场景 | 额外Skills | 预估轮次 |
|---------|---------|-----------|---------|
| prd | 产品需求文档 | docx, notion | 35 |
| tech_doc | 技术设计文档 | markdown, mermaid | 35 |
| api_doc | API接口文档 | openapi, swagger | 30 |
| user_manual | 用户手册/使用说明 | docx, pdf | 30 |
| presentation | 汇报材料/PPT | pptx | 25 |
| changelog | CHANGELOG/发布说明 | markdown | 20 |

---

## 模块一：上下文工程（Context Engineering）

> **设计参考**：Claude Code 的分层上下文策略，适配文档撰写任务的轻量版。
> **核心理念**：Writer 需要大量读取上游产出物，上下文风险是"素材过多"。
> 必须像管理内存一样管理上下文，只读取与当前章节相关的内容。

### 上下文分层策略

```yaml
context_layers:
  # ═══ Layer 1: 常驻上下文（Hot Memory）═══
  # 每次 spawn 都注入，始终保持在场
  layer_1_hot:
    budget: "≤ 2000 tokens"
    contents:
      - "角色身份 + 核心职责（~200 tokens）"
      - "当前文档目标（~100 tokens）"
      - "一致性约束列表（~300 tokens）"
      - "文档模板要求（~200 tokens）"
      - "可用 Skills Catalog（~200 tokens）"
    rule: "精简到极致，只保留决策所需的最少信息"

  # ═══ Layer 2: 工作上下文（Working Memory）═══
  # 任务启动时一次性加载，执行期间可能被压缩
  layer_2_working:
    budget: "≤ 12000 tokens"
    contents:
      - "完整 SKILL.md（~1500 tokens）"
      - "项目 HEARTBEAT 状态摘要（~800 tokens）"
      - "product.md（产品定义，~500 tokens）"
      - "requirements.md（需求清单，~800 tokens）"
      - "decisions.md（决策记录，~500 tokens）"
      - "上游任务 HEARTBEAT 核心结论（~500 tokens/task）"
      - "Domain Skills（按需加载，每个 ~2000 tokens）"
    rule: "启动时批量加载，执行中如感觉冗余则压缩"

  # ═══ Layer 3: 冷引用（Cold Reference）═══
  # 不主动加载，需要时 read_file 读取后即弃
  layer_3_cold:
    contents:
      - "pm-writer/references/doc-templates.md"
      - "shared/references/recovery-recipes.md"
      - "上游完整产出物（按需读取特定章节）"
    rule: "只在 prompt 中给出路径提示，Agent 自行判断何时读取"
```

### 噪声过滤规范

```yaml
noise_filtering:
  # 上游文件选择性读取
  upstream_files:
    strategy: |
      1. 先读取上游 HEARTBEAT 获取素材路径
      2. 根据当前撰写章节，判断需要哪些素材
      3. 只读取与当前章节相关的部分
    chapter_mapping:
      "功能描述": ["product.md 功能列表", "requirements.md 功能需求"]
      "技术实现": ["tech_stack.md", "architecture.md"]
      "API接口": ["api-schema.json", "coder HEARTBEAT"]
      "测试策略": ["test-plan.md", "coder HEARTBEAT"]

  # 大文件阈值
  large_file_threshold: 300            # 超过 300 行的文件，只读相关部分
  strategy: "先 search_content 定位 → read_file(offset, limit)"

  # 重复内容过滤
  duplicate_filter:
    enabled: true
    rule: "同一内容不要在多个章节重复出现，使用交叉引用"
```

### 上下文预算控制

```yaml
context_budget:
  estimated_tokens_per_turn:
    read_file_small: 500               # < 100 行的文件
    read_file_large: 2000             # > 100 行的文件
    search_content: 800               # 搜索内容
    write_to_file: 1500              # 创建文件
    replace_in_file: 1000            # 编辑文件

  health_check:
    trigger: "每完成一个章节后"
    action: |
      1. 评估已用轮次 / max_turns
      2. 如使用率 > 60% → 压缩 Layer 2
      3. 如使用率 > 75% → 启动交接流程
    escalation: "使用率 > 90% → 立即交接，不再执行新操作"
```

---

## 模块二：一致性检查钩子（Consistency Check Hooks）

> **设计参考**：Coder Harness 的事件驱动钩子系统，适配文档撰写任务。
> **核心理念**：Writer 的核心风险是"文档与代码/上游产出物不一致"。
> 用确定性检查规则确保文档内容与上游保持一致。

### 钩子定义

```yaml
hooks:
  # ═══ 章节完成钩子（Post-Step Hooks）═══
  post_step:
    - name: "upstream_consistency_check"
      trigger: "每完成一个章节后"
      description: "章节内容与上游产出物一致性检查"
      check: |
        1. 引用的 API 端点是否与 api-schema.json 一致
        2. 引用的技术栈版本是否与 tech_stack.md 一致
        3. 引用的决策是否与 decisions.md 一致
        4. 引用的功能描述是否与 requirements.md 一致
        5. 引用的里程碑是否与 project HEARTBEAT 一致
      action: |
        如发现不一致 → 修正文档内容并记录修正项
      on_failure: |
        标注"⚠️ 待与上游确认"并通知 orchestrator

    - name: "cross_reference_check"
      trigger: "章节之间有交叉引用时"
      description: "交叉引用完整性检查"
      check: |
        1. 引用的章节标题是否存在
        2. 引用的图片/表格编号是否正确
        3. 引用的 URL 是否有效
      action: |
        如发现错误 → 修正引用或标注"引用待更新"

    - name: "terminology_consistency"
      trigger: "每完成一个章节后"
      description: "术语一致性检查"
      check: |
        1. 同一概念是否使用统一术语
        2. 如不能混用"用户"和"客户"、"前端"和"前台"
        3. 专有名词大小写是否统一
        4. 版本号格式是否统一
      action: |
        如发现不一致 → 统一为规范术语

  # ═══ 任务完成钩子（Completion Hooks）═══
  on_complete:
    - name: "template_completeness_gate"
      trigger: "文档完成后、发送 task_complete 前"
      description: "模板完整性门禁"
      check: |
        1. 模板要求的章节是否全部完成
        2. 模板要求的表格是否全部填写
        3. 模板要求的示例是否全部提供
        4. 格式规范是否符合模板要求
      action: |
        如有缺失 → 补充缺失项
      on_failure: |
        明确标注未完成的项 → send_message(task_partial_success)

    - name: "glossary_check"
      trigger: "文档完成后"
      description: "术语表检查"
      check: |
        1. 首次出现的专业术语是否提供解释
        2. 缩写词是否在首次出现时展开
        3. 是否有术语表/词汇表章节（如需）
      action: |
        如有缺失 → 补充术语说明

    - name: "link_integrity_check"
      trigger: "文档完成后"
      description: "链接完整性检查"
      check: |
        1. 内部链接（锚点）是否有效
        2. 外部链接 URL 格式是否正确
        3. 图片路径是否正确
      action: |
        如有错误 → 修正或标注"链接待验证"

    - name: "final_consistency_audit"
      trigger: "文档完成后"
      description: "最终一致性审计"
      check: |
        1. 文档标题与内容是否匹配
        2. 摘要与正文是否一致
        3. 结论与全文论述是否一致
        4. 文档版本与 HEARTBEAT 记录是否一致
      action: |
        如有矛盾 → 修正矛盾项
```

### 钩子执行顺序

```
章节撰写（write_to_file / replace_in_file）
    │
    ▼
每章节完成后
    ├──→ post_step: upstream_consistency_check（上游一致性）
    ├──→ post_step: cross_reference_check（交叉引用）
    └──→ post_step: terminology_consistency（术语一致性）

所有章节撰写完成
    │
    ▼
文档整合
    │
    ├──→ on_complete: template_completeness_gate（模板完整性）
    ├──→ on_complete: glossary_check（术语表）
    ├──→ on_complete: link_integrity_check（链接完整性）
    └──→ on_complete: final_consistency_audit（最终审计）
         │
         ▼
    全部通过 → send_message(task_complete)
    有失败 → 补充/修复 → 重新检查
```

---

## 模块三：交接棒机制（Baton-Style Handoff）

> **设计参考**：Coder Harness 的 HANDOFF 协议，适配文档撰写任务的轻量版。
> **核心理念**：长文档撰写中可能需要交接，确保新 Agent 能无缝接手。

### 触发条件

```yaml
handoff_triggers:
  automatic:
    - condition: "已用轮次 > max_turns × 75%"
      action: "启动交接流程"
    - condition: "已完成章节 < 50% 但上下文接近极限"
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
    action: "不再启动新的撰写操作，只完成当前章节"

  # Step 2: 压缩当前状态
  - step: "compress"
    action: "生成 HANDOFF.md"
    template: |
      # HANDOFF: T{XXX} 文档撰写任务

      ## 交接原因
      {auto: 上下文预算耗尽 | manual: orchestrator 请求}

      ## 当前进度
      ### 已完成章节
      - [x] {章节1}（产出：{文件路径}）
      - [x] {章节2}（产出：{文件路径}）
      ### 进行中
      - [ ] {章节3} — 进度 {N}%
      ### 未开始
      - [ ] {章节4}
      - [ ] {章节5}

      ## 系统状态
      - **文档草稿 路径**: {路径}
      - **HEARTBEAT 路径**: {路径}
      - **已用轮次**: {N}/{max_turns}

      ## 一致性已验证项
      | # | 验证项 | 状态 |
      |---|--------|------|
      | 1 | API端点一致性 | ✅ |
      | 2 | 技术栈版本 | ✅ |

      ## 遗留问题
      | # | 问题 | 状态 |
      |---|------|------|
      | 1 | {问题} | ⏳待解决 |

      ## 下一步建议
      1. {建议}
      2. {注意事项}

      ## 恢复指引
      1. read_file T{XXX}-heartbeat.md → 了解任务状态
      2. read_file {文档草稿路径} → 了解已完成内容
      3. 继续未完成的章节
      4. 注意：{关键注意事项}

    output_path: ".workbuddy/context_pool/progress/T{XXX}-handoff.md"

  # Step 3: 更新 HEARTBEAT
  - step: "sync"
    action: |
      replace_in_file 更新任务 HEARTBEAT：
      - 状态改为 🔄 handoff
      - 记录交接原因和 HANDOFF.md 路径
      - 列出已完成章节清单

  # Step 4: 通知 orchestrator
  - step: "notify"
    action: |
      send_message(type="message", recipient="main",
        event_type="task_handoff",
        task_id: "T{XXX}",
        handoff_path: "T{XXX}-handoff.md",
        progress_pct: {当前进度},
        completed_chapters: {已完成章节数},
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
        【task_handoff】T{XXX} | pm-writer
        交接文档: {handoff_path}
        进度: {progress_pct}%
        已完成章节: {N} 章
        原因: {handoff_reason}

    - event: consistency_alert
      message: |
        【consistency_alert】T{XXX} | pm-writer
        发现: {不一致项描述}
        建议: {修正方案或需要人工确认}
```
