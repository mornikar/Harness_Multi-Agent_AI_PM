# 健康检查协议（Health Check Protocols）

> 供 orchestrator 在执行健康检查时参考的详细协议。
> 子 Agent 在发送 health_report 时也应遵循此规范。
> 需要时通过 `read_file` 渐进加载。

---

## 1. 存活检查协议（L1）

### 检查流程

```yaml
protocol: l1_aliveness_check
trigger: 子Agent状态为 RUNNING
interval: 每次orchestrator轮询周期

steps:
  1. read_file 任务 HEARTBEAT
     └─ 检查"最后更新"时间戳
     
  2. 计算时间差
     └─ now - last_update = elapsed_minutes
     
  3. 判定结果
     ├─ elapsed < 5min  → 🟢 正常（无需动作）
     ├─ elapsed 5-15min → 🟡 关注（记录到风险追踪）
     ├─ elapsed 15-30min → 🟠 预警（send_message 询问状态）
     └─ elapsed > 30min  → 🔴 异常（视为失联，触发崩溃恢复）
```

### 失联处理

```yaml
agent_unresponsive:
  step_1: send_message(type="message", recipient="{agent}", content="健康检查：请报告当前状态")
  step_2: 等待响应（最多 2 分钟）
  step_3:
    收到响应:
      - 更新 HEARTBEAT 时间戳
      - 记录"假失联"事件
      - 正常继续
    未收到响应:
      - 标记任务状态为 INTERRUPTED
      - 从最近检查点恢复
      - 重新 spawn 子Agent
```

---

## 2. 进度检查协议（L2）

### 进度偏差检测

```yaml
protocol: l2_progress_check
trigger: 收到 task_progress 或存活检查发现心跳停滞

steps:
  1. 获取预期进度
     └─ expected_pct = (elapsed_time / estimated_duration) * 100
     
  2. 获取实际进度
     └─ actual_pct = 从 HEARTBEAT 的进度区域提取
     
  3. 计算偏差
     └─ deviation = actual_pct - expected_pct
     
  4. 判定结果
     ├─ deviation > -10%  → 🟢 正常（轻微超前或按预期）
     ├─ -30% < deviation ≤ -10% → 🟡 轻微滞后（记录观察）
     ├─ -50% < deviation ≤ -30% → 🟠 明显滞后（主动询问原因）
     └─ deviation ≤ -50% → 🔴 严重滞后（评估是否需要拆分任务或增加资源）
```

### 进度停滞检测

```yaml
stall_detection:
  # 检测条件：进度百分比在连续 2 次检查中未变化
  condition: |
    current_progress == previous_progress 
    AND elapsed_since_previous > 10min
  
  action: |
    1. send_message 询问当前卡在哪个步骤
    2. 检查是否是阻塞（dependency_missing、tool_failure 等）
    3. 如确认停滞：
       - 分析停滞原因
       - 提供具体帮助或调整任务拆分
       - 更新健康度评分
```

---

## 3. 产出质量检查协议（L3）

### 抽样检查时机

```yaml
quality_sampling:
  triggers:
    - 子Agent报告 task_progress 且 progress_pct ∈ {25%, 50%, 75%}
    - 子Agent报告 task_complete（全量检查）
    - orchestrator 主动触发（health_score < 60 时）
  
  sampling_strategy:
    # 不全量检查，而是抽样关键文件
    - check_first_deliverable: true     # 检查第一个产出物
    - check_latest_deliverable: true    # 检查最新产出物
    - random_sample: 1                  # 随机抽 1 个中间文件
```

### 质量检查清单

#### 通用检查（所有任务类型）

```yaml
general_quality_checks:
  - name: "文件存在性"
    method: "read_file 检查 HEARTBEAT 产出物清单中的文件"
    pass: "文件存在且非空"
    fail: "文件缺失或为空 → 通知子Agent补充"
    
  - name: "格式规范"
    method: "检查文件格式是否符合项目约定"
    pass: "格式正确"
    fail: "格式不符 → 提供修正建议"
    
  - name: "一致性"
    method: "检查产出物与 Goal 的 success_criteria 方向是否一致"
    pass: "产出物支撑至少一个 success_criteria"
    fail: "偏离目标 → 通知子Agent调整方向"
```

#### 编码任务专项检查

```yaml
coder_quality_checks:
  - name: "编译检查"
    method: "execute_command 运行编译命令"
    pass: "编译通过，无错误"
    fail: "编译失败 → 附错误信息通知子Agent修复"
    
  - name: "Lint检查"
    method: "execute_command 运行 lint 工具"
    pass: "0 errors，warnings < 10"
    fail: "超出阈值 → 通知子Agent修复"
    
  - name: "测试检查"
    method: "execute_command 运行测试"
    pass: "测试通过率 ≥ 80%"
    fail: "低于阈值 → 通知子Agent修复"
    
  - name: "代码规范"
    method: "检查命名规范、注释完整性、模块结构"
    pass: "符合 pm-coder/code-standards.md 规范"
    fail: "不符合 → 提供具体违规列表"
```

#### 调研任务专项检查

