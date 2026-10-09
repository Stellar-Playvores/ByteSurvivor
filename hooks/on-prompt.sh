#!/bin/bash
# Called when user submits a prompt
export CLAUDE_HOOK_EVENT="message"
exec ~/ByteSurvivor/hooks/bytesurvivor-hook.sh
