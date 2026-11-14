import helder.scene.view.SceneTags.*;
import helder.ui.Clock;
import helder.ui.StyleSheet;
import helder.ui.Transform;
import helder.ui.draw.UiWindow;
import helder.ui.draw.UiWindow.Surface;
import helder.view.*;
import helder.view.Flow.*;
import helder.view.graph.Graph.*;

// The game's window: the island's sky (a gradient), the <Scene> filling it
// (the course, drawn by helder.scene in half floats with bloom;
// <OrbitControls> for the camera, the shot a gesture of the game's on the
// same box) and the HUD over it in ui's markup, clear of the phone's bars
// (env(safe-area-inset-*)): the title, the hole's card as the camera flies
// over it, the hole and the strokes, a hint, a toast, the card after a
// hole-in (stars, retry, next), the islands' scorecard (stars and best
// strokes, saved) and a curtain between holes. Set in Nunito (the
// numbers, labels, tips and buttons), the title and the holes' names in
// Fredoka (both OFL, fonts/), embedded. The game steps on ui's clock
// (Game.frame), its simulation at a fixed rate. Its screenshots are its
// stories (LittleSkies.story.hx: a hole's
// recorded round played to a moment, or an aim held), the same screen
// (view) in a story's Ui.
class LittleSkies implements Markup {
	static inline var INK = "#2b2d42";
	static inline var MUTED = "#7d8597";
	static inline var STAR = "#ffb703";

	static function main() {
		fonts();
		var game = new Game();
		Clock.add(t -> {
			game.frame(t);
			true;
		});
		UiWindow.run(<Surface title="Little Skies" width={390} height={844} theme={sheet}>
			{view(game)}
		</Surface>);
	}

	static var fontsAdded = false;

	// Nunito and Fredoka added to the system's fonts (once)
	public static function fonts() {
		if (fontsAdded) return;
		fontsAdded = true;
		try helder.text.SystemFonts.get().add(helder.asset.Asset.embed("fonts/Fredoka.ttf")) catch (_:Dynamic) {}
		try helder.text.SystemFonts.get().add(helder.asset.Asset.embed("fonts/Nunito.ttf")) catch (_:Dynamic) {}
	}

	// the game's screen: the island's sky, the <Scene>, the HUD, the curtain
	public static function view(game:Game):View
		return <view grow={1} background={game.sky()} font-family="Nunito" color={INK}>
			<Scene grow={1} world={game.world} camera={game.camera} hdr animate setup={game.setup} ref={game.attach}>
				<OrbitControls ref={game.controls}/>
			</Scene>
			<Hud game={game}/>
			<view position="absolute" left={0} top={0} right={0} bottom={0} pointer-events="none" background={game.sky()}
				opacity={game.curtain() || !game.ready() ? 1.0 : 0.0} transition="opacity 0.28s ease-in-out" align-items="center" justify="center">
				<Show when={!game.ready()}>
					<Loading game={game}/>
				</Show>
			</view>
		</view>;

	// the loading curtain's three dots, pulsing in turn
	static function Loading(props:{game:Game}):View {
		var g = props.game;
		function dot(i:Int):View
			return <view width={10} height={10} radius={5} background={LETTERS[g.island()]}
				opacity={0.25 + 0.6 * Math.max(0, Math.sin(g.pulse() * 5 - i * 0.9))}/>;
		return <view direction="row" column-gap={10}>{dot(0)}{dot(1)}{dot(2)}</view>;
	}

	// (the pop-ins: from small and clear when first drawn, eased by their transition)
	static final sheet:StyleSheet = {
		rules: [
			{slot: "pop", when: ["starting"], style: {opacity: 0, transform: Transform.parse("scale(0.7)")}},
			{slot: "rise", when: ["starting"], style: {opacity: 0, transform: Transform.parse("translate(0, 24px)")}},
			{slot: "drop", when: ["starting"], style: {opacity: 0, transform: Transform.parse("translate(0, -30px)")}},
			{slot: "button", when: ["active"], style: {transform: Transform.parse("scale(0.94)")}},
			{slot: "button", when: ["hover"], style: {opacity: 0.92}},
			{slot: "star", when: ["starting"], style: {opacity: 0, transform: Transform.parse("scale(0.2) rotate(-60deg)")}},
			{slot: "fade", when: ["starting"], style: {opacity: 0}}
		]
	};

