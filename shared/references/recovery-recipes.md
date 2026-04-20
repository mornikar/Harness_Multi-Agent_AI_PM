# 恢复配方参考（所有 Agent 共享）

> 基于 claw-code 的 Recovery Recipes 模式设计。
> 当子 Agent 遇到已知失败模式时，按此 SOP 自动恢复，减少人工干预。
> 需要时通过 `read_file` 渐进加载。

---

## 1. 恢复总则

```
遇到失败时，按以下顺序处理：
1. 分类失败类型（参考下方分类表）
2. 查找对应的恢复配方
3. 执行恢复动作（最多重试 1 次）
4. 恢复失败 → send_message 通知 orchestrator 升级处理
5. 更新 HEARTBEAT 记录恢复过程
```

**核心原则**（来自 claw-code ROADMAP）：
- **恢复优先于升级** — 已知失败模式先自动恢复一次
- **部分成功是一等的** — 支持大部分完成但有瑕疵的中间态
- **证据驱动** — 每次恢复必须记录失败原因和恢复动作

---

## 2. 失败分类表

| 失败类型 | 分类码 | 严重度 | 是否可自动恢复 |
|---------|--------|--------|--------------|
| 任务上下文丢失 | `context_overflow` | HIGH | ✅ 通过 HEARTBEAT 恢复 |
| 上游依赖未满足 | `dependency_missing` | MEDIUM | ❌ 需通知 orchestrator |
| 文件冲突 | `file_conflict` | MEDIUM | ✅ 读取最新版本后重试 |
| 工具调用失败 | `tool_failure` | LOW | ✅ 重试 1 次 |
| API/网络超时 | `network_timeout` | LOW | ✅ 等待后重试 |
| Skill 未找到 | `skill_missing` | MEDIUM | ❌ 需通知 orchestrator |
| 输出格式不符 | `output_mismatch` | LOW | ✅ 自行修正后重试 |
| 编译/测试失败 | `build_failure` | HIGH | ✅ 分析错误后修复 |
| 权限不足 | `permission_denied` | HIGH | ❌ 需人工介入 |

---

## 3. 恢复配方详解

### R1: 上下文窗口溢出恢复

**触发条件**：感觉上下文快满、输出被截断、或收到上下文窗口错误。

**恢复步骤**：
```
1. 立即将当前状态 + 核心结论 压缩写入 HEARTBEAT
2. 总结已完成的工作和未完成的步骤
3. 通知 orchestrator（send_message）：需要重启会话
4. orchestrator 重新 spawn 时，子 Agent 通过 HEARTBEAT 恢复
```

**HEARTBEAT 压缩清单**：
- [ ] 目标和当前状态已写入
- [ ] 产出物路径已记录
- [ ] 未完成步骤已列出
- [ ] 关键决策已记录
- [ ] 阻塞项已标注

---

### R2: 上游依赖未满足

**触发条件**：需要读取的上游任务 HEARTBEAT/产出物不存在或不完整。

**恢复步骤**：
```
1. replace_in_file 更新自己 HEARTBEAT 状态为 ⚠️ blocked
2. send_message 通知 orchestrator：
   - 类型：dependency_missing
   - 缺少：{具体依赖任务和文件}
   - 建议：{哪个 Agent 应该先完成}
3. 等待 orchestrator 解除阻塞
```

---

### R3: 文件冲突恢复

**触发条件**：写入文件时发现已被其他 Agent 修改。

**恢复步骤**：
```
1. read_file 读取最新版本
2. 对比自己的修改与最新版本的差异
3. 智能合并（保留双方修改）
4. 如无法自动合并 → send_message 通知 orchestrator
```

---

### R4: 工具调用失败恢复

**触发条件**：execute_command、web_search 等工具返回错误。

**恢复步骤**：
```
1. 分析错误类型：
   - 临时性错误（网络/超时）→ 等待 5 秒后重试
   - 参数错误 → 修正参数后重试
   - 权限错误 → send_message 通知 orchestrator
2. 最多重试 1 次
3. 仍然失败 → send_message 通知 orchestrator
```

---

### R5: 编译/测试失败恢复

**触发条件**：代码编译失败或测试不通过（pm-coder 专用）。

**恢复步骤**：
```
1. 分析编译错误/测试失败原因
2. 分类：
   - 自身代码问题 → 修复代码后重新编译/测试
   - 依赖变化（上游 Agent 修改了接口）→ send_message 通知 orchestrator
3. 最多重试 2 次
4. 仍然失败 → 附带完整错误信息通知 orchestrator
```

---

### R6: 输出格式不符恢复

**触发条件**：orchestrator 验证发现输出不符合预期格式。

**恢复步骤**：
```
1. 读取 orchestrator 的反馈（通过 send_message）
2. 对照验收标准/模板检查
3. 修正输出格式
4. 重新通知 orchestrator（send_message）
```

---

## 4. 恢复台账格式

每次恢复尝试应在 HEARTBEAT 的"遇到的问题"区域记录：

```markdown
| # | 时间 | 问题描述 | 恢复配方 | 尝试次数 | 结果 | 状态 |
|---|------|---------|---------|---------|------|------|
| P1 | {HH:mm} | 上下文窗口溢出 | R1 | 1 | 压缩完成，通知orchestrator重启 | ✅已恢复 |
| P2 | {HH:mm} | 上游T001报告不存在 | R2 | - | 等待orchestrator处理 | ⏳阻塞中 |
```

---

## 5. 升级处理条件

以下情况**不应**自动恢复，必须立即通知 orchestrator：

1. **权限不足** — 无法写入目标路径，需要调整权限
2. **需求歧义** — 任务描述有矛盾或缺少关键信息
3. **上游 Agent 产出物质量不达标** — 需要上游 Agent 返工
4. **重试已耗尽** — 同一配方已尝试 2 次仍失败
5. **范围蔓延** — 任务执行过程中发现远超预期的工作量
