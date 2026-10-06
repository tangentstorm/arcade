import flash.display.MovieClip;
import flash.events.Event;
import flash.filters.GlowFilter;

class Assets {}
class ClockFont extends flash.text.Font {}

class BorderClip extends MovieClip {}
class GlassLayer extends MovieClip {}

class BG0000 extends MovieClip {}
class BG0001 extends MovieClip {}
class BG0002 extends MovieClip {}
class BG0003 extends MovieClip {}
class BG0004 extends MovieClip {}
class BG0005 extends MovieClip {}
class BG0006 extends MovieClip {}
class BG0007 extends MovieClip {}
class BG0009 extends MovieClip {}

class FG0000 extends MovieClip {}
class FG0001 extends MovieClip {}
class FG0002 extends MovieClip {}
class FG0003 extends MovieClip {}
class FG0004 extends MovieClip {}
class FG0005 extends MovieClip {}
class FG0006 extends MovieClip {}
class FG0007 extends MovieClip {}
class FG0009 extends MovieClip {}

class ShepClip extends MovieClip {}
class GlowClip extends MovieClip {}
class DoorClip extends MovieClip {}
class SpinnerClip extends MovieClip {}
class CargoClip extends MovieClip {}
class CrateClip extends MovieClip {}


class BallClip extends MovieClip {

  public function new() {
    super();
    gotoAndPlay(Math.floor(Math.random() * totalFrames));
  }
}
class RedBallClip extends BallClip {}



class SoundIcon extends MovieClip {}
class MuteIcon extends MovieClip {}


class PocketGlow extends MovieClip {}

// Putting the stops in the animated swf
// caused the game to lock up... I guess
// haxe or swfmill couldn't handle it.
// So, we do this instead:
class PocketClip extends MovieClip {

  static var HALF_OPENED:Int =  6;
  static var FULLY_OPEN:Int = 11;
  static var HALF_CLOSED:Int = 16;
  public var glow:MovieClip;
  public var needFuses:Bool;

  public function new() {
    super();
    addEventListener(Event.ENTER_FRAME, onEnterFrame);
    needFuses = true;
  }

  public function swallow() {
    gotoAndPlay(HALF_CLOSED);
  }

  public function openWide() {
    needFuses = false;
    gotoAndPlay(HALF_CLOSED);
  }

  private function onEnterFrame(e) {

    var frame = this.currentFrame;
    switch (frame) {
    case HALF_OPENED:
      if (needFuses)
	stop();
    case FULLY_OPEN:
      stop();
    default: 
      // do nothing
    }
  }
}

