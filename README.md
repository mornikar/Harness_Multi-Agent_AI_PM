# AI产品经理多Agent Skill体系

> 基于 WorkBuddy/OpenClaw Skill 规范构建的 Multi-Agent 协作开发框架

## 架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                        pm-orchestrator                          │
│                    (AI产品经理主控器)                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  需求澄清    │  │  任务拆解    │  │  Skills管理  │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │ 上下文池管理 │  │ 子Agent调度  │  │  结果整合    │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
                              │
          ┌───────────────────┼───────────────────┐
          ▼                   ▼                   ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│  pm-researcher  │  │    pm-coder     │  │   pm-writer     │
│   (信息检索)     │  │   (编程执行)     │  │   (内容输出)     │
│                 │  │                 │  │                 │
│ • 技术调研      │  │ • 代码编写      │  │ • PRD撰写       │
│ • 竞品分析      │  │ • 调试修复      │  │ • 技术文档      │
│ • 方案选型      │  │ • 重构优化      │  │ • API文档       │
│ • 可行性评估    │  │ • 测试编写      │  │ • CHANGELOG     │
└─────────────────┘  └─────────────────┘  └─────────────────┘
```

## 核心特性

### 1. 智能任务拆解
- 自动分析需求依赖关系
- 生成可并行执行的子任务
- 动态分配任务给专业Agent

### 2. Skills 动态管理
- 自动匹配任务所需 Skills
- 本地 Skills 缓存复用
- 缺失 Skills 自动下载

### 3. 上下文池（Context Pool）
- 全局共享的项目上下文
- 细粒度的访问权限控制
- 版本化的决策记录

### 4. HEARTBEAT 状态追踪
- 实时任务状态看板
- 关键决策记录
- 风险与问题追踪

### 5. 结果自动整合
- 多 Agent 输出合并
- 一致性自动检查
- 完整交付物生成

## 目录结构

```
AI_PM_SKills/
├── README.md                    # 本文件
├── ARCHITECTURE.md              # 架构详细说明
├── QUICKSTART.md               # 快速开始指南
│
├── pm-orchestrator/            # 主控器 Skill
│   └── SKILL.md
│
├── pm-coder/                   # 编程执行 Skill
│   └── SKILL.md
│
├── pm-researcher/              # 信息检索 Skill
│   └── SKILL.md
│
├── pm-writer/                  # 内容输出 Skill
│   └── SKILL.md
│
├── shared/                     # 共享资源
│   ├── assets/                 # 模板、图片等
│   │   ├── ui-components/
│   │   ├── api-templates/
│   │   └── doc-templates/
│   │
│   └── references/             # 参考资料
│       ├── coding-standards.md
│       ├── api-design-guide.md
│       └── security-checklist.md
│
└── scripts/                    # 工具脚本
    ├── init-project.ps1        # 项目初始化
    ├── skill-install.ps1       # Skill安装
    └── heartbeat-sync.ps1      # 状态同步
```

## 工作流程

```
用户输入需求
    ↓
pm-orchestrator 触发
    ↓
┌────────────────────────────────────────┐
│ Phase 1: 需求澄清                       │
│ - 确认产品类型、技术栈、交付标准          │
└────────────────────────────────────────┘
    ↓
┌────────────────────────────────────────┐
│ Phase 2: 任务拆解 + Skills分析          │
│ - 拆解为独立子任务                       │
│ - 分析每个任务所需 Skills                │
└────────────────────────────────────────┘
    ↓
┌────────────────────────────────────────┐
│ Phase 3: Skills管理                     │
│ - 检查本地 Skills 可用性                 │
│ - 下载缺失 Skills 到对应目录             │
└────────────────────────────────────────┘
    ↓
┌────────────────────────────────────────┐
│ Phase 4: 上下文池 + HEARTBEAT初始化      │
│ - 创建项目上下文池                       │
│ - 生成 HEARTBEAT.md 状态文件             │
└────────────────────────────────────────┘
    ↓
┌────────────────────────────────────────┐
│ Phase 5: 子Agent并行调度                 │
│ - 创建子Agent会话                        │
│ - 派发任务 + 注入 Skills                 │
│ - 监控执行状态                           │
└────────────────────────────────────────┘
    ↓
┌────────────────────────────────────────┐
│ Phase 6: 上下文同步与结果收集            │
│ - 接收子Agent结果                        │
│ - 更新上下文池                           │
│ - 处理阻塞项                             │
└────────────────────────────────────────┘
    ↓
┌────────────────────────────────────────┐
│ Phase 7: 结果整合与交付                  │
│ - 整合各子Agent输出                      │
│ - 质量检查                               │
│ - 向用户呈现完整交付物                    │
└────────────────────────────────────────┘
```

## 使用场景

### 场景1：从0到1开发新产品
```
用户：帮我做一个个人知识管理工具，支持Markdown编辑和全文搜索

