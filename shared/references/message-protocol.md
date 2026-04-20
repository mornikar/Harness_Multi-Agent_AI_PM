# Agent 间通信协议规范

> 统一定义 AI PM Skills 系统中所有 Agent 间的消息格式、事件类型和处理规则。
> 本文档整合了分散在各 Harness 中的通信定义，作为唯一的通信协议权威参考。

---

## 1. 消息信封标准格式

所有 Agent 间通信必须通过 `send_message` 工具，遵循以下信封格式：

```yaml
send_message(
  type: "message" | "broadcast" | "shutdown_request" | "shutdown_response" | "plan_approval_response"
  recipient: "main" | "{agent-role}-T{task_id}"   # "main" = orchestrator
  summary: "一句话摘要（必填，≤30字）"
  content: |
    【{event_type}】T{task_id} | {agent_role} | {status/progress}
    
    {结构化详情}
)
```

### 字段说明

| 字段 | 必填 | 约束 | 说明 |
|------|:----:|------|------|
| `type` | ✅ | 枚举值 | 消息传输类型（见下表） |
| `recipient` | ✅ | `"main"` 或 `"{role}-T{id}"` | 接收者标识。`"main"` 为 orchestrator 的固定别名 |
| `summary` | ✅ | ≤30字 | 一句话摘要，用于消息列表快速浏览 |
| `content` | ✅ | - | 消息体，首行必须为事件类型声明 |

### type 枚举说明

| type | 用途 | 接收者 |
|------|------|--------|
| `message` | 点对点消息 | 指定 recipient |
| `broadcast` | 广播消息 | 全体成员 |
| `shutdown_request` | 请求子Agent关闭 | 指定 recipient |
| `shutdown_response` | 子Agent确认关闭 | 发给请求方 |
| `plan_approval_response` | 审批规划文档的回复 | 指定 recipient |

### content 首行格式

```
【{event_type}】T{task_id} | {agent_role} | {status_or_progress}
```

- `event_type`：事件类型标识（见第2节注册表）
- `task_id`：任务ID（如 T001）
- `agent_role`：发送者角色标识（如 pm-coder, pm-researcher, pm-orchestrator）
- `status_or_progress`：状态描述或进度百分比

---

## 2. 事件类型注册表

### 2.1 子Agent → orchestrator

#### task_complete — 任务完成

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| status | ✅ | 固定为 "completed" |
| deliverables | ✅ | 产出物路径列表 |
| suggestions | ❌ | 对下游任务的建议 |
| duration | ❌ | 实际耗时（轮次数） |

#### task_progress — 进度更新

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| progress_pct | ✅ | 进度百分比（0-100） |
| current_step | ✅ | 当前完成步骤描述 |
| next_step | ✅ | 下一步计划 |
| health_score | ❌ | 自评健康度（0-100） |

#### task_blocked — 任务阻塞

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| block_reason | ✅ | 阻塞原因描述 |
| needed_from | ✅ | 需要谁解决（orchestrator/特定Agent/用户） |
| severity | ❌ | 严重度：high/medium/low，默认 medium |
| suggested_action | ❌ | 建议的解除方案 |

#### task_failed — 任务失败

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| error_kind | ✅ | 错误分类码（见 recovery-recipes.md） |
| error_detail | ✅ | 错误详细描述 |
| recoverable | ✅ | 是否可自动恢复（true/false） |
| recovery_attempted | ❌ | 是否已尝试恢复 |
| partial_deliverables | ❌ | 失败前已产出的文件 |

#### task_partial_success — 部分成功

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| completed_items | ✅ | 已完成项列表 |
| incomplete_items | ✅ | 未完成项列表 |
| degradation_report | ✅ | 降级说明（核心功能是否完整） |
| suggestion | ❌ | 建议处理方式 |

#### recovery_attempt — 恢复尝试

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| recipe_id | ✅ | 恢复配方ID（如 R1, R2...） |
| attempt_count | ✅ | 第几次尝试 |
| result | ✅ | 结果：success/failure |
| detail | ❌ | 恢复详情 |

