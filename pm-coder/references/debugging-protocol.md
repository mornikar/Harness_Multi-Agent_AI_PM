# Debugging Protocol — 四阶段系统性调试 SOP

> **设计参考**：毒舌产品经理 4.0 的"系统性调试模式（Bug Fixer 设计模式）"。
> 核心理念：摒弃"看到报错就试着改"的盲目模式，采用"医生诊断式"流程。
> 强制每个调试任务都经过"证据→分析→假设→验证→修复"的完整路径。

---

## 一、核心原则

| 原则 | 说明 |
|------|------|
| **不猜不试** | 没有证据不下结论，没有假设不写修复代码 |
| **一次只改一处** | 每次修复只改一个逻辑点，便于精确定位 |
| **必须回归验证** | 修复后必须运行相关测试，防止"修A坏B" |
| **证据先行** | 先收集完整错误信息，再分析，再动手 |
| **止损机制** | 同一 bug 反复修不好，立即停止硬磕，重新审视根因 |

---

## 二、四阶段流程

### Phase 1：收集证据（Evidence Collection）

> **目标**：完整理解 bug 的表现、范围和环境。

```yaml
phase_1_evidence:
  steps:
    # Step 1: 完整读取错误信息
    - action: "读完整错误信息和 stack trace"
      rule: "不要只看错误摘要，必须读完整个 stack trace"
      tools: [read_file, search_content]
    
    # Step 2: 判断 bug 稳定性
    - action: "复现 bug — 判断是稳定复现还是偶发"
      rule: "稳定复现 > 容易定位；偶发 > 可能是竞态/时序/环境问题"
    
    # Step 3: 检查最近变更
    - action: "查看 git log 或 HEARTBEAT，确认最近改了什么"
      rule: "80% 的 bug 由最近的变更引入"
      tools: [search_content, read_file]
    
    # Step 4: 追踪数据流
    - action: "从错误点反向追踪数据流，定位可能的出错环节"
      rule: "画出数据流图：输入 → 处理步骤 → 输出，标出异常点"

  # 输出
  output: |
    写入 HEARTBEAT "遇到的问题"区：
    - Bug 描述：{一句话}
    - 错误信息：{完整 stack trace}
    - 复现条件：{稳定/偶发，触发步骤}
    - 最近变更：{相关文件和改动}
    - 数据流分析：{关键变量在哪个环节出错}
```

### Phase 2：分析模式（Pattern Analysis）

> **目标**：通过对比找到正常与异常的差异。

```yaml
phase_2_analysis:
  steps:
    # Step 1: 找相似的正常功能做对比
    - action: "在代码库中找到一个与本功能类似但正常工作的实现"
      rule: "对比两者的差异——差异就是线索"
      tools: [search_content, read_file]
    
    # Step 2: 识别差异模式
    - action: "列出所有差异点，按相关度排序"
      categories:
        - "数据差异：输入数据格式不同？范围不同？"
        - "逻辑差异：条件判断不同？执行路径不同？"
        - "环境差异：依赖版本不同？配置不同？"
        - "时序差异：异步/同步执行？竞态条件？"
    
    # Step 3: 排除法缩小范围
    - action: "逐一排除不太可能是根因的差异"
      rule: "保留最可能的 2-3 个差异点，进入假设阶段"

  # 输出
  output: |
    写入 HEARTBEAT：
    - 对比参照：{相似正常功能的文件路径}
    - 差异清单：
      | # | 差异点 | 可能性 | 说明 |
      |---|--------|--------|------|
```

### Phase 3：假设验证（Hypothesis Testing）

> **目标**：基于证据形成假设，用最小改动验证。

```yaml
phase_3_hypothesis:
  steps:
    # Step 1: 形成假设（最多3个，按可能性排序）
    - action: "基于 Phase 1-2 的证据，形成结构化假设"
      template: |
        假设 N: {最可能的根因}
        证据: {支持这个假设的证据}
        验证方法: {用什么最小改动来验证}
        预期结果: {如果假设正确，应该看到什么}
    
    # Step 2: 用最小改动验证最可能的假设
    - action: "添加一个临时的日志/断言/条件，验证假设"
      rule: "不直接修复，只添加诊断代码"
    
    # Step 3: 观察结果
    - action: "运行复现步骤，观察诊断输出"
      outcomes:
        - "假设被验证 → 进入 Phase 4 修复"
        - "假设被否定 → 记录原因 → 切换下一个假设"
        - "所有假设都被否定 → 返回 Phase 1 补充证据"

  # 假设验证记录
  hypothesis_log: |
    写入 HEARTBEAT：
    | # | 假设 | 验证方法 | 结果 | 备注 |
    |---|------|---------|------|------|
    | 1 | {根因描述} | {最小验证} | ✅确认 / ❌否定 | {原因} |
```

