import flash.events.Event;
import flash.display.Graphics;

class StarField extends flash.display.MovieClip {
  
  var w:Float;
  var h:Float;
  var stars:Array<Array<phx.Vector>>;
  var counter:Int;
  public var paused:Bool;
  static var layers:Int = 5;
  static var perLayer:Int = 100;
  
  public function new(w:Float, h:Float) {
    super();
    this.w = w;
    this.h = h;
    counter = 0;
    makeStars();
    addEventListener(Event.ENTER_FRAME, onEnterFrame);
  }


  public function makeStars() {
    stars = [];
    for (i in 0 ... layers) {
      stars.push([]);
      for (j in 0 ... perLayer) {
	stars[i].push(new phx.Vector(randomInt(Math.floor(w)), 
				     randomInt(Math.floor(h))));
      }
    }
  }


  public function onEnterFrame(e:Event) {

    if (paused)
      return;

    var g = this.graphics;
    var w = 850;
    var h = 575;

    g.clear();
    g.beginFill(0x000000);
    g.drawRect(0, 0, w, h);
    g.endFill();
    
    // g.lineStyle(0xFFFFFF, 1);

    counter++;
    var v = new phx.Vector(1, 0);
    for (c in 0 ... layers) {
      if (counter % c == 0) {
	for (i in 0 ... perLayer) {
	  var star = stars[c][i];
	  star.x += v.x;
	  star.y += v.y;
	  if (star.y > h) {
	    star.y = 0;
	    star.x = randomInt(Math.floor(w)); 
	  }
	  if (star.x > w) {
	    star.x = 0;
	    star.y = randomInt(Math.floor(h)); 
	  }
	}
      }
      for (i in 0 ... perLayer) {
	var star = stars[c][i];
	drawStar(g, star.x, star.y, 0x333333 * (5 - (c % 5)));
      }
    }
  }

  public function drawStar(g:Graphics, x:Float, y:Float, c) {
    g.beginFill(c);
    g.drawRect(x, y, 2, 1);
    g.endFill();
  }


  public function randomInt(max): Int {
    return Math.floor(Math.random()* max);
  }


}