import flash.display.MovieClip;

// @TODO: there should to be a plain Clock decoupled from flash

class ClockDigit extends MovieClip {}

class FlashClock extends FlashCounter {
  
  public var timeCount: Float;
  var timeEnd: Float;
  static var _TIME_LIMIT = 90;

  public function new () {
    super(4, function() { return new ClockDigit(); });
  }

  public function startTimer(howLong: Float) {
    timeEnd = haxe.Timer.stamp() + howLong;
  }


  public function updateCount () {
    timeCount = Math.ceil(timeLeft());
    if (timeCount <= 0) {
      timeCount = 0;
    }
  }
  
  public function timeLeft() {
    return timeEnd - haxe.Timer.stamp();
  }


  public function tick() {
    updateCount();
    updateDisplay();
  }

  // public function pause() {
  //    (we don't actually need this... we just don't call tick())
  // }

  public function resume() {
    this.startTimer(this.timeCount);
  }

  public function updateDisplay() {
    var mins:Int = Math.floor(timeCount / 60);
    var secs:Int = Math.floor(timeCount % 60);
    
    this.digits[0].gotoAndStop(Math.floor(mins / 10) + 1);
    this.digits[1].gotoAndStop(Math.floor(mins % 10) + 1);
    this.digits[2].gotoAndStop(Math.floor(secs / 10) + 1);
    this.digits[3].gotoAndStop(Math.floor(secs % 10) + 1);
  }

  override public function toString():String {
    updateCount();
    var mins:Int = Math.floor(timeCount / 60);
    var secs:Int = Math.floor(timeCount % 60);
    return "" 
      + Math.floor(mins / 10)
      + ""
      + Math.floor(mins % 10)
      + ":"
      + Math.floor(secs / 10)
      + ""
      + Math.floor(secs % 10);
  }

}