	// stars for a hole: 3 at par or better, 2 one over, 1 finished, 0 not yet
	public static function stars(strokes:Int, par:Int):Int
		return strokes <= 0 ? 0 : strokes <= par ? 3 : strokes == par + 1 ? 2 : 1;

	// the stars and the lock, drawn as SVG (a font's ★ is a box on some
	// phones): a star filled in STAR, one outlined in it, a padlock
	static inline var STAR_POINTS = "12,2.2 14.7,9.08 22.08,9.52 16.37,14.22 18.23,21.38 12,17.4 5.77,21.38 7.63,14.22 1.92,9.52 9.3,9.08";
	static final starFull = helder.ui.Svg.parse('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><polygon points="$STAR_POINTS" fill="$STAR" stroke="#f08c00" stroke-width="1.3" stroke-linejoin="round"/><polygon points="12,5.4 13.9,10.2 18.6,10.6 12,12.4" fill="#ffffff" fill-opacity="0.45"/></svg>');
	static final starEmpty = helder.ui.Svg.parse('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><polygon points="$STAR_POINTS" fill="$STAR" fill-opacity="0.12" stroke="$STAR" stroke-width="1.8" stroke-linejoin="round"/></svg>');
	static final lock = helder.ui.Svg.parse('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M7.5 10.5V8a4.5 4.5 0 0 1 9 0v2.5" fill="none" stroke="#9aa0b0" stroke-width="2.4" stroke-linecap="round"/><rect x="4.5" y="10" width="15" height="11" rx="3" fill="#9aa0b0"/><circle cx="12" cy="15.2" r="1.7" fill="#ffffff"/></svg>');

	// n of three stars (filled, then outlined), size points each
	static function Stars(props:{n:Int, size:Float, ?gap:Float}):View
		return <view direction="row" column-gap={props.gap ?? 1} align-items="center">
			{[for (i in 0...3) <image width={props.size} height={props.size} src={props.n > i ? starFull : starEmpty}/>]}
		</view>;

	// a star and a count beside it
	static function StarCount(props:{text:String, ?size:Float, ?color:String}):View
		return <view direction="row" align-items="center" column-gap={4}>
			<image width={props.size ?? 16} height={props.size ?? 16} src={starFull}/>
			<text font-size={Math.round((props.size ?? 16) * 0.9)} font-weight={700} color={props.color ?? INK}>{props.text}</text>
		</view>;

	// stars won on a world's holes (of 3 a hole)
	static function worldStars(best:Array<Int>, w:Int):Int {
		var s = 0;
		for (i in Course.holesOf(w))
			s += stars(best[i], Course.holes[i].par);
		return s;
	}

	static function totalStars(best:Array<Int>):Int {
		var s = 0;
		for (i in 0...Course.holes.length)
			s += stars(best[i], Course.holes[i].par);
		return s;
	}

	// the name of a score against par
	static function verdict(strokes:Int, par:Int):String
		return if (strokes == 1) "Hole in one!" else switch strokes - par {
			case -3: "Albatross!";
			case -2: "Eagle!";
			case -1: "Birdie!";
			case 0: "Par";
			case 1: "Bogey";
			case 2: "Double bogey";
			case d: '+$d';
		}

	static function powerColor(p:Float):String
		return p < 0.6 ? "#ffd166" : p < 0.9 ? "#f4a261" : "#ff6b6b";

	static function hex(c:Int):String
		return "#" + StringTools.hex(c, 6);

	static function accent(i:Int):String
		return hex(Course.worlds[Course.holes[i].world].accent);

	static function deep(i:Int):String
		return hex(Course.worlds[Course.holes[i].world].deep);

	static function Button(props:{label:String, onPress:Void->Void, ?tag:String, ?primary:Bool, ?color:String, ?wide:Bool}):View {
		var bg = props.primary == true ? (props.color ?? "#ff6b6b") : "#ffffff";
		return <view:button tag={props.tag} slot="button" role="button" focusable pointer-events="auto" cursor="pointer" padding="13 24" radius={24}
			min-width={props.wide == true ? 180 : 0} align-items="center" background={bg} color={props.primary == true ? "#ffffff" : INK} font-size={17}
			font-weight={700} shadow="0 4 14 #2b2d4230" transition="transform 0.12s ease-out" onPress={props.onPress}>{props.label}</view:button>;
	}

