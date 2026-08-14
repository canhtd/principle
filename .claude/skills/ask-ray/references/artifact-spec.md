# Artifact spec — thẻ nguyên tắc

Artifact chỉ làm một việc: cho thấy **ca này là ca gì, nguyên tắc nào áp vào, áp ở đâu**.
Lời khuyên và hướng đi nằm ở đoạn text trong chat, **không nhét vào artifact**. Tách vậy
để artifact còn dùng lại được — nó là bản ghi nguyên tắc, không phải bản ghi câu trả lời.

Định dạng: **một file React `.jsx`** (claude.ai) hoặc HTML đơn file (Claude Code).
Mobile-first — dựng cho khung ~380px trước, desktop chỉ là nới ra.

---

## Cấu trúc

```
┌─────────────────────────────────┐
│  CHẨN ĐOÁN                      │  ← eyebrow, đỏ, chữ nhỏ in hoa
│  Ca lặp lại — vấn đề cỗ máy     │  ← tên kiểu ca, đậm
│  <1 câu vì sao xếp vào kiểu này>│
├─────────────────────────────────┤
│ ▌NGUYÊN TẮC SỐNG · 1.6          │  ← thẻ đen, nhãn đỏ + số hiệu
│  Đau đớn + Suy ngẫm = Tiến bộ   │  ← tiêu đề nguyên tắc, trắng đậm
│                                 │
│  "<nguyên văn từ sách, ≤40 từ>" │  ← xám nhạt
│                                 │
│  ÁP VÀO CA NÀY                  │  ← nhãn nhỏ
│  <1–2 câu bắc cầu>              │  ← trắng
├─────────────────────────────────┤
│ ▌… thẻ 2                        │
├─────────────────────────────────┤
│ ▌… thẻ 3 (tối đa 3)             │
├─────────────────────────────────┤
│  GIÁ TRỊ KỲ VỌNG   (tùy ca)     │  ← block tính toán, chỉ khi ca cần
└─────────────────────────────────┘
```

## Thẻ nguyên tắc — bắt buộc có

| Thành phần | Quy tắc |
|---|---|
| Nhãn | `NGUYÊN TẮC SỐNG` hoặc `NGUYÊN TẮC LÀM VIỆC` + số hiệu. Đỏ, in hoa, có thanh dọc đỏ bên trái |
| Tiêu đề | Nguyên văn tiêu đề nguyên tắc từ sách. Không viết lại |
| Trích | Nguyên văn thân nguyên tắc, cắt còn ≤40 từ. Cắt bằng `…`, không sửa chữ |
| Áp vào ca này | **Bắt buộc.** Không có phần này thì thẻ vô nghĩa — đó đúng là chỗ DigitalRay bỏ trống |

Thẻ mặc định **thu gọn** (nhãn + tiêu đề + dòng "áp vào ca"), chạm để mở phần trích.
Ba thẻ mở sẵn trên mobile là một bức tường chữ.

## Block tùy ca

Chỉ hiện khi Bước 3 thực sự dùng đến. Không có thì bỏ hẳn, đừng để khung rỗng.

- **Giá trị kỳ vọng** — bảng hai dòng: `Đúng: <xác suất> × <phần thưởng>` /
  `Sai: <xác suất> × <hình phạt>`, dòng cuối là EV. Đánh dấu rõ số nào là ước lượng.
- **Độ tin cậy** — danh sách người có ý kiến trong ca, kèm căn cứ tin (đã làm được việc
  này mấy lần) chứ không phải chức danh.
- **Bậc hai / bậc ba** — ba cột: hệ quả ngay → hệ quả sau → hệ quả sau nữa.

## Typography

**Sans-serif, lấy font mặc định của hệ điều hành.** Không webfont, không Google Fonts,
không serif. Serif đọc mệt trên màn nhỏ, và các face serif phổ biến (Georgia, Times) dựng
dấu tiếng Việt kém — `ườ`, `ẵ` hay lệch hoặc rơi sang font khác giữa câu. Font hệ thống
(SF Pro / Roboto / Segoe UI) đều là sans-serif và có bộ dấu tiếng Việt đầy đủ.

```css
--font: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto,
        "Helvetica Neue", Arial, sans-serif;
```

Tailwind: `font-sans` đã trỏ đúng stack này. Đừng đụng vào.

### Giãn dòng — chỗ dễ hỏng nhất với tiếng Việt

Dấu tiếng Việt ăn cả trên lẫn dưới dòng chữ. Giãn dòng kiểu tiếng Anh (1.3–1.4) làm dấu
huyền dòng dưới chạm dấu nặng dòng trên. Sàn tối thiểu:

| Vai trò | line-height | Tailwind |
|---|---|---|
| Tiêu đề nguyên tắc | **1.35** | `leading-snug` |
| Phần trích + phần áp vào ca | **1.7** | `leading-relaxed` |
| Nhãn, caption | 1.4 | `leading-tight` |

Không bao giờ dùng `leading-none` / `leading-tight` cho câu tiếng Việt dài hơn một dòng.

### Độ đậm

Tiêu đề nguyên tắc **để đậm** (600) — đúng như bản tham chiếu DigitalRay. Đây là thứ
người ta quét mắt qua đầu tiên.

