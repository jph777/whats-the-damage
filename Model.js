// Pure helpers for the damage numbers: formatting, sizing, and the burst
// merging that keeps a flood of tiny token counts from becoming confetti.
// No state lives here; Particles.qml owns the particles.

.pragma library

// Destiny prints plain integers with thousands separators.
function formatDamage(n) {
  var v = Math.round(Number(n))
  if (!isFinite(v) || v <= 0) return ""
  return String(v).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}

// Tokens that count against the session quota for one assistant message.
// Cache reads are re-sent context, not new spend, so they are left out.
function quotaTokens(usage) {
  if (!usage || typeof usage !== "object") return 0
  var n = 0
  var keys = ["input_tokens", "output_tokens", "cache_creation_input_tokens"]
  for (var i = 0; i < keys.length; i++) {
    var v = Number(usage[keys[i]])
    if (isFinite(v) && v > 0) n += v
  }
  return n
}

// Size tier 0..3 from the magnitude, so a 40k hit feels bigger than a 40.
function tierFor(n) {
  if (n >= 10000) return 3
  if (n >= 1000) return 2
  if (n >= 100) return 1
  return 0
}

function fontScaleFor(n) {
  return [1.0, 1.2, 1.45, 1.75][tierFor(n)]
}

// Hits arriving within windowMs of each other are one number. `pending` is
// {tokens, at} or null; returns the new pending and whether to flush the old.
function addHit(pending, tokens, nowMs, windowMs) {
  var t = Math.round(Number(tokens))
  if (!isFinite(t) || t <= 0) return { pending: pending, flush: null }
  if (pending && nowMs - pending.at <= windowMs)
    return { pending: { tokens: pending.tokens + t, at: pending.at }, flush: null }
  return { pending: { tokens: t, at: nowMs }, flush: pending }
}

// One line from bin/token-tap: a bare positive integer. Anything else is noise.
function parseTapLine(line) {
  var s = String(line || "").trim()
  if (!/^\d+$/.test(s)) return 0
  var n = parseInt(s, 10)
  return n > 0 && n < 1e9 ? n : 0
}
