import Course.Hole;

// Tools for making holes and their recorded rounds, run on the simulation
// alone (no window):
//
//   helder run src/Shots.hx -- tune                    how far a shot rolls on a flat green, by speed
//   helder run src/Shots.hx -- preview N dx dz speed   the aim's preview of a shot from hole N's tee (Aim)
//   helder run src/Shots.hx -- trace N '[[dx, dz, speed], ...]'
//                                                      the ball's way through the shots, every quarter second
//   helder run src/Shots.hx -- search N ['[shots]'] [x z] [wide]
//                                                      after the shots given, the next shots that hole hole N
//                                                      (1-based); else those ending nearest x, z (the cup)
//   search ... waits=60,0                             each shot tried after these waits (steps at rest)
class Shots {
	static function main() {
		var args = Sys.args();
		switch args[0] {
			case "tune": tune();
			case "search": search(args.slice(1));
			case "trace": follow(Std.parseInt(args[1]) - 1, haxe.Json.parse(args[2]));
			case "preview": preview(Std.parseInt(args[1]) - 1, Std.parseFloat(args[2]), Std.parseFloat(args[3]), Std.parseFloat(args[4]));
			case _:
				Sys.println("Shots tune | preview N dx dz speed | trace N shots | search N [shots] [x z] [wide]");
				Sys.exit(2);
		}
	}

	static function fmt(f:Float):String
		return Std.string(Math.round(f * 10000) / 10000);

	// the aim's preview of a shot from the tee: where it bounces first, where and why it ends
	static function preview(index:Int, dx:Float, dz:Float, speed:Float) {
		var sim = new Sim(Course.holes[index]), aim = new Aim(sim);
		aim.predict(sim, dx, dz, speed);
		var ends = ["rest", "length", "blocker", "portal", "off", "cup", "steps"];
		aim.at(aim.length);
		Sys.println('${aim.ran} steps, ${aim.count} points, first bounce at ${fmt(aim.bounce)} m, fading from ${fmt(aim.fadeFrom)} m, ends at ${fmt(aim.length)} m (${fmt(aim.px)} ${fmt(aim.py)} ${fmt(aim.pz)}): ${ends[aim.ending]}');
	}

	static function tune() {
		var hole:Hole = {name: "flat", world: 0, par: 1, tee: {x: 0, y: 0, z: 0}, cup: {x: 100, y: 0, z: 100}, pieces: [Course.Piece.Flat(0, -15, 4, 40, 0)]};
		var speed = 0.6;
		while (speed <= 7.01) {
			var sim = new Sim(hole);
			sim.shoot(0, -1, speed);
			var n = 0;
			while (!sim.resting && n++ < 30 * 120)
				sim.step();
			Sys.println('speed ${fmt(speed)}: ${fmt(-sim.ball.position.z)} m in ${fmt(n / 120)} s');
			speed += 0.4;
		}
	}

	// the ball's way through the shots given, every quarter second
	static function follow(index:Int, shots:Array<Array<Float>>) {
		var hole = Course.holes[index];
		for (n in 0...shots.length + 1) {
			var sim = Rounds.replay(hole, shots.slice(0, n)).sim;
			var p = sim.ball.position;
			Sys.println('after ${n}: ${fmt(p.x)} ${fmt(p.y)} ${fmt(p.z)}, ${sim.strokes} strokes, step ${sim.steps}${sim.sunk ? ", holed" : ""}, gates ${sim.gateOpen}');
		}
		var sim = new Sim(hole);
		var k = 0;
		for (s in shots) {
			var w = Rounds.waitOf(s);
			for (_ in 0...w) sim.step();
			while (!sim.resting) sim.step();
			sim.shoot(s[0], s[1], s[2]);
			var n = 0;
			while (!sim.sunk && n < 20 * 120 && !(n > 2 && sim.resting)) {
				sim.step();
				if (n % 30 == 0) {
					var p = sim.ball.position, v = sim.ball.velocity;
					Sys.println('  shot $k t ${fmt(n / 120)}: ${fmt(p.x)} ${fmt(p.y)} ${fmt(p.z)} v ${fmt(v.x)} ${fmt(v.y)} ${fmt(v.z)}${sim.grounded ? " ground" : ""} area ${sim.area}');
				}
				n++;
			}
			k++;
		}
	}

	// a grid of directions and speeds after the shots given: those that hole it, else the nearest to a point
	static function search(all:Array<String>) {
		var args = all.filter(a -> a != "wide" && !StringTools.startsWith(a, "waits="));
		var index = Std.parseInt(args[0]) - 1;
		var hole = Course.holes[index];
		var prefix:Array<Array<Float>> = args.length > 1 && args[1] != "" ? haxe.Json.parse(args[1]) : [];
		var tx = args.length > 3 ? Std.parseFloat(args[2]) : hole.cup.x, tz = args.length > 3 ? Std.parseFloat(args[3]) : hole.cup.z;
		var wide = all.indexOf("wide") >= 0;
		var start = Rounds.replay(hole, prefix).sim;
		var p = start.ball.position;
		Sys.println('from ${fmt(p.x)} ${fmt(p.y)} ${fmt(p.z)}, ${start.strokes} strokes${start.sunk ? ", holed" : ""}');
		var base = Math.atan2(tx - p.x, -(tz - p.z));
		var found = 0;
		var best:Array<{d:Float, s:String}> = [];
		var angles = wide ? 240 : 121;
		var given = Lambda.find(all, a -> StringTools.startsWith(a, "waits="));
		var waits = [for (w in (given == null ? "60" : given.substr(6)).split(",")) Std.parseInt(w)];
		for (wait in waits)
		for (ai in 0...angles) {
			var a = wide ? ai * Math.PI * 2 / angles : base + (ai - 60) * 0.0125;
			for (si in 0...33) {
				var speed = Math.round((0.8 + si * 0.19) * 100) / 100;
				var dx = Math.round(Math.sin(a) * 10000) / 10000, dz = Math.round(-Math.cos(a) * 10000) / 10000;
				var shot = wait == Rounds.WAIT ? [dx, dz, speed] : [dx, dz, speed, wait];
				var res = Rounds.replay(hole, prefix.concat([shot]));
				var s = haxe.Json.stringify(shot);
				if (res.sim.sunk && res.sim.strokes == prefix.length + 1) {
					Sys.println('holed: $s');
					if (++found > 10) return;
				} else if (res.sim.strokes == prefix.length + 1) {
					var q = res.sim.ball.position;
					var d = Math.sqrt((q.x - tx) * (q.x - tx) + (q.z - tz) * (q.z - tz));
					best.push({d: d, s: '$s -> ${fmt(q.x)} ${fmt(q.y)} ${fmt(q.z)}'});
				}
			}
		}
		if (found > 0) return;
		best.sort((a, b) -> a.d < b.d ? -1 : a.d > b.d ? 1 : 0);
		Sys.println("none holed; nearest:");
		for (i in 0...Std.int(Math.min(10, best.length)))
			Sys.println('  ${fmt(best[i].d)} m: ${best[i].s}');
	}
}
