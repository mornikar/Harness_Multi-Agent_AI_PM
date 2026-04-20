# HEARTBEAT 模板规范

> 本文件定义了项目中 HEARTBEAT.md 的统一格式与使用规范。
> 所有子Agent（pm-coder、pm-researcher、pm-writer）均须遵守此规范。

---

## 1. HEARTBEAT 是什么

HEARTBEAT.md 是项目级别的**持久化记忆文件**，相当于整个多Agent协作团队的"共享大脑"。

### 核心理念：用结构化摘要替代无限增长的聊天历史

> **问题**：AI Agent 的上下文窗口有限。随着对话和任务执行越来越长，Chat History 会膨胀直到撑爆上下文，导致早期信息被截断遗忘。
>
> **解决方案**：不依赖 Chat History 做长期记忆。Agent 每次执行任务后，强制将"当前状态"和"核心结论"**压缩写入 HEARTBEAT.md**。
>
> **效果**：上下文永远不会无限增长。旧的对话细节被丢弃，只保留结构化的摘要。
>
> **类比**：就像项目经理不看开发者的每一行代码提交记录（Chat History），只看每周的周报（HEARTBEAT）。

### 上下文压缩机制

```
Chat History（临时性，会丢失）          HEARTBEAT.md（持久化，不会丢失）
┌──────────────────────────┐          ┌──────────────────────────┐
│ 对话轮次1: 用户说...     │          │                          │
│ Agent回复: 我来分析...   │   压缩   │  一、任务目标            │
│ 对话轮次2: 搜索了...     │ ──────→  │  二、执行进度（已完成✅） │
│ Agent回复: 发现了...     │   丢弃   │  三、产出物清单          │
│ 对话轮次3: 修改了...     │   细节   │  四、关键发现与决策      │
│ Agent回复: 调整了...     │  保留    │  五、遇到的问题          │
│ 对话轮次4: 测试了...     │   结论   │                          │
│ Agent回复: 通过了...     │          └──────────────────────────┘
│ ...                      │                    │
│ （越来越长，最终截断）    │                    │ 下次醒来时读取
└──────────────────────────┘                    │ 恢复上下文
                                               ▼
                                        ┌──────────────────────────┐
                                        │ Agent 新会话启动          │
                                        │ 1. 读取 HEARTBEAT.md     │
                                        │ 2. 一分钟恢复全部上下文    │
                                        │ 3. 继续执行未完成的任务    │
                                        └──────────────────────────┘
```

### 错误恢复机制

```
任务执行出错
    │
    ▼
1. 读取 HEARTBEAT.md → 了解：我做到哪了？产出了什么？哪里出错了？
    │
    ▼
2. 反思分析 → 对比 HEARTBEAT 中的目标与当前状态，定位偏差
    │
    ▼
3. 矫正行动 → 基于 HEARTBEAT 中的上下文重新规划，避免重复已完成的工作
    │
    ▼
4. 更新 HEARTBEAT → 记录错误原因和矫正措施
```

### 核心作用

| 作用 | 说明 |
|------|------|
| **上下文压缩** | 将冗长对话历史压缩为结构化摘要，防止上下文爆掉 |
| **状态追踪** | 实时记录所有子任务的状态、进度、阻塞项 |
| **决策记忆** | 记录所有关键技术决策及其理由，防止遗忘和矛盾 |
| **上下文同步** | 子Agent通过读取HEARTBEAT了解全局进展，避免重复工作 |
| **异常恢复** | 任务出错时通过HEARTBEAT快速定位偏差，矫正方向 |
| **跨会话恢复** | Agent被重建时，通过HEARTBEAT快速恢复全部上下文 |

### 与 Context Pool 的关系

```
HEARTBEAT.md          ← 全局状态快照（看板式），所有Agent读写
  │
  ├── 引用 → context_pool/product.md       （只读）
  ├── 引用 → context_pool/requirements.md  （只读）
  ├── 引用 → context_pool/tech_stack.md    （只读）
  ├── 引用 → context_pool/decisions.md     （追加）
  └── 引用 → context_pool/progress/*.md    （各Agent自行更新）
```

