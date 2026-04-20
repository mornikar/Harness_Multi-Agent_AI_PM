# HEARTBEAT 操作规范（pm-coder）

> 供 pm-coder 子Agent 在执行任务时参考的 HEARTBEAT 操作详细规范。
> 由 SKILL.md 中的 Step 0/2/5/8/9 引用，需要时通过 read_file 渐进加载。

## 任务级 HEARTBEAT 创建模板

```markdown
# T{task_id} - {任务简述}

## 基本信息
- **任务ID**: T{task_id}
- **类型**: {frontend/backend/database/testing/debugging/refactoring}
- **分配Agent**: pm-coder
- **分配时间**: {YYYY-MM-DD HH:mm}
- **状态**: 🔄 running
- **进度**: 0%

## 任务目标
{从orchestrator的任务派发中复制}

## 输入
- 上游任务产出: {路径列表（如有依赖）}
- 技术栈: {从tech_stack.md读取}
- 编码规范: pm-coder/references/code-standards.md

## 输出要求
- 交付物: {文件路径和说明}
- 验收标准: {检查清单}

## 执行进度
- [ ] Step 1: 理解任务 + 读取上游产出
- [ ] Step 2: 设计实现方案（函数/类结构）
- [ ] Step 3: 编码实现核心逻辑
- [ ] Step 4: 错误处理 + 注释
- [ ] Step 5: 测试编写 + 验证
- [ ] Step 6: 代码自审

## 产出物清单
| # | 文件路径 | 说明 | 行数 |
|---|---------|------|------|
| - | - | - | - |

## 遇到的问题
| # | 问题描述 | 解决方式 | 状态 |
|---|---------|---------|------|
| - | - | - | - |

## 依赖与阻塞
- **上游依赖**: T{YYY}（状态: {completed/pending}）
- **当前阻塞**: 无 / {阻塞描述}
```

## HEARTBEAT 更新时机

| 事件 | 更新内容 | 工具 |
|------|---------|------|
| 完成一个 Step | 勾选执行进度 checkbox | `replace_in_file` |
| 生成文件 | 追加到产出物清单 | `replace_in_file` |
| 遇到问题 | 追加到"遇到的问题" | `replace_in_file` |
| 任务完成 | 状态→✅completed, 进度→100% | `replace_in_file` |
| 任务阻塞 | 状态→⚠️blocked, 记录阻塞原因 | `replace_in_file` |

## 更新示例

```python
# 勾选一个完成步骤
replace_in_file(
    filePath="context_pool/progress/T003-heartbeat.md",
    old_str="- [ ] Step 3: 编码实现核心逻辑",
    new_str="- [x] Step 3: 编码实现核心逻辑"
)

# 追加产出物
replace_in_file(
    filePath="context_pool/progress/T003-heartbeat.md",
    old_str="| - | - | - | - |",
    new_str="| - | - | - | - |\n| 1 | src/components/UserForm.vue | 用户表单组件 | 156 |"
)

# 标记任务完成
replace_in_file(
    filePath="context_pool/progress/T003-heartbeat.md",
    old_str="- **状态**: 🔄 running\n- **进度**: 0%",
    new_str="- **状态**: ✅ completed\n- **进度**: 100%"
)
```