```yaml
researcher_quality_checks:
  - name: "结论明确性"
    method: "检查报告是否包含明确的推荐结论"
    pass: "有 '推荐方案: XXX' 或等价表述"
    fail: "结论模糊 → 退回补充"
    
  - name: "对比完整性"
    method: "检查是否对比了至少 2 个候选方案"
    pass: "有方案对比表或等效内容"
    fail: "只有一个方案 → 要求补充替代方案分析"
    
  - name: "数据支撑"
    method: "检查关键声明是否有数据/引用支撑"
    pass: "每个推荐都附带理由"
    fail: "空洞推荐 → 要求补充数据"
```

#### 文档任务专项检查

```yaml
writer_quality_checks:
  - name: "完整性"
    method: "对照文档模板检查章节完整性"
    pass: "所有必要章节都存在"
    fail: "缺章节 → 列出缺失部分"
    
  - name: "准确性"
    method: "对照 context_pool 中的源数据交叉验证"
    pass: "文档内容与源数据一致"
    fail: "有不一致 → 标注具体冲突"
    
  - name: "可读性"
    method: "检查格式、标题层级、列表结构"
    pass: "Markdown 格式规范，标题层级正确"
    fail: "格式混乱 → 提供修正示例"
```

---

## 4. 约束合规检查协议（L4）

### 检查方式

```yaml
constraint_check:
  timing: "每次子Agent自验证时 + orchestrator验收时"
  
  steps:
    1. read_file context_pool/goal.md → 提取所有 constraints
    
    2. 对每个 constraint 检查：
       hard_constraint:
         - 逐一核对，零容忍
         - 任何一项违反 → 立即中断，ESCALATE
       
       soft_constraint:
         - 记录违规次数和类型
         - 违规累计 ≥ 3 次 → 升级为警告
    
    3. 汇总合规报告
       └─ 格式：
         | 约束ID | 类型 | 状态 | 说明 |
         | C1     | hard | ✅合规 | - |
         | C2     | soft | ⚠️偏差 | 使用了非首选框架（但兼容） |
```

### 常见约束检查项

```yaml
common_constraints:
  - id: "workspace_boundary"
    check: "所有产出物路径是否在 workspace 内"
    method: "检查产出物清单中的所有路径"
    
  - id: "no_paid_api"
    check: "是否调用了付费API"
    method: "检查子Agent HEARTBEAT 的外部API调用记录"
    
  - id: "tech_stack_match"
    check: "使用的技术栈是否与 goal.md 一致"
    method: "检查依赖文件（package.json/requirements.txt 等）"
    
  - id: "output_format"
    check: "产出物格式是否符合约定"
    method: "检查文件扩展名和内容结构"
```

---

## 5. 健康报告格式规范

### 子Agent发送格式

```yaml
# 子Agent通过 send_message 发送健康自检报告
health_report:
  type: "message"
  recipient: "main"
  summary: "{agent} 健康报告: {score}分"
  content:
    event_type: "health_report"
    task_id: "T{XXX}"
    agent_name: "{agent-role}"
    timestamp: "{YYYY-MM-DD HH:mm}"
    payload:
      health_score: 85
      factors:
        progress_velocity: 0.9
        heartbeat_freshness: 1.0
        error_count: 0.8
        constraint_compliance: 1.0
      concerns: []              # 可为空
      next_checkpoint: "预计完成核心功能实现（75%）"
      completed_steps: 5
      remaining_steps: 3
```

### orchestrator聚合格式

```yaml
# orchestrator 在项目 HEARTBEAT 中维护的健康度面板
health_dashboard:
  project_health: 82            # 项目整体健康度
  
  agents:
    - agent: "researcher-T001"
      health: 95
      status: "✅ healthy"
      trend: "↗ improving"
    - agent: "coder-T002"
      health: 68
      status: "🟡 attention"
      trend: "→ stable"
      concerns: ["测试通过率低", "超出预算风险"]
    - agent: "writer-T003"
      health: 82
      status: "✅ healthy"
      trend: "↗ improving"
  
  alerts:
    - level: "warning"
      agent: "coder-T002"
      message: "进度滞后 20%，测试通过率仅 65%"
      action: "已发送修正建议"
```

---

## 6. 检查点质量门禁

### 门禁执行流程

```yaml
quality_gate:
  trigger: "子Agent到达预设里程碑检查点"
  
  steps:
    1. read_file 检查 expected_output 文件是否存在
       └─ 不存在 → 阻止继续，要求子Agent先完成当前阶段
       
    2. 执行质量门禁命令（如定义了 quality_gate 命令）
       ├─ 门禁通过 → 标记里程碑完成，允许进入下一阶段
       └─ 门禁失败 → 附错误信息退回子Agent
       
    3. 更新 HEARTBEAT 里程碑状态
       └─ replace_in_file 更新任务 HEARTBEAT 的进度区
    
    4. 通知 orchestrator
       └─ send_message(type="message", event_type="milestone_reached")
```

### 里程碑跳过规则

```yaml
milestone_skip:
  # 某些情况下可以跳过非关键里程碑
  allowed_when:
    - "soft constraint 偏差导致的调整"
    - "任务范围缩小（用户确认）"
  
  not_allowed_when:
    - "hard constraint 相关的里程碑"
    - "影响下游任务的里程碑"
  
  process: |
    如需跳过里程碑：
    1. send_message(type="message", recipient="main")
    2. 说明跳过原因和建议
    3. orchestrator 评估后决定是否批准
    4. 批准 → 更新 HEARTBEAT 记录跳过决策
```
