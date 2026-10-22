// Renders the RepTrack app icon (1024x1024, opaque RGB PNG) with plain Node.js — no dependencies.
// Usage: node tools/generate-app-icon.mjs RepTrack/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
//
// Design: near-black background with a soft lime glow, a lime "progress ring" (like an activity ring)
// and a tilted dumbbell in the middle. Shapes are signed distance fields, supersampled 4x4 for smooth edges.

import { writeFileSync, mkdirSync } from "node:fs";
import { dirname } from "node:path";
import { deflateSync } from "node:zlib";

const SIZE = 1024;
const SAMPLES = 4; // per axis

// ---------- colour helpers ----------
const hex = (h) => [parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255];
const mix = (a, b, t) => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];
const clamp01 = (x) => Math.min(1, Math.max(0, x));
const smooth = (e0, e1, x) => {
  const t = clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
};
const over = (dst, src, alpha) => mix(dst, src, clamp01(alpha));

const LIME = hex("#D4FF3F");
const LIME_LIGHT = hex("#EEFF9E");
const LIME_DIM = hex("#9DC41F");
const LIME_DEEP = hex("#6E8C12");
const INK = hex("#0B0B0D");
const BG_TOP = hex("#1C2014");
const BG_BOTTOM = hex("#050506");
const TRACK = hex("#1F2219");

// ---------- signed distance functions ----------
function sdRoundBox(px, py, hx, hy, r) {
  const qx = Math.abs(px) - hx + r;
  const qy = Math.abs(py) - hy + r;
  const ox = Math.max(qx, 0);
  const oy = Math.max(qy, 0);
  return Math.hypot(ox, oy) + Math.min(Math.max(qx, qy), 0) - r;
}

// Dumbbell parts in local coordinates (u along the bar, v across it). Returns {d, part, v, hv}.
const PARTS = [
  { cu: 0, hu: 175, hv: 24, r: 24, kind: "handle" },
  { cu: -205, hu: 36, hv: 182, r: 30, kind: "plate" },
  { cu: 205, hu: 36, hv: 182, r: 30, kind: "plate" },
  { cu: -268, hu: 26, hv: 134, r: 24, kind: "plate2" },
  { cu: 268, hu: 26, hv: 134, r: 24, kind: "plate2" },
  { cu: -306, hu: 14, hv: 46, r: 10, kind: "cap" },
  { cu: 306, hu: 14, hv: 46, r: 10, kind: "cap" },
];

const ANGLE = (-38 * Math.PI) / 180;
const COS = Math.cos(ANGLE);
const SIN = Math.sin(ANGLE);
const DB_SCALE = 0.86;

function dumbbell(x, y) {
  // rotate into the bar's frame
  const u = (x * COS + y * SIN) / DB_SCALE;
  const v = (-x * SIN + y * COS) / DB_SCALE;
  let best = { d: Infinity, part: null, u, v };
  for (const p of PARTS) {
    const d = sdRoundBox(u - p.cu, v, p.hu, p.hv, p.r) * DB_SCALE;
    if (d < best.d) best = { d, part: p, u, v };
  }
  return best;
}

// Progress ring
const RING_R = 378;
const RING_HALF = 28;
const RING_START = -Math.PI / 2; // 12 o'clock
const RING_SWEEP = (300 / 360) * Math.PI * 2;

function ringTrack(x, y) {
  return Math.abs(Math.hypot(x, y) - RING_R) - RING_HALF;
}

// Distance to the filled arc (round caps), plus the 0..1 position along it
function ringArc(x, y) {
  let a = Math.atan2(y, x) - RING_START;
  while (a < 0) a += Math.PI * 2;
  while (a >= Math.PI * 2) a -= Math.PI * 2;
  if (a <= RING_SWEEP) {
    return { d: Math.abs(Math.hypot(x, y) - RING_R) - RING_HALF, t: a / RING_SWEEP };
  }
  const capA = [RING_START, RING_START + RING_SWEEP];
  let d = Infinity;
  let t = 0;
  capA.forEach((ca, i) => {
    const cx = Math.cos(ca) * RING_R;
    const cy = Math.sin(ca) * RING_R;
    const dd = Math.hypot(x - cx, y - cy) - RING_HALF;
    if (dd < d) {
      d = dd;
      t = i;
    }
  });
  return { d, t };
}

