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

## App macOS

App chat riêng, vẫn dùng Claude Code làm engine: hỏi ca, thấy thẻ nguyên tắc, ca
được ghi vào `memory/cases/` y như khi gọi `/ask-ray` trong terminal.

Khác một chỗ: file ca và dòng index trong `memory/MEMORY.md` do **app** ghi, lấy
từ cùng dòng trailer mà nó đã dùng để dựng thẻ. Model chỉ nghĩ và trả lời — nó
không mở `Write` cho hai chỗ đó nữa, vì soạn file bằng tay từng ăn mất ~29 giây
đầu mỗi lượt. Định dạng file vẫn theo `memory/cases/_TEMPLATE.md`, nên bản
terminal đọc tiếp được bình thường.

```bash
cd apps/mac && swift run        # chạy thẳng lúc đang sửa code
apps/mac/scripts/make-app.sh    # dựng Principle.app vào ~/Applications
```

UI của app bằng tiếng Anh; nội dung Ray trả lời vẫn tiếng Việt. Trong **Settings**
(⌘,): **Response Model**, **Repo Folder** (nơi ghi phiên và ca), và đường dẫn
`claude` — để trống thì app tự tìm.

Kiểm tra vòng lặp có chạy thật không:

```bash
apps/mac/Tests/E2E/e2e-smoke.sh
```

Chạy một ca thật trên repo giả lập tách biệt, tốn đúng 2 lượt haiku, không đụng
vào `memory/` thật.

## Corpus

`references/corpus.jsonl` đi kèm sẵn (bản cá nhân). Nếu mất hoặc muốn dựng lại:

```bash
python3 .claude/skills/ask-ray/build-corpus.py ~/books/VIE_-_Principles_-_Dalio__Ray-update_V1.epub
```

Script nhận cả `.epub` thật (zip) lẫn file markdown đặt tên `.epub` — bản đang
dùng thuộc loại thứ hai.

## Khi chia sẻ cho người khác

Bỏ `corpus.jsonl` và `index.md` ra khỏi zip. Người nhận tự chạy `build-corpus.py`
trên bản sách của họ.
