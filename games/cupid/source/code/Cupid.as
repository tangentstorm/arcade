package
{
	import org.flixel.*;

	public class Cupid extends FlxSprite
	{
		
		
		protected static const SPEED:Number = 2.5; // base speed... it changes based on how far the mouse is moved
		protected static const kFlightAnimation:String = "flight";					
		protected static const kShootAnimation:String = "shoot";					
		
		public function Cupid()
		{
			super(Const.CUPID_START_X, Const.CUPID_START_Y);
			loadGraphic(Assets.CupidSprite, true, true);

			addAnimation(kFlightAnimation, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], 12, true);
			addAnimation(kShootAnimation, [10, 11, 12, 10], 12, true);
			
			addAnimationCallback(onFrame);
			play(kFlightAnimation);			
		}


		public function doShootAnimation():void
		{
			play(kShootAnimation, true);
		}
		
		private function onFrame(name:String, num:uint, index:uint):void
		{
			if (finished && name=="shoot")
			{
				play(kFlightAnimation);
			}
			
		}

		override public function update():void
		{
			var dx:int = (FlxG.mouse.x - x);
			velocity.x = dx * SPEED;
			if (dx > 0)
			{
				facing = RIGHT;
			} 
			else if (dx < 0)
			{
				facing = LEFT;
			}
			super.update();
		}

	}		
}