#### decision_request — 请求决策

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| decision_description | ✅ | 需要决策的问题描述 |
| options | ✅ | 候选选项列表（至少2个） |
| recommendation | ❌ | 子Agent的推荐及理由 |
| urgency | ❌ | 紧急度：high/medium/low |

#### plan_ready — 规划文档就绪

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| plan_path | ✅ | plan.md 文件路径 |
| estimated_turns | ❌ | 预估执行轮次 |
| affected_files | ❌ | 影响文件列表 |
| risk_assessment | ❌ | 风险评估摘要 |

#### task_handoff — 任务交接

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| handoff_path | ✅ | HANDOFF.md 文件路径 |
| progress_pct | ✅ | 当前进度百分比 |
| reason | ✅ | 交接原因 |
| remaining_steps | ❌ | 剩余步骤摘要 |

#### risk_notification — 风险通知（黄灯）

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| level | ✅ | 固定为 "yellow" |
| operation | ✅ | 执行的操作描述 |
| reason | ✅ | 为什么需要此操作 |

#### risk_approval_request — 风险审批请求（红灯）

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| level | ✅ | 固定为 "red" |
| operation | ✅ | 计划执行的操作 |
| impact | ✅ | 影响分析 |
| rollback | ✅ | 回滚方案 |

#### permission_violation — 权限违规（禁区）

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| operation | ✅ | 尝试执行的操作 |
| reason | ❌ | 为什么需要此操作 |

#### health_report — 健康自检报告

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| health_score | ✅ | 自评分数（0-100） |
| concerns | ✅ | 当前担忧列表（可为空） |
| next_checkpoint | ✅ | 下一个预期检查点描述 |

### 2.2 orchestrator → 子Agent

#### plan_approved — 规划审批通过

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| feedback | ❌ | 附加反馈/修改建议 |
| approved_plan_path | ❌ | 如有修改，新 plan.md 路径 |

#### plan_rejected — 规划审批驳回

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| reason | ✅ | 驳回原因 |
| suggestions | ✅ | 修改建议 |
| needs_research | ❌ | 是否需要补充调研 |

#### task_update — 任务状态更新

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| update_type | ✅ | 更新类型：scope_change/priority_change/dependency_resolved |
| detail | ✅ | 更新详情 |
| action_required | ❌ | 需要子Agent采取的行动 |

#### decision — 决策下达

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| decision | ✅ | 决策内容 |
| reason | ✅ | 决策理由 |
| action_required | ❌ | 需要子Agent执行的操作 |

#### cancel — 任务取消

| 字段 | 必填 | 说明 |
|------|:----:|------|
| task_id | ✅ | 任务ID |
| reason | ✅ | 取消原因 |
| save_progress | ✅ | 是否保存当前进度（true/false） |

### 2.3 orchestrator → 全体（broadcast）

#### project_pause — 项目暂停

| 字段 | 必填 | 说明 |
|------|:----:|------|
| reason | ✅ | 暂停原因 |
| estimated_resume | ❌ | 预计恢复时间 |
| action_required | ✅ | 子Agent应采取的行动（如：保存进度并等待） |

#### project_cancel — 项目取消

| 字段 | 必填 | 说明 |
|------|:----:|------|
| reason | ✅ | 取消原因 |
| action_required | ✅ | 子Agent应采取的行动（如：保存进度并关闭） |

---

## 3. 消息示例

### 3.1 子Agent → orchestrator

#### task_complete 示例

```
send_message(
  type="message",
  recipient="main",
  summary="T001 技术调研完成",
  content="""
    【task_complete】T001 | pm-researcher | 100%
    
    产出物:
      - context_pool/progress/T001-report.md
      - context_pool/shared/api-schema.json
    
    建议:
      - T002 架构设计可直接基于推荐方案（Vue3 + Pinia + Vite）
      - 建议后端使用 Node.js + Express，与前端技术栈统一
    
    耗时: 28轮
  """
)
```

