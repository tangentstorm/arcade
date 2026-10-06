package
{
	import flash.display.BitmapData;
	import flash.geom.Rectangle;
	
	import org.flixel.*;

	public class Bubble extends FlxSprite
	{

		private var owner:Person;

		public function Bubble(person:Person, symbol:int)
		{
			this.owner = person;
			super(person.x, person.y - Const.BUBBLE_HEIGHT);
			this.loadGraphic(Assets.BubbleSprite, false, false, 0, 0, true);
			
			/*
			// draw the symbols:
			var bmp:BitmapData = this.pixels;			
			var bin:String = dec2bin(symbol);
			for (var i:int = 0; i<3; ++i)
			{
				for (var j:int = 0; j<3; ++j)
				{
					if (bin.charAt(i*3+j) == "1")
					{
						bmp.fillRect(new Rectangle(20 + i*Const.BLOCK_SIZE, 5 + j*Const.BLOCK_SIZE, 
												   Const.BLOCK_SIZE, Const.BLOCK_SIZE),
								   		0xFF000000);
					}
				}
			}
			this.pixels = bmp;
			*/
			
			this.visible = false;
		}

		
		
		/*
		// convert decimal number to binary string
		// http://www.kirupa.com/developer/actionscript/binary_conversion.htm
		private function dec2bin(iNumber:Number, digits:int=9) : String
		{
			var bin:String = "";
			var oNumber:Number = iNumber;
			//this while method constructs a string from the number you enter as iNumber when you call the function
			while (iNumber>0)
			{
				if (iNumber%2)
				{
					bin = "1"+bin;
				} else {
					bin = "0"+bin;
				}
				iNumber = Math.floor(iNumber/2);
			}
			// left pad with zeros
			while (bin.length < digits) 
			{
				bin = "0"+bin;
			}
			return bin;
		}
		*/
		
	}		
}