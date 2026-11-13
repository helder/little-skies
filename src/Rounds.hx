import Course.Hole;

// The recorded rounds: for every hole, shots that hole it at or under par,
// each a direction, a speed and how long to wait once the ball rests
// (steps of Sim.DT; WAIT when left out: the stories wait as long), played
// as the game takes its steps. The physics has no trigonometry or
// transcendental functions in a step, so the same shots give the same
// result natively and as wasm32-wasi: the tests (Rounds.test.hx) replay
// them on both, the stories (LittleSkies.story.hx) play them in the game.
class Rounds {
	public static inline var WAIT = 60;

	// per hole: its index, then its shots (dx, dz, speed[, wait]), holed in that many strokes
	public static final rounds:Array<{hole:Int, shots:Array<Array<Float>>}> = [
		{hole: 0, shots: [[0, -1, 4.4]]},
		{hole: 1, shots: [[0, -1, 3.55], [0.9944, 0.1059, 3.55]]},
		{hole: 2, shots: [[-0.3074, -0.9516, 6.88]]},
		{hole: 3, shots: [[-0.6631, -0.7485, 5.36]]},
		{hole: 4, shots: [[-0.4719, -0.8816, 6.88], [0.994, 0.1097, 3.46]]},
		{hole: 5, shots: [[-0.0749, -0.9972, 6.88]]},
		{hole: 6, shots: [[-0.2836, -0.959, 6.69]]},
		{hole: 7, shots: [[-0.512, -0.859, 6.5]]},
		{hole: 8, shots: [[-0.1741, -0.9847, 6.31]]},
		{hole: 9, shots: [[0, -1, 6.88], [-0.6816, -0.7317, 0.99]]},
		{hole: 10, shots: [[0, -1, 4.41, 0], [-0.6816, -0.7317, 6.5]]},
		{hole: 11, shots: [[-0.6052, -0.7961, 6.88], [0.8165, 0.5773, 2.7]]},
		{hole: 12, shots: [[-0.0749, -0.9972, 6.5]]},
		{hole: 13, shots: [[-0.0976, -0.9952, 4.6]]},
		{hole: 14, shots: [[-0.3456, -0.9384, 5.55], [0.6954, -0.7187, 4.98]]},
		{hole: 15, shots: [[0.1658, -0.9862, 4.6], [0.4326, 0.9016, 6.88], [-0.5261, -0.8504, 1.18]]},
		{hole: 16, shots: [[-0.5249, -0.8512, 3.65], [0.7606, -0.6492, 6.88], [-0.6395, -0.7688, 3.84]]},
		{hole: 17, shots: [[0.0311, -0.9995, 4.98], [0.1353, -0.9908, 6.88], [0.6912, 0.7227, 6.88], [0.1045, -0.9945, 2.51]]}
	];

	// a shot's wait: steps at rest before it is played
	public static function waitOf(shot:Array<Float>):Int
		return shot.length > 3 ? Std.int(shot[3]) : WAIT;

	// the shots played in turn, each when the ball has rested its wait; at most 20 s a shot
	public static function replay(hole:Hole, shots:Array<Array<Float>>):{sim:Sim, bytes:Float, allocating:Int} {
		var sim = new Sim(hole);
		var bytes = 0.0, allocating = 0;
		function run(limit:Int) {
			var n = 0;
			// (the physics' buffers grow to the hole's size: its bodies at the
			// first step, the contacts and pairs at the most there have been)
			while (!sim.sunk && n < limit) {
				var before = hxmc.GcStats.bytesAllocated();
				sim.step();
				var d = hxmc.GcStats.bytesAllocated() - before;
				if (d > 0) allocating++;
				bytes += d;
				n++;
				if (limit > 1000 && sim.resting) break;
			}
		}
		for (s in shots) {
			if (sim.sunk) break;
			// (resting: its wait, then the shot)
			run(waitOf(s));
			if (!sim.resting) run(20 * 120);
			sim.shoot(s[0], s[1], s[2]);
			run(20 * 120);
		}
		return {sim: sim, bytes: bytes, allocating: allocating};
	}
}