Bù lại thì mọi thứ khác phải im: trong mỗi thẻ chỉ có **tiêu đề và nhãn đỏ** được 600,
phần còn lại 400. Không dùng 700+ ở đâu cả. Phân cấp giữa các phần 400 làm bằng cỡ và màu.

| Thành phần | Cỡ | Đậm | Màu |
|---|---|---|---|
| Nhãn phần + số hiệu | 11px, `tracking-wide`, in hoa | 600 | đỏ `#E8332A` |
| Tiêu đề nguyên tắc | `clamp(18px, 4.6vw, 22px)`, `tracking-[-0.01em]` | **600** | trắng |
| Phần trích | `clamp(14px, 3.7vw, 15px)` | 400 | `#9A9A9A` |
| Nhãn "Áp vào ca này" | 10px, in hoa | 600 | `#6E6E6E` |
| Nội dung áp vào ca | `clamp(14px, 3.7vw, 15px)` | 400 | `#E4E4E4` |

Chữ càng lớn thì tracking càng phải âm nhẹ — mặc định của font hệ thống là dựng cho cỡ
body, để nguyên ở 22px trông rời rạc.

### Bề rộng dòng

Tiếng Việt nhiều từ hai âm tiết, dòng dài đọc mệt hơn tiếng Anh. Chặn `max-w-[62ch]` cho
mọi khối văn bản. Trên desktop thẻ **không** giãn hết chiều ngang — container `max-w-2xl`,
căn giữa.

## Responsive

Mobile-first thật, không phải "dựng ở 380px rồi thôi":

| Ngưỡng | Thay đổi |
|---|---|
| < 480px | Một cột. Padding thẻ `16px`. Nhãn và số hiệu xuống dòng riêng nếu chật |
| ≥ 480px | Padding thẻ `20px`. Nhãn + số hiệu cùng dòng |
| ≥ 768px | Container `max-w-2xl` căn giữa. Block phụ (EV, độ tin cậy) chuyển sang lưới 2 cột |
| ≥ 1024px | Không đổi gì thêm. Đọc là đọc, không cần rộng hơn |

Cỡ chữ dùng `clamp()` để trôi mượt giữa các ngưỡng thay vì nhảy bậc.
Vùng chạm ≥ 44px. Kiểm bằng cách thu cửa sổ xuống 320px — không được tràn ngang.

## Ngôn ngữ hình

Hướng thị giác lấy từ DigitalRay (ảnh tham chiếu người dùng đưa) — bám sát, đây là brief
chứ không phải mặc định:

- Nền trang trong suốt / trắng ngà. Thẻ nguyên tắc **đen đặc** (`#0A0A0A`), bo góc lớn (~20px).
- Nhãn đỏ (`#E8332A`), luôn đi kèm thanh dọc đỏ 3px bên trái.
- Chữ trong thẻ: trắng cho tiêu đề, `#A0A0A0` cho phần trích.
- Header chẩn đoán để nền sáng, tương phản với dãy thẻ đen bên dưới.
- Không icon. Không emoji. Không gradient. Không progress bar trang trí.

Chỗ duy nhất được phép mạnh tay: **cách xử lý số hiệu nguyên tắc** — nó là thứ mã hóa
thông tin thật (nguyên tắc này ở đâu trong hệ thống), nên cho nó có mặt rõ ràng.
Mọi thứ còn lại giữ im lặng.

## Ràng buộc kỹ thuật

- **Artifact không có Tailwind compiler.** Chỉ class có sẵn trong base stylesheet mới ăn.
  Mọi arbitrary value — `bg-[#0A0A0A]`, `text-[15px]`, `max-w-[62ch]`, `leading-[1.7]` —
  rơi im lặng, không báo lỗi. Thẻ mất nền đen mà `text-white` vẫn ăn = **trắng trên
  trắng, mở ra không thấy gì**. Đây là lỗi đã thực sự xảy ra một lần.
- Cách an toàn: màu, cỡ chữ, khoảng cách đi bằng **inline `style`**; `className` chỉ dùng
  cho media query trong thẻ `<style>`. Xem `references/example-artifact.jsx`.
- Không import webfont, không `<link>` tới Google Fonts. Khai `fontFamily` bằng stack hệ
  điều hành trực tiếp trong style.
- Tự kiểm trước khi gửi: `grep -c '\-\[' file.jsx` phải ra 0.
- **Không dùng `localStorage` / `sessionStorage`** — hỏng trong artifact claude.ai.
  State giữ trong `useState`.
- Không `<form>` trong React artifact. Dùng `onClick` / `onChange`.
- Không props bắt buộc; `export default`.
- Chạm được: vùng bấm ≥44px. Tôn trọng `prefers-reduced-motion`.

## Mẫu tham chiếu

`references/example-artifact.jsx` — bản dựng thật đúng theo spec này. Đọc nó trước khi
viết mới; sửa nội dung nhanh hơn dựng lại từ đầu.

## Không làm

- Không đưa lời khuyên vào artifact — nó thuộc về đoạn text.
- Không hơn 3 thẻ.
- Không thẻ nào thiếu phần "Áp vào ca này".
- Không diễn giải lại nguyên tắc bằng lời khác rồi để trong ngoặc kép.