// ---------- shading ----------
function shade(x, y) {
  // background: diagonal gradient + centred lime glow + vignette
  const g = clamp01((x + y) / (SIZE * 1.4) + 0.5);
  let c = mix(BG_TOP, BG_BOTTOM, g);
  const rr = Math.hypot(x, y - 10);
  c = over(c, LIME, 0.16 * Math.exp(-((rr / 330) ** 2)));

  // ring track and arc
  const track = ringTrack(x, y);
  c = over(c, TRACK, 1 - smooth(-0.5, 0.5, track));
  const arc = ringArc(x, y);
  c = over(c, LIME, 0.28 * Math.exp(-Math.max(arc.d, 0) / 26)); // glow
  if (arc.d < 1) {
    const ringCol = mix(LIME_DIM, LIME_LIGHT, arc.t);
    // light from the top-left: a little brighter on the inner edge
    const across = (Math.hypot(x, y) - RING_R) / RING_HALF; // -1 inner .. 1 outer
    const lit = mix(ringCol, LIME_DEEP, clamp01(across * 0.35 + 0.1));
    c = over(c, lit, 1 - smooth(-0.5, 0.5, arc.d));
  }

  // dumbbell drop shadow
  const sh = dumbbell(x - 10, y - 26);
  c = over(c, hex("#000000"), 0.55 * (1 - smooth(-30, 40, sh.d)));

  // dumbbell glow
  const db = dumbbell(x, y);
  c = over(c, LIME, 0.22 * Math.exp(-Math.max(db.d, 0) / 45) * (db.d > 0 ? 1 : 0));

  if (db.d < 1) {
    const p = db.part;
    const tv = clamp01((db.v / p.hv + 1) / 2); // 0 at the top edge, 1 at the bottom
    let base;
    if (p.kind === "handle") {
      base = mix(hex("#E4F7A0"), hex("#8FA83A"), tv);
      // knurling stripes
      const stripe = Math.abs(((db.u / 14) % 2) + 2) % 2 < 1 ? 0.06 : 0;
      base = mix(base, INK, Math.abs(db.u) < 120 ? stripe : 0);
    } else if (p.kind === "cap") {
      base = mix(hex("#D9DCCB"), hex("#6D7064"), tv);
    } else {
      base = p.kind === "plate" ? mix(LIME, LIME_DIM, tv) : mix(LIME_DIM, LIME_DEEP, tv * 0.85);
      // vertical sheen across the plate face
      const fu = (db.u - p.cu) / p.hu; // -1..1
      base = mix(base, LIME_LIGHT, 0.45 * Math.exp(-(((fu + 0.35) / 0.35) ** 2)));
    }
    // inner bevel: darken close to each part's own edge, highlight the top edge
    const edge = -db.d;
    base = mix(base, LIME_DEEP, (1 - smooth(0, 14, edge)) * (p.kind === "cap" ? 0.2 : 0.45) * tv);
    base = mix(base, hex("#FFFFFF"), (1 - smooth(0, 10, edge)) * 0.35 * (1 - tv));
    c = over(c, base, 1 - smooth(-0.5, 0.5, db.d));
  }
  return c;
}

// ---------- render ----------
const raw = Buffer.alloc((SIZE * 3 + 1) * SIZE);
for (let py = 0; py < SIZE; py++) {
  raw[py * (SIZE * 3 + 1)] = 0; // PNG filter: none
  for (let px = 0; px < SIZE; px++) {
    let r = 0;
    let g = 0;
    let b = 0;
    for (let sy = 0; sy < SAMPLES; sy++) {
      for (let sx = 0; sx < SAMPLES; sx++) {
        const x = px + (sx + 0.5) / SAMPLES - SIZE / 2;
        const y = py + (sy + 0.5) / SAMPLES - SIZE / 2;
        const c = shade(x, y);
        r += c[0];
        g += c[1];
        b += c[2];
      }
    }
    const n = SAMPLES * SAMPLES;
    const o = py * (SIZE * 3 + 1) + 1 + px * 3;
    raw[o] = Math.round(clamp01(r / n) * 255);
    raw[o + 1] = Math.round(clamp01(g / n) * 255);
    raw[o + 2] = Math.round(clamp01(b / n) * 255);
  }
}

// ---------- PNG encoding ----------
const CRC_TABLE = new Uint32Array(256).map((_, n) => {
  let c = n;
  for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});
function crc32(buf) {
  let c = 0xffffffff;
  for (const byte of buf) c = CRC_TABLE[(c ^ byte) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}
const ihdr = Buffer.alloc(13);
ihdr.writeUInt32BE(SIZE, 0);
ihdr.writeUInt32BE(SIZE, 4);
ihdr[8] = 8; // bit depth
ihdr[9] = 2; // colour type: RGB (no alpha — required for iOS app icons)
const png = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  chunk("IHDR", ihdr),
  chunk("IDAT", deflateSync(raw, { level: 9 })),
  chunk("IEND", Buffer.alloc(0)),
]);

const out = process.argv[2] ?? "AppIcon.png";
mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, png);
console.log(`Wrote ${out} (${png.length} bytes)`);
