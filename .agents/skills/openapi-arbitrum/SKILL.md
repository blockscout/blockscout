---
name: openapi-arbitrum
description: "Manage OpenAPI spec Arbitrum branch workflow. Manual only via /openapi-arbitrum. Commands: init, sync, deliver, push."
disable-model-invocation: true
allowed-tools: Bash(.claude/skills/openapi-arbitrum/scripts/openapi-arbitrum.sh *)
---

# openapi-arbitrum

Parse args and run via Bash:

```
.claude/skills/openapi-arbitrum/scripts/openapi-arbitrum.sh <command> [args...]
```

**IMPORTANT**: Always use the relative path shown above — never an absolute path.

Commands: `init <id>`, `sync`, `deliver <id> <message>`, `push`.

Report the script output to the user. If the script exits non-zero, report the error and stop.
