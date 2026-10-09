#!/bin/bash
# Called when Claude finishes responding
export CLAUDE_HOOK_EVENT="response"
exec ~/ByteSurvivor/hooks/bytesurvivor-hook.sh
