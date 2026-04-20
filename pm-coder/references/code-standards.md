# 编码标准参考（pm-coder）

> 供 pm-coder 子Agent在编码时参考的标准规范。需要时通过 read_file 渐进加载。

## 命名规范

| 类型 | 规则 | 示例 |
|------|------|------|
| 文件名 | kebab-case | `user-profile.vue`, `auth-service.ts` |
| 组件名 | PascalCase | `UserProfile`, `AuthService` |
| 函数名 | camelCase | `getUserData()`, `validateForm()` |
| 常量 | UPPER_SNAKE | `MAX_RETRY_COUNT`, `API_BASE_URL` |
| CSS类名 | BEM | `.btn__icon--active` |
| 数据库表 | snake_case | `user_profiles`, `order_items` |

## TypeScript 规范

### 必须遵守
- 所有函数必须有返回类型注解
- 禁止使用 `any`，用 `unknown` + 类型守卫替代
- 异步操作必须有 try-catch
- 导出使用命名导出，默认导出仅用于页面组件

### 代码结构
```typescript
// 1. 类型定义
interface UserDTO {
  id: string;
  name: string;
  email: string;
  createdAt: Date;
}

// 2. 常量
const MAX_NAME_LENGTH = 50;

// 3. 主逻辑
export async function createUser(input: CreateUserInput): Promise<UserDTO> {
  try {
    const user = await db.users.create(input);
    return mapToDTO(user);
  } catch (error) {
    logger.error('Failed to create user', { input, error });
    throw new AppError('USER_CREATE_FAILED', '创建用户失败');
  }
}

// 4. 辅助函数
function mapToDTO(user: UserEntity): UserDTO {
  return {
    id: user.id,
    name: user.name,
    email: user.email,
    createdAt: user.createdAt,
  };
}
```

## Python 规范

### 必须遵守
- 所有函数必须有 type hints
- 使用 Pydantic 做数据校验（FastAPI 项目）
- 禁止裸 `except:`，必须指定异常类型
- 使用 pathlib 处理路径

### 代码结构
```python
from pathlib import Path
from typing import Optional
import logging

logger = logging.getLogger(__name__)

class UserService:
    """用户服务类"""
    
    def __init__(self, repo: UserRepository):
        self._repo = repo
    
    async def get_user(self, user_id: int) -> UserDTO:
        """
        获取用户信息
        
        Args:
            user_id: 用户ID
            
        Returns:
            用户DTO
            
        Raises:
            UserNotFoundError: 用户不存在
        """
        user = await self._repo.find_by_id(user_id)
        if not user:
            raise UserNotFoundError(f"User {user_id} not found")
        return UserDTO.from_entity(user)
```

## Git 提交规范

```
feat: 新增XX功能
fix: 修复XX问题
refactor: 重构XX模块
docs: 更新XX文档
test: 添加XX测试
chore: 构建/工具变更
```

## 错误处理规范

### 错误分类
| 类型 | 处理方式 | HTTP状态码 |
|------|---------|-----------|
| 业务错误 | 抛出自定义异常，返回友好提示 | 400/409/422 |
| 认证错误 | 返回401，引导登录 | 401 |
| 权限错误 | 返回403 | 403 |
| 服务器错误 | 记录日志，返回通用错误 | 500 |

### 错误日志格式
```
[ERROR] {timestamp} | {module} | {operation} | {message}
  Context: {相关上下文}
  Stack: {堆栈摘要}
```
