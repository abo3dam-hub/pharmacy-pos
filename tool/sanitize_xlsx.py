"""Post-process a Dart-`excel`-generated xlsx so desktop Excel opens it cleanly.

Removes two anomalies the Dart writer leaves behind:
  1. An orphan empty drawing (`xl/drawings/drawing1.xml` + its sheet rels):
     the sheet has no <drawing> element referencing it.
  2. A stale `<dimension ref="A1"/>`: recomputed from the actual sheet data.

Usage: sanitize_xlsx.py <in.xlsx> <out.xlsx>
"""
import io
import re
import sys
import zipfile


def _sheet_refs(xml: str) -> str:
    """Compute the A1-style dimension covering all cells with r attributes."""
    refs = re.findall(r'r="([A-Z]+)(\d+)"', xml)
    if not refs:
        return 'A1'
    cols = [c for c, _ in refs]
    rows = [int(n) for _, n in refs]
    max_col = max(cols, key=lambda c: (len(c), c))
    return f'A1:{max_col}{max(rows)}'


def sanitize(src: str, dst: str) -> None:
    with zipfile.ZipFile(src, 'r') as zin:
        items = [(i, zin.read(i.filename)) for i in zin.infolist()]

    drop = {
        'xl/drawings/drawing1.xml',
        'xl/worksheets/_rels/sheet1.xml.rels',
    }
    out = []
    for info, data in items:
        if info.filename in drop:
            continue
        if info.filename == '[Content_Types].xml':
            text = data.decode('utf-8')
            text = re.sub(
                r'<Override[^>]*drawing[^>]*/>', '', text)
            data = text.encode('utf-8')
        if info.filename == 'xl/worksheets/sheet1.xml':
            text = data.decode('utf-8')
            dim = _sheet_refs(text)
            text = re.sub(r'<dimension ref="[^"]*"/>',
                           f'<dimension ref="{dim}"/>', text, count=1)
            data = text.encode('utf-8')
        out.append((info, data))

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, 'w', zipfile.ZIP_DEFLATED) as zout:
        for info, data in out:
            zout.writestr(info, data)
    with open(dst, 'wb') as f:
        f.write(buf.getvalue())
    print(f'sanitized -> {dst}')


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('usage: sanitize_xlsx.py <in.xlsx> <out.xlsx>')
        sys.exit(2)
    sanitize(sys.argv[1], sys.argv[2])
