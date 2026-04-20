# Code Review Protocol — 两阶段自动闭环审查

> **设计参考**：毒舌产品经理 4.0 的"两阶段 Code Review 自动闭环"。
> 区别于传统的"一次性Review"，本协议要求：
> - Stage 1 通过后才进入 Stage 2
> - Stage 2 失败后自动进入 bug-fixer 循环
> - 两个 Stage 都通过后才能标记 task_complete

---

## 一、核心原则

### 1.1 审查优先级规则

```
设计图（如有） > 设计规范（Design Brief） > 需求文档（Spec） > 实现代码
```

当多个参考源对同一功能有不同描述时，以上面的优先级为准。

### 1.2 审查执行颗粒度

- **Task 级审查**：每完成一个 Task（plan step 的产出）跑一遍
- **Phase 级审查**：所有 Task 完成后，额外执行高层级集成检查
- 禁止"攒到 Phase 结束再审查"——问题越早发现，修复成本越低

---

## 二、两阶段审查流程

> **⚠️ 设计变更说明**：完整的语义级审查由 orchestrator 在验收时执行（三角验证第二层）。
> Coder 自检仅做轻量级关键词匹配，避免 LLM 无法自我审查逻辑错误的问题。

### Stage 1：功能完整性自检（Lightweight Self-Check）

> **目标**：通过关键词匹配进行轻量级检查，不依赖语义推理。
> 完整的功能完整性审查由 orchestrator 验收时执行。

#### 输入

| 来源 | 文件 | 说明 |
|------|------|------|
| 需求规格 | `context_pool/requirements.md` | 功能需求清单（提取关键词） |
| 任务规划 | `T{XXX}-plan.md` | 当前任务的执行计划 |
| 产出代码 | plan 中列出的所有文件 | 待审查对象 |

#### 审查步骤（轻量级关键词匹配）

```
Step 1: 提取关键词
  └─ 从 requirements.md 提取关键术语（如 API 端点名称、函数名、变量名）
  └─ 从 plan.md 提取每个 Step 定义的文件路径和关键产物

Step 2: 关键词匹配检查（不做语义理解）
  └─ 对每个关键词：
      ├── 代码中是否包含该关键词？→ 存在 / 不存在
      ├── plan 中列出的文件是否都已创建？→ 是 / 否

Step 3: 问题分类
  └─ BLOCKING：关键文件缺失 / 核心关键词全部不匹配
  └─ WARNING：部分关键词不匹配（可能是命名差异）
  └─ OK：所有关键词匹配

Step 4: 评审结论
  ├── BLOCKING 问题 → 修复 → 重新检查
  ├── WARNING 问题 → 记录，通知 orchestrator 关注
  └─ OK → ✅ 通过，进入 Stage 2

注意：此检查只做关键词匹配，不做语义理解。
      语义级 Spec 深度对照由 orchestrator 验收时执行。
```

#### Stage 1 不通过的处理

```
Stage 1 不通过（有 HIGH 问题）
    │
    ├──→ 生成 Stage 1 审查报告（列出所有问题）
    │    └─ 问题格式：{severity} | {功能点} | {预期} | {实际} | {修复建议}
    │
    ├──→ 修复循环（最多 2 轮）
    │    ├── 修复 HIGH 问题
    │    ├── 重新运行 Stage 1
    │    └── 仍不通过 → send_message(task_blocked) 通知 orchestrator
    │
    └──→ orchestrator 决策：是否降低验收标准 或 人工介入
```

---

### Stage 2：代码质量检查（Computational Checks）

> **前提**：Stage 1 通过（无 BLOCKING 问题）。
> **目标**：确保代码质量达到交付标准（计算型检查，不依赖语义推理）。
> **⚠️ 注意**：完整语义级质量审查由 orchestrator 验收时执行。

#### 审查维度

| 维度 | 检查项 | 工具 | 阻塞级别 |
|------|--------|------|---------|
| **编译/语法** | 无编译错误、无语法错误 | tsc / py_compile | ❌ 阻塞 |
| **测试通过率** | 单元测试通过率 ≥ 80% | npm test / pytest | ❌ 阻塞 |
| **代码风格** | 无 lint 错误（warning 可接受） | eslint / pylint | ⚠️ 非阻塞 |
| **命名规范** | 变量/函数/文件命名符合项目约定 | 推理型传感器 | ⚠️ 非阻塞 |
| **类型安全** | TypeScript 严格模式通过（如项目启用） | tsc --strict | ⚠️ 非阻塞 |
| **安全性** | 无硬编码密钥、无 SQL 注入风险 | 推理型传感器 | ❌ 阻塞 |
| **结构合理性** | 函数长度 < 50行、文件职责单一 | 推理型传感器 | ⚠️ 非阻塞 |

#### 审查步骤（计算型检查）

```
Step 1: 确定性检查（H7/H8/H9 Hooks，自动化执行）
  ├── H7 full_test_suite → 运行完整测试
  ├── H8 lint_check → 运行代码风格检查
  └── H9 deliverable_integrity → 产出物完整性检查

Step 2: 评审结论
  ├── H7/H8/H9 阻塞项 = 0 → ✅ 通过
  │    └── send_message(task_complete)
  │    └── 注意：完整语义级审查由 orchestrator 验收时执行
  │
  ├── H7/H8/H9 阻塞项 > 0 → ❌ 不通过
  │    └── 修复 → 重新进入审查循环
  │
  └── 非阻塞项（warning）> 0
       └── 记录到审查报告，不阻塞交付

注意：以下检查由 orchestrator 验收时执行（不在此处）：
  • 代码结构合理性（语义评估）
  • 编码规范符合度（语义评估）
  • 性能问题识别（语义评估）
  • 安全隐患评估（语义评估）
```

