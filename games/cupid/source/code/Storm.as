package
{
	import org.flixel.*;
	
	public class Storm
	{

		private var clouds:Array;
		private var cloudsLeft:int;

		public function Storm(layer:FlxLayer)
		{
			
			cloudsLeft = Const.NUM_COUPLES;

			clouds = [];
			for (var i:int = 0; i<cloudsLeft; ++i)
			{
				var sprinkler:FlxEmitter;
				sprinkler = new FlxEmitter(0, -100, 0.7);
				sprinkler.scrollFactor.x = Const.RAIN_SCROLL_FACTOR;
				sprinkler.createSprites(Assets.HeavyRainSprites, Const.HEAVY_RAIN, true, layer);
				sprinkler.setXVelocity(20, 20);		
				sprinkler.setRotation(0, 0);
				sprinkler.setSize(Const.GAME_WIDTH, 0);
				clouds.push(sprinkler);

			/*
				// seed the sprinkler so the stage opens with rain already falling
				for (i= 0; i<20; i++)
				{
					sprinkler.emit();
				}
			*/

			}
			
		}
		
		
		public function emit():void
		{
			for (var i:int = 0; i<cloudsLeft; ++i)
			{
				clouds[i].emit();
			}
		}
		
		public function nextLevel():void
		{
			cloudsLeft--;
		}

	}
}