	static function Hud(props:{game:Game}):View {
		var g = props.game;
		var hole = memo(() -> Course.holes[g.holeIndex()]);
		var world = memo(() -> Course.worlds[hole().world]);
		return <view position="absolute" left={0} top={0} right={0} bottom={0} pointer-events="none"
			padding-top="calc(env(safe-area-inset-top) + 12px)" padding-bottom="calc(env(safe-area-inset-bottom) + 16px)"
			padding-left="max(14px, env(safe-area-inset-left))" padding-right="max(14px, env(safe-area-inset-right))">
			<Show when={g.screen() == "play" || g.screen() == "done"}>
				<view direction="row" align-items="flex-start" justify="space-between" column-gap={8}>
					<view:button tag="menu" slot="button" role="button" focusable pointer-events="auto" cursor="pointer" direction="row" align-items="center"
						column-gap={10} padding="6 14 6 6" radius={24} background="#ffffffe0" shadow="0 3 10 #2b2d4224" transition="transform 0.12s ease-out"
						onPress={g.openMenu}>
						<view width={36} height={36} radius={18} background={accent(g.holeIndex())} align-items="center" justify="center">
							<text font-size={18} font-weight={700} color="#ffffff">{"" + (g.holeIndex() + 1)}</text>
						</view>
						<view>
							<text font-size={11} font-weight={600} color={MUTED} letter-spacing={1}>{world().name.toUpperCase()}</text>
							<text font-size={17} font-weight={500} font-family="Fredoka">{hole().name}</text>
						</view>
					</view:button>
					<view tag="score" direction="row" column-gap={14} padding="6 16" radius={24} background="#ffffffe0" shadow="0 3 10 #2b2d4224">
						<view align-items="center">
							<text font-size={11} font-weight={600} color={MUTED} letter-spacing={1}>PAR</text>
							<text font-size={20} font-weight={600}>{"" + hole().par}</text>
						</view>
						<view width={1} background="#2b2d421c"/>
						<view align-items="center">
							<text font-size={11} font-weight={600} color={MUTED} letter-spacing={1}>STROKES</text>
							<text tag="strokes" font-size={20} font-weight={600} color={g.strokes() > hole().par ? "#e76f51" : INK}>{"" + g.strokes()}</text>
						</view>
					</view>
				</view>
			</Show>
			<view grow={1} align-items="center" justify="center">
				<Show when={g.toast() != ""}>
					<text tag="toast" slot="pop" transition="opacity 0.2s ease-out, transform 0.25s ease-out" font-size={18} font-weight={600} color="#ffffff"
						padding="10 20" radius={22} background="#2b2d42c0">{g.toast()}</text>
				</Show>
			</view>
			<Show when={g.screen() == "done"}>
				<view align-items="center"><Done game={g}/></view>
			</Show>
			<Show when={g.screen() == "play"}>
				<view align-items="center" row-gap={8}>
					<Show when={g.card()}>
						<HoleCard game={g}/>
					</Show>
					<Show when={g.shots() == 0 && !g.aiming() && !g.card()}>
						<text tag="hint" font-size={15} font-weight={500} padding="9 18" radius={18} background="#ffffffd0">Drag back from the ball, let go to shoot</text>
					</Show>
				</view>
			</Show>
			<Show when={g.screen() == "play" && g.aiming()}>
				<view tag="power" position="absolute" left={g.readX() - 30} top={g.readY() - 14} width={60} height={28} radius={14} background="#2b2d42d9"
					align-items="center" justify="center" shadow="0 2 8 #2b2d4230">
					<text font-size={15} font-weight={700} color={powerColor(g.power())}>{Math.round(g.power() * 100) + "%"}</text>
				</view>
			</Show>
			<Show when={g.screen() == "title" && !g.ready()}>
				<Title game={g}/>
			</Show>
			<Show when={g.screen() == "title" && g.ready()}>
				<Title game={g}/>
			</Show>
			<Show when={g.screen() == "menu"}>
				<Menu game={g}/>
			</Show>
		</view>;
	}

