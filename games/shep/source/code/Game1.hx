
import feffects.Tween;
import feffects.easing.Bounce;
import feffects.easing.Linear;
import feffects.easing.Sine;
import flash.display.MovieClip;
import flash.display.Sprite;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.filters.BlurFilter;
import flash.filters.DropShadowFilter;
import flash.filters.GlowFilter;
import flash.geom.ColorTransform;
import flash.media.Sound;
import flash.net.SharedObject;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.text.AntiAliasType;
import flash.text.TextField;
import flash.text.TextFieldAutoSize;
import flash.text.TextFieldType;
import flash.text.TextFormat;
import flash.ui.Keyboard;
import flash.utils.SetIntervalTimer;

import Assets;


class BodyClip {
  public var clip : MovieClip;
  public var body : phx.Body;
  public var code : Int; // for doors and locks
  public function new(body, clip) {
    this.body = body;
    this.clip = clip;
  }
}

class Pocket extends phx.Body {
  public var code : Int;
}

class Game1
{

  // config
  private static var timeLimit = 120;
  private static var blurAmount : Int = 10;
  private static var spinnerVelocity :Float= 0.03;
  private static var spinnerTorque :Float = 0.03;
  private static var border = 25;

  private var world : phx.World;
  private var parent : Sprite;

  private var floatyWall : phx.Material;
  private var bouncyWall : phx.Material;
  private var fuseMaterial : phx.Material;
  private var shepMaterial : phx.Material;

  private var pockets : Array<BodyClip>;
  private var cuebot : phx.Body;

  private var done : Bool;
  private var paused: Bool;
  private var keyboardControl: Bool;

  private var loader : URLLoader;
  private var svg : Xml;

  private var clock:FlashClock;
  private var clockText:TextField;

  private var physaxeLayer : MovieClip;
  private var redGlow : GlowFilter;
  private var cyanGlow : GlowFilter;

  private var currentLevel : Int;
  private var bg : MovieClip;
  private var mg : MovieClip;
  private var fg : MovieClip;
  private var blurFilter : BlurFilter;

  private var shepClip : MovieClip;
  private var glowClip : MovieClip;
  private var showPhysics : Bool;
  private var smallballs : Array<BodyClip>;
  private var doors : Array<BodyClip>;
  private var spinners : Array<BodyClip>;
  private var floaters : Array<BodyClip>;

  public var starfield : StarField;
  public var winCallback : Float -> Void;
  public var loseCallback : Void -> Void;

  private var sound:SoundManager;
  private var muteButton:MovieClip;

