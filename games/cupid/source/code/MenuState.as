package
{
	import org.flixel.*;

	public class MenuState extends FlxState
	{

		public function MenuState()
		{
			super();
			this.add(new FlxSprite(0, 0, Assets.TitleImage));
		}
		
		public override function update():void
		{
			super.update();
			if (FlxG.keys.justPressed("SPACE")) {
				FlxG.switchState(GameState);
			}
		}
		
	}
}
