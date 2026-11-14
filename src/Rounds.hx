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

	// per hole: its name, then its shots (dx, dz, speed[, wait]), holed in that many strokes
	public static final rounds:Array<{hole:String, shots:Array<Array<Float>>}> = [
		{hole: "First Putt", shots: [[0, -1, 3.6], [-0.1564, -0.9877, 2.268]]},
		{hole: "The Bend", shots: [[0, -1, 3.55], [0.9944, 0.1059, 3.55]]},
		{hole: "Uphill", shots: [[-0.3663, -0.9305, 6.88], [0.8331, -0.5532, 0.99]]},
		{hole: "Pinball", shots: [[-0.6631, -0.7485, 5.36]]},
		{hole: "Sandy Shortcut", shots: [[-0.4719, -0.8816, 6.88], [0.994, 0.1097, 3.46]]},
		{hole: "Terraces", shots: [[-0.5206, -0.8538, 6.88], [0.6494, -0.7604, 6.69]]},
		{hole: "The Leap", shots: [[-0.0749, -0.9972, 6.88]]},
		{hole: "Carom", shots: [[-0.3663, -0.9305, 5.55], [0.2331, -0.9725, 4.214]]},
		{hole: "Hilltop Hop", shots: [[0.6884, -0.7254, 6.5], [-0.7287, -0.6849, 4.77]]},
		{hole: "Booster Run", shots: [[-0.0125, -0.9999, 6.69], [-0.546, -0.8378, 1.99]]},
		{hole: "Lift Off", shots: [[0, -1, 4.41, 0], [-0.6816, -0.7317, 6.5]]},
		{hole: "Sliders", shots: [[-0.2836, -0.959, 6.69]]},
		{hole: "Turnstile", shots: [[-0.512, -0.859, 6.5]]},
		{hole: "Roundabout", shots: [[-0.6052, -0.7961, 6.88], [0.8165, 0.5773, 2.7]]},
		{hole: "Crosswind", shots: [[-0.1741, -0.9847, 6.31]]},
		{hole: "Gearbox", shots: [[-0.4573, -0.8893, 6.88]]},
		{hole: "Updraft", shots: [[0.4447, -0.8957, 6.88], [0.5, -0.866, 3.12]]},
		{hole: "Clockwork", shots: [[0, -1, 4.41, 0], [0.809, -0.5878, 6.69], [0.4777, 0.8785, 3.38]]},
		{hole: "Skipping Stone", shots: [[-0.0749, -0.9972, 6.5]]},
		{hole: "Wormhole", shots: [[0.4003, -0.9164, 5.74], [0.4688, -0.8833, 1.99]]},
		{hole: "Lantern Falls", shots: [[0.6691, -0.7431, 5.17], [0.4772, -0.8788, 2.89], [-0.9751, 0.2219, 1.156]]},
		{hole: "Mirror Pools", shots: [[-0.4305, -0.9026, 5.74], [0.5043, -0.8635, 3.102]]},
		{hole: "Flip Switch", shots: [[-0.3434, -0.9392, 6.0], [0.5664, 0.8241, 6.31], [-0.2433, -0.9699, 1.434]]},
		{hole: "Two Doors", shots: [[-0.5249, -0.8512, 3.65], [0.7606, -0.6492, 6.88], [-0.6395, -0.7688, 3.84]]},
		{hole: "Brittle Bridge", shots: [[0.1658, -0.9862, 4.6], [0.4326, 0.9016, 6.88], [-0.5261, -0.8504, 1.18]]},
		{hole: "Lockstep", shots: [[-0.5851, -0.811, 4.41], [-0.5661, -0.8244, 5.17]]},
		{hole: "Moonrise", shots: [[0, -1, 5], [0.7071, 0.7071, 5.55], [0.1976, -0.9803, 6.12], [0.6317, -0.7752, 3.658]]},
		{hole: "First Frost", shots: [[-0.5438, -0.8392, 3.08], [-0.2132, -0.977, 1.434]]},
		{hole: "Ice Rink", shots: [[0.6771, -0.7359, 5.74], [0.5016, -0.8651, 1.156]]},
		{hole: "Curling", shots: [[0.2334, -0.9724, 4.03], [0.5906, -0.8069, 1.712]]},
		{hole: "Frozen Portal", shots: [[0.4003, -0.9164, 6.69], [0.4714, -0.8819, 2.268]]},
		{hole: "Snowgate", shots: [[0.9333, -0.3592, 2.7], [-0.2661, -0.9639, 6.16]]},
		{hole: "Glacier Slide", shots: [[-0.0625, -0.998, 4.98], [0.3899, -0.9209, 2.268]]},
		{hole: "Thin Ice", shots: [[-0.4123, -0.911, 3.46], [0.9833, 0.1822, 1.94], [-0.1002, -0.995, 2.268]]},
		{hole: "Icefall", shots: [[0.5, -0.866, 6.31], [-0.4462, -0.8949, 1.434]]},
		{hole: "Aurora Summit", shots: [[0, -1, 5.55], [-0.5664, -0.8241, 3.46], [0.6691, -0.7431, 5.55], [0.3227, -0.9465, 2.546]]}
	];

	// a hole's recorded shots (null: none, or no such hole)
	public static function of(index:Int):Null<Array<Array<Float>>> {
		var hole = Course.hole(index);
		if (hole == null) return null;
		for (r in rounds)
			if (r.hole == hole.name) return r.shots;
		return null;
	}

	// a hole's index by its name (-1: none)
	public static function indexOf(name:String):Int {
		for (i in 0...Course.holes.length)
			if (Course.holes[i].name == name) return i;
		return -1;
	}

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