  private function new(parent:Sprite) {

    this.parent = parent;

    smallballs = [];
    pockets = [];
    doors = [];
    floaters = [];
	//	GlowFilter(color:uint = 0xFF0000, alpha:Number = 1.0, blurX:Number = 6.0, blurY:Number = 6.0, strength:Number = 2, quality:int = 1, inner:Boolean = false, knockout:Boolean = false)
    redGlow = new GlowFilter(0xff1e0d, .3, 6, 6, 3);
    cyanGlow = new GlowFilter(0x36a3cc, .5, 3, 3, 3);


    sound = new SoundManager();
//note to michal:  while researching the 'restitution' property, I came across this gem in wikipedia:  "A COR greater than one is theoretically possible, representing a collision that generates kinetic energy, such as land mines being thrown together and exploding."  This sounds like a game you could make in a day - landmineflinger!
    // phx.Material(restitution, friction, density );  
    floatyWall = new phx.Material(0.5, 2, 100);
    bouncyWall = new phx.Material(.9, 2, Math.POSITIVE_INFINITY);
    fuseMaterial = new phx.Material(0.5, 10, 15);
    shepMaterial = new phx.Material(0.5, 20, 20);

#if !FLEX_WRAP
    starfield = new StarField(800,575);
    parent.addChild(starfield);
#end

    //var glass = new GlassLayer();
    //parent.addChild(glass);

    /*
      var glint = new Sprite();
      var g = glint.graphics;
      g.moveTo(glass.width/2,0);
      g.lineStyle(3, 0x999999);
      g.lineTo(glass.width/2,glass.height);
      g.moveTo(glass.width/2,0);
      g.lineStyle(1, 0xCCCCCC);
      g.lineTo(glass.width/2,glass.height);
      glass.addChild(glint);
      glass.filters = [new BlurFilter(15, 0)];
    */
      
    bg = new MovieClip();
    blurFilter = new BlurFilter(0,0);
    bg.filters = [blurFilter];
    parent.addChild(bg);

    mg = new MovieClip();
    parent.addChild(mg);

    fg = new MovieClip();
    //fg.x = border; fg.y = border;
    parent.addChild(fg);

    parent.addChild(new BorderClip());

    clock = new FlashClock();

    physaxeLayer = new MovieClip();
    physaxeLayer.alpha = 0.5;
    parent.addChild(physaxeLayer);

    var ds = new ClockFont();
    var fmt = new TextFormat(ds.fontName, 24, 0xFF0000);


    clockText = new TextField();
    clockText.embedFonts = true;
    clockText.x = 400;
    clockText.y = 0;
    clockText.antiAliasType = AntiAliasType.ADVANCED;
    clockText.background = false;
    //clockText.backgroundColor = ;
    clockText.multiline = false;
    clockText.visible = true;

    clockText.defaultTextFormat = fmt;
    clockText.setTextFormat(fmt);
    clockText.text = "00:00";

    clockText.autoSize = TextFieldAutoSize.CENTER;
    clockText.x = (400 - clockText.textWidth/2)-2;

    parent.addChild(clockText);


    muteButton = new MovieClip();
    muteButton.x = 696;
    muteButton.y = 552;
    muteButton.buttonMode = true;
    drawMuteButton();
    parent.addChild(muteButton);    

    done = true;

#if FLEX_WRAP
    // @TODO: this is a kludge:
    cuebot = new phx.Body(10, 10);
    cuebot.addShape(new phx.Circle(20, new phx.Vector(0, 0), shepMaterial));
    shepClip = new MovieClip();
    world = newEmptyWorld();
    world.addBody(cuebot);
#else
    startLevel(1);
#end

    // save this to the end so world is ready to go for first frame event
    parent.addEventListener(Event.ENTER_FRAME, onEnterFrame);
    muteButton.addEventListener(MouseEvent.MOUSE_DOWN, onMuteButton);
    parent.addEventListener(MouseEvent.MOUSE_DOWN, onClick);
    if (flash.Lib.current.stage != null)
      flash.Lib.current.stage.addEventListener(KeyboardEvent.KEY_DOWN, 
					       onKeyDown);
    // nothing below here should edit the world!
  }

  private function onEnterFrame(e) {
    if (! (done || paused)) {

      updateWorld();
      updateClock();

      // these have to come after the clock updates, or there
      // will be trouble with restarting after a timeout
      checkForWin();
      checkForLoss();

      drawWorld();
    }
  }


  var lastText:String;
  private function updateClock() {
    if (done || paused) return;  
    clockText.text = clock.toString();

    var secs = clock.timeCount;
    if (secs <= 30) {
      // red alert!
      var v = (1 + Math.sin(clock.timeLeft()*5)) * 0.40;
      var ct = new flash.geom.ColorTransform(0.25+v, 0, 0);
      bg.transform.colorTransform = ct;
      mg.transform.colorTransform = 
	new flash.geom.ColorTransform(1+v, 0.75, 0.75);
      fg.transform.colorTransform = 
	new flash.geom.ColorTransform(0.75+v, 0.5, 0.5);

      if (clockText.text != lastText) {
	if (secs <= 5) {
	  sound.alert3(0, 2);
	} else if (secs <= 10) {
	  sound.alert3();
	} else if (secs <= 20) {
	  sound.alert2();
	} else {
	  sound.alert1();
	}
      }

    }

    /* // we had level 9 as a disco level for a while :)
      else if (currentLevel == 9 && Math.ceil((tl * 10)) % 10 == 0) {
      bg.transform.colorTransform = new flash.geom.ColorTransform(Math.random(), Math.random(), Math.random());
      mg.transform.colorTransform = new flash.geom.ColorTransform(Math.random()+0.25, Math.random()+0.25, Math.random()+0.25);
    }*/
    lastText = clockText.text;
  }


