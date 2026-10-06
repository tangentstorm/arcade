package
{
	import org.flixel.*;

	public class Arrow extends FlxSprite
	{
		
		public function Arrow()
		{
			super(0, 0);
			loadGraphic(Assets.ArrowSprite, false);
			exists = false;
		}
	
	
		override public function update():void
		{
			if (dead && finished) 
			{
				exists = false
			}
			else if (y >= Const.STAGE_HEIGHT)
			{
				exists = false;
			}
			else
			{
				super.update();
			}
		}
		
		override public function hitWall(Contact:FlxCore=null):Boolean 
		{ 
			hurt(0); 
			return true; 
		}
  		override public function hitFloor(Contact:FlxCore=null):Boolean 
  		{ 
  			hurt(0);
  			return true; 
  		}
  		override public function hitCeiling(Contact:FlxCore=null):Boolean { 
  			hurt(0);
  			return true;
  		}
		
		
		override public function hurt(Damage:Number):void
		{
			if (dead) return;
			velocity.x = 0;
			velocity.y = 0;
			dead = true;
		}
		
		public function shoot(x:int, y:int, velocityX:int, velocityY:int):void
		{
			super.reset(x, y);
			velocity.x = velocityX;
			velocity.y = velocityY;
		}
		
		
		
	}
}