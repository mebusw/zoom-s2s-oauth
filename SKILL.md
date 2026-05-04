---
name: zoom-s2s-oauth
description: Zoom meeting 的REST API 调用技能。当用户需要管理 Zoom meetings, 直接调用 Zoom meeting "Server-to-Server OAuth" 调用REST API（不走 MCP 协议）。适用场景：(1) 列出/查看/搜索/创建/删除 Zoom 会议，(2) 查询云录像，(3) 获取用户信息，(4) 任何 Zoom REST API 调用。触发词："Zoom meeting", "安排zoom会议", "zoom会议", "list meetings", "schedual a meeting".
---

# Zoom Server-to-Server OAuth REST API

## 凭证配置

在 `.env` 文件中配置并查看凭证：

```env
ZOOM_ACCOUNT_ID=你的AccountID
ZOOM_CLIENT_ID=你的ClientID
ZOOM_CLIENT_SECRET=你的ClientSecret
ZOOM_USER_ID=你的用户邮箱或user_id
```

**Token 获取方式**：Server-to-Server OAuth，机器对机器，无需用户交互授权。

## 核心脚本

`scripts/zoom-s2s.py` — 纯 Python，无外部依赖，兼容 Python 3.7+。

```bash
cd ~/.agents/skills/zoom-s2s-oauth/scripts

# 获取帮助
python3 zoom-s2s.py help

# 列出即将到来的会议
python3 zoom-s2s.py list_meetings <user> <page_size> upcoming

# 获取单个会议详情
python3 zoom-s2s.py get_meeting <meeting_id>

# 创建会议 (start_time: YYYY-MM-DDTHH:MM:SS)
python3 zoom-s2s.py create_meeting "<主题>" "<start_time>" <时长分钟> [时区] [密码]
python3 zoom-s2s.py create_meeting "煎饼果子讨论会" "2026-05-05T10:00:00" 60 Asia/Shanghai

# 删除会议
python3 zoom-s2s.py delete_meeting <meeting_id>

# 获取云录像
python3 zoom-s2s.py recordings <user> <page_size>

# 获取用户信息
python3 zoom-s2s.py get_user [user]

# 列出账户下所有用户
python3 zoom-s2s.py list_users [page_size]
```

## Token 缓存

脚本自动缓存 Token 到 `~/.zoom-s2s-token.json`（有效期约 50 分钟），重复调用无需每次重新认证。

## 常用操作快速参考

| 操作 | 命令 |
|------|------|
| 列出最近5个会议 | `list_meetings <user> 5 upcoming` |
| 列出最近10个历史会议 | `list_meetings <user> 10 past` |
| 创建明天10点会议 | `create_meeting "主题" "YYYY-MM-DDT10:00:00" 60 Asia/Shanghai` |
| 获取会议详情 | `get_meeting <id>` |
| 删除会议 | `delete_meeting <id>` |
| 获取云录像 | `recordings <user> 10` |

## 踩坑记录

1. **scope 错误 (4711)**：某些 API（如 `get_user`）需要在 App 里开通对应 scope，又如 `list_meetings` 需要在 App 里开通 `meeting:read:list_meetings` 权限
2. **Token 有效期**：Server-to-Server Token 有效期 1 小时，脚本自动刷新并缓存
3. **用户 ID**：可用邮箱，也可用 `list_users` 查 user_id