- **HEARTBEAT** = 精简的"仪表盘"，一页纸看懂项目全貌
- **Context Pool** = 详细的"资料库"，需要深入时才去读
- **HEARTBEAT** 替代 Chat History 做记忆，**Context Pool** 替代 Chat History 做资料

---

## 2. 文件位置与命名

```
{workspace}/.workbuddy/
├── HEARTBEAT.md                    ← 项目级HEARTBEAT（由orchestrator创建维护）
├── context_pool/
│   ├── progress/
│   │   ├── T001-heartbeat.md       ← 任务级HEARTBEAT（由各子Agent自行维护）
│   │   ├── T002-heartbeat.md
│   │   └── ...
│   └── ...
```

### 两级HEARTBEAT

| 级别 | 文件 | 维护者 | 读者 |
|------|------|--------|------|
| **项目级** | `.workbuddy/HEARTBEAT.md` | pm-orchestrator | 所有Agent |
| **任务级** | `.workbuddy/context_pool/progress/T{XXX}-heartbeat.md` | 对应子Agent | orchestrator + 同任务Agent |

---

## 3. 项目级 HEARTBEAT 模板

```markdown
# Project Heartbeat — {项目名称}

> **维护者**: pm-orchestrator
> **创建时间**: {YYYY-MM-DD HH:mm}
> **最后更新**: {YYYY-MM-DD HH:mm}
> **当前阶段**: Phase {N}

---

## 一、项目概览

| 维度 | 内容 |
|------|------|
| **项目名称** | {名称} |
| **项目类型** | Web应用 / 桌面应用 / 脚本工具 / 小程序 |
| **目标用户** | {目标用户} |
| **核心需求** | {一句话描述} |
| **技术栈** | {前端} + {后端} + {数据库} + {部署} |
| **当前状态** | 🟢正常 / 🟡有风险 / 🔴阻塞 |

---

## 二、任务状态看板

### 总体进度
- 总任务数: {N}
- 已完成: {N} | 进行中: {N} | 待执行: {N} | 已阻塞: {N}

### 任务明细

| 任务ID | 描述 | 类型 | 负责Agent | 状态 | 进度 | 阻塞项 | 最后更新 |
|--------|------|------|----------|------|------|--------|---------|
| T001 | {描述} | 调研/编码/文档 | pm-researcher | ✅完成/🔄进行中/⏳待执行/⚠️阻塞 | 100% | - | {HH:mm} |
| T002 | {描述} | 编码 | pm-coder | 🔄进行中 | 40% | 依赖T001 | - |

> 状态说明：✅ completed | 🔄 running | ⏳ pending | ⚠️ blocked | ❌ failed

---

## 三、关键决策记录

> 每次做出重要技术/架构决策时追加，格式：`[时间] 决策内容 — 理由 — 决策者`

| # | 时间 | 决策内容 | 理由 | 决策者 |
|---|------|---------|------|--------|
| D1 | {MM-DD HH:mm} | 选择Vue3作为前端框架 | TypeScript支持好，生态成熟 | orchestrator |
| D2 | {MM-DD HH:mm} | 使用SQLite作为存储 | 轻量级，无需额外部署 | pm-researcher建议 |

---

## 四、风险与问题

| # | 级别 | 描述 | 影响 | 应对措施 | 状态 |
|---|------|------|------|---------|------|
| R1 | 🔴HIGH | {描述} | {影响} | {措施} | 🔄处理中 |
| R2 | 🟡MEDIUM | {描述} | {影响} | {措施} | ⏳待处理 |

---

## 五、上下文池文件索引

> 列出所有Context Pool文件及其当前状态，方便子Agent快速定位

| 文件路径 | 用途 | 最后更新 | 更新者 |
|---------|------|---------|--------|
| context_pool/product.md | 产品定义 | {时间} | orchestrator |
| context_pool/requirements.md | 需求清单 | {时间} | orchestrator |
| context_pool/tech_stack.md | 技术栈 | {时间} | pm-researcher |
| context_pool/architecture.md | 架构设计 | {时间} | - |
| context_pool/decisions.md | 决策详情 | {时间} | orchestrator |
| context_pool/progress/T001-heartbeat.md | T001进度 | {时间} | pm-researcher |

---

## 六、下一步行动

> 由orchestrator维护，按优先级排列

- [ ] {行动项} — 负责Agent: {agent} — 优先级: {高/中/低}
- [ ] {行动项} — 需要用户确认

---

## 七、变更日志

> 每次HEARTBEAT更新时追加一行

| 时间 | 变更内容 | 变更者 |
|------|---------|--------|
| {HH:mm} | 创建HEARTBEAT，启动项目 | orchestrator |
| {HH:mm} | T001状态: pending → running | pm-researcher |
| {HH:mm} | T001完成，新增决策D1 | orchestrator |
```

