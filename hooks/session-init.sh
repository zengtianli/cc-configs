#!/usr/bin/env bash
# session-init.sh — SessionStart 统一入场 hook
# 合并自: session_start.sh (基础信息: handoffs/tasks/INBOX/archived repos) + sync-cc-auto.sh (CC drift detect)
#
# 顺序: 1) session_start → 基础上下文 (stdout)  2) sync-cc-auto → drift 检测 (stderr 单行)
# 非 async (5s 内完成); 两段独立 exec 不重写逻辑.

set +e

bash "$HOME/Dev/tools/dev/scripts/tools/session_start.sh"
bash "$HOME/.claude/hooks/sync-cc-auto.sh"

exit 0