  private function newEmptyWorld():phx.World {
    var broadphase = new phx.col.SortedList();
    var boundary = new phx.col.AABB(-2000, -2000, 2000, 2000);
    return new phx.World(boundary, broadphase);
  }

  private function resetWorld(level:Int) {

    done = true;
    
    // clear red alert / strobe
    bg.transform.colorTransform = new flash.geom.ColorTransform(1.00, 1.0, 1.0);
    mg.transform.colorTransform = new flash.geom.ColorTransform(1.00, 1.0, 1.0);
    fg.transform.colorTransform = new flash.geom.ColorTransform(1.00, 1.0, 1.0);
 
    world = newEmptyWorld();

    clearClip(mg);

    cuebot = new phx.Body(10, 10);
    cuebot.addShape(new phx.Circle(20, new phx.Vector(0, 0), shepMaterial));
    world.addBody(cuebot);

    var png = new ShepClip();
    shepClip = centerClip(png);
    glowClip = new GlowClip();
    glowClip.x = -glowClip.width / 2;
    glowClip.y = png.y + png.height - glowClip.height + 5;
    glowClip.alpha = 0;
    shepClip.addChild(glowClip);

    var w = 800;
    var h = 575;
    var b = border;
    
    addWall(world, phx.Shape.makeBox(w, b, 0, 0)); // top
    addWall(world, phx.Shape.makeBox(b, h-(2*b), 0, b)); // left
    addWall(world, phx.Shape.makeBox(b, h-(2*b), w-b, b)); // right
    addWall(world, phx.Shape.makeBox(w, b, 0, h-b)); // bottom
    
    try { haxe.Log.clear(); } catch (e:Dynamic){}
    loadLevel(level);

  }

  function addWall(room:phx.World, shape:phx.Shape, ?mat):Void {
    shape.material = (mat != null) ? mat : bouncyWall;
    room.addStaticShape(shape);
  }

  function updateWorld() {
    world.step(1, 25);
    
    // friction:
    var friction = 0.985;
    var oldv = cuebot.v;
    cuebot.setSpeed(oldv.x * friction, oldv.y * friction);
    for (b in smallballs) {
      oldv = b.body.v;
      b.body.setSpeed(oldv.x * friction, oldv.y * friction);
    }

    // power the spinners:
    for (s in spinners) {
      s.body.w = spinnerVelocity;
      s.body.t = spinnerTorque;
    }

  }

  function checkForWin() {

    for (pocketBC in pockets) {
      var pocket:Pocket = cast pocketBC.body;
      var pclip:PocketClip = cast pocketBC.clip.getChildAt(0);
      for (arb in pocket.arbiters) {
	var shape = (arb.s1.body == pocket) ? arb.s2 : arb.s1;
	if (shape.body == cuebot) {
	  if (smallballs.length == 0) {
	    onWin();
	  }
	} else {
	  for (b in smallballs) {
	    if (shape.body == b.body) {
              if (b.code == pocket.code) {

		smallballs.remove(b);
		mg.removeChild(b.clip);
		world.removeBody(shape.body);

		//@TODO: multiple colored doors?
		if (pocket.code > 0) {
		  if (doors.length > 0)
		    openDoor(doors[0]);
		}
		sound.pocket();

		if (smallballs.length == 0) {
		  for (p in pockets) {
		    var each:PocketClip = cast p.clip.getChildAt(0);
		    each.openWide();
		  } 
		} else {
		  pclip.swallow();
		}
		break;
	      }
	    }
	  }
	}
      }
    }
  }

    
  var openingDoor:BodyClip;
  function openDoor(d:BodyClip) {
    sound.door();
    doors.remove(d);
    world.removeBody(d.body);
    d.clip.filters= [];
    openingDoor = d;
    var tween = new Tween( d.clip.y, 
			   d.clip.y+d.clip.height, 
			   1000, Bounce.easeOut );
    tween.setTweenHandlers(slideDoor, onDoorOpen);
    tween.start();
  }

  function slideDoor(e:Float) {
    openingDoor.clip.y = e;
  }

  function onDoorOpen(e:Float) {
    doors.remove(openingDoor);
    mg.removeChild(openingDoor.clip);
  }

