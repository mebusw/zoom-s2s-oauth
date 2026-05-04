#!/bin/bash
#==============================================================================
# Zoom Server-to-Server OAuth REST API 调用脚本
# 用法: ./zoom-s2s.sh <action> [额外参数]
#
# 环境变量 (从 .env 加载):
#   ZOOM_ACCOUNT_ID
#   ZOOM_CLIENT_ID
#   ZOOM_CLIENT_SECRET
#   ZOOM_USER_ID        # 默认用户 (email 或 user_id)
#
# Token 缓存: ~/.zoom-s2s-token.json (有效期约 50 分钟)
#==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/../.env"
TOKEN_CACHE="${HOME}/.zoom-s2s-token.json"

#------------------------------------------------------------------------------
# 加载 .env
#------------------------------------------------------------------------------
load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
  else
    echo "❌ .env 文件不存在: $ENV_FILE" >&2
    exit 1
  fi
}

#------------------------------------------------------------------------------
# 获取 Access Token (带缓存)
#------------------------------------------------------------------------------
get_token() {
  local cached_token cached_expiry

  # 检查缓存
  if [[ -f "$TOKEN_CACHE" ]]; then
    cached_token=$(python3 -c "import json,sys; print('${TOKEN_CACHE}'); d=json.load(open('${TOKEN_CACHE}')); print(d.get('access_token',''))" 2>/dev/null || echo "")
    cached_expiry=$(python3 -c "import json; d=json.load(open('${TOKEN_CACHE}')); print(d.get('expiry',0))" 2>/dev/null || echo "0")

    if [[ -n "$cached_token" && "$(python3 -c "import time; print('valid' if time.time()<${cached_expiry} else 'expired')")" == "valid" ]]; then
      echo "$cached_token"
      return 0
    fi
  fi

  echo "🔑 获取新 Token..." >&2

  local token_resp
  token_resp=$(curl -s -X POST "https://zoom.us/oauth/token?grant_type=account_credentials&account_id=${ZOOM_ACCOUNT_ID}" \
    -H "Authorization: Basic $(echo -n "${ZOOM_CLIENT_ID}:${ZOOM_CLIENT_SECRET}" | base64)" \
    -H "Content-Type: application/x-www-form-urlencoded")

  local access_token error_msg
  access_token=$(echo "$token_resp" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('access_token',''))" 2>/dev/null)
  error_msg=$(echo "$token_resp" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('message',''))" 2>/dev/null)

  if [[ -z "$access_token" ]]; then
    echo "❌ Token 获取失败: $error_msg" >&2
    exit 1
  fi

  # 缓存 (提前 5 分钟过期)
  local expires_in
  expires_in=$(echo "$token_resp" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('expires_in',3600))" 2>/dev/null)
  python3 -c "
import json, time
d = {'access_token': '''$access_token''', 'expiry': time.time() + ${expires_in} - 300}
with open('${TOKEN_CACHE}', 'w') as f:
    json.dump(d, f)
"

  echo "$access_token"
}

#------------------------------------------------------------------------------
# API 调用 (自动带 Token)
#------------------------------------------------------------------------------
api_call() {
  local method="${1:-GET}"
  local endpoint="$2"
  local data="$3"

  local token
  token=$(get_token)

  local curl_args=("-s" "-X" "$method" "https://api.zoom.us/v2${endpoint}" \
    "-H" "Authorization: Bearer ${token}" \
    "-H" "Content-Type: application/json")

  if [[ -n "$data" ]]; then
    curl_args+=("-d" "$data")
  fi

  curl "${curl_args[@]}"
}

#------------------------------------------------------------------------------
# Actions
#------------------------------------------------------------------------------

action_list_meetings() {
  # 用法: list_meetings [user_id] [page_size] [type]
  local user="${1:-$ZOOM_USER_ID}"
  local page_size="${2:-10}"
  local type="${3:-upcoming}"

  echo "📋 获取用户 $user 的会议列表 (type=$type, page_size=$page_size)" >&2
  api_call "GET" "/users/${user}/meetings?page_size=${page_size}&type=${type}" | python3 -m json.tool 2>/dev/null || echo "解析失败"
}

