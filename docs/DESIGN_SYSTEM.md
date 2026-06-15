# Memoria Design System

## Direction

Memoria should feel private, calm, source-backed, and quietly premium. It should
not look like a generic SaaS dashboard or CRM.

## Tokens

```json
{
  "colors": {
    "background": "#F8F5EF",
    "surface": "#FFFFFF",
    "surfaceMuted": "#F1ECE3",
    "textPrimary": "#241F1A",
    "textSecondary": "#6B6258",
    "accent": "#8B6F47",
    "accentMuted": "#E8DDCC",
    "private": "#7C5C8A",
    "sensitive": "#9B3A3A",
    "aiPending": "#B8792F",
    "confirmed": "#3F7A54",
    "border": "#DED5C8"
  },
  "radius": {
    "sm": 8,
    "md": 14,
    "lg": 22
  },
  "spacing": {
    "xs": 4,
    "sm": 8,
    "md": 16,
    "lg": 24,
    "xl": 32
  },
  "typography": {
    "display": 28,
    "title": 22,
    "section": 17,
    "body": 14,
    "caption": 12
  }
}
```

## UI Rules

- Use sidebar navigation for the main macOS sections.
- Keep the macOS sidebar grouped as 总览, 工作流, 三种模式, and 系统. The write/review loop must stay visible as 记录 and 整理台.
- Prefer inline panels, split views, sheets, and inspectors over modal-heavy
  flows.
- Proposal cards must show source quote, confidence, sensitivity, related people
  and themes, and per-item actions.
- Sensitive/private content should be marked with quiet badges rather than
  alarming warning blocks.
- Avoid neon gradients, over-animation, crowded tables, and CRM-style density.
