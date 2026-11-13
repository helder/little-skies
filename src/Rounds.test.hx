import helder.test.Test;

// The recorded rounds (Rounds) replayed on the simulation alone (no
// window, no GPU), natively and as wasm32-wasi (`helder test --target
// all`): every hole has one, and each is holed in its strokes, at or under
// par; a step allocates only while the physics' buffers grow; before each
// shot the aim's preview (Aim), played to the end, leaves the ball where the
// shot does, bit for bit; a fan of previews from each tee, as the game
// makes them, allocates nothing once the ghost's buffers have grown.
function tests() {
	describe("recorded rounds", () -> {
		test("every hole has one", () -> {
			for (i in 0...Course.holes.length)
				assert(Lambda.exists(Rounds.rounds, r -> r.hole == i), 'hole ${i + 1} has no recorded round');
		});
		for (r in Rounds.rounds) {
			var hole = Course.holes[r.hole];
			test('hole ${r.hole + 1}, ${hole.name}: holed at or under par', () -> {
				var res = Rounds.replay(hole, r.shots);
				assert(res.sim.sunk, 'not holed: the ball at ${res.sim.ball.position.x} ${res.sim.ball.position.y} ${res.sim.ball.position.z}');
				equals(res.sim.strokes, r.shots.length);
				assert(res.sim.strokes <= hole.par, '${res.sim.strokes} strokes, par ${hole.par}');
				// (only while the buffers grow: a few steps, a little)
				assert(res.allocating <= 6 && res.bytes <= 4096, '${res.bytes} bytes allocated in ${res.allocating} steps');
			});
		}
	});

	describe("the aim's preview", () -> {
		for (r in Rounds.rounds) {
			var hole = Course.holes[r.hole];
			test('hole ${r.hole + 1}: each shot\'s preview ends where the shot does', () -> {
				var sim = new Sim(hole), aim = new Aim(sim);
				var k = 0;
				for (s in r.shots) {
					if (sim.sunk) break;
					for (_ in 0...Rounds.waitOf(s))
						sim.step();
					while (!sim.resting)
						sim.step();
					aim.predict(sim, s[0], s[1], s[2], false, 20 * 120);
					var g = aim.ghost;
					sim.shoot(s[0], s[1], s[2]);
					var n = 0;
					while (!sim.sunk && n < 20 * 120) {
						sim.step();
						n++;
						if (sim.resting) break;
					}
					var a = g.ball.position, b = sim.ball.position;
					var same = a.x == b.x && a.y == b.y && a.z == b.z && g.sunk == sim.sunk && g.strokes == sim.strokes;
					assert(same, 'shot ${k + 1}: the preview ends at ${a.x} ${a.y} ${a.z}${g.sunk ? " (holed)" : ""}, the shot at ${b.x} ${b.y} ${b.z}${sim.sunk ? " (holed)" : ""}');
					k++;
				}
			});
			test('hole ${r.hole + 1}: 48 previews from the tee allocate nothing', () -> {
				var tee = new Sim(hole), aim = new Aim(tee);
				var bytes = 0.0, allocating = 0;
				for (i in 0...48) {
					var a = i / 48 * Math.PI * 2, speed = Sim.MIN_SPEED + (Sim.MAX_SPEED - Sim.MIN_SPEED) * ((i % 4) + 1) / 4;
					var before = hxmc.GcStats.bytesAllocated();
					aim.predict(tee, Math.sin(a), -Math.cos(a), speed);
					var d = hxmc.GcStats.bytesAllocated() - before;
					assert(aim.count > 0 && aim.ran <= Aim.STEPS);
					// (the first: the ghost's buffers growing)
					if (i < 4) continue;
					if (d > 0) allocating++;
					bytes += d;
				}
				assert(allocating <= 2 && bytes <= 4096, '$bytes bytes allocated in $allocating previews');
			});
		}
	});
}