  function checkForLoss() {
    if (clock.timeCount <= 0) {
      onLoss();
    }
  }


  public function drawPreview(level:Int):MovieClip {
    var room = newEmptyWorld();
    var roomClip = new MovieClip();
    parseSVG(roomClip, room, getPackedSVG(level));
    room.step(1, 25);
    
    var preview = new MovieClip();

    var g = preview.graphics;
    
    /*g.lineStyle(1, 0x000000);
    g.beginFill(0xDDFFDD);
    g.moveTo(0,0);
    g.lineTo(800, 0);
    g.lineTo(800, 575);
    g.lineTo(0, 575);
    g.lineTo(0, 0);
    g.endFill();*/
    
    var fd = new phx.FlashDraw(preview.graphics);
    var fill = 0x042105;
    var line = 0x8CE796;
    fd.staticShape.fill = fill; 
    fd.staticShape.line = line;
    fd.shape.fill = fill;
    fd.shape.line = line;
    fd.drawWorld(room);
    
    preview.scaleX = 0.33;
    preview.scaleY = 0.33;
    //preview.x = 100;
    //preview.y = 100;
    return preview;
  }

  function drawWorld() {
    var g = physaxeLayer.graphics;
    g.clear();

    if (showPhysics) {
      var fd = new phx.FlashDraw(g);
      //fd.boundingBox.line = 0x000000;
      //fd.contact.line = 0xFF0000;
      //fd.sleepingContact.line = 0xFF00FF;
      // fd.staticShape.fill = 0x00FF00;
      //fd.drawCircleRotation = true;
      fd.drawWorld(world);
    }

    var g = fg.graphics;
    g.clear();
    drawVector(g);

    for (s in spinners) {
      s.clip.rotation = rad2deg(s.body.a);
    }

    for (b in smallballs) {
      b.clip.x = b.body.x;
      b.clip.y = b.body.y;
      b.clip.rotation = rad2deg(b.body.a);
      makeBallSounds(b.body);
    }

    for (s in floaters) {
      s.clip.x = s.body.x;
      s.clip.y = s.body.y;
      s.clip.rotation = rad2deg(s.body.a);
      makeFloatSounds(s.body);
    }

    for (arb in cuebot.arbiters) {
      if (arb.sleeping) continue;
      if (arb.contacts == null || (! arb.contacts.updated)) continue;
      var shape = (arb.s1.body == cuebot) ? arb.s2 : arb.s1;
      if (Type.getClass(shape.body) == Pocket) {
	continue; // handle it later
      } else if (Type.getClass(shape) == phx.Circle) {
	sound.fuse();
	break; // only play one sound
      } else {
	sound.wall();
	var c = arb.contacts;
	var shiftX = -Math.floor((c.px - cuebot.x) / 2.5);
	new Tween( shiftX, 0, 600, bg, "x", null ).start();
	new Tween( shiftX, 0, 600, blurFilter, "blurX", null ).start();
	var shiftY = -Math.floor((c.py - cuebot.y) / 2.5);
	new Tween( shiftY, 0, 600, bg, "y", null ).start();
	new Tween( shiftY, 0, 600, blurFilter, "blurY", null ).start();
	break; // only play one sound
      }
    }
    bg.filters = [blurFilter];

    var fgBlur = new BlurFilter();
    fgBlur.blurX = blurFilter.blurX / 2;
    fgBlur.blurY = blurFilter.blurY / 2;
    fg.filters = [fgBlur];

    shepClip.x = cuebot.x;
    shepClip.y = cuebot.y;
    
  }

  
  // @TODO: iterator
  private function makeBallSounds(b:phx.Body) {
    // this is all same as above
    for (arb in b.arbiters) {
      if (arb.sleeping) continue;
      if (arb.contacts == null || (! arb.contacts.updated)) continue;
      var other = (arb.s1.body == b) ? arb.s2 : arb.s1;
      var otherClass = Type.getClass(other);

      if (otherClass == phx.Circle) {

	// only do s1 because the two balls share an arbiter
	if (arb.s2.body == b) continue;

	// ignore collisions with cuebot. it's handled elsewhere
	if (arb.s2.body == cuebot) continue;

	// still here, so:
	sound.fuse(); // fuse on fuse
      } else { sound.fusewall(); } // fuse on wall
    }
  }

