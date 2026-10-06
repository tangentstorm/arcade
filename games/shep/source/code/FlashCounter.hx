import flash.display.MovieClip;

/* Shows a sequence of digits.
 * The digitFactory clip should have 10 frames
 * containing the digits (0..9)
 */
class FlashCounter extends MovieClip {
  
  private var digits: Array<MovieClip>;

  public function new ( numDigits: Int, digitFactory : Void -> MovieClip) {
    super();

    this.digits = [];
    for (i in 0...numDigits) {
      var digit = digitFactory();
      digit.x = i * digit.width;
      digit.stop();
      this.addChild(digit);
      this.digits.push(digit);
    }	   
  }

  public function show(value : Int) {

    var curr:Int = 0;

    for (i in 0...digits.length) {

      // get the current digit, right to left
      curr = Math.floor(value % Math.pow(10, i+1) / Math.pow(10, i));

      // the array is left to right, so we use length-i
      // and the frames start at frame 1 for "0" so we use curr+1
      this.digits[digits.length - i - 1].gotoAndStop(curr + 1);
      
    }
  }

}
