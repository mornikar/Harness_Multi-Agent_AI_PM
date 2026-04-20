# AI PM Skills - 项目初始化脚本
# 用法: .\init-project.ps1 -ProjectName "MyApp" [-Template "web"]

param(
    [Parameter(Mandatory=$true)]
    [string]$ProjectName,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("web", "desktop", "mobile", "api", "script")]
    [string]$Template = "web",
    
    [Parameter(Mandatory=$false)]
    [string]$WorkspacePath = $PWD
)

$ErrorActionPreference = "Stop"

# 颜色定义
$Colors = @{
    Success = "Green"
    Info = "Cyan"
    Warning = "Yellow"
    Error = "Red"
}

function Write-ColorLine {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Colors[$Color]
}

function New-ProjectStructure {
    param([string]$ProjectPath)
    
    Write-ColorLine "创建项目目录结构..." "Info"
    
    $dirs = @(
        "src",
        "docs",
        "tests",
        ".workbuddy/context_pool/progress",
        ".workbuddy/context_pool/shared",
        ".workbuddy/agents",
        ".workbuddy/skills"
    )
    
    foreach ($dir in $dirs) {
        $fullPath = Join-Path $ProjectPath $dir
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        Write-ColorLine "  ✓ $dir" "Success"
    }
}

function Initialize-ContextPool {
    param([string]$ProjectPath, [string]$ProjectName, [string]$Template)
    
    Write-ColorLine "`n初始化上下文池..." "Info"
    
    $contextPoolPath = Join-Path $ProjectPath ".workbuddy/context_pool"
    
    # product.md
    $productContent = @"# $ProjectName - 产品定义

## 基本信息
- **项目名称**: $ProjectName
- **项目类型**: $Template
- **创建时间**: $(Get-Date -Format "yyyy-MM-dd HH:mm")
- **状态**: 初始化中

## 产品概述
<!-- 待补充：一句话描述产品核心价值 -->

## 目标用户
<!-- 待补充：目标用户画像 -->

## 核心功能
<!-- 待补充：3-5个核心功能点 -->

## 成功指标
<!-- 待补充：如何衡量产品成功 -->
"@
    Set-Content -Path (Join-Path $contextPoolPath "product.md") -Value $productContent
    Write-ColorLine "  ✓ product.md" "Success"
    
    # requirements.md
    $requirementsContent = @"# $ProjectName - 需求清单

## 用户故事

### US001: 
**作为** [角色]  
**我希望** [功能]  
**以便** [价值]

**验收标准**:
- [ ] AC1: 
- [ ] AC2: 
- [ ] AC3: 

---

## 功能需求

| ID | 功能 | 优先级 | 状态 |
|----|------|--------|------|
| F001 | | P0 | 待开发 |

## 非功能需求

### 性能
- 

### 兼容性
- 

### 安全
- 
"@
    Set-Content -Path (Join-Path $contextPoolPath "requirements.md") -Value $requirementsContent
    Write-ColorLine "  ✓ requirements.md" "Success"
    
    # tech_stack.md
    $techStackContent = @"# $ProjectName - 技术栈

## 前端
<!-- 待调研后填写 -->
- 框架: 
- 状态管理: 
- UI库: 

## 后端
<!-- 待调研后填写 -->
- 语言: 
- 框架: 
- 数据库: 

## 部署
<!-- 待设计后填写 -->
- 平台: 
- CI/CD: 

## 开发工具
- 包管理器: 
- 构建工具: 
- 测试框架: 
"@
    Set-Content -Path (Join-Path $contextPoolPath "tech_stack.md") -Value $techStackContent
    Write-ColorLine "  ✓ tech_stack.md" "Success"
    
    # architecture.md
    $architectureContent = @"# $ProjectName - 架构设计

## 系统架构
<!-- 待设计后补充架构图 -->

## 模块划分

| 模块 | 职责 | 技术选型 |
|------|------|----------|
| | | |

## 数据模型
<!-- 待设计后补充ER图 -->

## 接口设计
<!-- 待设计后补充API规范 -->

## 部署架构
<!-- 待设计后补充部署图 -->
"@
    Set-Content -Path (Join-Path $contextPoolPath "architecture.md") -Value $architectureContent
    Write-ColorLine "  ✓ architecture.md" "Success"
    
    # decisions.md
    $decisionsContent = @"# $ProjectName - 决策记录

## 决策模板

### [YYYY-MM-DD] 决策标题

**背景**: 

**选项**:
- 选项A: 
- 选项B: 

**决策**: 选择[选项]

**理由**:
1. 
2. 

**影响**:
- 

**参与者**: 

---

## 历史决策

"@
    Set-Content -Path (Join-Path $contextPoolPath "decisions.md") -Value $decisionsContent
    Write-ColorLine "  ✓ decisions.md" "Success"
}