  private function makeFloatSounds(b:phx.Body) {
    // this is all same as above
    for (arb in b.arbiters) {
      if (arb.sleeping) continue;
      if (arb.contacts == null || (! arb.contacts.updated)) continue;
      var other = (arb.s1.body == b) ? arb.s2 : arb.s1;
      var otherClass = Type.getClass(other);
      if ((arb.s1.body == b) && (otherClass != phx.Circle)) {
	  sound.wall();
      }
    }
  }

  function calcVector(r:Int) {
    var x1 = cuebot.x;
    var y1 = cuebot.y;
    
    var x2 = parent.mouseX;
    var y2 = parent.mouseY;

    var rise = (y2 - y1);
    var run = (x2 - x1);
    if (run == 0) {
      return new phx.Vector(0, rise);
    } else {
      var m = rise / run;
      var vx = Math.sqrt(r) / Math.sqrt(m*m+1);
      vx *= (x2 > x1) ? 1 : -1;
      var vy = m * vx;
      return new phx.Vector(vx, vy);
    }
  }

  function rad2deg(rad:Float) {
    return  180 * rad / Math.PI;
  }

  function deg2rad(deg:Float) {
    return deg * Math.PI / 180;
  }
  
  function rad2vec(r:Float) {
    return new phx.Vector(Math.cos(r), Math.sin(r));
  }



  private function shepClipVector() {
    return rad2vec(deg2rad(shepClip.rotation-90));
  }



  function drawVector(g:flash.display.Graphics) {

    // draw a line from the bot to the mouse
    // but scaled down to n units

    /* maxima session: 
       intersection of a line and circle of radius r
       if line passes through origin and circle centered at origin
       
       (%i27) y^2=r-x^2, y=m*x;
       (%o27) m^2*x^2=r-x^2
       (%i28) solve(%o27,x);
       (%o28) [x=-sqrt(r)/sqrt(m^2+1),x=sqrt(r)/sqrt(m^2+1)]
    */

    
    var r = 150;
    var v:phx.Vector;

    if (keyboardControl) {
      v = shepClipVector().mult(10);

    } else {
      v = calcVector(r);

      if (v.x == 0) {
	shepClip.rotation = v.y <= 0 ? 0 : 180;
      } else {
	var slope = v.y / v.x;
	shepClip.rotation = 90 + rad2deg( Math.atan(slope));
	if (v.x < 0)
	  shepClip.rotation += 180;
      }
    }

    /*
      g.moveTo(cuebot.x, cuebot.y);
      g.lineStyle(5, 0x3333FF);
      g.lineTo(cuebot.x+v.x, cuebot.y+v.y);
    */
  }


  private function onKeyDown(e) {

    switch(e.keyCode) {
    case 66: // b
      blurFilter.blurX = 10;
      // trace("blur!");
      
    case 79:
      if (doors.length > 0) {
	openDoor(doors[0]);
	doors = [];
      }
    case 80: // physics
      showPhysics = ! showPhysics;


    case 82: // r = red alert 1
      clock.startTimer(30);
    case 69: // e = red alert 2
      clock.startTimer(20);
    case 68: // d = red alert 3
      clock.startTimer(10);

    case 84: // t
      bg.transform.colorTransform = 
	new flash.geom.ColorTransform(Math.random(), 
				      Math.random(), 
				      Math.random());
    case 88: // x
      fg.addChild(drawPreview(currentLevel));

    case 48,49,50,51,52,53,54,55,56,57:
      startLevel(e.keyCode - 48);
    default:
      if (keyboardControl) {
	switch(e.keyCode) {
	case Keyboard.UP:
	  kick(cuebot, shepClipVector().mult(5));
	case Keyboard.LEFT:
	  shepClip.rotation -= 15;
	case Keyboard.RIGHT:
	  shepClip.rotation += 15;
	default:
	  restart();
	}
      } else {
	restart();
      }
    }
  }

