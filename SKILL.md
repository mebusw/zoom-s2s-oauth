---
name: zoom-meetin-admin
description: Zoom Meeting REST API call skills. When users need to manage Zoom meetings, they can directly call the Zoom Meeting "Server-to-Server OAuth" REST API (without using the MCP protocol). Applicable scenarios are (1) List/view/search/create/delete Zoom meetings, (2) Query cloud recordings, (3) Get user information, (4) Any Zoom REST API call. Trigger words includes "Zoom meeting", "Schedule a Zoom meeting", "View Zoom meeting", "List meetings", "Scheduled a meeting".
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
| 删除会议 | `delete_meeting <id> --yes` |
| 获取云录像 | `recordings <user> 10` |

## 最小权限配置建议

根据实际使用场景按需开通 scope，不需要的功能不要授权：

| 功能 | 所需 Scope | 建议 |
|------|-----------|------|
| 列出会议 | `meeting:read:list_meetings` | ✅ 核心 |
| 查看会议详情 | `meeting:read:meeting` | ✅ 核心 |
| 创建会议 | `meeting:write:create` | 按需开启 |
| **删除会议** | `meeting:write:delete` | ⚠️ 谨慎开启 |
| **读取云录像** | `cloud_recording:read:list_user_recordings` | ⚠️ 谨慎开启 |
| **列出账户用户** | `user:read:list_users` | ⚠️ 谨慎开启 |

> 建议为此 Skill 单独创建一个 Zoom Server-to-Server App，不要复用已有 App 的凭证。

## Agent 调用规范

- **创建会议前**：向用户确认主题、时间、时长，再执行。
- **删除会议前**：必须向用户明确展示会议信息并获得确认，命令需附加 `--yes` 参数。
- **禁止超范围调用**：仅允许文档中列出的 Action，不得构造任意 Zoom REST API 请求。

## 创建周期性会议（重要避坑）

创建 `type=8`（周期性）会议时，`recurrence` 参数有如下限制：

| recurrence.type | 说明 | 是否可用 |
|---|---|---|
| 1 | 每日循环（Daily） | ✅ 可用 |
| 2 | 每周循环（Weekly）+ `weekly_days` | ❌ 总是返回 "Request Body should be a valid JSON object"（Zoom API 自身 bug） |
| 3 | 每月循环（Monthly）+ `monthly_day` | ✅ 可用 |

**变通方案**：当需要每周特定天数（如周六日）但 type=2 失败时，可以：
- 用 type=1（每日循环）+ `end_date_time` 限定日期范围，覆盖目标日期
- 或用 type=3（每月循环）+ `monthly_day` 指定某日（适用于固定日期）
- 或直接创建多个单独会议（type=2）

**示例**：创建 5月23日-24日（周六日）两天的周期性会议：
```python
payload = {
    "topic": "CSM公开课",
    "type": 8,
    "start_time": "2026-05-23T08:00:00",
    "duration": 540,
    "timezone": "Asia/Shanghai",
    "recurrence": {
        "type": 1,                        # 每日循环
        "repeat_interval": 1,
        "end_date_time": "2026-05-24T00:00:00Z"  # 结束日期
    },
    "settings": {"host_video": True, "participant_video": True, "join_before_host": False, "mute_upon_entry": False}
}
```

## 踩坑记录

1. **scope 错误 (4711)**：某些 API（如 `get_user`）需要在 App 里开通对应 scope，又如 `list_meetings` 需要在 App 里开通 `meeting:read:list_meetings` 权限
2. **Token 有效期**：Server-to-Server Token 有效期 1 小时，脚本自动刷新并缓存
3. **用户 ID**：可用邮箱，也可用 `list_users` 查 user_id
4. **周期性会议 type=2 失败**：Zoom API 对 `recurrence.type=2`（每周循环）有 bug，任何包含 `weekly_days` 的请求都会返回 "Request Body should be a valid JSON object"，改用 type=1 或 type=3 变通