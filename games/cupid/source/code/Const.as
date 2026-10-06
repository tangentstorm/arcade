package
{
	public class Const
	{

		// I lied. these aren't constants at all.
		// Rather, they're pulled from the values in game2.mxml
		// (flex prohibits expressions in application attributes)
		public static var STAGE_WIDTH:int; 
		public static var STAGE_HEIGHT:int;

		public static const GAME_WIDTH:int = 1800;

		
		// number of pixels above bottom of stage for the top of the sprites:
		public static const PERSON_HEIGHT:int = 90;		
		public static const BUBBLE_HEIGHT:int = 55; // height above person's head
		
		public static const NUM_COUPLES:int = 5;
		
		public static const SYMBOL_COUNT:int=10;
		public static const SYMBOL_OFFSET_X:int=15;
		public static const SYMBOL_OFFSET_Y:int=5;
		
		public static const HEAVY_RAIN:int = 500; // particles per cloud
		public static const RAIN_SCROLL_FACTOR:Number = 0.33;

		public static const AVG_WALK_SPEED:Number = 1.25;
		public static const ARROW_SPEED:Number = 500;
		
		public static const BUBBLE_DURATION:Number = 1500; // ms
		
		
		public static const MATCH_ICON_SIZE:int = 40;
		
		

		public static const CUPID_START_X:int = 300;
		public static const CUPID_START_Y:int = 55;

		// these are relative to cupid
		public static const ARROW_START_XOFF:int = 42;
		public static const ARROW_START_YOFF:int = 72;
		
		
		// these are the tints for each layer at each level of gameplay
		// example: for the sky, I drew a gradient from gray (0xBBC1C4)
		// to a nice happy blue sky (0xA0CFE2)... 
		
		public static const BG_TINTS:Array = [
		    // sky      far       mid      near      fg bldgs
			[0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF],
			[0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF],
			[0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF],
			[0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF],
			[0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF, 0xFFFFFF],
		];
		
		// this is the color to apply to the person when they're
		// hit. a second copy of the sprite is overlaid, tinted to
		// this color and applied in this mode
		public static const PERSON_HIT_TINT:uint = 0xFFCCCC;
        public static const PERSON_BLEND_MODE:String = "screen";
	}
}