---

## 三、传感器分工说明

> **⚠️ 重要设计变更**：推理型传感器由 orchestrator 在验收时执行，不在 Coder 自检范围内。

### 3.1 Coder 自检 vs Orchestrator 验收

| 执行者 | 传感器类型 | 说明 |
|-------|-----------|------|
| **Coder（自检）** | 计算型传感器 | H1-H9 Hooks，确定性检查，零幻觉 |
| **Coder（自检）** | 轻量自检 | Stage 1 关键词匹配，极低开销 |
| **Orchestrator（验收）** | 推理型传感器 | 三角验证第二层，语义级评估 |

### 3.2 推理型传感器执行规范（Orchestrator 职责）

```yaml
reasoning_sensors:
  # 执行者：orchestrator（在验收时执行）
  executor: "orchestrator（三角验证模型）"

  # 触发时机
  trigger_points:
    - "收到 coder 的 task_complete 消息后"
    - "执行三角验证的第二层：语义评估"

  # 语义评估内容
  evaluation:
    - "对比 Goal 的 success_criteria 加权打分"
    - "Spec 深度对照：理解代码与需求的关系"
    - "代码质量语义审查：架构合理性、安全隐患"

  # 幻觉防护
  anti_hallucination:
    - "推理结论必须有代码证据支撑（引用具体行号或函数名）"
    - "推理结论必须有 Spec 或规范引用"

  # 不通过处理
  on_failure:
    - "置信度 < 80% → 发回 coder 修复"
    - "硬约束违规 → ESCALATE 人工介入"
```

### 3.3 计算型传感器清单（Coder 自执行）

详见 `hooks-specification.md`（H1-H9 Hooks）。

---

## 四、自动闭环流程

> **⚠️ 设计变更**：推理型审查由 orchestrator 在验收时执行，Coder 自检只做计算型检查。

```
编码完成
    │
    ▼
Stage 1: 功能完整性自检（轻量关键词匹配）
    │
    ├── ❌ BLOCKING 问题 → 修复（最多2轮）→ 重新 Stage 1
    │                     │
    │                     └── 仍不通过 → send_message(task_blocked)
    │
    ├── ⚠️ WARNING 问题 → 记录，通知 orchestrator 关注
    │
    └── ✅ 通过
         │
         ▼
Stage 2: 代码质量检查（计算型 H7/H8/H9）
    │
    ├── H7 full_test_suite
    │    ├── ❌ 阻塞 → 修复 → 重新 Stage 2
    │    └── ✅ 通过
    │
    ├── H8 lint_check
    │    └── ⚠️ warning → 记录，不阻塞
    │
    └── H9 deliverable_integrity
         ├── ❌ 阻塞 → 修复 → 重新 Stage 2
         └── ✅ 通过
              │
              ▼
send_message(task_complete)
              │
              ▼
    ┌─────────────────────────────────┐
    │ Orchestrator 验收（异步执行）       │
    │                                  │
    │ Stage 3: 语义评估（推理型传感器）   │
    │   ├── 对比 Goal success_criteria │
    │   ├── Spec 深度对照               │
    │   └── 代码质量语义审查             │
    │                                  │
    │ 置信度 ≥ 80% → COMPLETED         │
    │ 置信度 < 80% → 发回 coder 修复    │
    └─────────────────────────────────┘
```

---

## 五、审查报告模板

```markdown
# Code Review Report: T{XXX}

## 概要
- **审查时间**: {YYYY-MM-DD HH:mm}
- **审查阶段**: Stage 1 / Stage 2
- **审查结论**: ✅ 通过 / ❌ 不通过 / ⚠️ 条件通过
- **问题总数**: HIGH: {N} / MEDIUM: {N} / LOW: {N}

## Stage 1: 功能完整性

### 功能对照表
| # | 功能点 | 状态 | 预期 | 实际 | 问题级别 |
|---|--------|------|------|------|---------|
| 1 | {Spec 功能点} | ✅实现 / ❌缺失 / ⚠️偏差 | {Spec 描述} | {代码实际} | HIGH/MEDIUM/LOW |

### 额外实现（Spec 未要求）
| # | 实现内容 | 文件位置 | 评估 |
|---|---------|---------|------|
| 1 | {描述} | {文件:行号} | 合理/冗余 |

## Stage 2: 代码质量

### 计算型检查结果（H7/H8/H9）
| 检查项 | 工具 | 结果 | 详情 |
|--------|------|------|------|
| 测试 | npm test (H7) | ✅/❌ | {通过率} |
| Lint | eslint (H8) | ✅/⚠️ | {警告数} |
| 完整性 | 文件检查 (H9) | ✅/❌ | {缺失文件} |

> 注意：语义级检查（结构合理性、安全评估）由 orchestrator 验收时执行。

## 修复记录（如有）
| 轮次 | 修复内容 | 修复前审查结论 | 修复后审查结论 |
|------|---------|-------------|-------------|
| 1 | {修复了什么} | ❌ (HIGH x2) | ⚠️ (MEDIUM x1) |
```
