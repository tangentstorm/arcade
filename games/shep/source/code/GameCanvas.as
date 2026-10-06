package {
   import flash.display.*;
   import flash.events.Event;
   import flash.system.ApplicationDomain;
   import flash.system.LoaderContext;
   
   import mx.containers.*;
   import mx.controls.*;
   import mx.core.*;

   public class GameCanvas extends Canvas {

      [Embed(source="../game1.swf", mimeType="application/octet-stream")]
      public static var Game1SWF:Class;
      private var loader:Loader;
      private var Game:Class;
      public var StarField:Class;
      public var game:Object;
      
      private var wincb:Function;
      private var losecb:Function;
      private var starCanvas:Canvas;
      
      public function init(winCallback:Function, loseCallback:Function, starCanvas:Canvas):void {

         loader = new Loader();
         var context:LoaderContext = 
            new LoaderContext(false, ApplicationDomain.currentDomain);

         loader.loadBytes(new Game1SWF(), context);
         loader.contentLoaderInfo.addEventListener(Event.COMPLETE, onLoadSWF);
         
         wincb = winCallback;
         losecb = loseCallback;
         this.starCanvas = starCanvas;
      }
      
      private function onLoadSWF(e:Event):void {
      	
      	 Game = ApplicationDomain.currentDomain.getDefinition("Game1") as Class;
      	 StarField = ApplicationDomain.currentDomain.getDefinition("StarField") as Class;

         var container:Sprite = new Sprite();
         rawChildren.addChild(container);
         game = new Game(container);
         game.winCallback = wincb;
         game.loseCallback = losecb;
         
         var starfield:MovieClip = new StarField(800, 575);
         starCanvas.rawChildren.addChild(starfield);
         game.starfield = starfield;
         
         game.done = true;
      }

   }
}
