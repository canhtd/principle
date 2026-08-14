#!/usr/bin/env python3
"""
build-corpus.py — dựng corpus.jsonl từ bản Principles của chính bạn.

Skill ask-ray KHÔNG kèm nội dung sách (bản dịch có bản quyền).
Bạn tự cấp bản sách của mình, script này chuyển nó thành corpus tra cứu.

    python3 build-corpus.py /duong/dan/toi/Principles.epub

Ra: references/corpus.jsonl — mỗi dòng một nguyên tắc:
    {"id","part","chapter","num","title","body","has_body"}

Vì sao JSONL chứ không để nguyên sách:
  - một dòng = một nguyên tắc trọn vẹn, grep ra là dùng được ngay, không cần đọc quanh
  - chuẩn hóa số hiệu một lần lúc build (5. 6 → 5.6, 1,5 → 1.5, 1.1. 0 → 1.10)
  - bỏ Phần I (hồi ký, ~40% sách) — skill không dùng tới
"""
import json, re, sys, unicodedata, zipfile, io, os

# ---------- đọc file ----------

def load(path):
    """Nhận .epub thật (zip) hoặc file markdown/text đặt tên .epub."""
    raw = open(path, 'rb').read()
    if raw[:2] == b'PK':
        parts = []
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            for n in sorted(z.namelist()):
                if n.lower().endswith(('.xhtml', '.html', '.htm')):
                    html = z.read(n).decode('utf-8', 'ignore')
                    html = re.sub(r'<(script|style)[^>]*>.*?</\1>', ' ', html, flags=re.S | re.I)
                    html = re.sub(r'<[^>]+>', '\n', html)
                    parts.append(html)
        text = '\n'.join(parts)
        import html as H
        text = H.unescape(text)
    else:
        text = raw.decode('utf-8', 'ignore')
    return text.split('\n')

# ---------- chuẩn hóa ----------

def clean(s):
    s = re.sub(r'\]\([^)]*\)', ']', s)
    s = s.replace('[', '').replace(']', '').replace('**', '')
    return re.sub(r'\s+', ' ', s).strip()

def norm(s):
    s = unicodedata.normalize('NFC', s).lower()
    s = re.sub(r'[^\w ]', ' ', s)
    return re.sub(r'\s+', ' ', s).strip()

def fix_num(a, b, c=''):
    """5. 6 -> 5.6 · 1,5 -> 1.5 · 1.1. 0 -> 1.10"""
    return f'{a}.{b}{c}'

# ---------- định vị các bảng nguyên tắc ----------

MARK = {
    'life_table': 'TÓM TẮT VÀ BẢNG NGUYÊN TẮC SỐNG',
    'work_table': 'TÓM TẮT VÀ BẢNG NGUYÊN TẮC LÀM VIỆC',
}

def find(lines, needle, start=0, end=None, last=True):
    """Vị trí khớp `needle`. Mặc định lấy cái CUỐI — mục lục đầu file cũng khớp."""
    n = norm(needle)
    hits = [i for i in range(start, end if end is not None else len(lines))
            if n in norm(lines[i]) and len(lines[i]) < 120]
    if not hits:
        return None
    return hits[-1] if last else hits[0]

MID = re.compile(r'^(\d{1,2})[.,]\s?(\d{1,2})\s?[.,]?\s?(\d{0,2})\s*\.?\s*(.*)$')
SUB = re.compile(r'^([a-z])\s?\.\s*(.*)$')
TOP = re.compile(r'^(\d{1,2})\.?\s+(\S.{8,})$')

def parse_table(lines, lo, hi, max_gap=8):
    """Đọc bảng nguyên tắc -> (kind, num, title, chapter).

    Bảng là một dải liên tục các dòng dạng nguyên tắc. Gặp `max_gap` dòng liên tiếp
    không phải nguyên tắc thì coi như hết bảng — nếu không sẽ ăn luôn vào thân sách.
    """
    out, prev, chapter, gap, end = [], None, None, 0, hi
    for i in range(lo, hi):
        end = i
        s = clean(lines[i])
        if not s:
            continue
        if len(s) > 400:
            gap += 1
            if out and gap >= max_gap:
                break
            continue
        before = len(out)
        m = MID.match(s)
        if m and m.group(4):
            a, b, c, txt = m.groups()
            out.append(('mid', fix_num(a, b, c), txt.lstrip('. ').strip(), chapter))
            prev, gap = None, 0
            continue
        m = SUB.match(s)
        if m:
            out.append(('sub', m.group(1), m.group(2), chapter))
            prev, gap = m.group(1), 0
            continue
        if s.startswith('. ') and prev:              # 'c.' bị rụng chữ cái
            prev = chr(ord(prev) + 1)
            out.append(('sub', prev, s[2:], chapter))
            gap = 0
            continue
        m = TOP.match(s)
        if m and len(m.group(2)) > 8:
            chapter = f'{m.group(1)}. {m.group(2)}'
            out.append(('top', m.group(1), m.group(2), chapter))
            prev, gap = None, 0
            continue
        if s.startswith('•'):
            out.append(('bullet', '•', s[1:].strip(), chapter))
            prev = None
        if len(out) == before:
            gap += 1
            if out and gap >= max_gap:
                break
        else:
            gap = 0
    return out, end

