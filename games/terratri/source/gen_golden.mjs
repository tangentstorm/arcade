// Regenerate tools/golden/terratri_playouts.json from the original TS rules:
//   tsc --target es2022 --module es2022 --moduleResolution node --outDir out shared/{terratri,Game,types}.ts
//   echo '{"type":"module"}' > out/package.json && node gen_golden.mjs > ../../../tools/golden/terratri_playouts.json
// Golden playout generator: drives the original TS Game class with a seeded
// policy and records every derived field after each atomic step.
import { Game } from './out/Game.js';
function mulberry32(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296;}}
const snap = g => ({ steps: g.steps, board: g.board, turn: g.whoseTurn, winner: g.winner ?? '',
  rb: g.redBanked, bb: g.blueBanked, rs: g.redSupply, bs: g.blueSupply,
  valid: Object.entries(g.validSteps).map(([k,v]) => k + ':' + v).join(' '),
  history: g.history.join(',') });
const games = [];
for (let seed = 1; seed <= 8; seed++) {
  const rnd = mulberry32(seed); let g = new Game(); const states = [snap(g)];
  for (let i = 0; i < 2000 && !g.winner; i++) {
    const keys = Object.keys(g.validSteps); if (!keys.length) break;
    let pick = keys.find(k => k.toLowerCase() === 'f' && rnd() < 0.8);
    if (!pick && seed % 2 === 0) pick = keys.find(k => k.toLowerCase() === 'k' && rnd() < 0.3);
    if (!pick) pick = keys[Math.floor(rnd() * keys.length)];
    g = g.applyStep(pick); states.push(snap(g));
  }
  games.push({ seed, final: g.steps, winner: g.winner ?? '', states });
  console.error(seed, g.winner, states.length, g.steps.length);
}
process.stdout.write(JSON.stringify({ source: 'tangentstorm/terratri@7c20663 src/shared/Game.ts', games }));
