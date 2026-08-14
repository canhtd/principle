import { useState, useEffect } from "react";

// ——— Dalio Ch.5 Decision Journal ———
// Palette: ink #101014 / paper #F7F5F0 / win #2F9E63 / loss #C6483F / pending #D9A036
const C = {
  ink: "#101014",
  paper: "#F7F5F0",
  line: "#DDD8CE",
  win: "#2F9E63",
  loss: "#C6483F",
  pending: "#D9A036",
  mut: "#8A857B",
};

const KEY = "dalio-decisions-v1";
const todayStr = () => new Date().toISOString().slice(0, 10);

const fmtDay = (iso) => {
  const d = new Date(iso + "T00:00:00");
  return d.toLocaleDateString("en-GB", { day: "numeric", month: "short" });
};

export default function App() {
  const [entries, setEntries] = useState([]);
  const [loaded, setLoaded] = useState(false);
  const [view, setView] = useState("today"); // today | review
  const [saving, setSaving] = useState(false);

  // form state
  const [decision, setDecision] = useState("");
  const [calm, setCalm] = useState(false);
  const [learned, setLearned] = useState("");
  const [prob, setProb] = useState(60);
  const [reward, setReward] = useState("");
  const [penalty, setPenalty] = useState("");
  const [criteria, setCriteria] = useState("");

  useEffect(() => {
    (async () => {
      try {
        const r = await window.storage.get(KEY);
        if (r && r.value) setEntries(JSON.parse(r.value));
      } catch (e) {
        /* no data yet */
      }
      setLoaded(true);
    })();
  }, []);

  const persist = async (next) => {
    setEntries(next);
    try {
      await window.storage.set(KEY, JSON.stringify(next));
    } catch (e) {
      console.error("save failed", e);
    }
  };

  const ev = () => {
    const r = parseFloat(reward) || 0;
    const p = parseFloat(penalty) || 0;
    return (prob / 100) * r - (1 - prob / 100) * p;
  };

  const addEntry = async () => {
    if (!decision.trim()) return;
    setSaving(true);
    const e = {
      id: Date.now().toString(),
      date: todayStr(),
      decision: decision.trim(),
      calm,
      learned: learned.trim(),
      prob,
      reward: parseFloat(reward) || 0,
      penalty: parseFloat(penalty) || 0,
      ev: ev(),
      criteria: criteria.trim(),
      outcome: "pending",
    };
    await persist([e, ...entries]);
    setDecision(""); setCalm(false); setLearned("");
    setProb(60); setReward(""); setPenalty(""); setCriteria("");
    setSaving(false);
  };

  const setOutcome = (id, outcome) =>
    persist(entries.map((e) => (e.id === id ? { ...e, outcome } : e)));

  const removeEntry = (id) => persist(entries.filter((e) => e.id !== id));

  // ——— 30-day dot data ———
  const days = [];
  for (let i = 29; i >= 0; i--) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    const iso = d.toISOString().slice(0, 10);
    const dayEntries = entries.filter((e) => e.date === iso);
    let color = C.line;
    if (dayEntries.length) {
      if (dayEntries.some((e) => e.outcome === "loss")) color = C.loss;
      else if (dayEntries.every((e) => e.outcome === "win")) color = C.win;
      else if (dayEntries.some((e) => e.outcome === "win")) color = C.win;
      else color = C.pending;
    }
    days.push({ iso, color, count: dayEntries.length, isToday: iso === todayStr() });
  }

  // ——— criteria patterns ———
  const critMap = {};
  entries.forEach((e) => {
    if (!e.criteria) return;
    const k = e.criteria;
    if (!critMap[k]) critMap[k] = { total: 0, win: 0, loss: 0 };
    critMap[k].total++;
    if (e.outcome === "win") critMap[k].win++;
    if (e.outcome === "loss") critMap[k].loss++;
  });
  const critList = Object.entries(critMap).sort((a, b) => b[1].total - a[1].total);

  const decided = entries.filter((e) => e.outcome !== "pending");
  const winRate = decided.length
    ? Math.round((decided.filter((e) => e.outcome === "win").length / decided.length) * 100)
    : null;

  const S = styles;

  return (
    <div style={S.page}>
      <style>{`
        input, textarea { font-family: inherit; }
        input:focus, textarea:focus { outline: 2px solid ${C.ink}; }
        button { cursor: pointer; font-family: inherit; }
        @media (prefers-reduced-motion: reduce) { * { transition: none !important; } }
      `}</style>

      {/* Header */}
      <header style={S.header}>
        <div style={S.eyebrow}>Principles · Chapter 5</div>
        <h1 style={S.h1}>Decision Journal</h1>
        <div style={S.sub}>Learn first. Then decide. Write down the criteria.</div>
      </header>

      {/* 30-day dots — the signature */}
      <section style={S.dotWrap}>
        <div style={S.dotGrid}>
          {days.map((d) => (
            <div key={d.iso} title={`${fmtDay(d.iso)} · ${d.count} decision${d.count === 1 ? "" : "s"}`}
              style={{
                ...S.dot,
                background: d.color,
                boxShadow: d.isToday ? `0 0 0 2px ${C.paper}, 0 0 0 4px ${C.ink}` : "none",
              }} />
          ))}
        </div>
        <div style={S.dotLegend}>
          <span><i style={{ ...S.leg, background: C.win }} /> worked</span>
          <span><i style={{ ...S.leg, background: C.loss }} /> didn't</span>
          <span><i style={{ ...S.leg, background: C.pending }} /> pending</span>
          {winRate !== null && <span style={{ marginLeft: "auto", fontWeight: 700 }}>{winRate}% win rate</span>}
        </div>
      </section>

      {/* Tabs */}
      <nav style={S.tabs}>
        {["today", "review"].map((t) => (
          <button key={t} onClick={() => setView(t)}
            style={{ ...S.tab, ...(view === t ? S.tabOn : {}) }}>
            {t === "today" ? "Log a decision" : `Review (${entries.length})`}
          </button>
        ))}
      </nav>

      {view === "today" && (
        <section style={S.card}>
          {/* 5.1 emotion check */}
          <label style={S.checkRow} onClick={() => setCalm(!calm)}>
            <span style={{ ...S.checkbox, background: calm ? C.ink : "transparent" }}>
              {calm && <span style={{ color: C.paper, fontSize: 13 }}>✓</span>}
            </span>
            <span>
              <b>Emotion check</b> — I'm calm, not deciding from fear or excitement
              <span style={S.ref}> 5.1</span>
            </span>
          </label>

          <div style={S.field}>
            <label style={S.label}>The decision <span style={S.ref}>what am I betting on?</span></label>
            <textarea value={decision} onChange={(e) => setDecision(e.target.value)}
              rows={2} placeholder="e.g. Ship feature X this sprint instead of next"
              style={S.textarea} />
          </div>

          <div style={S.field}>
            <label style={S.label}>Learn before deciding <span style={S.ref}>5.2a — who did I ask? Are they believable?</span></label>
            <input value={learned} onChange={(e) => setLearned(e.target.value)}
              placeholder="e.g. Asked Minh (shipped 3 similar features)" style={S.input} />
          </div>

          {/* 5.6 EV */}
          <div style={S.evBox}>
            <div style={S.label}>Expected value <span style={S.ref}>5.6 — every decision is a bet</span></div>
            <div style={S.evRow}>
              <div style={{ flex: 1 }}>
                <div style={S.small}>Chance I'm right: <b>{prob}%</b></div>
                <input type="range" min={5} max={95} step={5} value={prob}
                  onChange={(e) => setProb(+e.target.value)} style={{ width: "100%" }} />
              </div>
            </div>
            <div style={S.evRow}>
              <input type="number" value={reward} onChange={(e) => setReward(e.target.value)}
                placeholder="Reward if right" style={{ ...S.input, flex: 1 }} />
              <input type="number" value={penalty} onChange={(e) => setPenalty(e.target.value)}
                placeholder="Cost if wrong" style={{ ...S.input, flex: 1 }} />
            </div>
            {(reward || penalty) && (
              <div style={{ ...S.evResult, color: ev() >= 0 ? C.win : C.loss }}>
                EV = {ev() >= 0 ? "+" : ""}{ev().toFixed(1)}
                {ev() < 0 && " — negative bet. Don't take it, or change the terms."}
              </div>
            )}
          </div>

          <div style={S.field}>
            <label style={S.label}>My criteria <span style={S.ref}>5.9 — the rule I'm using. This becomes a principle.</span></label>
            <input value={criteria} onChange={(e) => setCriteria(e.target.value)}
              placeholder='e.g. "Ship small, learn fast beats big-bang release"' style={S.input} />
          </div>

          <button onClick={addEntry} disabled={!decision.trim() || saving} style={{
            ...S.primary, opacity: !decision.trim() || saving ? 0.4 : 1,
          }}>
            {saving ? "Saving…" : "Log this bet"}
          </button>
        </section>
      )}

      {view === "review" && (
        <section>
          {/* criteria scoreboard */}
          {critList.length > 0 && (
            <div style={{ ...S.card, marginBottom: 14 }}>
              <div style={S.cardTitle}>Your criteria — which rules actually work</div>
              {critList.map(([k, v]) => {
                const promote = v.total >= 3 && v.win > v.loss;
                return (
                  <div key={k} style={S.critRow}>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontStyle: "italic" }}>"{k}"</div>
                      <div style={S.small}>
                        used {v.total}× · <span style={{ color: C.win }}>{v.win} won</span> · <span style={{ color: C.loss }}>{v.loss} lost</span>
                      </div>
                    </div>
                    {promote && <span style={S.badge}>→ Principle 5.9</span>}
                  </div>
                );
              })}
            </div>
          )}

          {/* entries */}
          {loaded && entries.length === 0 && (
            <div style={{ ...S.card, textAlign: "center", color: C.mut }}>
              No decisions logged yet. Log today's first bet.
            </div>
          )}
          {entries.map((e) => (
            <div key={e.id} style={{ ...S.card, marginBottom: 10 }}>
              <div style={S.entryTop}>
                <span style={S.small}>{fmtDay(e.date)}</span>
                <span style={{
                  ...S.small, fontWeight: 700,
                  color: e.ev >= 0 ? C.win : C.loss,
                }}>EV {e.ev >= 0 ? "+" : ""}{e.ev.toFixed(1)} · {e.prob}%</span>
              </div>
              <div style={{ margin: "6px 0", fontWeight: 600 }}>{e.decision}</div>
              {e.criteria && <div style={{ ...S.small, fontStyle: "italic" }}>"{e.criteria}"</div>}
              {e.learned && <div style={S.small}>Asked: {e.learned}</div>}
              {!e.calm && <div style={{ ...S.small, color: C.loss }}>⚠ decided while not calm</div>}
              <div style={S.outcomeRow}>
                {[["win", "Worked", C.win], ["loss", "Didn't", C.loss], ["pending", "Pending", C.pending]].map(
                  ([val, lab, col]) => (
                    <button key={val} onClick={() => setOutcome(e.id, val)} style={{
                      ...S.outBtn,
                      background: e.outcome === val ? col : "transparent",
                      color: e.outcome === val ? "#fff" : C.mut,
                      borderColor: e.outcome === val ? col : C.line,
                    }}>{lab}</button>
                  )
                )}
                <button onClick={() => removeEntry(e.id)} style={{ ...S.outBtn, marginLeft: "auto", color: C.mut, borderColor: "transparent" }}>✕</button>
              </div>
            </div>
          ))}
        </section>
      )}

      <footer style={S.footer}>
        Pain + Reflection = Progress · after 30 days, promote winning criteria to principles (5.9), then turn them into rules a computer could follow (5.11)
      </footer>
    </div>
  );
}