	// the title's lockup (brand/: the island over "little / skies", in each
	// island's colours) and the haze of the island's sky behind it, so a far
	// island or the course's far end never runs through the letters
	static final lockups = [for (w in ["meadowdrift", "copperwind", "lanternwater", "frostglass"]) svg(w)];
	static final hazes = [
		helder.ui.Svg.parse(helder.asset.Asset.embed("brand/title-haze-meadowdrift.svg").toString()),
		helder.ui.Svg.parse(helder.asset.Asset.embed("brand/title-haze-copperwind.svg").toString()),
		helder.ui.Svg.parse(helder.asset.Asset.embed("brand/title-haze-lanternwater.svg").toString()),
		helder.ui.Svg.parse(helder.asset.Asset.embed("brand/title-haze-frostglass.svg").toString())
	];
	// the letters' colour on each island's sky (the loading dots')
	static final LETTERS = ["#27314f", "#55263a", "#fff3df", "#1f3566"];
	// the lockup's size (brand/title-*.svg's viewBox)
	static inline var LOCKUP_W = 428.7;
	static inline var LOCKUP_H = 549.2;

	static function svg(island:String):helder.ui.Svg
		return switch island {
			case "meadowdrift": helder.ui.Svg.parse(helder.asset.Asset.embed("brand/title-meadowdrift.svg").toString());
			case "copperwind": helder.ui.Svg.parse(helder.asset.Asset.embed("brand/title-copperwind.svg").toString());
			case "frostglass": helder.ui.Svg.parse(helder.asset.Asset.embed("brand/title-frostglass.svg").toString());
			case _: helder.ui.Svg.parse(helder.asset.Asset.embed("brand/title-lanternwater.svg").toString());
		}

	// the title over the hole turning slowly behind it: the lockup centred,
	// on its side about 38% of the screen's height with its top 4% down, upright
	// 61% of its width, 9% down (drawn first behind the loading curtain, its
	// glyphs and pictures made, then again once ready: its entrance smooth)
	static function Title(props:{game:Game}):View {
		var g = props.game;
		var total = memo(() -> totalStars(g.best()));
		var height = memo(() -> Math.round(g.wide() ? g.height() * 0.38 : g.width() * 0.61 * LOCKUP_H / LOCKUP_W));
		var width = memo(() -> Math.round(height() * LOCKUP_W / LOCKUP_H));
		var top = memo(() -> Math.round(g.height() * (g.wide() ? 0.04 : 0.09)));
		return <view tag="title" position="absolute" left={0} top={0} right={0} bottom={0} pointer-events="none" align-items="center" justify="space-between"
			padding-top="env(safe-area-inset-top)" padding-bottom="calc(env(safe-area-inset-bottom) + 48px)" padding-left={20} padding-right={20}>
			<view slot="drop" transition="opacity 0.5s ease-out, transform 0.6s ease-out" align-items="center" padding-top={top()}>
				<view tag="lockup" width={width()} height={height()}>
					<image position="absolute" left={-width() / 2} top={-height() * 0.35} width={width() * 2} height={height() * 1.7} src={hazes[g.island()]}/>
					<image position="absolute" left={0} top={0} width={width()} height={height()} src={lockups[g.island()]}/>
				</view>
			</view>
			<view slot="rise" transition="opacity 0.5s ease-out, transform 0.6s ease-out" align-items="center" row-gap={12}>
				<Button tag="play" label={g.best()[0] > 0 ? "Play hole " + (g.holeIndex() + 1) : "Play"} primary wide onPress={g.start}/>
				<Button tag="holes" label="Holes" wide onPress={g.openMenu}/>
				<view direction="row" align-items="center" column-gap={6} padding="5 14" radius={14} background="#ffffffa8">
					<StarCount text={total() + " of " + Course.holes.length * 3} size={16}/>
					<text font-size={14} font-weight={600} color={INK}>{"· " + Course.holes.length + " holes"}</text>
				</view>
			</view>
		</view>;
	}