function Initialize-Heartbeat {
    param([string]$ProjectPath, [string]$ProjectName)
    
    Write-ColorLine "`n初始化 HEARTBEAT.md..." "Info"
    
    $heartbeatContent = @"# Project Heartbeat - $ProjectName

## 项目信息
- **项目名称**: $ProjectName
- **创建时间**: $(Get-Date -Format "yyyy-MM-dd HH:mm")
- **最后更新**: $(Get-Date -Format "yyyy-MM-dd HH:mm")
- **状态**: 🟡 初始化中

## 任务状态看板

| 任务ID | 类型 | Agent | 状态 | 进度 | 阻塞项 | 最后更新 |
|--------|------|-------|------|------|--------|----------|
| | | | | | | |

## 关键决策
<!-- 重要决策记录 -->

## 风险与问题
<!-- 当前风险跟踪 -->
| 等级 | 描述 | 应对措施 | 状态 |
|------|------|----------|------|
| | | | |

## 下一步行动
<!-- 待办事项 -->
- [ ] 

## 里程碑

| 阶段 | 计划日期 | 实际日期 | 状态 |
|------|----------|----------|------|
| M1-调研 | | | 🔴 未开始 |
| M2-设计 | | | 🔴 未开始 |
| M3-MVP | | | 🔴 未开始 |
| M4-优化 | | | 🔴 未开始 |
| M5-发布 | | | 🔴 未开始 |
"@
    
    Set-Content -Path (Join-Path $ProjectPath ".workbuddy/HEARTBEAT.md") -Value $heartbeatContent
    Write-ColorLine "  ✓ HEARTBEAT.md" "Success"
}

function Initialize-GitRepo {
    param([string]$ProjectPath)
    
    Write-ColorLine "`n初始化 Git 仓库..." "Info"
    
    # .gitignore
    $gitignoreContent = @"# Dependencies
node_modules/
__pycache__/
*.pyc
.env
.venv/

# Build outputs
dist/
build/
*.exe
*.dll

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# WorkBuddy context (optional, can be committed)
# .workbuddy/context_pool/
# .workbuddy/HEARTBEAT.md
"@
    Set-Content -Path (Join-Path $ProjectPath ".gitignore") -Value $gitignoreContent
    Write-ColorLine "  ✓ .gitignore" "Success"
    
    # 初始化 git
    Push-Location $ProjectPath
    try {
        git init 2>$null | Out-Null
        git add . 2>$null | Out-Null
        git commit -m "Initial commit: Project initialized with AI PM Skills" 2>$null | Out-Null
        Write-ColorLine "  ✓ Git 仓库初始化完成" "Success"
    } catch {
        Write-ColorLine "  ⚠ Git 初始化失败（可能未安装Git），可手动执行" "Warning"
    } finally {
        Pop-Location
    }
}

