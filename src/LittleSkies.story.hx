import helder.story.Story;
import helder.ui.Clock;
import helder.view.View;

// Little Skies' screenshots, for the stores and helder.run alike
// (store: true: helder publish --screenshots at the stores' sizes with
// their captions, helder publish --run at a window's without): each the
// game's own screen (LittleSkies.view) on a hole, its recorded round played
// (Rounds) or an aim held, the game stepped on the story's clock frame
// by frame (Controls.play) to its moment, then settled. In this order on
// helder.run's page. In the studio each runs live.
// (Turnstile: Google Play's feature graphic too, feature: true)
final turnstile = story({
	name: "Holes/Turnstile",
	store: true,
	caption: "Eighteen holes, three islands",
	feature: true,
	render: c -> round(c, "Turnstile")
});

final roundabout = story({
	name: "Holes/Roundabout",
	store: true,
	caption: "See each shot's path",
	render: c -> aim(c, "Roundabout", 0.18, -1, 0.8)
});

final brittle = story({name: "Holes/Brittle Bridge", store: true, caption: "Bridges that crumble", render: c -> round(c, "Brittle Bridge")});

final booster = story({name: "Holes/Booster Run", store: true, caption: "Boosters up the slopes", render: c -> round(c, "Booster Run")});

final moonrise = story({name: "Holes/Moonrise", store: true, caption: "Portals and switches", render: c -> round(c, "Moonrise")});

final pinball = story({name: "Holes/Pinball", store: true, caption: "Bumpers that kick back", render: c -> round(c, "Pinball")});

final skipping = story({name: "Holes/Skipping Stone", store: true, caption: "Sink it in one", render: c -> round(c, "Skipping Stone")});

// (the moment: seconds into the hole)
private final MOMENT = 4.0;

// a hole (by its name) with its recorded round playing
private function round(c:Controls, name:String):View {
	var g = game(c);
	var i = Rounds.indexOf(name);
	g.demo(i, Rounds.of(i));
	return LittleSkies.view(g);
}

// a hole (by its name) with an aim held: its direction (dx, dz) and power (0 to 1), the path shown
private function aim(c:Controls, name:String, dx:Float, dz:Float, power:Float):View {
	var g = game(c);
	g.holdAim(Rounds.indexOf(name), dx, dz, power);
	return LittleSkies.view(g);
}

// a game of the story's own on its clock, silent, played to the moment (let go with the story)
private function game(c:Controls):Game {
	LittleSkies.fonts();
	Sounds.silent = true;
	var g = new Game();
	c.onDispose(g.dispose);
	Clock.add(t -> {
		g.frame(t);
		true;
	});
	c.play(MOMENT);
	return g;
}