	// the hole's card as the camera flies over it: its number and name, par, what it brings in
	static function HoleCard(props:{game:Game}):View {
		var g = props.game;
		var i = g.holeIndex.peek(), h = Course.holes[i], w = Course.worlds[h.world];
		return <view tag="card" slot="pop" transition="opacity 0.3s ease-out, transform 0.4s ease-out" align-items="center" row-gap={6} padding="18 26"
			radius={26} background="#ffffffeb" shadow="0 10 30 #2b2d4235" max-width={340} margin-bottom={24}>
			<text font-size={12} font-weight={700} color={hex(w.deep)} letter-spacing={2}>{"HOLE " + (i + 1) + " · " + w.name.toUpperCase()}</text>
			<text font-size={32} font-weight={500} font-family="Fredoka" text-align="center">{h.name}</text>
			<view direction="row" column-gap={8} align-items="center">
				<text font-size={15} font-weight={700} padding="3 12" radius={12} background="#2b2d420f">{"Par " + h.par}</text>
			</view>
			<Show when={(h.tip ?? "") != ""}>
				<text font-size={15} font-weight={500} color="#5c6375" text-align="center" margin-top={2}>{h.tip ?? ""}</text>
			</Show>
			<text font-size={12} font-weight={600} color="#7d8597b0" margin-top={4}>Tap to skip</text>
		</view>;
	}

	// after a hole-in: the verdict, the stars popping in one by one, the
	// strokes against par (a new best said so), the island's stars so far, an
	// island finished and the next one opened; retry and next
	static function Done(props:{game:Game}):View {
		var g = props.game;
		var i = g.holeIndex.peek();
		var h = Course.holes[i], w = h.world, world = Course.worlds[w];
		var par = h.par, strokes = g.strokes.peek();
		var n = stars(strokes, par), before = g.lastBest.peek();
		var record = before > 0 && strokes < before;
		var holes = Course.holesOf(w);
		var last = i == Course.holes.length - 1;
		var islandEnd = i == holes[holes.length - 1];
		var got = worldStars(g.best.peek(), w), all = holes.length * 3;
		// (the next island, opened by finishing this one's last hole for the first time)
		var opened = islandEnd && !last && before == 0;
		function star(k:Int):View {
			var d = 0.25 + k * 0.22, size = k == 1 ? 62 : 50;
			return <view slot={n > k ? "star" : "fade"} margin-top={k == 1 ? 0 : 12}
				transition={'opacity 0.2s ease-out ${d}s, transform 0.55s cubic-bezier(0.34, 1.56, 0.64, 1) ${d}s'}>
				<image width={size} height={size} src={n > k ? starFull : starEmpty}/>
			</view>;
		}
		return <view tag="done" slot="pop" transition="opacity 0.25s ease-out, transform 0.35s ease-out" pointer-events="auto" align-items="center"
			row-gap={8} padding="20 24 22" radius={30} background="#fffffff4" shadow="0 12 36 #2b2d4250" min-width={290} max-width={360}>
			<text tag="verdict" font-size={32} font-weight={500} font-family="Fredoka" color={deep(i)}>{verdict(strokes, par)}</text>
			<view tag="stars" direction="row" align-items="flex-start" column-gap={6} height={66}>{star(0)}{star(1)}{star(2)}</view>
			<view direction="row" align-items="center" column-gap={8}>
				<text font-size={15} font-weight={700} color={INK}>{strokes + (strokes == 1 ? " stroke" : " strokes") + " · par " + par}</text>
				<Show when={record}>
					<text tag="record" slot="pop" transition="opacity 0.3s ease-out 0.9s, transform 0.4s cubic-bezier(0.34, 1.56, 0.64, 1) 0.9s" font-size={13}
						font-weight={800} color="#ffffff" padding="3 10" radius={11} background="#ef8a17">NEW BEST</text>
				</Show>
				<Show when={!record && before > 0}>
					<text font-size={14} font-weight={600} color={MUTED}>{"best " + Std.int(Math.min(before, strokes))}</text>
				</Show>
			</view>
			<Show when={n < 3}>
				<text font-size={13} font-weight={600} color={MUTED}>{n == 2 ? "One stroke off three stars" : "Par for three stars"}</text>
			</Show>
			<view width="100%" row-gap={5} margin-top={4} padding="10 12" radius={16} background="#2b2d420a">
				<view direction="row" align-items="center" justify="space-between">
					<text font-size={13} font-weight={700} color={hex(world.deep)}>{islandEnd ? world.name + " complete!" : world.name}</text>
					<StarCount text={got + " / " + all} size={14}/>
				</view>
				<view height={8} radius={4} background="#2b2d4214">
					<view height={8} radius={4} width={(got * 100 / all) + "%"} background={hex(world.accent)}/>
				</view>
			</view>
			<Show when={opened}>
				<text tag="opened" font-size={14} font-weight={700} color={deep(i + 1)}>{Course.worlds[w + 1].name + " is open"}</text>
			</Show>
			<Show when={last && islandEnd}>
				<text font-size={14} font-weight={700} color={deep(i)}>The whole sky is yours</text>
			</Show>
			<view direction="row" column-gap={12} margin-top={6}>
				<Button tag="retry" label="Retry" onPress={g.retry}/>
				<Button tag="next" label={last ? "Scorecard" : islandEnd ? "Next island" : "Next hole"} primary color={deep(i)}
					onPress={() -> last ? g.openMenu() : g.next()}/>
			</view>
		</view>;
	}

