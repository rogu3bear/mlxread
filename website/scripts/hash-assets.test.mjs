import { expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { fingerprintAssets } from "./hash-assets.mjs";

const js = Buffer.from('const wasm = new URL("app.wasm",import.meta.url);');
const css = Buffer.from("body { color: black; }");
const digest = bytes => createHash("sha256").update(bytes).digest("hex").slice(0, 16);

test("JS fingerprint covers final bytes and changes when only WASM changes", () => {
  const first = fingerprintAssets("app", js, Buffer.from("wasm-v1"), css);
  const next = fingerprintAssets("app", js, Buffer.from("wasm-v2"), css);
  expect(first.jsHash).toBe(digest(Buffer.from(first.rewrittenJs)));
  expect(first.hashedJsName).toBe(`app.${digest(Buffer.from(first.rewrittenJs))}.js`);
  expect(first.rewrittenJs).toContain(first.hashedWasmName);
  expect(next.hashedWasmName).not.toBe(first.hashedWasmName);
  expect(next.hashedJsName).not.toBe(first.hashedJsName);
  expect(next.hashedCssName).toBe(first.hashedCssName);
  expect(fingerprintAssets("app", js, Buffer.from("wasm-v1"), css)).toEqual(first);
});

test("missing, malformed and ambiguous WASM references fail before publication", () => {
  for (const source of ["export const value = 1;", 'new URL("app.wasm", wrongBase)',
    `${js.toString()} ${js.toString()}`]) {
    expect(() => fingerprintAssets("app", Buffer.from(source), Buffer.from("wasm"), css))
      .toThrow("expected exactly one static WASM URL");
  }
});
