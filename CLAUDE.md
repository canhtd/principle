# Principle

Hệ ra quyết định dựa trên *Principles* — Ray Dalio (bản dịch tiếng Việt).
Không phải app đọc sách. Là cỗ máy: chẩn đoán ca → tra nguyên tắc gốc → áp vào
tình huống cụ thể → chốt hướng đi → **ghi lại để lần sau không bắt đầu từ số 0**.

## Bố cục

```
.claude/skills/ask-ray/     skill chính — cố vấn ra quyết định mọi vấn đề
memory/                     trí nhớ giữa các session — hồ sơ + ca đã hỏi
goals/GOALS.md              mục tiêu đang theo
rules/                      quy tắc dùng chung mà SKILL.md trỏ tới
apps/decision-journal/      app React ghi quyết định theo vòng lặp 5.1→5.11
docs/concept.md             concept gốc + lộ trình
```

## Trí nhớ giữa các session — LUẬT BẮT BUỘC

Vấn đề gốc: mỗi session trước đây bắt đầu trắng, hỏi xong là mất. Ba file dưới
đây là cách đóng vòng lặp. **Skill giữ nguyên tính portable — mọi logic trí nhớ
nằm ở đây, không nhét vào SKILL.md.**

**Đầu session, TRƯỚC khi chẩn đoán bất kỳ ca nào** (`/ask-ray`, hoặc anh Danny
kể một vấn đề):

1. Đọc `memory/MEMORY.md` (hồ sơ + index ca) và `goals/GOALS.md`.
2. Kiểm tra ca mới có phải tập tiếp theo của một ca cũ không — nếu có, đọc file
   ca đó trong `memory/cases/` và tiếp nối, đừng chẩn đoán lại từ đầu.
3. Hai file trên là bộ nhớ của việc **tư vấn**. Việc **dựng app** đọc `STATE.md`
   ở gốc repo — điểm nối lại của mọi session build: đang ở đâu, xong gì, bước
   kế. Vào session code thì đọc nó trước tiên, và ghi thêm mục mới ở cuối mỗi
   khi cột mốc dịch chuyển.

**Sau mỗi lần tư vấn xong:**

1. Ghi một file `memory/cases/YYYY-MM-DD-slug.md` theo `memory/cases/_TEMPLATE.md`.
2. Thêm một dòng vào index trong `MEMORY.md`.
3. Ca chạm tới mục tiêu nào → cập nhật `goals/GOALS.md` (tiến độ, hoặc thêm goal
   mới nếu anh xác nhận).
4. Lộ ra điều mới về con người / hoàn cảnh anh Danny → cập nhật phần hồ sơ
   trong `MEMORY.md`.

**Khi anh nói "review" / "review goals":** đối chiếu các ca đang mở — điều kiện
lật đã kích hoạt chưa, follow-up đến hạn chưa, goal nào đứng yên quá lâu. Đây
chính là bước suy ngẫm của `1.7` (đau + suy ngẫm = tiến bộ).

**Trường `Kết quả` trong file ca để trống khi tạo** — chỉ điền khi có kết quả
thật. Không suy diễn kết quả từ việc đã đưa lời khuyên.

**Trong app macOS, bước 1 và 2 do app làm, không phải model.** Model đọc memory
(app đã cấp sẵn) rồi trả về trường `case` trong dòng trailer; app ghi file ca và
dòng index từ đó, cùng định dạng trên. Soạn file bằng `Write` từng tốn ~29 giây
của một lượt trước khi chữ đầu tiên của câu trả lời kịp ra. Bước 3 và 4 vẫn là
việc của model. Chạy `/ask-ray` trong terminal thì giao thức trên giữ nguyên
từng chữ — model tự ghi cả bốn bước.

## Nguồn sự thật

`.claude/skills/ask-ray/references/corpus.jsonl` — 513 nguyên tắc, mỗi dòng một
nguyên tắc trọn vẹn. **Đây là thứ được tra, không phải file sách.** File `.epub`
chỉ cần khi dựng lại corpus.

```bash
C=.claude/skills/ask-ray/references/corpus.jsonl
grep '"num": "5.6"' "$C"   # JSONL ghi có khoảng trắng sau dấu hai chấm
grep -i "giá trị kỳ vọng" "$C"
```

Dựng lại khi cần: `python3 .claude/skills/ask-ray/build-corpus.py /duong/dan/Principles.epub`

## Luật cứng khi làm việc trong repo này

- **Không bịa nguyên tắc.** Không grep ra được thì không có. Model rất giỏi viết
  câu nghe hệt Dalio mà sách không hề có.
- **492/513 nguyên tắc có `has_body: true`.** Phần còn lại chỉ có tiêu đề — tiêu
  đề chính LÀ nguyên tắc, đừng bịa thân bài để lấp chỗ trống.
- **Không commit `corpus.jsonl` / `index.md` lên repo công khai.** Bản dịch có
  bản quyền. `.gitignore` đã chặn sẵn — đừng gỡ.
- **`memory/` và `goals/` là dữ liệu cá nhân** — nếu repo có remote công khai,
  phải vào `.gitignore` trước khi push.
- **Tiếng Việt** theo `rules/vietnamese.md`.
- **Bản canonical của skill là `.claude/skills/` trong repo này.** Sửa skill thì
  sửa ở đây rồi đồng bộ ra bản cài global (`~/.claude/skills/`) và zip Desktop —
  đừng sửa lệch từng bản.

## Trạng thái

| Phần | Trạng thái |
|---|---|
| corpus + router + SKILL.md | xong, đã chạy thật 3 ca |
| artifact spec | xong, đã sửa lỗi Tailwind arbitrary values |
| `rules/vietnamese.md`, `rules/model-delegation.md` | có nội dung thật, bổ sung dần |
| memory + goals | dựng 2026-08-14 — 3 ca cũ chưa được ghi lại nội dung |
| Decision Journal | prototype trong `apps/`, 6 lỗi đã biết ghi ở `CONCEPT.md` |
| Nối ask-ray ↔ Journal | vòng lặp đã đóng ở mức file (`memory/cases/`); app Journal chưa nối |

## Agent skills

### Issue tracker

Issues and specs live in this repo's GitHub Issues (via `gh`). See `docs/agents/issue-tracker.md`.

### Domain docs

Single-context: one `CONTEXT.md` at the repo root + `docs/adr/`. See `docs/agents/domain.md`.
