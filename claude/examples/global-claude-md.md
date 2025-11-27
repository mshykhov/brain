# Global CLAUDE.md

Location: `~/.claude/CLAUDE.md`

```markdown
# Global Instructions

## Language
- Always respond in Russian

## MCP Tools - Use PROACTIVELY
**Always verify against official documentation (Context7, web docs) - never rely solely on training data.**

- `mcp__context7__*` - library/framework docs (source of truth)
- `mcp__fetch__fetch` - web content, online docs
- `mcp__github__*` - GitHub operations
- `mcp__memory__aim_*` - persistent knowledge storage

## Brain - Personal Knowledge Base
- Location: `/mnt/c/Users/Myron/brain` or https://github.com/mshykhov/brain
- When user says "brain" = this knowledge base repo
- Consult brain for personal notes, configs, decisions
- When modifying brain - follow rules in its README

## Code Style
- Keep it simple, avoid over-engineering
- Follow existing patterns in the codebase
- Don't add unnecessary comments or docstrings

## Git Commits
- No Claude/AI attribution in commit messages
- Use conventional commits format
```
