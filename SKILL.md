---
name: zoom-s2s-oauth
description: Zoom Server-to-Server OAuth REST API 调用技能。当用户需要用 Zoom Server-to-Server OAuth App 直接调用 Zoom REST API（不走 MCP 协议）时触发。适用场景：(1) 列出/搜索/创建/删除 Zoom 会议，(2) 查询云录像，(3) 获取用户信息，(4) 任何 Zoom REST API 调用。触发词：Zoom、Server-to-Server、OAuth、zoom会议, 安排会议。
---

# Zoom Server-to-Server OAuth REST API

## 凭证配置

在 `.env` 文件中配置：

```env
ZOOM_ACCOUNT_ID=你的AccountID
ZOOM_CLIENT_ID=你的ClientID
ZOOM_CLIENT_SECRET=你的ClientSecret
ZOOM_USER_ID=你的用户邮箱或user_id
```

**Token 获取方式**：Server-to-Server OAuth，机器对机器，无需用户交互授权。

## 核心脚本

`scripts/zoom-s2s.sh` — 所有 API 调用都通过这个脚本。

```bash
# 先加载 .env（脚本内部自动加载，也可手动）
source ../.env

# 获取帮助
./scripts/zoom-s2s.sh help

# 列出即将到来的会议
./scripts/zoom-s2s.sh list_meetings <user_id> <page_size> upcoming

# 获取单个会议详情
./scripts/zoom-s2s.sh get_meeting <meeting_id>

# 创建会议
# start_time 格式: YYYY-MM-DDTHH:MM:SS (北京时间即 Asia/Shanghai)
./scripts/zoom-s2s.sh create_meeting "<主题>" "<start_time>" <时长分钟> [时区] [密码]
./scripts/zoom-s2s.sh create_meeting "季度经营讨论会" "2026-05-05T10:00:00" 60 Asia/Shanghai

# 删除会议
./scripts/zoom-s2s.sh delete_meeting <meeting_id>

# 获取云录像
./scripts/zoom-s2s.sh recordings <user_id> <page_size>

# 获取用户信息
./scripts/zoom-s2s.sh get_user [user_id]

# 列出账户下所有用户
./scripts/zoom-s2s.sh list_users
```

## Token 缓存

脚本自动缓存 Token 到 `~/.zoom-s2s-token.json`（有效期约 50 分钟），重复调用无需每次重新认证。

## 常用 API 快速参考

| 操作 | 命令 |
|------|------|
| 列出最近5个会议 | `list_meetings <user> 5 upcoming` |
| 列出最近10个历史会议 | `list_meetings <user> 10 past` |
| 创建明天10点会议 | `create_meeting "主题" "YYYY-MM-DDT10:00:00" 60` |
| 获取会议详情 | `get_meeting <id>` |
| 删除会议 | `delete_meeting <id>` |
| 获取云录像 | `recordings <user> 10` |

## 踩坑记录

1. **scope 错误 (4711)**：`list_meetings` 需要在 App 里开通 `meeting:read:list_meetings` 权限
2. **Token 失效**：Server-to-Server Token 有效期 1 小时，脚本自动刷新并缓存
3. **用户 ID**：可用邮箱，也可在 `list_users` 里查 user_id