#### task_progress 示例

```
send_message(
  type="message",
  recipient="main",
  summary="T003 前端开发进度60%",
  content="""
    【task_progress】T003 | pm-coder | 60%
    
    已完成: 基础框架搭建 + TodoList组件 + AddTodo组件
    下一步: EditTodo组件 + 删除功能
    健康度: 85
  """
)
```

#### task_blocked 示例

```
send_message(
  type="message",
  recipient="main",
  summary="T004 后端开发阻塞",
  content="""
    【task_blocked】T004 | pm-coder
    
    原因: 数据库设计文档尚未产出（依赖T002的架构设计中DB Schema部分）
    级别: high
    需要: orchestrator确认T002架构设计中DB Schema的产出时间
    建议: 可先使用 mock 数据开发，待DB Schema就绪后替换
  """
)
```

#### task_failed 示例

```
send_message(
  type="message",
  recipient="main",
  summary="T003 前端开发失败",
  content="""
    【task_failed】T003 | pm-coder
    
    错误类型: build_failure
    错误详情: TypeScript strict模式编译失败，12个类型错误
    可恢复: true
    已尝试恢复: true（修复了8个，剩余4个需要重构接口定义）
    部分产出: src/components/TodoList.vue, src/components/AddTodo.vue
  """
)
```

#### task_partial_success 示例

```
send_message(
  type="message",
  recipient="main",
  summary="T003 部分完成（核心功能OK）",
  content="""
    【task_partial_success】T003 | pm-coder
    
    已完成: [TodoList组件, AddTodo组件, 删除功能, 编辑功能]
    未完成: [拖拽排序功能（需要第三方库支持）]
    降级说明: 核心CRUD功能已完整，拖拽排序为增强功能
    建议: 接受当前交付，拖拽排序作为后续迭代
  """
)
```

#### recovery_attempt 示例

```
send_message(
  type="message",
  recipient="main",
  summary="T003 恢复尝试R5",
  content="""
    【recovery_attempt】T003 | pm-coder
    
    配方ID: R5（编译/测试失败恢复）
    尝试次数: 1
    结果: success
    详情: 修复了TypeScript类型错误，编译通过
  """
)
```

#### decision_request 示例

```
send_message(
  type="message",
  recipient="main",
  summary="T003 需要架构决策",
  content="""
    【decision_request】T003 | pm-coder
    
    决策描述: 状态管理方案选择
    候选选项:
      - A: Pinia（Vue3官方推荐，TypeScript友好）
      - B: Vuex4（Vue2兼容，团队更熟悉）
    推荐: 方案A（Pinia），理由：项目使用Vue3+TS，Pinia类型推断更好
    紧急度: medium
  """
)
```

#### plan_ready 示例

```
send_message(
  type="message",
  recipient="main",
  summary="T003 规划文档就绪",
  content="""
    【plan_ready】T003 | pm-coder | Phase A
    
    规划文档: context_pool/progress/T003-plan.md
    预估轮次: 35轮
    影响文件:
      - 新建: src/components/TodoList.vue
      - 新建: src/stores/todo.ts
      - 修改: src/router/index.ts
    风险: TypeScript strict模式可能需要额外类型定义
    
    请求审批
  """
)
```

#### task_handoff 示例

```
send_message(
  type="message",
  recipient="main",
  summary="T003 交接（上下文耗尽）",
  content="""
    【task_handoff】T003 | pm-coder
    
    交接文档: context_pool/progress/T003-handoff.md
    进度: 65%
    原因: 上下文预算使用超过70%，主动交接
    剩余步骤:
      - EditTodo组件完善（进行中，40%）
      - 拖拽排序功能（未开始）
      - 单元测试编写（未开始）
  """
)
```

#### risk_notification 示例（黄灯）

```
send_message(
  type="message",
  recipient="main",
  summary="T003 黄灯通知：修改路由配置",
  content="""
    【risk_notification】T003 | pm-coder | 🟡
    
    操作: replace_in_file src/router/index.ts — 添加todo路由
    原因: 需要在现有路由配置中新增/todo路径
  """
)
```