const styles = {
  page: {
    minHeight: "100vh", background: C.paper, color: C.ink,
    fontFamily: "'Helvetica Neue', Arial, sans-serif",
    maxWidth: 560, margin: "0 auto", padding: "20px 16px 60px",
    fontSize: 15, lineHeight: 1.45,
  },
  header: { marginBottom: 18 },
  eyebrow: { fontSize: 11, letterSpacing: "0.14em", textTransform: "uppercase", color: C.mut, marginBottom: 4 },
  h1: { fontFamily: "Georgia, 'Times New Roman', serif", fontSize: 30, fontWeight: 700, margin: 0, letterSpacing: "-0.01em" },
  sub: { color: C.mut, marginTop: 4, fontSize: 13.5 },
  dotWrap: { background: C.ink, borderRadius: 14, padding: "16px 14px 12px", marginBottom: 16 },
  dotGrid: { display: "grid", gridTemplateColumns: "repeat(10, 1fr)", gap: 9, justifyItems: "center" },
  dot: { width: 16, height: 16, borderRadius: "50%", transition: "background .2s" },
  dotLegend: { display: "flex", gap: 14, marginTop: 12, fontSize: 11.5, color: "#B9B4AA", alignItems: "center", flexWrap: "wrap" },
  leg: { display: "inline-block", width: 8, height: 8, borderRadius: "50%", marginRight: 4 },
  tabs: { display: "flex", gap: 8, marginBottom: 14 },
  tab: {
    flex: 1, padding: "10px 0", border: `1.5px solid ${C.ink}`, borderRadius: 10,
    background: "transparent", color: C.ink, fontSize: 14, fontWeight: 600,
  },
  tabOn: { background: C.ink, color: C.paper },
  card: { background: "#fff", border: `1px solid ${C.line}`, borderRadius: 14, padding: 16 },
  cardTitle: { fontFamily: "Georgia, serif", fontSize: 17, fontWeight: 700, marginBottom: 10 },
  checkRow: { display: "flex", gap: 10, alignItems: "flex-start", marginBottom: 14, cursor: "pointer", fontSize: 14 },
  checkbox: {
    width: 20, height: 20, minWidth: 20, border: `1.5px solid ${C.ink}`, borderRadius: 6,
    display: "flex", alignItems: "center", justifyContent: "center", marginTop: 1,
  },
  field: { marginBottom: 14 },
  label: { display: "block", fontSize: 13, fontWeight: 700, marginBottom: 5 },
  ref: { fontWeight: 400, color: C.mut, fontSize: 12 },
  input: {
    width: "100%", boxSizing: "border-box", padding: "10px 12px", fontSize: 14,
    border: `1px solid ${C.line}`, borderRadius: 9, background: C.paper,
  },
  textarea: {
    width: "100%", boxSizing: "border-box", padding: "10px 12px", fontSize: 14,
    border: `1px solid ${C.line}`, borderRadius: 9, background: C.paper, resize: "vertical",
  },
  evBox: { border: `1px dashed ${C.mut}`, borderRadius: 10, padding: 12, marginBottom: 14 },
  evRow: { display: "flex", gap: 8, marginTop: 8 },
  evResult: { marginTop: 8, fontSize: 13.5, fontWeight: 700 },
  small: { fontSize: 12.5, color: C.mut },
  primary: {
    width: "100%", padding: "13px 0", background: C.ink, color: C.paper,
    border: "none", borderRadius: 10, fontSize: 15, fontWeight: 700,
  },
  critRow: { display: "flex", gap: 10, alignItems: "center", padding: "9px 0", borderTop: `1px solid ${C.line}` },
  badge: {
    fontSize: 11, fontWeight: 700, background: C.win, color: "#fff",
    padding: "4px 8px", borderRadius: 20, whiteSpace: "nowrap",
  },
  entryTop: { display: "flex", justifyContent: "space-between" },
  outcomeRow: { display: "flex", gap: 6, marginTop: 10, alignItems: "center" },
  outBtn: {
    padding: "6px 12px", fontSize: 12.5, fontWeight: 600, borderRadius: 20,
    border: `1.5px solid ${C.line}`, background: "transparent",
  },
  footer: { marginTop: 24, fontSize: 12, color: C.mut, textAlign: "center", lineHeight: 1.5 },
};
