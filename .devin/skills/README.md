# Project-Specific Skills

This directory is for project-specific Devin skills that complement the template's general guidance.

## Adding Skills

Skills here should be:
- **Project-specific**: Custom to this particular project's domain or workflow
- **Complementary**: Build on the template's general guidance, not replace it
- **Lightweight**: Focused on specific tasks rather than broad orchestration

## Template Skills (Global)

For general-purpose skills that work across projects, use the global skills directory:
- `~/.config/devin/skills/` or
- `~/.claude/skills/`

See [`inventory/catalog-skills-agents.md`](../../inventory/catalog-skills-agents.md) for available skills.

## Example Project Skills

- `project-setup.md` - Custom project initialization steps
- `deployment.md` - Project-specific deployment procedures  
- `testing.md` - Custom testing patterns for this codebase
- `api-contracts.md` - API design patterns and conventions

## Skill Format

Follow the standard skill format (see global skills for examples):
```markdown
# Skill Name

Brief description of what this skill does.

## When to use
- Use this when...
- Also use for...

## What it does
- Step 1...
- Step 2...

## Prerequisites
- Tool X installed
- Configuration Y set
```