  private function onClick(e) {
    if ((e.stageX > muteButton.x) && (e.stageY >= muteButton.y)) {
      return;
    } else if (! (done || paused)) {
      kick(cuebot, calcVector(50));
      sound.thrust();
      var tween = new Tween( 1.0, 0, 1000, Sine.easeInOut );
      var self = this;
      tween.setTweenHandlers(function (e:Float){self.glowClip.alpha = e;}, 
			     function (e:Float){});
      tween.start();
    }
  }

  private function onMuteButton(e:Event) {
    sound.toggle();
    drawMuteButton();
    e.stopPropagation();
  }

  
  private function drawMuteButton() {
    clearClip(muteButton);
    if (sound.muted) {
      muteButton.addChild(new MuteIcon());
    } else {
      muteButton.addChild(new SoundIcon());
    }
  }

  private function kick(body:phx.Body, howHard:phx.Vector) {
    var oldv = body.v;
    body.setSpeed(oldv.x + howHard.x, oldv.y + howHard.y);
    world.activate(body);
  }



  private function getPackedSVG(which:Int):String {
    switch (which) {
    case 0: return LevelPack.svg0000;
    case 1: return LevelPack.svg0001;
    case 2: return LevelPack.svg0002;
    case 3: return LevelPack.svg0003;
    case 4: return LevelPack.svg0004;
    case 5: return LevelPack.svg0005;
    case 6: return LevelPack.svg0006;
    case 7: return LevelPack.svg0007;
    case 8: return LevelPack.svg0008;
    case 9: return LevelPack.svg0009;
    default:
      return "";
    }
  }

  private function loadLevel(which:Int) {
    currentLevel = which;

#if FLEX_WRAP
    parseSVG(mg, world, getPackedSVG(which));
#else
    var url = "levels/000" + which + ".svg";
    loader = new URLLoader(new URLRequest(url));
    loader.addEventListener("complete", onSVGRequest);
#end

    clearClip(fg);
    clearClip(bg);

    var fgc:MovieClip;
    var bgc:MovieClip;

    switch (which) {
    case 0: fgc = new FG0000(); bgc = new BG0000();
    case 1: fgc = new FG0001(); bgc = new BG0001();
    case 2: fgc = new FG0002(); bgc = new BG0002();
    case 3: fgc = new FG0003(); bgc = new BG0003();
    case 4: fgc = new FG0004(); bgc = new BG0004();
    case 5: fgc = new FG0005(); bgc = new BG0005();
    case 6: fgc = new FG0006(); bgc = new BG0006();
    case 7: fgc = new FG0007(); bgc = new BG0007();
    case 8: fgc = new FG0009(); bgc = new BG0009(); // debug level
    case 9: fgc = new FG0009(); bgc = new BG0009();
    default:
      fgc = new MovieClip();
      bgc = new MovieClip();
    }
    bg.addChild(bgc);
    fg.addChild(fgc);
  }


  private function addPocket(clip:MovieClip, room:phx.World, 
			     cx:Float, cy:Float, ?code:Int) {
    // the zone is really just here for debugging purposes
    // it also makes the pocket look like a square so it's
    // easier to distingquish from the small balls
    var zone = new phx.Body(0, 0);
    zone.addShape(phx.Shape.makeBox(60, 60, cx-30, cy-30, 
				    new phx.Material(0,0,0)));
    room.addBody(zone);
    
    var pocket = new Pocket(cx, cy);
    pocket.code = code;
    pocket.addShape(new phx.Circle(15, new phx.Vector(0, 0),
				   bouncyWall));
    room.addBody(pocket);
    var pclip:MovieClip;

    pclip = centerClip(new PocketClip());

    var glow = new PocketGlow();
    pclip.addChild(centerClip(glow));

    if (code > 0) {
      // red:
      glow.transform.colorTransform 
	= new flash.geom.ColorTransform(0.95, 0, 0);
    } else {
      glow.transform.colorTransform
	= new flash.geom.ColorTransform(0, 0.65, 0.85); 
    }

    pclip.x = cx;
    pclip.y = cy;


    clip.addChild(pclip);
    pockets.push(new BodyClip(pocket, pclip));
    return pocket;
  }