---

## 4. 任务级 HEARTBEAT 模板

> 每个子Agent在执行任务时，**必须**维护自己的任务级HEARTBEAT。

```markdown
# Task Heartbeat — T{XXX}: {任务描述}

> **负责Agent**: {agent名称}
> **任务类型**: {调研/编码/文档}
> **创建时间**: {YYYY-MM-DD HH:mm}
> **最后更新**: {YYYY-MM-DD HH:mm}
> **状态**: 🔄 running | ✅ completed | ❌ failed | ⚠️ blocked

---

## 一、任务目标

> 从项目HEARTBEAT或任务派发指令中提取

- **目标**: {一句话描述要达成什么}
- **输入**: {需要读取的文件/数据}
- **输出**: {需要产出的文件/结果}
- **验收标准**: {什么算完成}

---

## 二、执行进度

### 已完成步骤
- [x] {步骤1描述} — {HH:mm}
- [x] {步骤2描述} — {HH:mm}

### 进行中
- [ ] {当前步骤描述} — 开始于 {HH:mm}

### 待执行
- [ ] {下一步骤}
- [ ] {下一步骤}

---

## 三、产出物清单

| # | 文件路径 | 类型 | 状态 | 说明 |
|---|---------|------|------|------|
| 1 | context_pool/progress/T001-report.md | 调研报告 | ✅已完成 | 技术选型对比 |
| 2 | context_pool/shared/api-schema.json | API规范 | 🔄编写中 | 接口定义 |

---

## 四、依赖与阻塞

### 上游依赖（我需要等别人）
| 依赖任务 | 需要什么 | 状态 |
|---------|---------|------|
| T001 | 调研结论 | ✅已提供 |

### 下游影响（别人在等我）
| 受影响任务 | 依赖我什么 | 状态 |
|-----------|-----------|------|
| T003 | API规范 | ⚠️我还没完成 |

### 当前阻塞
- ❌ {阻塞描述} — 需要 {谁} 提供 {什么} — 时间: {HH:mm}

---

## 五、关键发现与决策

> 执行过程中发现的重要信息或做出的局部决策

| # | 时间 | 发现/决策 | 影响 |
|---|------|----------|------|
| F1 | {HH:mm} | {发现内容} | {对后续任务的影响} |

---

## 六、遇到的问题

| # | 时间 | 问题描述 | 解决方式 | 状态 |
|---|------|---------|---------|------|
| P1 | {HH:mm} | {问题} | {自行解决/上报orchestrator/等待用户} | ✅已解决 |

---

## 七、资源消耗记录

| 资源 | 数量 | 说明 |
|------|------|------|
| 新增文件数 | {N} | |
| 修改文件数 | {N} | |
| 代码行数 | {N} | |
| 调用外部API次数 | {N} | |
```

---

## 5. HEARTBEAT 读写规则

### 5.1 各角色的读写权限

