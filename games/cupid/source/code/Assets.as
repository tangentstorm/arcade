package
{

	public class Assets
	{
				
		// cupid stuff 
		
		[Embed(source="../assets/crosshair-heart-1.png")]
		public static var HeartCursor:Class;

		[Embed(source="../assets/cupid.png")]
		public static var CupidSprite:Class;

		[Embed(source="../assets/arrow.png")]
		public static var ArrowSprite:Class;


		// rain stuff

 		[Embed(source="../assets/raindrop.png")]
	    public static var RaindropSprite:Class;

 		[Embed(source="../assets/heavy-rain.png")]
	    public static var HeavyRainSprites:Class;


		// people

		[Embed(source="../assets/pixel-people-standins-gray.png")]
		public static var PersonSprite:Class;

		[Embed(source="../assets/bubble.png")]
		public static var BubbleSprite:Class;


        [Embed(source="../assets/symbols.png")]
	    public static var SymbolSprite:Class;
	    
	    
	    // hud stuff
	    
	    [Embed(source="../assets/HEART-Symbol-animated.png")]
	    public static var GoodMatchIcon:Class;

	    [Embed(source="../assets/heart-breaking.png")]
	    public static var BadMatchIcon:Class;


		// backgrounds

		[Embed(source="../assets/bg-00.png")]
		public static var BgLayer00:Class;

		[Embed(source="../assets/bg-01.png")]
		public static var BgLayer01:Class;

		[Embed(source="../assets/bg-02.png")]
		public static var BgLayer02:Class;

		[Embed(source="../assets/bg-03.png")]
		public static var BgLayer03:Class;

		[Embed(source="../assets/bg-04.png")]
		public static var BgLayer04:Class;


		// soundloops

 		[Embed(source="../assets/soundloops.swf", symbol="RainSound")]
	    public static var RainLoop:Class;

	    /*
 		[Embed(source="../assets/soundloops.swf", symbol="CupidSong00")]
		public static var CupidSong00:Class;
 		[Embed(source="../assets/soundloops.swf", symbol="CupidSong01")]
		public static var CupidSong01:Class;
 		[Embed(source="../assets/soundloops.swf", symbol="CupidSong02")]
		public static var CupidSong02:Class;
 		[Embed(source="../assets/soundloops.swf", symbol="CupidSong03")]
		public static var CupidSong03:Class;
 		[Embed(source="../assets/soundloops.swf", symbol="CupidSong04")]
		public static var CupidSong04:Class;
	    */

	}
}