  private function addPolyXml(roomClip:MovieClip, room:phx.World, poly:Xml) {
      var points = StringTools.trim(poly.get("points"));
      var vertices:Array<phx.Vector> = [];

      if (points != null) {
	for (pair in points.split(" ")) {
	  
	  var xy = pair.split(",");
	  var x = Std.parseFloat(xy[0]);
	  var y = Std.parseFloat(xy[1]);
	  vertices.push(new phx.Vector(x, y));
	}

	// transpose points to origin = center
	var c = findCenter(vertices);
	for (i in 0 ... vertices.length) {
	  vertices[i] = vertices[i].minus(c);
	}

	var origin = new phx.Vector(0,0);
	var mat = poly.get("fill") == "#FF00FF" ? floatyWall : bouncyWall;
	var p = new phx.Polygon(vertices, origin, mat);

	// revese the vertices, or physaxe will screw up the area
	// calculations, and make it a static shape.
	if (p.area < 0) {
	  vertices.reverse();
	  p = new phx.Polygon(vertices, origin, mat);
	}

	var b = new phx.Body(c.x, c.y);
	b.addShape(p);

	if (mat == floatyWall) {
	  var clip:MovieClip;
	  if (vertices.length == 8) {
	    clip = centerClip(new CargoClip());
	  } else {
	    clip = centerClip(new CrateClip());
	  }
	  clip.x = c.x; clip.y = c.y;
	  floaters.push(addBodyClip(roomClip, room, b, clip));

	} else {
	  room.addBody(b);
	  room.activate(b);
	}
      }
  }
  

  private function findCenter(vertices:Array<phx.Vector>) {
    var avg = new phx.Vector(0,0);
    for (v in vertices) {
      avg = avg.plus(v);
    }
    return avg.mult(1 / vertices.length);
  }

  private function addBodyClip(roomClip:MovieClip, room:phx.World, 
			       body, clip) : BodyClip {
    var bc = new BodyClip(body, clip);
    room.addBody(body);
    roomClip.addChild(clip);
    return bc;
  }

  private function addSpinner(roomClip:MovieClip, room:phx.World, 
			      cx:Float, cy:Float, w:Float, h:Float) {

    var sc = centerClip(new SpinnerClip());
    sc.x = cx; sc.y = cy;

    // hard coded shape because of the sprite
    var shape = phx.Shape.makeBox(15, 175, -7.5, -87.5, bouncyWall);
    var body = new phx.Body(cx, cy);
    body.addShape(shape);
    if (w > h) {
      body.a = deg2rad(-90);
    }

    spinners.push(addBodyClip(roomClip, room, body, sc));
  }

  private function addDoor(roomClip:MovieClip, room:phx.World,
			   shape:phx.Shape, clip:MovieClip, cx, cy) {
    var body = new phx.Body(0, 0);
    body.addShape(shape);
    clip.x = cx; clip.y = cy;
    clip.filters = [redGlow];
    doors.push(addBodyClip(roomClip, room, body, clip));
  }

  private function onSVGRequest(e:Event) {
    parseSVG(mg, world, loader.data);
  }