# ---------- ghép thân nguyên tắc ----------

def attach_bodies(entries, lines, lo, hi):
    """Tìm mỗi tiêu đề trong thân sách, lấy văn bản tới tiêu đề kế tiếp."""
    body = [(i, clean(lines[i])) for i in range(lo, hi)]
    body = [(i, s) for i, s in body if s]
    nb = [(i, norm(s)) for i, s in body]

    anchors, used = {}, set()
    for idx, (kind, num, title, ch) in enumerate(entries):
        key = norm(title)[:45]
        if len(key) < 15:
            continue
        for i, ns in nb:
            if i in used:
                continue
            if key in ns:
                anchors[idx] = i
                used.add(i)
                break

    stops = sorted(anchors.values())
    out = []
    for idx, (kind, num, title, ch) in enumerate(entries):
        txt = ''
        if idx in anchors:
            start = anchors[idx]
            nxt = next((s for s in stops if s > start), hi)
            chunk = [s for i, s in body if start < i < nxt]
            txt = ' '.join(chunk)[:1400].strip()
        out.append((kind, num, title, ch, txt))
    return out

# ---------- main ----------

def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = sys.argv[1]
    lines = load(src)

    lt = find(lines, MARK['life_table'])
    wt = find(lines, MARK['work_table'], (lt or 0) + 1)
    if lt is None or wt is None:
        sys.exit('Không tìm thấy bảng nguyên tắc. Bản sách này có thể khác cấu trúc — '
                 'mở file kiểm tra thủ công.')

    life_tbl, _ = parse_table(lines, lt, wt)
    work_tbl, work_tbl_end = parse_table(lines, wt, len(lines))

    # Thân Phần II nằm TRƯỚC bảng tóm tắt Phần II; thân Phần III nằm SAU bảng Phần III.
    p2 = (find(lines, 'NGUYÊN LÝ CUỘC SỐNG', 0, lt)
          or find(lines, 'PHẦN II', 0, lt) or 0)
    life = attach_bodies(life_tbl, lines, p2, lt)
    work = attach_bodies(work_tbl, lines, work_tbl_end, len(lines))

    records, seen = [], set()
    for part, rows in (('life', life), ('work', work)):
        parent = ''                      # số hiệu nguyên tắc mẹ gần nhất
        for kind, num, title, ch, body in rows:
            if kind == 'top':
                parent = ''
                continue
            if kind == 'sub':
                pnum = f'{parent}{num}' if parent else num
                rid = f'{part}:{pnum}'
            elif kind == 'bullet':
                pnum = '•'
                rid = f'{part}:overview:{len(records)}'
            else:
                parent = num
                pnum = num
                rid = f'{part}:{num}'
            if rid in seen:
                rid += f'~{len(records)}'
            seen.add(rid)
            records.append({
                'id': rid,
                'part': 'Nguyên tắc sống' if part == 'life' else 'Nguyên tắc làm việc',
                'chapter': ch or '',
                'num': pnum,
                'title': title,
                'body': body,
                'has_body': bool(body),
            })

    os.makedirs('references', exist_ok=True)
    out = 'references/corpus.jsonl'
    with open(out, 'w', encoding='utf-8') as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + '\n')

    # index.md — menu tiêu đề để lướt chọn, sinh từ chính corpus
    with open('references/index.md', 'w', encoding='utf-8') as f:
        f.write('# Index nguyên tắc — menu để CHỌN\n\n'
                '> Chọn xong thì lấy nguyên văn từ `corpus.jsonl`. Đừng trích từ đây.\n')
        part = ch = None
        for r in records:
            if r['part'] != part:
                part = r['part']; ch = None
                f.write(f'\n## {part}\n')
            if r['chapter'] != ch:
                ch = r['chapter']
                if ch:
                    f.write(f'\n**{ch}**\n\n')
            mark = '' if r['has_body'] else ' ·no-body'
            f.write(f'- `{r["num"]}`{mark} {r["title"]}\n')

    wb = sum(1 for r in records if r['has_body'])
    print(f'{out}: {len(records)} nguyên tắc · {wb} có thân ({wb*100//len(records)}%) '
          f'· {os.path.getsize(out)//1024} KB')
    print('Nguyên tắc không có thân: trích tiêu đề — tiêu đề chính LÀ nguyên tắc, '
          'thân chỉ là phần Dalio diễn giải.')

if __name__ == '__main__':
    main()
