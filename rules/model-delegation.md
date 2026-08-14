# Model delegation

> Stub. `ask-ray/SKILL.md` và `ask-fable/SKILL.md` đều trỏ tới file này nhưng
> trước đó nó chưa tồn tại. Nội dung dưới là phần đã nói rõ trong hai SKILL.md,
> viết lại một chỗ. Bổ sung thêm nếu cần.

## Ai trả lời việc gì

| Loại quyết định | Skill | Model |
|---|---|---|
| Vấn đề đời sống / công việc / con người | `ask-ray` | Fable 5 |
| Go/no-go sản phẩm, positioning, ưu tiên | không skill — hỏi thẳng (đang chạy Fable trực tiếp; skill ask-fable đã gỡ 2026-08-14) | Fable 5 |
| Kỹ thuật, kiến trúc, chọn stack, sửa code | không skill | model đang chạy |

## Quy tắc

- **Phiên đang chạy Fable** → trả lời trực tiếp.
- **Chạy model khác + có Agent tool** → thu thập ngữ cảnh, delegate sang Fable
  (`model: fable`, `subagent_type: general-purpose`) với brief tự chứa. Trả về
  nguyên phán đoán của Fable, không viết đè.
- **Không có Agent tool** (claude.ai) → nói rõ một dòng ở đầu là đang chạy model
  khác, chất lượng thấp hơn, rồi vẫn chạy đủ khung.
- Không để model rẻ hơn giả làm phán đoán của Fable mà không khai báo.

## Ghi chú

Quyết định kỹ thuật không đi qua skill nào. Đừng ép nó vào khung Dalio — nguyên
tắc trong sách nói về người và cược, không nói về chọn database.