### Phase 4：实施修复（Fix Implementation）

> **目标**：基于已验证的假设，实施最小化、可回滚的修复。

```yaml
phase_4_fix:
  steps:
    # Step 1: 一次只改一个逻辑点
    - action: "修改最少的代码来修复根因"
      rule: "不要顺便重构、不要顺便优化、不要顺便改其他东西"
      anti_pattern: "切忌'顺手改了旁边那段看起来也不太对的代码'"
    
    # Step 2: 编译验证
    - action: "修改后立即运行编译检查"
      commands:
        - "tsc --noEmit"     # TypeScript
        - "python -m py_compile {file}" # Python
      on_failure: "立即回滚，检查修复是否引入了新的语法问题"
    
    # Step 3: 功能验证
    - action: "复现 bug 的触发步骤，确认 bug 已修复"
      on_failure: "回滚修复，返回 Phase 3 检查假设"
    
    # Step 4: 回归验证
    - action: "运行相关测试套件，确认没有引入新的 bug"
      rule: "至少运行与修复文件相关的所有测试"
      commands:
        - "npm test -- --related {files}"  # Node.js
        - "python -m pytest {related_tests}" # Python
      on_failure: "分析失败测试 → 如果是修复引入的 → 回滚并调整修复方案"
    
    # Step 5: 清理
    - action: "删除 Phase 3 添加的临时诊断代码"
      rule: "修复完成后，代码中不应残留任何调试代码"
```

---

## 三、止损机制（Stop-Loss）

### 3.1 触发条件

```yaml
stop_loss:
  triggers:
    - condition: "同一 bug 经过 2 轮完整四阶段流程仍未修复"
      action: "立即停止，send_message(task_blocked) 请求 orchestrator 介入"
    
    - condition: "Phase 3 所有假设都被否定（>3轮）"
      action: "返回 Phase 1 重新收集证据，可能需要 researcher 辅助调研"
    
    - condition: "修复引入了新的 HIGH 级别问题"
      action: "立即回滚所有修改，重新审视是否需要架构层面的调整"
    
    - condition: "怀疑是环境问题或依赖版本问题（非代码逻辑 bug）"
      action: "send_message(task_blocked) 附带环境诊断信息"
```

### 3.2 止损后的升级路径

```
止损触发
    │
    ├──→ send_message(task_blocked)
    │    附带：调试记录 + 已排除的假设 + 当前状态
    │
    ├──→ orchestrator 可能的处理：
    │    ├── 委托 researcher 调研相关技术问题
    │    ├── 调整任务范围或验收标准
    │    ├── 升级人工介入（ESCALATE）
    │    └── 决定是否回退到之前的检查点
```

---

## 四、调试任务模板

当 orchestrator 派发调试类任务时，Coder 的 plan.md 应包含以下结构：

```markdown
# 调试任务规划 T{XXX}

## Bug 描述
{用户或测试报告的 bug 描述}

## Phase 1: 收集证据
- [ ] 读取完整错误信息和 stack trace
- [ ] 判断 bug 稳定性（稳定/偶发）
- [ ] 检查最近变更记录
- [ ] 追踪数据流

## Phase 2: 分析模式
- [ ] 找到相似正常功能作为对比参照
- [ ] 列出差异清单
- [ ] 排除法缩小范围至 2-3 个候选

## Phase 3: 假设验证
- [ ] 形成最多 3 个假设
- [ ] 用最小改动验证假设 1
- [ ] 记录验证结果

## Phase 4: 实施修复
- [ ] 最小化修复（一次只改一处）
- [ ] 编译验证
- [ ] 功能验证（bug 已修复）
- [ ] 回归验证（无新 bug）
- [ ] 清理诊断代码

## 止损条件
- 最多 2 轮完整流程
- Phase 3 最多否定 3 个假设
```

---

## 五、与 Code Review 的协作

调试修复完成后，修复的代码仍需通过 Code Review Protocol 的审查：

```
调试完成 → 代码修复
    │
    ├──→ 运行 Stage 2 代码质量审查（测试 + Lint + 完整性）
    │    ├── 通过 → send_message(task_complete)
    │    └── 不通过 → 重新修复
    │
    └── 注意：如果是独立的 bug-fixing 任务，可以跳过 Stage 1（功能完整性）
         因为修复的目标是让代码恢复正常，不是实现新功能
```