	// the scorecard: a page an island, swiped between or picked on the tabs
	// over them; each page the island's banner (its sky, its stars and holes
	// done) over its holes in a grid, each hole's number, name, stars and
	// best, locked until the one before it is finished; one tapped is played
	static function Menu(props:{game:Game}):View {
		var g = props.game;
		var page = signal(Course.holes[g.holeIndex.peek()].world);
		var pager = new helder.ui.widgets.Pager(page, Course.worlds.length, p -> page(p));
		var total = memo(() -> totalStars(g.best()));
		return <view tag="holes" position="absolute" left={0} top={0} right={0} bottom={0} pointer-events="auto" background="#1b1d2e70"
			padding-top="calc(env(safe-area-inset-top) + 12px)" padding-bottom="calc(env(safe-area-inset-bottom) + 12px)"
			padding-left="max(10px, env(safe-area-inset-left))" padding-right="max(10px, env(safe-area-inset-right))" align-items="center" justify="center">
			<view slot="rise" transition="opacity 0.25s ease-out, transform 0.3s ease-out" width="100%" max-width={g.wide() ? 760 : 460} max-height="100%"
				padding={14} radius={28} background="#fff8f0" row-gap={10} shadow="0 12 44 #2b2d4250">
				<view direction="row" align-items="center" justify="space-between">
					<view row-gap={2}>
						<text font-size={24} font-weight={500} font-family="Fredoka">Scorecard</text>
						<StarCount text={total() + " of " + Course.holes.length * 3} size={15} color={MUTED}/>
					</view>
					<Button tag="close" label="Close" onPress={g.closeMenu}/>
				</view>
				<view tag="tabs" direction="row" column-gap={6}>
					{[for (w in 0...Course.worlds.length) <Tab game={g} index={w} page={page}/>]}
				</view>
				<helder.ui.widgets.Pager.Pages pager={pager} slides={[for (w in 0...Course.worlds.length) <Island game={g} index={w}/>]}/>
				<view direction="row" justify="center" column-gap={6}>
					{[for (w in 0...Course.worlds.length) <view width={page() == w ? 18 : 6} height={6} radius={3}
						background={page() == w ? hex(Course.worlds[w].accent) : "#2b2d4226"} transition="width 0.2s ease-out"/>]}
				</view>
			</view>
		</view>;
	}

	// an island's tab: its name, its stars (a lock while its first hole is)
	static function Tab(props:{game:Game, index:Int, page:helder.view.graph.Signal<Int>}):View {
		var g = props.game, w = props.index, world = Course.worlds[w];
		var on = memo(() -> props.page() == w);
		var open = memo(() -> g.unlocked(Course.holesOf(w)[0]));
		var got = memo(() -> worldStars(g.best(), w));
		var name = world.name.split(" ")[0];
		return <view:button tag={"island-" + (w + 1)} slot="button" role="button" focusable cursor="pointer" grow={1} basis={0} min-width={0}
			padding="7 2" radius={14} align-items="center" row-gap={2} transition="transform 0.12s ease-out, background-color 0.2s ease-out"
			background={on() ? hex(world.accent) : "#ffffff"} shadow="0 2 6 #2b2d4218" onPress={() -> props.page(w)}>
			<text font-size={12} font-weight={800} color={on() ? "#ffffff" : hex(world.deep)} text-wrap="nowrap">{name}</text>
			<Show when={open()} fallback={<image width={14} height={14} src={lock}/>}>
				<view direction="row" align-items="center" column-gap={3}>
					<image width={12} height={12} src={starFull}/>
					<text font-size={11} font-weight={700} color={on() ? "#ffffff" : MUTED}>{got() + "/" + Course.holesOf(w).length * 3}</text>
				</view>
			</Show>
		</view:button>;
	}

