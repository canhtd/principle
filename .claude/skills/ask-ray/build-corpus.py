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

Cách ghép thân: bảng tóm tắt trong epub là danh sách LIÊN KẾT, mỗi mục trỏ tới
đúng đoạn thân của nó (`href="...#id_p2c4lev2se5"`). Bám theo neo id đó thay vì
dò khớp chữ, vì tiêu đề trong bảng và tiêu đề trong thân sách nhiều chỗ dịch
lệch nhau — dò chữ sẽ trượt, và mục trượt bị nuốt vào thân của mục liền trước.
"""
import json, re, sys, unicodedata, zipfile, io, os
import html as H

# ---------- đọc file: giữ khối + neo id thay vì bẻ phẳng ra dòng ----------

BLOCK = re.compile(r'<(/?)(?:p|div|h[1-6]|li|blockquote|section|td|tr)\b([^>]*?)/?>', re.I)
SPAN = re.compile(r'<span\b[^>]*>(.*?)</span>', re.S | re.I)
ID_ATTR = re.compile(r'\bid\s*=\s*"([^"]+)"', re.I)
HREF_ID = re.compile(r'\bhref\s*=\s*"[^"]*#([^"]+)"', re.I)


def flat(s):
    return re.sub(r'\s+', ' ', H.unescape(re.sub(r'<[^>]+>', ' ', s))).strip()


def block(file, attrs, inner):
    i, h = ID_ATTR.search(attrs), HREF_ID.search(inner)
    return {'file': file,
            'id': i.group(1) if i else None,
            'href': h.group(1) if h else None,
            'text': flat(inner),
            'spans': [t for t in (flat(x) for x in SPAN.findall(inner)) if t]}


def html_blocks(file, html):
    """Một khối = văn bản giữa một thẻ block và thẻ block kế tiếp.

    Không đệ quy nên khối lồng nhau (`<div><div id=...>`) vẫn ra riêng — chỗ này
    quan trọng: nguyên tắc cấp `X.Y` nằm trong div lồng, bắt hụt là mất neo.
    """
    html = re.sub(r'<(script|style)[^>]*>.*?</\1>', ' ', html, flags=re.S | re.I)
    out, attrs, pos = [], None, 0
    for m in BLOCK.finditer(html):
        if attrs is not None:
            out.append(block(file, attrs, html[pos:m.start()]))
        attrs = None if m.group(1) else m.group(2)
        pos = m.end()
    if attrs is not None:
        out.append(block(file, attrs, html[pos:]))
    return [b for b in out if b['text']]


def load(path):
    """Nhận .epub thật (zip) hoặc file markdown/text đặt tên .epub."""
    raw = open(path, 'rb').read()
    if raw[:2] == b'PK':
        out = []
        with zipfile.ZipFile(io.BytesIO(raw)) as z:
            for n in sorted(z.namelist()):
                if n.lower().endswith(('.xhtml', '.html', '.htm')):
                    out += html_blocks(n, z.read(n).decode('utf-8', 'ignore'))
        return out
    return [{'file': path, 'id': None, 'href': None, 'text': t, 'spans': []}
            for t in (clean(l) for l in raw.decode('utf-8', 'ignore').split('\n')) if t]

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

MID = re.compile(r'^(\d{1,2})[.,]\s?(\d{1,2})\s?[.,]?\s?(\d{0,2})\s*\.?\s*(.*)$')
SUB = re.compile(r'^([a-z])\s?\.\s*(.*)$')
TOP = re.compile(r'^(\d{1,2})\.?\s+(\S.{8,})$')
# số hiệu đứng riêng một span: '1.1. ' · '1.6. .' · '10. 3' · '.1. ' (rụng chữ số) · 'a. '
# nhận diện bằng "chỉ có chữ số và dấu chấm", không liệt kê từng biến thể — epub này
# tách span rất tùy tiện, liệt kê kiểu nào cũng sót.
NUMONLY = re.compile(r'^(?=[^A-Za-z]*$)(?=.*[.,])[\d.,\s]{1,10}$|^[a-z]\.\s*$')
# dòng mở đầu bằng số hiệu -> là tiêu đề, không phải văn xuôi
HEAD = re.compile(r'^(?:\d{1,2}[.,]\s?\d{1,2}[.,]?|[a-z]\.)\s')


def find(blocks, needle, start=0, end=None):
    """Vị trí bảng nguyên tắc thật. Mục lục / nav cũng khớp tên bảng, nên chấm
    điểm ứng viên bằng số mục dạng nguyên tắc ngay sau nó rồi lấy cái cao nhất."""
    n = norm(needle)
    hi = end if end is not None else len(blocks)
    best, score = None, 0
    for i in range(start, hi):
        if n not in norm(blocks[i]['text']) or len(blocks[i]['text']) > 120:
            continue
        s = sum(1 for b in blocks[i + 1:i + 60] if SUB.match(b['text']))
        if s >= score:
            best, score = i, s
    return best


def parse_table(blocks, lo, hi, max_gap=8):
    """Đọc bảng nguyên tắc -> (kind, num, title, chapter, href).

    Bảng là một dải liên tục các mục dạng nguyên tắc. Gặp `max_gap` khối liên tiếp
    không phải nguyên tắc, hoặc sang file khác, thì coi như hết bảng — nếu không
    sẽ ăn luôn vào thân sách.
    """
    out, prev, chapter, gap, end = [], None, None, 0, hi
    file = blocks[lo]['file'] if lo < len(blocks) else None
    for i in range(lo, hi):
        end = i
        b = blocks[i]
        if out and b['file'] != file:
            break
        s, href = b['text'], b['href']
        if len(s) > 400:
            gap += 1
            if out and gap >= max_gap:
                break
            continue
        before = len(out)
        m = MID.match(s)
        if m and m.group(4):
            a, x, c, txt = m.groups()
            out.append(('mid', fix_num(a, x, c), txt.lstrip('. ').strip(), chapter, href))
            prev, gap = None, 0
            continue
        m = SUB.match(s)
        if m:
            out.append(('sub', m.group(1), m.group(2), chapter, href))
            prev, gap = m.group(1), 0
            continue
        if s.startswith('. ') and prev:              # 'c.' bị rụng chữ cái
            prev = chr(ord(prev) + 1)
            out.append(('sub', prev, s[2:], chapter, href))
            gap = 0
            continue
        m = TOP.match(s)
        if m and len(m.group(2)) > 8:
            txt = m.group(2).lstrip('. ').strip()   # '16. . Và vì Chúa' -> bỏ dấu chấm thừa
            chapter = f'{m.group(1)}. {txt}'
            out.append(('top', m.group(1), txt, chapter, href))
            prev, gap = None, 0
            continue
        if s.startswith('•'):
            out.append(('bullet', '•', s[1:].strip(), chapter, href))
            prev = None
        if len(out) == before:
            gap += 1
            if out and gap >= max_gap:
                break
        else:
            gap = 0
    return out, end

# ---------- ghép thân nguyên tắc ----------


def is_head(b):
    return bool(HEAD.match(b['text'])) or bool(b['spans'] and NUMONLY.match(b['spans'][0]))


def strip_head(b):
    """Bỏ tiêu đề ở đầu khối thân, giữ lại phần Dalio diễn giải."""
    sp = b['spans']
    if not sp:
        return b['text']
    if NUMONLY.match(sp[0]):                 # span đầu chỉ là số hiệu, span sau là tiêu đề
        i = 2
    elif HEAD.match(sp[0]):                  # span đầu là cả tiêu đề
        i = 1
    else:
        return b['text']
    while i < len(sp) and re.fullmatch(r'[.,;:]', sp[i]):   # dấu kết tiêu đề bị tách span riêng
        i += 1
    return ' '.join(sp[i:]).strip()


def marker_of(b):
    """Số hiệu mà chính khối thân tự khai ở đầu: 'b' · '1.5' · None."""
    m = SUB.match(b['text'])
    if m:
        return m.group(1)
    m = MID.match(b['text'])
    return fix_num(m.group(1), m.group(2), m.group(3)) if m and m.group(4) else None


def realign(i, num, blocks, span=8):
    """Neo id trong epub lệch một nấc ở vài chỗ (mục `a.` trỏ vào đoạn của `b.`).
    Lấy khối gần `i` nhất mà số hiệu tự khai đúng bằng `num`."""
    lo, hi = max(0, i - span), min(len(blocks), i + span + 1)
    near = sorted(range(lo, hi), key=lambda j: abs(j - i))
    return next((j for j in near if marker_of(blocks[j]) == num), i)


def attach_bodies(entries, blocks, lo, hi):
    """Neo mỗi mục vào đoạn thân của nó, lấy văn bản tới tiêu đề kế tiếp."""
    byid = {b['id']: i for i, b in enumerate(blocks) if b['id']}
    anchors, used = {}, set()
    for idx, (kind, num, title, ch, href) in enumerate(entries):
        i = byid.get(href)
        mk = marker_of(blocks[i]) if i is not None else None
        if i is not None and kind in ('sub', 'mid') and mk != num:
            j = realign(i, num, blocks)       # chỉ chỉnh khi neo trỏ sai số hiệu
            if j != i and j not in used:
                i = j
            elif kind == 'sub' and mk and len(mk) == 1:
                i = None                      # neo trỏ nhầm sang mục khác cùng dãy chữ cái
            # số hiệu lệch kiểu '2.1' vs '12.1' là lỗi đánh số của chính bảng — vẫn tin neo
        if i is None or i in used:            # dự phòng: bản text, link hỏng, link trùng
            key = norm(title)[:45]
            if len(key) < 15:
                continue
            i = next((j for j in range(lo, hi)
                      if j not in used and key in norm(blocks[j]['text'])), None)
        if i is None or i in used:
            continue
        anchors[idx] = i
        used.add(i)

    # mọi tiêu đề đều chặn thân của mục trước — kể cả tiêu đề không mục nào neo tới
    stops = sorted(set(anchors.values()) | set(byid[h] for h in
                   (e[4] for e in entries) if h in byid)
                   | {i for i, b in enumerate(blocks) if is_head(b)})
    out = []
    for idx, (kind, num, title, ch, href) in enumerate(entries):
        txt = ''
        if idx in anchors:
            start = anchors[idx]
            nxt = next((s for s in stops if s > start), len(blocks))
            file = blocks[start]['file']
            chunk = [strip_head(blocks[start])]
            chunk += [b['text'] for b in blocks[start + 1:nxt] if b['file'] == file]
            txt = ' '.join(x for x in chunk if x)[:1400].strip()
        out.append((kind, num, title, ch, txt))
    return out

# ---------- main ----------


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = sys.argv[1]
    blocks = load(src)

    lt = find(blocks, MARK['life_table'])
    wt = find(blocks, MARK['work_table'], (lt or 0) + 1)
    if lt is None or wt is None:
        sys.exit('Không tìm thấy bảng nguyên tắc. Bản sách này có thể khác cấu trúc — '
                 'mở file kiểm tra thủ công.')

    life_tbl, _ = parse_table(blocks, lt, wt)
    work_tbl, work_tbl_end = parse_table(blocks, wt, len(blocks))

    # Thân Phần II nằm TRƯỚC bảng tóm tắt Phần II; thân Phần III nằm SAU bảng Phần III.
    p2 = (find(blocks, 'NGUYÊN LÝ CUỘC SỐNG', 0, lt)
          or find(blocks, 'PHẦN II', 0, lt) or 0)
    life = attach_bodies(life_tbl, blocks, p2, lt)
    work = attach_bodies(work_tbl, blocks, work_tbl_end, len(blocks))

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

    here = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'references')
    os.makedirs(here, exist_ok=True)
    out = os.path.join(here, 'corpus.jsonl')
    with open(out, 'w', encoding='utf-8') as f:
        for r in records:
            f.write(json.dumps(r, ensure_ascii=False) + '\n')

    # index.md — menu tiêu đề để lướt chọn, sinh từ chính corpus
    with open(os.path.join(here, 'index.md'), 'w', encoding='utf-8') as f:
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