function Initialize-TemplateFiles {
    param([string]$ProjectPath, [string]$Template)
    
    Write-ColorLine "`n根据模板 [$Template] 创建初始文件..." "Info"
    
    switch ($Template) {
        "web" {
            # package.json
            $packageJson = @{
                name = ($ProjectName -replace "\s+", "-").ToLower()
                version = "0.1.0"
                description = ""
                scripts = @{
                    dev = "vite"
                    build = "vite build"
                    preview = "vite preview"
                }
                dependencies = @{}
                devDependencies = @{
                    vite = "^5.0.0"
                }
            } | ConvertTo-Json -Depth 3
            Set-Content -Path (Join-Path $ProjectPath "package.json") -Value $packageJson
            Write-ColorLine "  ✓ package.json" "Success"
            
            # index.html
            $indexHtml = @"<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$ProjectName</title>
</head>
<body>
    <div id="app"></div>
    <script type="module" src="/src/main.js"></script>
</body>
</html>
"@
            Set-Content -Path (Join-Path $ProjectPath "index.html") -Value $indexHtml
            Write-ColorLine "  ✓ index.html" "Success"
            
            # src/main.js
            New-Item -ItemType Directory -Path (Join-Path $ProjectPath "src") -Force | Out-Null
            $mainJs = @"// $ProjectName - Entry Point
console.log('Welcome to $ProjectName!');
"@
            Set-Content -Path (Join-Path $ProjectPath "src/main.js") -Value $mainJs
            Write-ColorLine "  ✓ src/main.js" "Success"
        }
        
        "desktop" {
            # package.json for Electron
            $packageJson = @{
                name = ($ProjectName -replace "\s+", "-").ToLower()
                version = "0.1.0"
                description = ""
                main = "main.js"
                scripts = @{
                    start = "electron ."
                    dev = "electron . --dev"
                }
                dependencies = @{}
                devDependencies = @{
                    electron = "^28.0.0"
                }
            } | ConvertTo-Json -Depth 3
            Set-Content -Path (Join-Path $ProjectPath "package.json") -Value $packageJson
            Write-ColorLine "  ✓ package.json" "Success"
        }
        
        "api" {
            # requirements.txt for Python
            $requirementsTxt = @"# $ProjectName - Python Dependencies
fastapi==0.109.0
uvicorn[standard]==0.27.0
pydantic==2.5.0
python-dotenv==1.0.0

# Database (choose one)
# sqlalchemy==2.0.0
# motor==3.3.0

# Testing
pytest==7.4.0
httpx==0.26.0
"@
            Set-Content -Path (Join-Path $ProjectPath "requirements.txt") -Value $requirementsTxt
            Write-ColorLine "  ✓ requirements.txt" "Success"
            
            # main.py
            $mainPy = @"# $ProjectName - FastAPI Application
from fastapi import FastAPI

app = FastAPI(title="$ProjectName")

@app.get("/")
async def root():
    return {"message": "Welcome to $ProjectName!"}

@app.get("/health")
async def health():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
"@
            Set-Content -Path (Join-Path $ProjectPath "main.py") -Value $mainPy
            Write-ColorLine "  ✓ main.py" "Success"
        }
        
        default {
            Write-ColorLine "  ℹ 使用基础模板" "Info"
        }
    }
}

function Show-NextSteps {
    param([string]$ProjectPath, [string]$ProjectName)
    
    Write-ColorLine "`n═══════════════════════════════════════════════════════════" "Success"
    Write-ColorLine "  项目 [$ProjectName] 初始化完成！" "Success"
    Write-ColorLine "═══════════════════════════════════════════════════════════" "Success"
    
    Write-ColorLine "`n📁 项目位置: $ProjectPath" "Info"
    
    Write-ColorLine "`n📋 下一步操作:" "Info"
    Write-ColorLine "  1. 编辑 .workbuddy/context_pool/product.md 完善产品定义" "White"
    Write-ColorLine "  2. 编辑 .workbuddy/context_pool/requirements.md 补充需求" "White"
    Write-ColorLine "  3. 告诉 AI: '帮我开发 $ProjectName'" "White"
    
    Write-ColorLine "`n📖 可用命令:" "Info"
    Write-ColorLine "  cd '$ProjectPath'" "White"
    Write-ColorLine "  cat .workbuddy/HEARTBEAT.md  # 查看项目状态" "White"
    
    Write-ColorLine ""
}

# ═══════════════════════════════════════════════════════════
# 主程序
# ═══════════════════════════════════════════════════════════

Write-ColorLine "═══════════════════════════════════════════════════════════" "Info"
Write-ColorLine "  AI PM Skills - 项目初始化工具" "Info"
Write-ColorLine "═══════════════════════════════════════════════════════════" "Info"

# 确定项目路径
$projectPath = Join-Path $WorkspacePath $ProjectName

# 检查目录是否已存在
if (Test-Path $projectPath) {
    Write-ColorLine "`n错误: 目录 '$projectPath' 已存在" "Error"
    exit 1
}

# 创建项目目录
Write-ColorLine "`n创建项目: $ProjectName" "Info"
New-Item -ItemType Directory -Path $projectPath -Force | Out-Null

# 执行初始化步骤
New-ProjectStructure -ProjectPath $projectPath
Initialize-ContextPool -ProjectPath $projectPath -ProjectName $ProjectName -Template $Template
Initialize-Heartbeat -ProjectPath $projectPath -ProjectName $ProjectName
Initialize-TemplateFiles -ProjectPath $projectPath -Template $Template
Initialize-GitRepo -ProjectPath $projectPath

# 显示完成信息
Show-NextSteps -ProjectPath $projectPath -ProjectName $ProjectName
