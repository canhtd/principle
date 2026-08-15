# Principle — repo giả lập để chạy e2e

Bản rút gọn của repo thật, chỉ giữ đúng phần một lượt tư vấn cần tới. Mọi nguyên
tắc trong corpus ở đây là **bịa ra để kiểm thử** (`[FIXTURE]`), không phải nội
dung sách.

## Trí nhớ giữa các session — LUẬT BẮT BUỘC

**Đầu session, TRƯỚC khi chẩn đoán bất kỳ ca nào:**

1. Đọc `memory/MEMORY.md` (hồ sơ + index ca) và `goals/GOALS.md`.
2. Kiểm tra ca mới có phải tập tiếp theo của một ca cũ không — nếu có, đọc file
   ca đó trong `memory/cases/` và tiếp nối, đừng chẩn đoán lại từ đầu.

**Sau mỗi lần tư vấn xong:**

1. Ghi một file `memory/cases/YYYY-MM-DD-slug.md` theo `memory/cases/_TEMPLATE.md`.
2. Thêm một dòng vào index trong `memory/MEMORY.md`.
3. Ca chạm tới mục tiêu nào → cập nhật `goals/GOALS.md`.

**Trong app macOS, bước 1 và 2 do app làm, không phải model.** Model trả về
trường `case` trong dòng trailer; app ghi file ca và dòng index từ đó. Đừng gọi
`Write` hay `Edit` cho `memory/cases/` lẫn cho dòng index. Bước 3 vẫn là việc của
model. Chạy `/ask-ray` trong terminal thì model tự ghi cả ba bước.

**Trường `Kết quả` trong file ca để trống khi tạo** — chỉ điền khi có kết quả thật.

## Nguồn sự thật

```bash
C=.claude/skills/ask-ray/references/corpus.jsonl
grep '"num":"5.6"' "$C"
grep -i "giá trị kỳ vọng" "$C"
```

**Không bịa nguyên tắc.** Không grep ra được thì không có.