#### risk_approval_request 示例（红灯）

```
send_message(
  type="message",
  recipient="main",
  summary="T003 红灯审批：修改tsconfig",
  content="""
    【risk_approval_request】T003 | pm-coder | 🔴
    
    操作: replace_in_file tsconfig.json — 关闭strict模式
    影响: 全局TypeScript检查放宽，可能引入类型安全隐患
    回滚: 恢复strict: true，然后修复所有类型错误（预计额外15轮）
  """
)
```

#### permission_violation 示例（禁区）

```
send_message(
  type="message",
  recipient="main",
  summary="T003 权限违规：尝试全局安装",
  content="""
    【permission_violation】T003 | pm-coder | 🚫
    
    尝试: npm install -g typescript（全局安装，属于禁区操作）
    已跳过该操作，继续执行plan中的下一步
  """
)
```

#### health_report 示例

```
send_message(
  type="message",
  recipient="main",
  summary="T003 健康自检（82分）",
  content="""
    【health_report】T003 | pm-coder
    
    健康度: 82
    担忧: []
    下一个检查点: 核心功能实现完成（预计3轮后）
  """
)
```

### 3.2 orchestrator → 子Agent

#### plan_approved 示例

```
send_message(
  type="message",
  recipient="coder-T003",
  summary="T003 规划审批通过",
  content="""
    【plan_approved】T003 | pm-orchestrator
    
    规划已审阅通过，进入Phase C编码阶段。
    反馈: 建议将TodoList组件拆分为Presentational和Container两层。
  """
)
```

#### plan_rejected 示例

```
send_message(
  type="message",
  recipient="coder-T003",
  summary="T003 规划驳回",
  content="""
    【plan_rejected】T003 | pm-orchestrator
    
    原因: plan中修改了package.json的dependencies但未在风险评估中说明
    修改建议:
      1. 在风险评估中补充新增依赖的说明
      2. 确认新增依赖与现有依赖无版本冲突
    请修改后重新提交plan。
  """
)
```

#### task_update 示例

```
send_message(
  type="message",
  recipient="coder-T004",
  summary="T004 依赖已解除",
  content="""
    【task_update】T004 | pm-orchestrator
    
    更新类型: dependency_resolved
    详情: T002架构设计已完成，DB Schema已产出至 context_pool/shared/db-schema.sql
    行动: 请读取DB Schema后继续后端开发
  """
)
```

#### decision 示例

```
send_message(
  type="message",
  recipient="coder-T003",
  summary="T003 决策：使用Pinia",
  content="""
    【decision】T003 | pm-orchestrator
    
    决策: 状态管理使用Pinia
    理由: 项目技术栈为Vue3+TypeScript，Pinia类型推断优势明显
    行动: 请按Pinia方案调整plan.md并继续执行
  """
)
```

#### cancel 示例

```
send_message(
  type="message",
  recipient="coder-T003",
  summary="T003 任务取消",
  content="""
    【cancel】T003 | pm-orchestrator
    
    原因: 用户要求调整需求方向，当前前端方案需要重做
    保存进度: true
    请保存当前已完成的工作到HEARTBEAT，然后关闭。
  """
)
```

### 3.3 orchestrator → 全体

#### project_pause 示例

```
send_message(
  type="broadcast",
  summary="项目暂停通知",
  content="""
    【project_pause】| pm-orchestrator
    
    原因: 用户要求暂停，等待确认后续方向
    预计恢复: 待用户确认后通知
    行动: 所有Agent请保存当前进度到HEARTBEAT，停止新操作，等待恢复通知
  """
)
```

#### project_cancel 示例

```
send_message(
  type="broadcast",
  summary="项目取消通知",
  content="""
    【project_cancel】| pm-orchestrator
    
    原因: 用户决定终止项目
    行动: 所有Agent请立即保存进度到HEARTBEAT，准备接收shutdown_request
  """
)
```

---

