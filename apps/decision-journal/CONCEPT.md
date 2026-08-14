# Decision Journal — concept

## Vấn đề

`ask-ray` trả lời được "nên làm gì". Nhưng hỏi xong là mất. Không ai biết quyết định
đó đúng hay sai, và lần sau vẫn hỏi lại từ đầu.

Dalio không dạy quyết định giỏi hơn bằng ý chí. Ông dạy xây một cỗ máy để chất lượng
quyết định **tăng dần**. Cỗ máy đó cần một thứ mà con người không tự làm nổi: ghi lại
tiêu chí **trước khi** biết kết quả. Ghi sau thì trí nhớ đã tự sửa để mình đúng.

## Vòng lặp cộng dồn (5.1 → 5.11)

```
5.1   bình tĩnh trước đã          → emotion check
5.2a  học trước, hỏi người đáng tin → learn before deciding
5.6   mọi quyết định là một vụ cược → EV calculator
5.9   ghi tiêu chí đã dùng          → criteria field       ← dòng quan trọng nhất
      ↓ 30 ngày, đối chiếu kết quả
5.9   tiêu chí lặp lại + thắng nhiều → thăng cấp thành nguyên tắc
5.11  nguyên tắc đủ rõ              → thành thuật toán
```

Ba giai đoạn, làm tuần tự, không nhảy cóc:

| GĐ | Làm gì | Trạng thái |
|---|---|---|
| 1 | Decision Journal — ghi trước khi quyết | **prototype xong** |
| 2 | Review loop hàng tháng — promote tiêu chí thành nguyên tắc | có UI, chưa chạy đủ dữ liệu |
| 3 | Scoring/thuật toán cho quyết định lặp lại | **chưa làm, chưa nên làm** |

`5.12` cảnh báo rõ: hệ thống mà mình không hiểu logic nhân quả bên trong thì nguy hiểm
hơn không có hệ thống. Đừng nhảy vào GĐ3 trước khi GĐ2 chạy 2–3 tháng thật.

## App hiện có

`dalio-decision-journal.jsx` — React, một file.

**Tab "Log a decision"**
- Emotion check (`5.1`) — checkbox, không tick vẫn log được nhưng entry bị gắn cờ đỏ
- The decision — mình đang cược vào cái gì
- Learn before deciding (`5.2a`) — hỏi ai, người đó đáng tin ở việc này không
- EV calculator (`5.6`) — slider xác suất × reward − (1−p) × cost. EV âm thì báo thẳng:
  đừng cược, hoặc đổi điều khoản
- My criteria (`5.9`) — luật mình đang dùng, viết thành câu

**Tab "Review"**
- Bảng tiêu chí: mỗi tiêu chí dùng bao nhiêu lần, thắng/thua bao nhiêu
- Tiêu chí `total >= 3 && win > loss` → gắn badge **"→ Principle 5.9"**
- Danh sách entry, mỗi cái chấm kết quả: Worked / Didn't / Pending

**Dot grid 30 ngày** — nền đen, mỗi ngày một chấm. Xanh thắng, đỏ thua, hổ phách chờ,
xám không có quyết định nào. `5.3`: nhìn cả chuỗi, đừng bóp một chấm đơn lẻ.

Lưu bằng `window.storage`, key `dalio-decisions-v1`.

## Lỗi đã biết — sửa trước khi làm tính năng mới

1. **`window.storage` chỉ có trong artifact runtime Claude.** Chạy local là undefined,
   app trắng. Cần shim sang `localStorage` — xem `storage-shim.js`.
2. **Tiêu chí so khớp bằng exact string.** "Ship small, learn fast" và
   "ship small learn fast" đếm thành hai tiêu chí khác nhau → tính năng promote gần
   như không bao giờ kích hoạt. Cần normalize (lowercase, bỏ dấu câu) hoặc cho chọn
   lại tiêu chí cũ từ dropdown thay vì gõ tay.
3. **Dot grid tô hồng.** Ngày có 1 thắng + 1 pending vẫn ra xanh (nhánh `some(win)`).
   Nhìn vào tưởng tháng đẹp hơn thực tế — đúng thứ Dalio bảo đừng làm.
4. **Pending không bao giờ nhắc.** Log xong quên chấm kết quả thì vòng lặp hở, và
   đây là chỗ hở thật: phần khó không phải ghi, phần khó là quay lại chấm.
5. **`5.10` believability chỉ là ô text tự do**, không chấm điểm, không có trọng số.
   Chưa dùng được cho quyết định có nhiều ý kiến.
6. **Thiếu `5.7`** — chờ thêm thông tin có đáng giá không, cửa một chiều hay hai chiều.
   Đây là câu hỏi lọc mạnh nhất mà app chưa hỏi.

## Chỗ nối với ask-ray

Hiện hai nhánh rời nhau. `ask-ray` sinh ra quyết định, Journal ghi lại kết quả —
nhưng phải chép tay qua.

Nối được thì vòng lặp mới đóng: skill xuất ra một entry JSON (ca gì, nguyên tắc nào
đã dùng, hành động, điều gì làm đổi câu trả lời) → Journal nhập vào → 30 ngày sau
biết được **nguyên tắc nào của Dalio thực sự hiệu quả với mình**, chứ không phải chỉ
tiêu chí tự nghĩ. Đó mới là thứ không mua được ở đâu.

Việc cần làm để nối: chốt schema entry chung, thêm nút import vào Journal.
