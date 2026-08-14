import { useState } from "react";

/**
 * Mẫu tham chiếu cho artifact-spec.md.
 *
 * QUAN TRỌNG: artifact KHÔNG có Tailwind compiler — chỉ class có sẵn trong base
 * stylesheet mới ăn. Mọi arbitrary value (`bg-[#0A0A0A]`, `text-[15px]`,
 * `max-w-[62ch]`…) rơi im lặng. Thẻ mất nền đen mà chữ vẫn trắng = trắng trên
 * trắng, mở ra không thấy gì. Nên mọi màu và cỡ ở đây đi bằng inline style.
 *
 * Font: sans-serif mặc định của hệ điều hành. Không webfont.
 * Giãn dòng 1.7 cho câu tiếng Việt — dấu chồng hai tầng cần chỗ thở.
 */

const FONT =
  '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif';

const C = {
  red: "#E8332A",
  ink: "#111111",
  card: "#0A0A0A",
  quote: "#9A9A9A",
  apply: "#E4E4E4",
  muted: "#6E6E6E",
  sub: "#5A5A5A",
};

const T = {
  label: { fontSize: 11, fontWeight: 600, letterSpacing: "0.08em", lineHeight: 1.4 },
  title: {
    fontSize: "clamp(18px, 4.6vw, 22px)",
    fontWeight: 600,
    letterSpacing: "-0.01em",
    lineHeight: 1.35,
  },
  body: { fontSize: "clamp(14px, 3.7vw, 15px)", fontWeight: 400, lineHeight: 1.7 },
};

const CASE = {
  kind: "Quyết định — đang cược",
  why: "Có hai lựa chọn loại trừ nhau, có được–mất rõ, và có hạn chót thật.",
};

const CARDS = [
  {
    part: "NGUYÊN TẮC SỐNG",
    num: "5.6",
    title: "Hãy đưa ra quyết định dựa trên tính toán giá trị kỳ vọng.",
    quote:
      "Hãy nghĩ về mọi quyết định như một vụ cá cược với xác suất và phần thưởng cho việc đúng và xác suất và hình phạt cho việc sai…",
    apply:
      "Bạn đang so hai lựa chọn bằng cảm giác nào an toàn hơn, chưa lần nào viết ra xác suất và số tiền. Viết ra là đổi được câu hỏi.",
  },
  {
    part: "NGUYÊN TẮC SỐNG",
    num: "5.6c",
    title:
      "Lựa chọn tốt nhất là lựa chọn có nhiều ưu điểm hơn nhược điểm, chứ không phải lựa chọn không có nhược điểm nào cả.",
    quote: null,
    apply:
      "Ba tuần nay bạn loại phương án B chỉ vì tìm ra một rủi ro. Phương án A cũng có rủi ro, chỉ là bạn chưa đi tìm.",
  },
  {
    part: "NGUYÊN TẮC SỐNG",
    num: "1.8",
    title: "Cân nhắc hậu quả bậc hai và bậc ba.",
    quote:
      "…những người coi trọng hậu quả bậc nhất của quyết định của họ và bỏ qua tác động của hậu quả bậc hai và bậc tiếp theo hiếm khi đạt được mục tiêu của họ.",
    apply:
      "Bậc một của A là nhẹ người ngay. Bậc hai là mười hai tháng nữa vẫn đúng chỗ này. Đó mới là chỗ câu trả lời đảo chiều.",
  },
];

const EV = {
  rows: [
    { label: "Đúng · 60%", amount: "+180tr" },
    { label: "Sai · 40%", amount: "−90tr" },
  ],
  result: "+72tr",
};

