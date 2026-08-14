# Concept

## Vấn đề

Đọc *Principles* xong thì nhớ được vài câu, nhưng lúc cần quyết định thì không tra
được nguyên tắc nào. Sách nằm một chỗ, quyết định xảy ra chỗ khác.

Và cái bẫy lớn hơn: hỏi model về Dalio thì nó viết ra thứ **nghe hệt Dalio mà sách
không hề có**. Lời khuyên chung chung được dán nhãn nguyên tắc.

## Giải pháp

Tách sách thành corpus tra được, rồi bắt buộc mọi câu trả lời phải grep ra được từ
đó. Không grep ra thì không có nguyên tắc đó.

```
sách (.epub)
   ↓ build-corpus.py — bỏ Phần I hồi ký, chuẩn hóa số hiệu
corpus.jsonl — 515 dòng, mỗi dòng {id, part, chapter, num, title, body, has_body}
   ↓ router.md — 14 kiểu ca → cụm nguyên tắc
SKILL.md — 4 bước
   ↓
artifact thẻ nguyên tắc + đoạn text định hướng
```

## Bốn bước của ask-ray

1. **Chẩn đoán trước khi mở sách.** Viết lại vấn đề một câu → tách vấn đề thật khỏi
   vấn đề được kể → xác định đang hỏi bằng não nào (`5.5`) → phân loại ca.
   Bỏ bước này là hỏng cả câu trả lời. `5.9`: mọi ca chỉ là "một trong những ca kiểu đó".
2. **Tra nguyên tắc.** Tối đa 3. Năm nguyên tắc nghĩa là chưa chẩn đoán xong.
   Ưu tiên nguyên tắc con (`5.6a`) hơn nguyên tắc mẹ.
3. **Áp vào ca cụ thể.** Mỗi nguyên tắc một dòng: nó cắt vào tình huống này ở đâu.
   Không diễn giải lại nguyên tắc — người ta đọc được. Cái họ không tự làm được là bắc cầu.
4. **Output.** Artifact thẻ nguyên tắc + đoạn text 4 ý: đây là ca gì / nên làm gì
   tuần này / cái giá phải trả / điều gì làm đổi câu trả lời.

## Quyết định thiết kế đã chốt

| Chọn | Vì sao |
|---|---|
| JSONL chứ không để nguyên sách | một dòng = một nguyên tắc trọn vẹn, grep ra dùng được ngay, không phải đọc quanh |
| Bỏ Phần I | hồi ký, ~40% sách, skill không dùng tới |
| Chuẩn hóa số hiệu lúc build | `5. 6` → `5.6`, `1,5` → `1.5`; số trùng tách bằng hậu tố `~n` |
| `has_body: false` vẫn giữ | 267/515 mục chỉ có tiêu đề trong bảng tóm tắt — tiêu đề chính LÀ nguyên tắc |
| Tối đa 3 nguyên tắc | `5.8` đơn giản hóa; một nguyên tắc trúng đích thắng ba cái chung chung |
| Skill không kèm sách khi chia sẻ | bản dịch có bản quyền; người nhận tự build |

## Bài học đã trả giá

- **Tailwind arbitrary values im lặng rơi trong artifact runtime.** `bg-[#0A0A0A]`
  không compile → chữ trắng trên nền trắng, chỉ phát hiện khi mở trên mobile.
  Chuyển hết sang inline style.
- **File `.epub` không phải zip.** Bản đang dùng là markdown UTF-8 đặt tên `.epub`.
  `build-corpus.py` nhận cả hai.
- **Zip cài Desktop phải có thư mục gốc trùng `name:` frontmatter**, không thì
  không nhận.

## Lộ trình

**Đang mở**

- Nối `memory/cases/` vào app Decision Journal — vòng lặp đã đóng ở mức file
  (từ 2026-08-14, xem `CLAUDE.md` phần "Trí nhớ giữa các session"), app chưa nối.
- Ba ca đầu (bỏ thuốc lá, unknown unknowns, mục tiêu rõ ràng) chạy trước khi có
  memory nên nội dung không được lưu — chỉ còn tên trong `memory/MEMORY.md`.

**Đã chốt trước đó** (verdict từ `ask-fable`): CONDITIONAL GO — cài ngay, chạy đủ
3 ca thật rồi mới sửa tiếp. Điều kiện lật: sau 3 ca mà không quyết định nào khác đi
thì skill không tạo giá trị, dừng đầu tư.
→ Đã chạy 3 ca (bỏ thuốc lá, unknown unknowns, mục tiêu rõ ràng). Điều kiện lật
chưa kích hoạt.

**Nhánh thứ hai — Decision Journal**

Đã gộp vào `apps/decision-journal/`. Chi tiết ở `apps/decision-journal/CONCEPT.md`.

Chỗ nối hai nhánh: `ask-ray` sinh ra quyết định, Decision Journal ghi lại và chấm
điểm kết quả. Ghi được kết quả thì mới đóng được vòng lặp — hiện tại vòng lặp hở.
