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
//   search ... near                                  the shots ending nearest x, z even when some hole it
//   search ... waits=60,0                             each shot tried after these waits (steps at rest)
//   helder run src/Shots.hx -- survey N [M ...]       how hard hole N is: the share of shots from the tee
//                                                      holing it in one, the strokes a player aiming at
//                                                      the cup alone takes, how far each of the recorded
//                                                      round's shots may be off (degrees, speed) and still
//                                                      hole it at par
//   helder run src/Shots.hx -- finish N '[shots]'      after the shots, the steadiest putt holing it
//   helder run src/Shots.hx -- noisy N [trials] [skill]
//                                                      a player playing the recorded round with a hand's
//                                                      errors (aim 1.5 degrees, speed 4%, timing 0.07 s, times
//                                                      skill), each time a putt can hole it the steadiest
//                                                      such putt instead: how often it makes par
class Shots {
	static function main() {
		var args = Sys.args();
		switch args[0] {
			case "tune": tune();
			case "search": search(args.slice(1));
			case "trace": follow(number(args[1]), haxe.Json.parse(args[2]));
			case "noisy": noisy(number(args[1]), args.length > 2 ? Std.parseInt(args[2]) ?? 24 : 24, args.length > 3 ? Std.parseFloat(args[3]) : 1.0);
			case "finish":
				var hole = Course.holes[number(args[1])];
				var prefix:Array<Array<Float>> = args.length > 2 && args[2] != "" ? haxe.Json.parse(args[2]) : [];
				var base = Rounds.replay(hole, prefix).sim;
				var shot = steadiest(base, new Sim(hole), base.strokes + 1, Rounds.WAIT);
				Sys.println(shot == null ? "none" : haxe.Json.stringify([for (i in 0...3) Math.round(shot[i] * 10000) / 10000]));
			case "survey": for (a in args.slice(1)) survey(number(a));
			case "preview": preview(number(args[1]), Std.parseFloat(args[2]), Std.parseFloat(args[3]), Std.parseFloat(args[4]));
			case _:
				Sys.println("Shots tune | preview N dx dz speed | trace N shots | search N [shots] [x z] [wide]");
				Sys.exit(2);
		}
	}

