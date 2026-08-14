# Principle

## Cài vào Claude Code

Clone/copy thư mục này rồi mở bằng Claude Code. Skill trong `.claude/skills/`
được nạp tự động, gọi bằng `/ask-ray`.

## Cài vào Claude Desktop

Skill Desktop cần zip riêng từng cái, **thư mục gốc trong zip phải trùng `name:`
ở frontmatter**:

```bash
cd .claude/skills && zip -r ../../dist/ask-ray.zip ask-ray
```

## Corpus

`references/corpus.jsonl` đi kèm sẵn (bản cá nhân). Nếu mất hoặc muốn dựng lại:

```bash
python3 lib/build-corpus.py ~/books/VIE_-_Principles_-_Dalio__Ray-update_V1.epub
```

Script nhận cả `.epub` thật (zip) lẫn file markdown đặt tên `.epub` — bản đang
dùng thuộc loại thứ hai.

## Khi chia sẻ cho người khác

Bỏ `corpus.jsonl` và `index.md` ra khỏi zip. Người nhận tự chạy `build-corpus.py`
trên bản sách của họ.
