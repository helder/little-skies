import helder.test.Test;

// The course's own data, what its unchecked reads rest on: every hole's
// world is one of Course.worlds (so Course.worlds[hole.world] is never past
// the end), each world has holes, and Course.world and Course.hole are null
// past either end (an index that can run off, the next island's on the
// hole-in card, reads through them).
@:nullSafety(Strict) function tests() {
	describe("the course", () -> {
		test("every hole's world is a world", () -> {
			for (h in Course.holes)
				assert(h.world >= 0 && h.world < Course.worlds.length, '${h.name}: world ${h.world}');
		});
		test("every world has holes", () -> {
			for (w in 0...Course.worlds.length)
				assert(Course.holesOf(w).length > 0, '${Course.worlds[w].name} has no holes');
		});
		test("past either end, no world and no hole", () -> {
			equals(Course.world(-1), null);
			equals(Course.world(Course.worlds.length), null);
			equals(Course.hole(-1), null);
			equals(Course.hole(Course.holes.length), null);
			assert(Course.world(Course.worlds.length - 1) != null);
			assert(Course.hole(Course.holes.length - 1) != null);
		});
	});
}
