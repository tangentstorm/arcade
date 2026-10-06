package
{
	import mx.core.UIComponent;
	import flash.display.DisplayObject;

	public class DisplayObjectUIComponent extends UIComponent
	{
		public function DisplayObjectUIComponent(sprite:DisplayObject)
		{
			super();
			
			explicitHeight = sprite.height;
			explicitWidth = sprite.width;
			
			addChild(sprite);
		}
		
	}
}