  private function parseSVG(roomClip:MovieClip, room:phx.World, xml_text:String) {
    svg = Xml.parse(xml_text).firstElement();

    // trace("level loaded.");

    var green = "#00FF00";
    var red = "#FF0000";
    var blue = "#0000FF";
    var cyan = "#00FFFF";
    var darkCyan = "#009999";

    spinners = [];
    floaters = [];
    doors = [];

    for (rect in svg.elementsNamed("rect")) {

      var x = Std.parseFloat(rect.get("x"));
      var y = Std.parseFloat(rect.get("y"));
      var w = Std.parseFloat(rect.get("width"));
      var h = Std.parseFloat(rect.get("height"));
      var cx = x + (w/2);
      var cy = y + (h/2);

      var shape = phx.Shape.makeBox(w, h, x, y, bouncyWall);
      
      var fill = rect.get("fill");
      if (fill == green) {
	addPocket(roomClip, room, cx, cy);

      } else if (fill == cyan) {
	addPocket(roomClip, room, cx, cy, 1);

      } else if (fill == darkCyan) {
	addDoor(roomClip, room, shape, new DoorClip(), x, y);

      } else if (fill == blue) {
	addSpinner(roomClip, room, cx, cy, w, h);

      } else {
	addWall(room, shape);
      }
    }

    for (poly in svg.elementsNamed("polygon")) {
      addPolyXml(roomClip, room, poly);
    }

    smallballs = [];
    for (circ in svg.elementsNamed("circle")) {
      var cx = Std.parseFloat(circ.get("cx"));
      var cy = Std.parseFloat(circ.get("cy"));
      
      // green is the hero
      if (circ.get("fill") == green) {
	cuebot.setPos(cx, cy);
      }

      // anything else is a fuseball
      
      else {
	var smallball = new phx.Body(cx, cy);
	smallball.addShape(new phx.Circle(15, new phx.Vector(0, 0), 
					  fuseMaterial));
	room.addBody(smallball);
	var bodyclip:BodyClip;
    
	if (circ.get("fill") != red) {
	  bodyclip = new BodyClip(smallball, centerClip(new RedBallClip()));
	  bodyclip.clip.filters = [redGlow];
	  bodyclip.code = 1; // just some arbitrary code @TODO: match keys and doors
	} else {
	  bodyclip = new BodyClip(smallball, centerClip(new BallClip()));
	  bodyclip.clip.filters = [cyanGlow];
	}

	smallballs.push(bodyclip);
	roomClip.addChild(bodyclip.clip);
      } 
    } // circles

    // shep is at the very end so he goes on top
    roomClip.addChild(shepClip);
  }




  private function offsetClip(clip:MovieClip, x:Float, y:Float):MovieClip {
    var holder = new MovieClip();
    holder.addChild(clip);
    clip.x = x;
    clip.y = y;
    return holder;
  }

  private function centerClip(clip):MovieClip {
    return offsetClip(clip, -clip.width/2, -clip.height/2);
  }


  public static function main() {
#if !FLEX_WRAP
    var parent = flash.Lib.current;
    var game = new Game1(parent);
    //game.sound.alert3(0,9999);
#end
  }


  function clearClip(clip:MovieClip) {
    while (clip.numChildren > 0) {
      clip.removeChildAt(0);
    }
  }


  // these two are meant to be called from flex:

  public function pause() {
    paused = true;
    starfield.paused = true;
    sound.pause();
  }
  
  public function resume() {
    paused = false;
    starfield.paused = false;
    clock.resume();
    sound.resume();
  }

  public function restart() {
    startLevel(currentLevel);
  }

  public function startLevel(n:Int){
    try { resume(); } catch (e:Dynamic) {}  // just in case
    resetWorld(n);
    sound.startMusic();
    clock.startTimer(timeLimit);
    done = false;
  } 

  // these talk back to flex:

  public function onLoss() {
    done = true;
    sound.defeat();
    sound.pause(); // it should be done anyway, since it's 2:00, but...
    if (loseCallback != null) {
      loseCallback();
    } else {
      // trace("time ran out!");
    }
  }

  public function onWin() {
    done = true;
    sound.victory();
    sound.pause();
    updateHighScores();
    if (winCallback != null) {
      winCallback(clock.timeCount);
    } else {
      // trace("you won!");
    }
  }


  // shared object stuff:

  private function updateHighScores():Void {

    var score = clock.timeCount;
    
    trace("beat level "+ currentLevel + " with " 
	  + clock.timeCount + " seconds to spare");
    
    var share = getSharedObject();
    var raw_best = raw_score(currentLevel);
    var save_score = false;
    
    var best:Int = -1;
    if (raw_best == null) {
      save_score=true;
    } else {
      best = cast raw_best;
      // we want > because it's seconds LEFT, so bigger is faster
      if (score > best) {
	save_score=true;
	trace("new personal best!");
      }
      trace("previous best was: " + best);
    }
    
    if (save_score) {
      share.setProperty("level_" + currentLevel, score);
      share.flush();
    }

  }

  private function getSharedObject():SharedObject {
    return SharedObject.getLocal("shep_scores");
  }

  public function raw_score(level:Int):Dynamic {
    var field = "level_" + level;
    return Reflect.field(getSharedObject().data, field);
  }

}