function Card({ c }) {
  const [open, setOpen] = useState(false);
  return (
    <div className="ray-card" style={{ background: C.card, borderRadius: 20 }}>
      <div style={{ borderLeft: `3px solid ${C.red}`, paddingLeft: 12 }}>
        <span style={{ ...T.label, color: C.red, textTransform: "uppercase" }}>
          {c.part}
        </span>
        <span style={{ ...T.label, color: C.red, opacity: 0.6, marginLeft: 8 }}>
          {c.num}
        </span>
      </div>

      <h3 style={{ ...T.title, color: "#fff", margin: "12px 0 0", maxWidth: "62ch" }}>
        {c.title}
      </h3>

      {c.quote && (
        <>
          <button
            onClick={() => setOpen(!open)}
            style={{
              display: "flex",
              alignItems: "center",
              minHeight: 44,
              marginTop: 4,
              padding: 0,
              background: "none",
              border: "none",
              color: C.muted,
              fontFamily: FONT,
              fontSize: 12,
              lineHeight: 1.4,
              cursor: "pointer",
            }}
          >
            {open ? "Ẩn nguyên văn" : "Nguyên văn trong sách"}
            <span style={{ marginLeft: 6, fontSize: 9 }}>{open ? "▲" : "▼"}</span>
          </button>
          {open && (
            <p style={{ ...T.body, color: C.quote, margin: "0 0 4px", maxWidth: "62ch" }}>
              {c.quote}
            </p>
          )}
        </>
      )}

      <div
        style={{
          marginTop: 16,
          paddingTop: 16,
          borderTop: "1px solid rgba(255,255,255,0.10)",
        }}
      >
        <div
          style={{ ...T.label, fontSize: 10, color: C.muted, textTransform: "uppercase" }}
        >
          Áp vào ca này
        </div>
        <p style={{ ...T.body, color: C.apply, margin: "8px 0 0", maxWidth: "62ch" }}>
          {c.apply}
        </p>
      </div>
    </div>
  );
}

export default function PrincipleCards() {
  return (
    <div
      style={{
        fontFamily: FONT,
        WebkitFontSmoothing: "antialiased",
        maxWidth: 672,
        margin: "0 auto",
        padding: "24px 16px",
        boxSizing: "border-box",
      }}
    >
      <style>{`
        .ray-card { padding: 20px 16px; }
        @media (min-width: 480px) { .ray-card { padding: 24px 20px; } }
        @media (min-width: 768px) { .ray-ev { grid-template-columns: 1fr 1fr; } }
        @media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
      `}</style>

      <header style={{ marginBottom: 20 }}>
        <div style={{ ...T.label, color: C.red, textTransform: "uppercase" }}>
          Chẩn đoán
        </div>
        <h2 style={{ ...T.title, color: C.ink, margin: "8px 0 0", maxWidth: "62ch" }}>
          {CASE.kind}
        </h2>
        <p style={{ ...T.body, color: C.sub, margin: "8px 0 0", maxWidth: "62ch" }}>
          {CASE.why}
        </p>
      </header>

      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
        {CARDS.map((c) => (
          <Card key={c.num} c={c} />
        ))}
      </div>

      <section
        style={{
          marginTop: 12,
          border: "1px solid rgba(0,0,0,0.10)",
          borderRadius: 20,
          padding: "20px 16px",
        }}
      >
        <div
          style={{ ...T.label, fontSize: 10, color: C.muted, textTransform: "uppercase" }}
        >
          Giá trị kỳ vọng
        </div>

        <div
          className="ray-ev"
          style={{ display: "grid", gridTemplateColumns: "1fr", gap: 8, marginTop: 12 }}
        >
          {EV.rows.map((r) => (
            <div
              key={r.label}
              style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "baseline",
                gap: 12,
                background: "rgba(0,0,0,0.03)",
                borderRadius: 14,
                padding: "10px 12px",
              }}
            >
              <span style={{ fontSize: 13, lineHeight: 1.4, color: C.sub }}>
                {r.label}
              </span>
              <span
                style={{
                  fontSize: 15,
                  lineHeight: 1.4,
                  color: C.ink,
                  fontVariantNumeric: "tabular-nums",
                }}
              >
                {r.amount}
              </span>
            </div>
          ))}
        </div>

        <div
          style={{
            display: "flex",
            justifyContent: "space-between",
            alignItems: "baseline",
            gap: 12,
            marginTop: 12,
            paddingTop: 12,
            borderTop: "1px solid rgba(0,0,0,0.10)",
          }}
        >
          <span style={{ fontSize: 13, lineHeight: 1.4, color: C.sub }}>Kỳ vọng</span>
          <span
            style={{
              fontSize: 17,
              fontWeight: 600,
              lineHeight: 1.4,
              color: C.ink,
              fontVariantNumeric: "tabular-nums",
            }}
          >
            {EV.result}
          </span>
        </div>

        <p style={{ fontSize: 12, lineHeight: 1.7, color: "#8A8A8A", margin: "12px 0 0" }}>
          Cả hai xác suất đều là ước lượng của bạn, không phải số đo.
        </p>
      </section>
    </div>
  );
}
