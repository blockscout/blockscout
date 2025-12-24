# AI Assistant Knowledge Base

**Last Updated**: $(date +%Y-%m-%d)
**Project**: $(basename "$REPO_PATH")
**Organization**: $(basename "$(dirname "$REPO_PATH")")

## Project Overview

This repository is part of the $(basename "$(dirname "$REPO_PATH")") organization.

## Essential Commands

### Development
```bash
# Add common commands here
```

## Architecture

## Key Technologies

## Development Workflow

## Context for All AI Assistants

This file (`LLM.md`) is symlinked as:
- `.AGENTS.md`
- `CLAUDE.md`
- `QWEN.md`
- `GEMINI.md`

All files reference the same knowledge base. Updates here propagate to all AI systems.

## Rules for AI Assistants

1. **ALWAYS** update LLM.md with significant discoveries
2. **NEVER** commit symlinked files (.AGENTS.md, CLAUDE.md, etc.) - they're in .gitignore
3. **NEVER** create random summary files - update THIS file

---

**Note**: This file serves as the single source of truth for all AI assistants working on this project.