action_get_meeting() {
  # 用法: get_meeting <meeting_id>
  local meeting_id="$1"
  if [[ -z "$meeting_id" ]]; then
    echo "❌ 需要 meeting_id" >&2; exit 1
  fi
  echo "🔍 获取会议 $meeting_id 详情" >&2
  api_call "GET" "/meetings/${meeting_id}" | python3 -m json.tool 2>/dev/null
}

action_create_meeting() {
  # 用法: create_meeting <topic> <start_time> <duration_minutes> [timezone] [password]
  local topic="$1"
  local start_time="$2"
  local duration="${3:-60}"
  local timezone="${4:-Asia/Shanghai}"
  local password="${5:-}"

  if [[ -z "$topic" || -z "$start_time" ]]; then
    echo "❌ 需要 topic 和 start_time (格式: YYYY-MM-DDTHH:MM:SS)" >&2
    exit 1
  fi

  echo "📅 创建会议: $topic at $start_time" >&2

  local payload="{\"topic\":\"${topic}\",\"type\":2,\"start_time\":\"${start_time}\",\"duration\":${duration},\"timezone\":\"${timezone}\",\"settings\":{\"host_video\":true,\"participant_video\":true,\"join_before_host\":false,\"mute_upon_entry\":false}}"

  if [[ -n "$password" ]]; then
    payload=$(echo "$payload" | python3 -c "import json,sys; d=json.load(sys.stdin); d['password']='${password}'; print(json.dumps(d))")
  fi

  api_call "POST" "/users/${ZOOM_USER_ID}/meetings" "$payload" | python3 -m json.tool 2>/dev/null
}

action_delete_meeting() {
  # 用法: delete_meeting <meeting_id>
  local meeting_id="$1"
  if [[ -z "$meeting_id" ]]; then
    echo "❌ 需要 meeting_id" >&2; exit 1
  fi
  echo "🗑️ 删除会议 $meeting_id" >&2
  api_call "DELETE" "/meetings/${meeting_id}" | python3 -m json.tool 2>/dev/null
}

action_get_user() {
  # 用法: get_user [user_id]
  local user="${1:-$ZOOM_USER_ID}"
  echo "👤 获取用户信息: $user" >&2
  api_call "GET" "/users/${user}" | python3 -m json.tool 2>/dev/null
}

action_recordings() {
  # 用法: recordings [user_id] [page_size]
  local user="${1:-$ZOOM_USER_ID}"
  local page_size="${2:-10}"
  echo "🎬 获取云录像列表: $user" >&2
  api_call "GET" "/users/${user}/recordings?page_size=${page_size}" | python3 -m json.tool 2>/dev/null
}

action_list_users() {
  echo "👥 获取用户列表" >&2
  api_call "GET" "/users?page_size=30" | python3 -m json.tool 2>/dev/null
}

action_help() {
  cat << 'HELP'
用法: zoom-s2s.sh <action> [参数...]

可用 Action:
  list_meetings   <user_id> <page_size> <type>     列出会议 (type: upcoming/past/live)
  get_meeting     <meeting_id>                     获取单个会议详情
  create_meeting  <topic> <start_time> <duration> [timezone] [password]
                                                    创建会议
                                                    start_time 格式: YYYY-MM-DDTHH:MM:SS
  delete_meeting  <meeting_id>                     删除会议
  get_user        [user_id]                        获取用户信息
  recordings      [user_id] [page_size]            获取云录像
  list_users                                      列出账户下所有用户
  help                                             显示本帮助

示例:
  # 列出即将到来的会议
  ./zoom-s2s.sh list_meetings service@uperform.cn 10 upcoming

  # 创建明天早上10点的会议
  ./zoom-s2s.sh create_meeting "煎饼果子讨论" "2026-05-05T10:00:00" 60 Asia/Shanghai

  # 获取云录像
  ./zoom-s2s.sh recordings service@uperform.cn 10
HELP
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------
load_env

ACTION="$1"
shift || true

case "$ACTION" in
  list_meetings)    action_list_meetings "$@" ;;
  get_meeting)      action_get_meeting "$@" ;;
  create_meeting)   action_create_meeting "$@" ;;
  delete_meeting)   action_delete_meeting "$@" ;;
  get_user)         action_get_user "$@" ;;
  recordings)       action_recordings "$@" ;;
  list_users)       action_list_users "$@" ;;
  help)             action_help ;;
  *)                echo "❌ 未知 action: $ACTION"; action_help; exit 1 ;;
esac
