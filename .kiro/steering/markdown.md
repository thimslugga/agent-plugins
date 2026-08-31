---
inclusion: fileMatch
fileMatchPattern: ["**/*.md"]
---

# Markdown

- Do NOT wrap table cell content in bold (`**...**`), italics (`*...*` / `_..._`), or other emphasis markup. Terminal markdown renderers (render-markdown.nvim) count the emphasis characters when computing column width but conceal them on display, so emphasized cells push borders out of alignment. Keep table cells plain text.
- Inline code (`` `...` ``) in table cells is fine — it renders without breaking alignment.
- Emphasis and links are fine everywhere EXCEPT inside table cells.
