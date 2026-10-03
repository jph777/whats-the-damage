// Node test runner for Model.js, a QML `.pragma library` script rather than a
// CommonJS module, so it is evaluated in a vm sandbox.
const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")
const vm = require("node:vm")

const src = fs.readFileSync(path.join(__dirname, "..", "Model.js"), "utf8").replace(/^\.pragma.*$/m, "")
const M = vm.runInNewContext(src + "\n({formatDamage, quotaTokens, tierFor, fontScaleFor, addHit, parseTapLine})")
// Objects built inside the vm have another realm's prototypes; compare as plain data.
const plain = (v) => JSON.parse(JSON.stringify(v))

test("formatDamage uses thousands separators", () => {
  assert.equal(M.formatDamage(1000), "1,000")
  assert.equal(M.formatDamage(1234567), "1,234,567")
  assert.equal(M.formatDamage(7), "7")
  assert.equal(M.formatDamage(41.6), "42")
})

test("formatDamage hides nonsense", () => {
  for (const bad of [0, -5, NaN, "x", null, undefined]) assert.equal(M.formatDamage(bad), "")
})

test("quotaTokens skips cache reads", () => {
  assert.equal(M.quotaTokens({ input_tokens: 2, output_tokens: 401, cache_creation_input_tokens: 30, cache_read_input_tokens: 62627 }), 433)
  assert.equal(M.quotaTokens(null), 0)
})

test("bigger hits get bigger numbers", () => {
  assert.deepEqual(plain([5, 100, 1000, 10000].map(M.tierFor)), [0, 1, 2, 3])
  assert.ok(M.fontScaleFor(20000) > M.fontScaleFor(5))
})

test("addHit merges bursts inside the window and flushes outside it", () => {
  let r = M.addHit(null, 100, 0, 150)
  assert.deepEqual(plain(r.pending), { tokens: 100, at: 0 })
  assert.equal(r.flush, null)
  r = M.addHit(r.pending, 50, 100, 150)
  assert.deepEqual(plain(r.pending), { tokens: 150, at: 0 })
  r = M.addHit(r.pending, 7, 400, 150)
  assert.deepEqual(plain(r.flush), { tokens: 150, at: 0 })
  assert.deepEqual(plain(r.pending), { tokens: 7, at: 400 })
})

test("addHit ignores zero and negative hits", () => {
  const p = { tokens: 5, at: 0 }
  assert.equal(M.addHit(p, 0, 10, 150).pending, p)
  assert.equal(M.addHit(p, -3, 10, 150).pending, p)
})

test("parseTapLine accepts only bare positive integers", () => {
  assert.equal(M.parseTapLine("433\n"), 433)
  for (const bad of ["", "abc", "-4", "1.5", "0", "99999999999"]) assert.equal(M.parseTapLine(bad), 0)
})