## 4. 消息处理规则

### 4.1 orchestrator 收到各事件后的标准处理流程

#### 收到 task_complete

```
1. read_file 子Agent任务HEARTBEAT → 获取产出物详情
2. 执行三角验证：
   a. 确定性规则验证（子Agent已自验证，检查验证结果）
   b. 语义评估（对比Goal的success_criteria加权打分）
      - 置信度 ≥ 80% → 标记COMPLETED
      - 置信度 < 80% → 回退子Agent重做（附反馈）
      - 硬约束违规 → 立即ESCALATE
3. replace_in_file 更新项目HEARTBEAT看板
4. 追加决策记录（如有）
5. 更新文件索引
6. 检查下游依赖 → 自动解除阻塞（策略引擎 auto_unblock）
7. 追加变更日志
```

#### 收到 task_progress

```
1. 更新项目HEARTBEAT看板进度
2. 校验进度速度（vs预期）
3. 如进度停滞 → 标记为"关注"
4. 如有 health_score → 更新健康度追踪
5. 触发策略引擎检查：
   - budget_warning（总轮次>80%？）
   - L3产出质量检查（进度≥50%时抽样）
```

#### 收到 task_blocked

```
1. 读取子Agent HEARTBEAT → 了解阻塞详情
2. 判断阻塞类型：
   - 依赖缺失 → 检查上游任务状态，加速上游或提供替代
   - 需要决策 → 向用户转达或自主决策
   - 资源不足 → 调整任务优先级或降级
3. 更新项目HEARTBEAT风险与问题区
4. 追加变更日志
5. 尝试解除阻塞后 → send_message(task_update) 通知子Agent
```

#### 收到 task_failed

```
1. 读取错误详情
2. 判断是否可自动恢复：
   - 可恢复 + 尝试次数 < 2 → 策略引擎 auto_recover
   - 不可恢复 → ESCALATE
3. 更新项目HEARTBEAT：
   - 任务看板状态 → FAILED
   - 风险与问题区 → 新增风险项
4. 评估对下游任务的影响 → 通知下游Agent
5. 追加变更日志
```

#### 收到 task_partial_success

```
1. 读取降级报告
2. 评估核心功能是否完整：
   - 核心完整 → 标记COMPLETED，未完成项创建新任务
   - 核心不完整 → 回退子Agent继续完成核心部分
3. 更新项目HEARTBEAT
4. 通知用户降级情况
5. 追加变更日志
```

#### 收到 recovery_attempt

```
1. 记录恢复尝试到HEARTBEAT恢复台账
2. 如结果为 success → 恢复任务状态为 RUNNING
3. 如结果为 failure：
   - 尝试次数 < 2 → 允许再试一次
   - 尝试次数 ≥ 2 → 标记FAILED，升级处理
4. 追加变更日志
```

#### 收到 decision_request

```
1. 评估决策的紧急度和影响范围
2. 判断是否能自主决策：
   - 能 → send_message(decision) 通知子Agent
   - 不能 → 向用户转达，等待用户决策
3. 无论谁做决策 → 追加到 decisions.md
4. 追加变更日志
```

#### 收到 plan_ready

```
1. read_file plan.md
2. 审阅内容：
   - 文件修改范围是否合理？
   - 是否与Goal约束冲突？
   - 是否影响其他正在运行的任务？
   - 预估轮次是否在budget内？
3. 决策：
   - 通过 → send_message(plan_approved)
   - 驳回 → send_message(plan_rejected) + 修改建议
   - 需要调研 → 委托researcher补充 → 重新规划
```

#### 收到 task_handoff

```
1. read_file HANDOFF.md
2. 记录交接信息到HEARTBEAT
3. 重新spawn新的子Agent（从断点恢复）
4. 新Agent prompt中注入HANDOFF.md路径
5. 追加变更日志
```

#### 收到 risk_notification（黄灯）

```
1. 记录通知内容
2. 不阻塞子Agent操作
3. 如发现风险不可接受 → 在下一轮询介入拦截
4. 无问题 → 无需回复
```