	// a hole's index by its number on the command line (1 the first)
	static function number(arg:String):Int {
		var n = Std.parseInt(arg);
		if (n == null || Course.hole(n - 1) == null) throw 'no hole "$arg" (1 to ${Course.holes.length})';
		return n - 1;
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
		var args = all.filter(a -> a != "wide" && a != "near" && !StringTools.startsWith(a, "waits="));
		var index = number(args[0]);
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
				if (res.sim.sunk && res.sim.strokes == prefix.length + 1 && all.indexOf("near") < 0) {
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

	// whether shots hole the hole within strokes (and the sim after them)
	static function holes(hole:Hole, shots:Array<Array<Float>>, strokes:Int):Bool {
		var sim = Rounds.replay(hole, shots).sim;
		return sim.sunk && sim.strokes <= strokes;
	}

	// after prefix, one shot holing it (null: none found): near the line to the cup, then all round
	static function finish(hole:Hole, prefix:Array<Array<Float>>, strokes:Int):Null<Array<Float>> {
		var start = Rounds.replay(hole, prefix).sim;
		if (start.sunk) return start.strokes <= strokes ? [] : null;
		if (start.strokes >= strokes) return null;
		var p = start.ball.position;
		var base = Math.atan2(hole.cup.x - p.x, -(hole.cup.z - p.z));
		for (pass in 0...2)
			for (ai in 0...(pass == 0 ? 61 : 120)) {
				var a = pass == 0 ? base + (ai - 30) * 0.02 : ai * Math.PI / 60;
				for (si in 0...(pass == 0 ? 33 : 17)) {
					var speed = pass == 0 ? 0.8 + si * 0.19 : 0.8 + si * 0.38;
					var shot = [Math.sin(a), -Math.cos(a), speed];
					if (holes(hole, prefix.concat([shot]), strokes)) return shot;
				}
			}
		return null;
	}

	static function survey(index:Int) {
		var hole = Course.holes[index];
		var round = {shots: Rounds.of(index) ?? []};
		// (aces: a grid all round the tee)
		var aces = 0, tries = 0;
		for (ai in 0...180)
			for (si in 0...34) {
				var a = ai * Math.PI / 90, speed = 0.6 + si * 0.194;
				if (holes(hole, [[Math.sin(a), -Math.cos(a), speed]], 1)) aces++;
				tries++;
			}
		// (the naive player: each shot near the line to the cup, the one ending nearest it)
		var naive:Array<Array<Float>> = [];
		var naiveStrokes = -1;
		for (k in 0...6) {
			var start = Rounds.replay(hole, naive).sim;
			if (start.sunk) {
				naiveStrokes = start.strokes;
				break;
			}
			var p = start.ball.position;
			var base = Math.atan2(hole.cup.x - p.x, -(hole.cup.z - p.z));
			var bestD = 1e9, bestShot:Null<Array<Float>> = null;
			for (ai in 0...21)
				for (si in 0...23) {
					var a = base + (ai - 10) * 1.5 * Math.PI / 180, speed = 0.6 + si * 0.29;
					var shot = [Math.sin(a), -Math.cos(a), speed];
					var sim = Rounds.replay(hole, naive.concat([shot])).sim;
					var q = sim.ball.position;
					var d = sim.sunk ? -sim.strokes : Math.sqrt((q.x - hole.cup.x) * (q.x - hole.cup.x) + (q.y - hole.cup.y) * (q.y - hole.cup.y) + (q.z - hole.cup.z) * (q.z - hole.cup.z)) + sim.strokes * 100;
					if (d < bestD) {
						bestD = d;
						bestShot = shot;
					}
				}
			if (bestShot == null) break;
			naive.push(bestShot);
		}
		if (naiveStrokes < 0) {
			var s = Rounds.replay(hole, naive).sim;
			naiveStrokes = s.sunk ? s.strokes : 99;
		}
		Sys.println('hole ${index + 1} ${hole.name}: par ${hole.par}, aces ${fmt(aces / tries * 100)}% from the tee, the naive player ${naiveStrokes == 99 ? "never (6+)" : "" + naiveStrokes}');
		if (round == null) return;
		// (each recorded shot turned and sped up or down, the rest replayed; the last remaining stroke re-planned if need be)
		var shots = round.shots;
		for (k in 0...shots.length) {
			function ok(shot:Array<Float>):Bool {
				var list = shots.slice(0, k).concat([shot]);
				var rest = shots.slice(k + 1);
				if (holes(hole, list.concat(rest), hole.par)) return true;
				if (rest.length == 1 && hole.par - k - 1 == 1) return finish(hole, list, hole.par) != null;
				return false;
			}
			var s = shots[k];
			var a0 = Math.atan2(s[0], -s[1]);
			function turned(d:Float):Array<Float> {
				var a = a0 + d * Math.PI / 180;
				var out = [Math.sin(a), -Math.cos(a), s[2]];
				if (s.length > 3) out.push(s[3]);
				return out;
			}
			function sped(f:Float):Array<Float> {
				var out = s.copy();
				out[2] = s[2] * f;
				return out;
			}
			var lo = 0.0, hi = 0.0;
			while (lo > -12 && ok(turned(lo - 0.25))) lo -= 0.25;
			while (hi < 12 && ok(turned(hi + 0.25))) hi += 0.25;
			var slo = 1.0, shi = 1.0;
			while (slo > 0.3 && ok(sped(slo - 0.02))) slo -= 0.02;
			while (shi < 2.5 && s[2] * (shi + 0.02) <= Sim.MAX_SPEED + 0.001 && ok(sped(shi + 0.02))) shi += 0.02;
			Sys.println('  shot ${k + 1} ${haxe.Json.stringify(s)}: ${fmt(lo)}..${fmt(hi)} degrees, speed x${fmt(slo)}..${fmt(shi)}');
		}
	}

	static var seed = 12345;

	static function rand():Float {
		seed = (seed * 1103515245 + 12345) & 0x7fffffff;
		return seed / 0x7fffffff;
	}

	static function gauss():Float {
		var u = Math.max(1e-9, rand()), v = rand();
		return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * v);
	}

	// one shot played on scratch from base's state: its wait at rest, the shot, until it rests (as Rounds.replay plays it); holed within strokes
	static function playOn(scratch:Sim, base:Sim, shot:Array<Float>, strokes:Int):Bool {
		scratch.mirror(base);
		var w = Rounds.waitOf(shot);
		var n = 0;
		while (!scratch.sunk && n < w) {
			scratch.step();
			n++;
		}
		n = 0;
		while (!scratch.resting && !scratch.sunk && n < 20 * 120) {
			scratch.step();
			n++;
		}
		scratch.shoot(shot[0], shot[1], shot[2]);
		n = 0;
		while (!scratch.sunk && n < 20 * 120) {
			scratch.step();
			n++;
			if (scratch.resting || scratch.strokes > strokes) break;
		}
		return scratch.sunk && scratch.strokes <= strokes;
	}

	// the steadiest putt holing it from base within strokes (its neighbours on the grid holing it too), null none
	static function steadiest(base:Sim, scratch:Sim, strokes:Int, wait:Int):Null<Array<Float>> {
		var hole = base.hole;
		if (base.sunk || base.strokes >= strokes) return null;
		var p = base.ball.position;
		var aim = Math.atan2(hole.cup.x - p.x, -(hole.cup.z - p.z));
		var best:Null<Array<Float>> = null, bestScore = 0;
		for (pass in 0...2) {
			var na = pass == 0 ? 41 : 72, ns = pass == 0 ? 24 : 16;
			inline function angle(ai:Int):Float
				return pass == 0 ? aim + (ai - 20) * 0.75 * Math.PI / 180 : ai * Math.PI / 36;
			inline function speedOf(si:Int):Float
				return pass == 0 ? 0.6 + si * 0.278 : 0.6 + si * 0.42;
			var grid = [for (_ in 0...na * ns) false];
			var any = false;
			for (ai in 0...na)
				for (si in 0...ns) {
					var a = angle(ai);
					if (playOn(scratch, base, [Math.sin(a), -Math.cos(a), speedOf(si), wait], strokes)) {
						grid[ai * ns + si] = true;
						any = true;
					}
				}
			if (!any) continue;
			for (ai in 0...na)
				for (si in 0...ns) {
					if (!grid[ai * ns + si]) continue;
					var score = 0;
					for (da in -2...3)
						for (ds in -1...2) {
							var aj = ai + da, sj = si + ds;
							if (pass == 1) aj = (aj + na) % na;
							if (aj >= 0 && aj < na && sj >= 0 && sj < ns && grid[aj * ns + sj]) score++;
						}
					if (score > bestScore) {
						bestScore = score;
						var a = angle(ai);
						best = [Math.sin(a), -Math.cos(a), speedOf(si), wait];
					}
				}
			return best;
		}
		return null;
	}

	// the shot from base ending nearest (x, y, z) with the gates as given (null: any), on a grid toward it and all round
	static function toward(base:Sim, scratch:Sim, x:Float, y:Float, z:Float, gates:Null<Array<Bool>>, wait:Int):Null<Array<Float>> {
		var p = base.ball.position;
		var aim = Math.atan2(x - p.x, -(z - p.z));
		var best:Null<Array<Float>> = null, bestD = 1e18;
		for (pass in 0...2) {
			var na = pass == 0 ? 41 : 72, ns = pass == 0 ? 24 : 16;
			for (ai in 0...na)
				for (si in 0...ns) {
					var a = pass == 0 ? aim + (ai - 20) * 0.75 * Math.PI / 180 : ai * Math.PI / 36;
					var sp = pass == 0 ? 0.6 + si * 0.278 : 0.6 + si * 0.42;
					var shot = [Math.sin(a), -Math.cos(a), sp, wait];
					var holed = playOn(scratch, base, shot, base.strokes + 1);
					var q = scratch.ball.position;
					var d = (q.x - x) * (q.x - x) + (q.y - y) * (q.y - y) * 4 + (q.z - z) * (q.z - z);
					if (holed) d = -1;
					if (scratch.strokes > base.strokes + 1) d += 100;
					if (gates != null)
						for (g in 0...gates.length)
							if (scratch.gateOpen[g] != gates[g]) d += 50;
					if (d < bestD) {
						bestD = d;
						best = shot;
					}
				}
		}
		return best;
	}

	static function noisy(index:Int, trials:Int, skill:Float) {
		var hole = Course.holes[index];
		var plan = Rounds.of(index) ?? [];
		// (its waypoints are the plan's: none without one)
		if (plan.length == 0) throw 'hole ${index + 1} has no recorded round';
		var moving = false;
		for (pc in hole.pieces)
			switch pc {
				case Mover(_) | Spinner(_) | Lift(_): moving = true;
				case _:
			}
		// (the plan's waypoints: where the ball rests after each of its shots, the gates then)
		var points:Array<{x:Float, y:Float, z:Float, gates:Array<Bool>}> = [];
		for (k in 0...plan.length) {
			var sim = Rounds.replay(hole, plan.slice(0, k + 1)).sim;
			var q = sim.ball.position;
			points.push({x: q.x, y: q.y, z: q.z, gates: sim.gateOpen.copy()});
		}
		var made = 0, total = 0, hist = [for (_ in 0...12) 0];
		for (t in 0...trials) {
			var shots:Array<Array<Float>> = [];
			var next = 0, strokes = 0, onPlan = true;
			while (true) {
				var sim = Rounds.replay(hole, shots).sim;
				if (sim.sunk || sim.strokes >= 10) {
					strokes = sim.sunk ? sim.strokes : 11;
					break;
				}
				// (a waypoint reached: on to the next)
				while (next < points.length - 1) {
					var w = points[next], q = sim.ball.position;
					var near = (q.x - w.x) * (q.x - w.x) + (q.z - w.z) * (q.z - w.z) < 0.5 * 0.5 && Math.abs(q.y - w.y) < 0.15;
					for (g in 0...w.gates.length)
						if (sim.gateOpen[g] != w.gates[g]) near = false;
					if (!near || shots.length <= next) break;
					next++;
				}
				var wait = Rounds.WAIT;
				var scratch = new Sim(hole);
				var shot = steadiest(sim, scratch, sim.strokes + 1, wait);
				if (shot == null) {
					if (onPlan && shots.length < plan.length) shot = plan[shots.length];
					else {
						var w = points[Std.int(Math.min(next, points.length - 1))];
						shot = toward(sim, scratch, w.x, w.y, w.z, w.gates, wait);
					}
				}
				// (no shot at all: given up)
				if (shot == null) {
					strokes = 11;
					break;
				}
				var a = Math.atan2(shot[0], -shot[1]) + gauss() * 1.5 * skill * Math.PI / 180;
				var sp = shot[2] * (1 + gauss() * 0.04 * skill);
				var w = shot.length > 3 ? shot[3] : wait;
				if (moving) w = Math.max(0, Math.round(w + gauss() * 8 * skill));
				shots.push([Math.sin(a), -Math.cos(a), sp, w]);
				// (off the plan once a shot ends elsewhere than its waypoint)
				if (onPlan) {
					var after = Rounds.replay(hole, shots).sim, k = shots.length - 1;
					if (k >= points.length) onPlan = false else {
						var q = after.ball.position, p = points[k];
						if (!after.sunk && (q.x - p.x) * (q.x - p.x) + (q.z - p.z) * (q.z - p.z) > 0.3 * 0.3) onPlan = false;
						if (!after.sunk) next = k + 1;
					}
					if (!onPlan) next = Std.int(Math.min(k, points.length - 1));
				}
			}
			if (strokes <= hole.par) made++;
			total += strokes;
			hist[Std.int(Math.min(11, strokes))]++;
		}
		Sys.println('hole ${index + 1} ${hole.name}: par ${hole.par}, made par ${Math.round(made / trials * 100)}% of ${trials}, mean ${fmt(total / trials)}, strokes ${[for (i in 1...12) if (hist[i] > 0) i + ":" + hist[i]].join(" ")}');
	}
}
