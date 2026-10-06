package
{
	import org.flixel.*;

	public class Person extends FlxSprite
	{

		private var speed:Number=0.0;
		public var stopped:Boolean = false;
		private const WALK:String = "walk";
		
		public var bubble:Bubble;
		public var symbol:int;
		public var symbolSprite:FlxSprite;
		public var mask:FlxSprite;
		
	  public function Person(symbol:int, imageNum:int)
		{
			super(0, Const.STAGE_HEIGHT - Const.PERSON_HEIGHT);
			loadGraphic(Assets.PersonSprite, true, true);
			addAnimation(WALK, [imageNum], 12, true);
			play(WALK);

			// mask is a duplicate of the sprite that we'll use for glow effects
			mask = new FlxSprite(0,0);
			mask.loadGraphic(Assets.PersonSprite, true, true);
			mask.addAnimation(WALK, [imageNum], 12, true);
			mask.play(WALK);
			mask.visible = false;
			
			
			facing = (Math.random() > 0.5) ? LEFT : RIGHT;

			var speedChange : int = Math.floor(5.0 * (Math.random()-0.5));
			speed = Const.AVG_WALK_SPEED + speedChange * 0.10;
			
			this.symbol = symbol;
			
			this.symbolSprite = new FlxSprite(x+Const.SYMBOL_OFFSET_X, y-Const.BUBBLE_HEIGHT + Const.SYMBOL_OFFSET_Y);
			this.symbolSprite.loadGraphic(Assets.SymbolSprite, true, false, 0, 0, true);
			this.symbolSprite.specificFrame(symbol);
			this.symbolSprite.visible = false;
			
			
			// this.color = 0xEEEEEE + Math.floor((Math.random()-0.5) * 0x111111);
			this.bubble = new Bubble(this, symbol);
		}


		override public function update():void
		{
			
			if (stopped)
			{
				return;
			}
			
			// randomly turn around .2% of the time
			if (Math.random() > 0.998) {
				facing = (facing == LEFT) ? RIGHT : LEFT;
			}
			
			if (facing == RIGHT)
			{
				x += speed;
				if (x + this.width >= Const.GAME_WIDTH) 
				{
					x = Const.GAME_WIDTH - this.width;
					facing = LEFT;
				}
			} 
			else
			{
				x -= speed;
				if (x <= 0) 
				{
					x = 0;
					facing = RIGHT;
				}
			}
			super.update();
		}
		
		public function onArrow():void
		{
			stopped = true;		
			bubble.x = this.x;	
			symbolSprite.x = this.x + Const.SYMBOL_OFFSET_X;
			bubble.visible = true;
			symbolSprite.visible = true;

			mask.x = this.x;
			mask.y = this.y;
			mask.facing = this.facing;
			mask.visible = true;
			mask.color = Const.PERSON_HIT_TINT;
			mask.blend = Const.PERSON_BLEND_MODE;
			mask.antialiasing = true;
		}
		
		private function clearBubble():void
		{
			bubble.visible = false;
			symbolSprite.visible = false;
			mask.visible = false;
		}
		
		public function resume():void
		{
			stopped = false;
			clearBubble();
		}

		public function dissolve():void
		{
			clearBubble();
			exists = false;
		}

	}		
}