	// an island's page: its banner and its holes
	static function Island(props:{game:Game, index:Int}):View {
		var g = props.game, w = props.index;
		var holes = Course.holesOf(w);
		return <view direction={g.wide() ? "row" : "column"} column-gap={10} row-gap={10} padding="2 2 4">
			<Banner game={g} index={w}/>
			<view grow={1} direction="row" wrap justify="space-between" row-gap={7} align-content="flex-start">
				{[for (i in holes) <HoleTile game={g} index={i}/>]}
			</view>
		</view>;
	}

	// an island's banner: its sky, its name, its stars and holes done
	static function Banner(props:{game:Game, index:Int}):View {
		var g = props.game, w = props.index, world = Course.worlds[w];
		var holes = Course.holesOf(w);
		var got = memo(() -> worldStars(g.best(), w));
		var done = memo(() -> Lambda.count(holes, i -> g.best()[i] > 0));
		var score = memo(() -> {
			var strokes = 0, par = 0;
			for (i in holes) {
				strokes += g.best()[i];
				par += Course.holes[i].par;
			}
			done() == holes.length ? strokes + " strokes for par " + par : "par " + par;
		});
		var ink = LETTERS[w];
		return <view tag={"banner-" + (w + 1)} padding="12 14" radius={20} background={Game.gradient(world)} row-gap={6}
			width={g.wide() ? "36%" : "100%"} justify="center">
			<text font-size={22} font-weight={500} font-family="Fredoka" color={ink}>{world.name}</text>
			<text font-size={13} font-weight={600} color={ink} opacity={0.8}>{world.blurb}</text>
			<view height={8} radius={4} background="#ffffff70">
				<view height={8} radius={4} width={(got() * 100 / (holes.length * 3)) + "%"} background={hex(world.accent)}/>
			</view>
			<view direction="row" wrap justify="space-between" align-items="center" row-gap={4} column-gap={8}>
				<StarCount text={got() + " of " + holes.length * 3} size={14} color={ink}/>
				<text font-size={12} font-weight={700} color={ink} opacity={0.8}>{done() + " of " + holes.length + " holes · " + score()}</text>
			</view>
		</view>;
	}

	// a hole's tile: locked (its number, a padlock), or its number, name, stars and best
	static function HoleTile(props:{game:Game, index:Int}):View {
		var g = props.game, i = props.index, h = Course.holes[props.index];
		var color = hex(Course.worlds[h.world].deep);
		var open = memo(() -> g.unlocked(i));
		var n = memo(() -> stars(g.best()[i], h.par));
		var here = memo(() -> g.holeIndex() == i);
		var compact = g.wide.peek();
		return <view:button tag={"hole-" + (i + 1)} slot="button" role="button" focusable cursor={open() ? "pointer" : "default"} width="31.8%"
			height={compact ? 64 : 92} padding="6 4" radius={16} align-items="center" justify="center" row-gap={compact ? 1 : 3}
			transition="transform 0.12s ease-out" background={!open() ? "#2b2d420c" : n() == 3 ? "#fff3cf" : "#ffffff"} border-width={2}
			border-color={here() ? color : n() == 3 ? "#ffd56a" : "#ffffff00"} shadow={open() ? "0 2 6 #2b2d4218" : "0 0 0 #00000000"}
			onPress={() -> if (open()) g.go(i)}>
			<view direction="row" align-items="center" column-gap={5}>
				<text font-size={compact ? 16 : 20} font-weight={800} color={open() ? color : "#9aa0b0"}>{"" + (i + 1)}</text>
				<Show when={!open()}>
					<image width={14} height={14} src={lock}/>
				</Show>
			</view>
			<Show when={!compact}>
				<text font-size={12} font-weight={500} font-family="Fredoka" text-align="center" color={open() ? INK : "#9aa0b0"} text-wrap="nowrap"
					text-overflow="ellipsis" overflow="hidden" max-width="100%">{h.name}</text>
			</Show>
			<Show when={open()}>
				<Stars n={n()} size={compact ? 13 : 16}/>
				<text font-size={11} font-weight={700} color={MUTED}>{g.best()[i] > 0 ? "best " + g.best()[i] + " · par " + h.par : "par " + h.par}</text>
			</Show>
		</view:button>;
	}
}
