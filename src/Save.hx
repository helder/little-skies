import Course.Hole;
import helder.os.Store;

// The save: best strokes per hole (0: not finished yet), kept between runs
// in helder.os's Store ("little-skies": a file in the app's data
// directory, localStorage on the web), by the holes' names, as "scores" =
// "First Putt=2;The Bend=3;...", so holes added or moved keep their bests
// (a hole reworked is renamed: its old best dropped). The first version
// kept "best" = "3,2,0,..." in the eighteen holes' order then (LEGACY):
// read when there are no scores yet.
class Save {
	static final LEGACY = [
		"First Putt", "The Bend", "Uphill", "Pinball", "Sandy Shortcut", "The Leap", "Sliders", "Turnstile", "Crosswind", "Booster Run", "Lift Off",
		"Roundabout", "Skipping Stone", "Wormhole", "Flip Switch", "Brittle Bridge", "Two Doors", "Moonrise"
	];

	final store:Null<Store>;

	public function new() {
		store = try Store.open("little-skies") catch (_:Dynamic) null;
	}

	public function best(holes:Array<Hole>):Array<Int> {
		var byName = new Map<String, Int>();
		var text = store == null ? null : store.get("scores");
		if (text != null) {
			for (part in text.split(";")) {
				var eq = part.lastIndexOf("=");
				if (eq > 0) byName.set(part.substr(0, eq), Std.parseInt(part.substr(eq + 1)) ?? 0);
			}
		} else {
			var old = store == null ? null : store.get("best");
			var parts = old == null ? [] : old.split(",");
			for (i in 0...Std.int(Math.min(parts.length, LEGACY.length)))
				byName.set(LEGACY[i], Std.parseInt(parts[i]) ?? 0);
		}
		return [for (h in holes) byName.get(h.name) ?? 0];
	}

	public function write(holes:Array<Hole>, best:Array<Int>)
		if (this.store != null) this.store.set("scores", [for (i in 0...holes.length) if (best[i] > 0) holes[i].name + "=" + best[i]].join(";"));
}
