"""GUIDE.md → GUIDE.html: one offline page (no web fonts, no scripts), light and dark. Method by fwjelaa (FWJ STUDIOS).

Only the Markdown the guide uses: headings, paragraphs, - and 1. lists, pipe tables, fenced code, `code`,
**bold**, [links](url) and ![images](path)."""
import html as _html
import re

CSS = """
:root { --paper: #f7f5f0; --ink: #1d1f1c; --muted: #5a5f57; --rule: #d8d4ca; --code: #ebe7dd; --accent: #2f6b4f; }
@media (prefers-color-scheme: dark) {
  :root { --paper: #161816; --ink: #e6e4dd; --muted: #a3a79e; --rule: #33362f; --code: #23261f; --accent: #8fc7a6; }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--paper); color: var(--ink);
  font: 17px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
main { max-width: 46rem; margin: 0 auto; padding: 2.5rem 16px 4rem; }
h1, h2, h3 { font-family: Georgia, "Times New Roman", serif; line-height: 1.25; margin: 2.2rem 0 0.8rem; }
h1 { font-size: 2.1rem; margin-top: 0.5rem; }
h2 { font-size: 1.5rem; padding-top: 1.2rem; border-top: 1px solid var(--rule); }
h3 { font-size: 1.2rem; }
p, li { max-width: 42rem; }
a { color: var(--accent); }
code { font: 0.88em/1.4 ui-monospace, Consolas, "Cascadia Mono", monospace; background: var(--code);
  padding: 0.1em 0.3em; border-radius: 3px; }
pre { background: var(--code); padding: 0.9rem 1rem; border-radius: 4px; overflow-x: auto; }
pre code { padding: 0; background: none; }
.scroll { overflow-x: auto; margin: 1rem 0; }
table { border-collapse: collapse; font-size: 0.92rem; min-width: 32rem; }
th, td { text-align: left; vertical-align: top; padding: 0.45rem 0.7rem; border-bottom: 1px solid var(--rule); }
th { color: var(--muted); font-weight: 600; }
img { display: block; max-width: 100%; height: auto; border-radius: 4px; margin: 0.8rem 0; }
"""


def _slug(text, seen):
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-") or "section"
    base, n = s, 2
    while s in seen:
        s, n = f"{base}-{n}", n + 1
    seen.add(s)
    return s


def _inline(text):
    out = []
    for i, part in enumerate(re.split(r"(`[^`]*`)", text)):
        if i % 2:
            out.append("<code>" + _html.escape(part[1:-1], quote=False) + "</code>")
            continue
        s = _html.escape(part, quote=True)
        s = re.sub(r"!\[([^\]]*)\]\(([^)\s]+)\)", r'<img src="\2" alt="\1" loading="lazy">', s)
        s = re.sub(r"\[([^\]]+)\]\(([^)\s]+)\)", r'<a href="\2">\1</a>', s)
        s = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", s)
        out.append(s)
    return "".join(out)


def _cells(row):
    return [c.strip() for c in row.strip().strip("|").split("|")]


def build(md):
    lines = md.replace("\r\n", "\n").split("\n")
    body, seen, title, i = [], set(), "Guide", 0
    while i < len(lines):
        line = lines[i]
        if not line.strip():
            i += 1
        elif line.startswith("```"):
            j = i + 1
            while j < len(lines) and not lines[j].startswith("```"):
                j += 1
            code = "".join(_html.escape(x, quote=False) + "\n" for x in lines[i + 1:j])
            body.append(f"<pre><code>{code}</code></pre>")
            i = j + 1
        elif re.match(r"#{1,6} ", line):
            level = len(line) - len(line.lstrip("#"))
            text = line[level + 1:].strip()
            if level == 1 and title == "Guide":
                title = text
            body.append(f'<h{level} id="{_slug(text, seen)}">{_inline(text)}</h{level}>')
            i += 1
        elif line.startswith("|") and i + 1 < len(lines) and re.match(r"\|[\s:|-]+\|?\s*$", lines[i + 1]):
            head = "".join(f"<th>{_inline(c)}</th>" for c in _cells(line))
            rows, j = [], i + 2
            while j < len(lines) and lines[j].startswith("|"):
                rows.append("<tr>" + "".join(f"<td>{_inline(c)}</td>" for c in _cells(lines[j])) + "</tr>")
                j += 1
            body.append('<div class="scroll"><table>\n<thead><tr>' + head + "</tr></thead>\n<tbody>\n"
                        + "\n".join(rows) + "\n</tbody></table></div>")
            i = j
        elif re.match(r"(- |\d+\. )", line):
            tag = "ul" if line.startswith("- ") else "ol"
            items, j = [], i
            while j < len(lines) and (re.match(r"(- |\d+\. )", lines[j]) or (lines[j].startswith("  ") and items)):
                if re.match(r"(- |\d+\. )", lines[j]):
                    items.append(re.sub(r"^(- |\d+\. )", "", lines[j]).strip())
                else:
                    items[-1] += " " + lines[j].strip()
                j += 1
            body.append(f"<{tag}>\n" + "\n".join(f"<li>{_inline(t)}</li>" for t in items) + f"\n</{tag}>")
            i = j
        else:
            para, j = [], i
            while j < len(lines) and lines[j].strip() and not re.match(r"(#{1,6} |```|\||- |\d+\. )", lines[j]):
                para.append(lines[j].strip())
                j += 1
            body.append("<p>" + _inline(" ".join(para)) + "</p>")
            i = j
    return ("<!doctype html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n"
            '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
            f"<title>{_html.escape(title)}</title>\n<style>{CSS}</style>\n</head>\n<body>\n<main>\n"
            + "\n".join(body) + "\n</main>\n</body>\n</html>\n")