pm-orchestrator:
  ├── T001 → pm-researcher: 调研本地存储方案、搜索技术
  ├── T002 → pm-writer: 撰写PRD和产品原型
  ├── T003 → pm-coder: 开发编辑器核心功能
  ├── T004 → pm-coder: 实现搜索索引
  └── T005 → pm-writer: 编写用户手册
```

### 场景2：功能迭代
```
用户：给现有App添加用户认证功能

pm-orchestrator:
  ├── T001 → pm-researcher: 调研JWT vs Session方案
  ├── T002 → pm-coder: 实现登录/注册API
  ├── T003 → pm-coder: 实现前端登录页面
  └── T004 → pm-writer: 更新API文档
```

### 场景3：技术重构
```
用户：把项目从Vue2迁移到Vue3

pm-orchestrator:
  ├── T001 → pm-researcher: 调研迁移方案和 breaking changes
  ├── T002 → pm-coder: 迁移核心组件
  ├── T003 → pm-coder: 迁移状态管理
  └── T004 → pm-writer: 编写迁移指南
```

## 安装使用

### 1. 安装到 WorkBuddy

```powershell
# 复制到 WorkBuddy Skills 目录
Copy-Item -Path "D:\Auxiliary_means\All_AI_Skills\AI_PM_SKills\*" `
  -Destination "$env:USERPROFILE\.workbuddy\skills\" -Recurse -Force
```

### 2. 项目初始化

```powershell
# 运行初始化脚本
.\scripts\init-project.ps1 -ProjectName "MyApp"
```

### 3. 开始使用

直接对 AI 说出你的需求：
- "帮我做一个记账App"
- "开发一个Markdown编辑器"
- "实现用户认证功能"

## 子Agent详情

### pm-researcher
**职责**：技术调研、竞品分析、方案选型

**触发词**：调研、对比、选型、分析、竞品、方案、评估

**输出**：调研报告（Markdown）、对比表格、推荐结论

### pm-coder
**职责**：代码编写、调试修复、重构优化、测试编写

**触发词**：编码、实现、开发、调试、修复、重构、代码

**输出**：可运行代码、单元测试、代码审查报告

### pm-writer
**职责**：PRD撰写、技术文档、用户手册、CHANGELOG

**触发词**：文档、PRD、撰写、编写、手册、说明、CHANGELOG

**输出**：Markdown文档、API文档、用户指南

## 上下文池说明

### 文件结构

```
.workbuddy/context_pool/
├── product.md              # 产品定义（只读）
├── requirements.md         # 需求清单（只读）
├── tech_stack.md          # 技术栈决策（只读）
├── architecture.md        # 架构设计（只读）
├── decisions.md           # 决策记录（追加）
├── progress/              # 任务进度
│   ├── T001.md
│   ├── T002.md
│   └── ...
└── shared/                # 共享数据
    ├── api-schema.json
    ├── db-schema.sql
    └── ui-mockups/
```

### 访问权限

| 文件 | orchestrator | 子Agent |
|-----|-------------|---------|
| product.md | 读写 | 只读 |
| requirements.md | 读写 | 只读 |
| decisions.md | 读写 | 只读 |
| progress/*.md | 读写 | 读写 |
| shared/* | 读写 | 读写 |

## HEARTBEAT.md 格式

```markdown
# Project Heartbeat

## 项目信息
- **项目名称**: MyApp
- **创建时间**: 2024-01-15
- **最后更新**: 2024-01-15 14:30

## 任务状态看板

| 任务ID | 类型 | Agent | 状态 | 进度 | 阻塞项 | 最后更新 |
|-------|------|-------|------|------|--------|---------|
| T001 | 调研 | pm-researcher | completed | 100% | - | 10:30 |
| T002 | 设计 | pm-writer | running | 60% | - | 14:30 |
| T003 | 编码 | pm-coder | pending | 0% | 依赖T002 | - |

## 关键决策
- [2024-01-15] 选择Vue3 + Electron作为技术栈

## 风险与问题
- [MEDIUM] Electron打包体积较大 → 考虑使用Tauri替代

## 下一步行动
1. [ ] 完成PRD文档（pm-writer）
2. [ ] 确认UI设计稿
```

## 扩展开发

### 添加新的子Agent

1. 创建 `pm-{agent-name}/SKILL.md`
2. 在 `pm-orchestrator/SKILL.md` 中注册任务类型映射
3. 更新本 README 的子Agent列表

### 添加共享资源

1. 放入 `shared/assets/` 或 `shared/references/`
2. 在 `pm-orchestrator` 的 Skills 管理章节添加引用

## 最佳实践

1. **任务粒度**：单个任务应在 30-60 分钟内可完成
2. **依赖管理**：尽量减少任务间依赖，提高并行度
3. **决策记录**：所有关键决策必须写入 decisions.md
4. **状态同步**：子Agent定期更新 progress/*.md
5. **错误处理**：失败任务需明确失败原因和重试策略

## 版本历史

| 版本 | 日期 | 变更 |
|-----|------|------|
| v1.0 | 2024-04-20 | 初始版本，包含4个核心Agent |

## 许可证

MIT License
