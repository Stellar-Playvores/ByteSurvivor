#!/bin/bash
# Called after a tool is used (file read, edit, bash, etc.)
export CLAUDE_HOOK_EVENT="tool_use"
exec ~/ByteSurvivor/hooks/bytesurvivor-hook.sh
