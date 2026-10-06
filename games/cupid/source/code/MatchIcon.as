package
{
	import org.flixel.*;

	public class MatchIcon extends FlxSprite
	{

		private var owner:Person;
		public static var showing:Boolean = false;
		private var lastFrame:int;
		private var good:Boolean;
		private var which:String;
		
		public function MatchIcon(goodMatch:Boolean = true)
		{
			
			super((Const.STAGE_WIDTH-Const.MATCH_ICON_SIZE)/2,
			      (Const.STAGE_HEIGHT-Const.MATCH_ICON_SIZE)/2);
			      
			good = goodMatch;
			if (good)
			{
				this.lastFrame = 6;
				this.which = "good";
				this.loadGraphic(Assets.GoodMatchIcon, true);
				this.addAnimation(which, [0, 1, 2, 3, 4, 5, 6], 12, false);
			}
			else
			{
				this.which = "bad";
				this.lastFrame = 8;
				this.loadGraphic(Assets.BadMatchIcon, true);
				this.addAnimation(which, [0, 1, 2, 3, 4, 5, 6, 7, 8], 12, false);
			}
			this.addAnimationCallback(onFrameChange);
			this.visible = false;
		}
		
		
		public function show():void
		{
			this.visible = true;
			showing = true;
			trace("playing " + which) 
			this.play(which, true);
		}
		
		public function onFrameChange(name:String, num:uint, index:uint):void
		{
			trace("name: " + name + " num: " + num.toString() + " index: " + index.toString() + " lastFrame: " + lastFrame);	
			if (visible && (index == lastFrame))
			{
				trace("hiding " + which + " match icon");
				showing = false;
				finished = true;
				// this.visible = false;
			}
		}
	}
}