| 操作 | orchestrator | pm-coder | pm-researcher | pm-writer |
|------|:---:|:---:|:---:|:---:|
| 创建项目HEARTBEAT | ✅写 | ❌ | ❌ | ❌ |
| 更新任务状态看板 | ✅写 | 🟡建议 | 🟡建议 | 🟡建议 |
| 记录关键决策 | ✅写 | ❌ | 🟡建议 | ❌ |
| 记录风险与问题 | ✅写 | 🟡建议 | 🟡建议 | 🟡建议 |
| 读取全部内容 | ✅读 | ✅读 | ✅读 | ✅读 |
| 创建任务级HEARTBEAT | ✅写 | ✅写 | ✅写 | ✅写 |
| 更新自己的任务HEARTBEAT | ❌ | ✅写 | ✅写 | ✅写 |
| 更新别人的任务HEARTBEAT | ✅写 | ❌ | ❌ | ❌ |

> 🟡建议 = 通过 `send_message` 通知 orchestrator，由 orchestrator 代为更新

### 5.2 更新时机

| 事件 | 更新者 | 更新内容 | 工具 |
|------|--------|---------|------|
| 任务创建 | orchestrator | 看板新增行 | `replace_in_file` |
| 任务开始执行 | 子Agent | 自己的状态: pending → running | `replace_in_file` 或通知 orchestrator |
| 关键步骤完成 | 子Agent | 任务HEARTBEAT的执行进度 | `replace_in_file` |
| 产出物生成 | 子Agent | 任务HEARTBEAT的产出物清单 | `replace_in_file` |
| 遇到阻塞 | 子Agent | 任务HEARTBEAT的阻塞项 + 通知orchestrator | `replace_in_file` + `send_message` |
| 任务完成 | 子Agent | 状态: running → completed + 通知orchestrator | `replace_in_file` + `send_message` |
| orchestrator收到完成通知 | orchestrator | 项目HEARTBEAT看板更新 | `replace_in_file` |
| 技术决策产生 | orchestrator | 决策记录表 | `replace_in_file` |
| 风险发现 | 任何人 | 风险与问题表（通知orchestrator） | `send_message` → orchestrator更新 |

### 5.3 更新原则

1. **原子更新**：每次只更新自己负责的部分，不要整文件重写
2. **使用 replace_in_file**：定位到具体区域进行替换，避免覆盖他人内容
3. **更新后追加变更日志**：在"变更日志"区域追加一行
4. **阻塞必须上报**：遇到阻塞时，除了更新自己的任务HEARTBEAT，还必须 `send_message` 给 orchestrator
5. **不要频繁更新**：关键节点更新即可（状态变更、步骤完成、产出物生成），不要每个小操作都更新

### 5.4 上下文压缩规则（强制执行）

> ⚠️ 这是HEARTBEAT最核心的规则。**每个子Agent必须遵守。**

#### 压缩时机

| 时机 | 动作 | 说明 |
|------|------|------|
| **任务完成时** | 全量压缩 | 将整个任务的核心结论写入HEARTBEAT，Chat History可以丢弃 |
| **上下文快满时** | 增量压缩 | 感觉上下文快撑爆时，立即将当前进度和关键发现压缩写入 |
| **任务出错时** | 状态压缩 | 先将"做到哪了、产出了什么、哪里错了"写入HEARTBEAT，再分析原因 |
| **任务暂停/阻塞时** | 检查点压缩 | 暂停前确保HEARTBEAT是最新状态，下次恢复时可以无缝衔接 |

#### 压缩内容要求

写入HEARTBEAT的内容必须是**已经提炼过的结论**，不是原始对话的复制粘贴：

```
❌ 错误示范（复制对话细节）：
"用户说想要一个登录页面，我说用JWT还是Session，用户说看情况，
 然后我搜索了JWT的文档发现需要token刷新机制..."

✅ 正确示范（提炼结构化结论）：
"D1: 选择JWT作为认证方案 — 理由：无状态、适合前后端分离架构 — 决策者：orchestrator
  注意事项：需要实现token刷新机制（7200秒过期）"
```