#### 收到 risk_approval_request（红灯）

```
1. 评估操作影响：
   - 可接受 → send_message(decision, action="approved")
   - 不可接受 → send_message(decision, action="rejected") + 替代方案
   - 需要用户确认 → 向用户转达
2. 60秒内未回复 → 子Agent自动放弃该操作
```

#### 收到 permission_violation（禁区）

```
1. 记录违规事件
2. 检查子Agent行为是否偏离（频繁违规 → 可能方向错误）
3. 如频繁违规 → 考虑中断并调整任务描述
4. 追加变更日志
```

#### 收到 health_report

```
1. 更新健康度追踪
2. 按健康度等级采取行动：
   - ≥75（健康）→ 无需操作
   - 50-74（关注）→ 记录风险
   - 30-49（预警）→ 主动询问子Agent，考虑干预
   - <30（严重）→ 立即介入或重新派发
```

### 4.2 超时未回复的处理

| 场景 | 超时时间 | 处理方式 |
|------|---------|---------|
| orchestrator 未回复 risk_approval_request | 60秒 | 子Agent自动放弃该操作，继续plan下一步 |
| orchestrator 未回复 plan_ready | 5分钟 | 子Agent保持等待（规划审批不可跳过） |
| 子Agent 未回复 shutdown_request | 3分钟 | orchestrator 强制清理（team_delete时自动处理） |
| 子Agent HEARTBEAT 停止更新 | 15分钟 | 策略引擎 timeout_escalate → 检查后决定恢复或升级 |

### 4.3 消息丢失的处理

| 场景 | 检测方式 | 处理方式 |
|------|---------|---------|
| 子Agent发送的消息未被处理 | orchestrator 下次轮询时发现 HEARTBEAT 状态与预期不符 | 读取子Agent HEARTBEAT 同步状态 |
| orchestrator 的指令未被接收 | 子Agent长时间无响应 | 重新 send_message 发送指令 |
| broadcast 消息丢失 | 个别子Agent行为与其他不一致 | 定向 send_message 补发 |
| 通信通道整体故障 | send_message 持续返回错误 | 重新 team_create → 从检查点恢复 |

### 4.4 消息优先级

当 orchestrator 需要同时处理多条消息时，按以下优先级排序：

| 优先级 | 事件类型 | 理由 |
|--------|---------|------|
| P0（立即处理） | permission_violation | 禁区操作意味着安全风险 |
| P0（立即处理） | task_failed（不可恢复） | 需要立即评估影响 |
| P1（优先处理） | risk_approval_request | 红灯审批，子Agent在等待 |
| P1（优先处理） | task_blocked | 下游任务可能被级联阻塞 |
| P1（优先处理） | task_handoff | 需要尽快spawn新Agent接手 |
| P2（正常处理） | task_complete | 需要三角验证但不紧急 |
| P2（正常处理） | plan_ready | 审批后子Agent才能继续 |
| P2（正常处理） | decision_request | 不影响当前执行 |
| P3（可延迟） | task_progress | 仅更新状态 |
| P3（可延迟） | health_report | 仅更新追踪 |
| P3（可延迟） | risk_notification | 黄灯不阻塞 |

---

## 5. 附录：与各 Harness 的关系

本协议整合了以下 Harness 中的通信定义：

| 原始定义位置 | 整合内容 |
|------------|---------|
| `harnesses/orchestrator-harness.md` | 通信配置区、子Agent生命周期状态机、策略引擎 |
| `harnesses/coder-harness.md` | 通信配置区（plan_ready, risk_notification等事件） |
| `harnesses/researcher-harness.md` | 通信配置区（基础事件） |
| `harnesses/writer-harness.md` | 通信配置区（基础事件） |
| `pm-orchestrator/SKILL.md` | Phase 6 子Agent通知消息格式 |

> **规则**：本文件是通信协议的**唯一权威参考**。各 Harness 中的通信定义如与本文件冲突，以本文件为准。