#### 压缩质量检查

每次更新HEARTBEAT后，自检以下问题：

1. **如果我现在被销毁重建，只靠这个HEARTBEAT能恢复多少上下文？**
   - 目标：80%以上的关键信息应该能恢复
2. **下一个接手我工作的Agent，能看懂我做到哪了吗？**
   - 进度、产出物路径、未完成事项必须清晰
3. **决策理由写了吗？**
   - 不能只写"选了A"，必须写"选A因为...，淘汰B因为..."
4. **有没有冗余信息？**
   - HEARTBEAT是摘要不是日记，每个字都应该有信息量

---

## 6. HEARTBEAT 在各 Phase 的使用流程

```
Phase 4 (初始化)
  └→ orchestrator: write_to_file 创建项目HEARTBEAT.md

Phase 5 (调度)
  └→ orchestrator: 更新HEARTBEAT看板，添加任务行
  └→ 子Agent启动时: read_file 读取项目HEARTBEAT → 恢复全局上下文
  └→ 子Agent启动时: write_to_file 创建自己的任务HEARTBEAT

Phase 6 (执行中)
  └→ 子Agent: replace_in_file 更新自己任务HEARTBEAT的进度
  └→ 子Agent完成时: send_message 通知 orchestrator + 更新任务HEARTBEAT状态
  └→ orchestrator: replace_in_file 更新项目HEARTBEAT看板
  └→ orchestrator: replace_in_file 更新决策记录 / 风险记录

Phase 6.5 (上下文压缩 — 随时可能触发)
  └→ 检测到上下文快满 → 立即将当前状态压缩写入HEARTBEAT
  └→ 检测到任务出错 → 先写入HEARTBEAT当前进度 → 再分析原因 → 更新矫正措施

Phase 7 (整合)
  └→ orchestrator: 读取所有任务HEARTBEAT，收集产出物
  └→ orchestrator: 更新项目HEARTBEAT最终状态为 ✅completed
  └→ 全量压缩：确保项目HEARTBEAT包含完整的项目记忆，Chat History可以丢弃
```

---

## 7. 跨会话恢复流程

> 当Agent的会话结束（上下文满、超时、出错被重建），下次启动时的恢复流程：

```
Agent 新会话启动
    │
    ▼
Step 1: read_file 项目HEARTBEAT.md
    → 恢复信息：项目目标、技术栈、全局进度、已完成任务
    → 了解当前阶段：Phase几？下一步该做什么？
    │
    ▼
Step 2: read_file 自己的任务HEARTBEAT（如果存在）
    → 恢复信息：我做到哪了？产出了什么？遇到什么问题？
    → 检查：有没有未完成的步骤？有没有待解决的阻塞？
    │
    ▼
Step 3: read_file 上游任务的HEARTBEAT（如果存在依赖）
    → 恢复信息：上游Agent的结论、决策、产出物路径
    → 确认：我需要的输入是否已经准备好？
    │
    ▼
Step 4: 反思对比
    → 对比 HEARTBEAT 中的目标 vs 当前状态
    → 如果有偏差（上次出错/阻塞），分析原因
    → 制定矫正计划
    │
    ▼
Step 5: 继续执行
    → 从上次中断的地方继续
    → 不重复已完成的工作（HEARTBEAT已记录）
    → 如果需要调整方向，更新HEARTBEAT记录决策变更
```

### 恢复后必须做的事

- [ ] 确认上次的产出物是否完整（对照HEARTBEAT产出物清单逐个检查文件是否存在）
- [ ] 确认上次的未完成步骤（对照HEARTBEAT执行进度中的未勾选项）
- [ ] 确认是否有新阻塞（检查HEARTBEAT阻塞区域）
- [ ] 如果是错误恢复，分析错误原因并更新HEARTBEAT的问题记录
