package
{
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import org.flixel.*;


	public class GameState extends FlxState
	{

		protected var cupid:Cupid = null;
		protected var levelBlocks:Array = new Array();

		protected var people:Array = new Array();
		protected var arrow:Arrow = new Arrow();

		protected var map:FlxTilemap;

		public static var lyrStage:FlxLayer;
        public static var lyrSprites:FlxLayer;
        public static var lyrHUD:FlxLayer;

        public static var lyrRain:FlxLayer;
        public var storm:Storm;
        
        private var lastHit:Person;
        private var couplesLeft:int;
        
        private var timer:Timer;
        private var music:Music;

		private var bgLayers:Array;
		private var level:int;
		
		private var goodMatchIcon:MatchIcon;
		private var badMatchIcon:MatchIcon;

		public function GameState()
		{
			super();
			
			level = -1; // start with -1 so the first tint is 0 (and matches the array index)
				
			addWall(0, Const.STAGE_HEIGHT, Const.GAME_WIDTH, 10);
			
			bgLayers = [];
			addBgLayer(Assets.BgLayer00, 0.0);
			addBgLayer(Assets.BgLayer01, 0.2);
			addBgLayer(Assets.BgLayer02, 0.4);
			addBgLayer(Assets.BgLayer03, 0.6);
			addBgLayer(Assets.BgLayer04, 0.8);


			lyrStage = new FlxLayer();
            lyrSprites = new FlxLayer();
            lyrHUD = new FlxLayer();	
            lyrRain = new FlxLayer();		
			
			
			cupid = new Cupid();
			lyrSprites.add(cupid);
			
			
			var mm:MatchMaker = new MatchMaker();
			couplesLeft = Const.NUM_COUPLES;
			
			people = [];
			for (var i:int = 0; i < Const.NUM_COUPLES; ++i)
			{

				// as a first approximation, we'll pretend these are male-female couples
			  var m:Person = new Person(mm.symbols[i], i);
			  var f:Person = new Person(mm.matches[i], i+Const.NUM_COUPLES);

				people.push(m);
				people.push(f);
				
			}


			var dist:int = Const.GAME_WIDTH / ((Const.NUM_COUPLES*2) +1);
			mm.shuffle(people);
			for (i = 0; i < people.length; ++i)
			{
				var p:Person = people[i];
				p.x = (i+1) * dist;
				lyrSprites.add(p);
				lyrSprites.add(p.bubble);
				lyrSprites.add(p.symbolSprite);
				lyrSprites.add(p.mask);
			}


			FlxG.follow(cupid, 1);
			FlxG.followAdjust(0.5, 0.0);
			FlxG.followBounds(0, 0, Const.GAME_WIDTH, Const.STAGE_HEIGHT);
		
			lyrHUD.scrollFactor.x = 0;					

			this.add(lyrStage);
			this.add(lyrSprites);
			this.add(lyrRain);
			
			
			this.add(lyrHUD);
			
			goodMatchIcon = new MatchIcon(true);
			badMatchIcon = new MatchIcon(false);
			lyrHUD.add(goodMatchIcon, true);
			lyrHUD.add(badMatchIcon, true);
						
			// mouse cursor
			FlxG.showCursor(Assets.HeartCursor);

			// rain background
			music = new Music();
			music.rain();
			
			storm = new Storm(lyrRain);
			lyrSprites.add(arrow, true);			
		}
		
		public function addBgLayer(LayerImage:Class, scrollFactor:Number):void
		{
			var layer:FlxLayer = new FlxLayer();
			var sprite:FlxSprite = new FlxSprite(0, 0, LayerImage);
			sprite.scrollFactor.x = scrollFactor; 
			layer.add(sprite);
			this.add(layer);
			bgLayers.push(layer);
		}
		
		
		public function addWall(x:int, y:int, w:int, h:int):void
		{
			var block:FlxBlock = new FlxBlock(x, y, w, h);
			block.loadGraphic(Assets.SymbolSprite);
			levelBlocks.push(this.add(block));			
		}
		
		public override function update():void
		{
			super.update();
			storm.emit();
			
			if (FlxG.keys.justPressed("N"))
			{
				nextLevel();
			}
			
			if (arrow.exists)
			{
				FlxG.overlapArray(people, arrow, onCollision);
			}
			else if (FlxG.mouse.justPressed())
			{
				onClick(FlxG.mouse.x, FlxG.mouse.y);
			}
			
		}
		
		
		public function nextLevel():void
		{
			level++;
			if (level >= Const.BG_TINTS.length)
			{
				level = 0;
			}	
			tintBackgrounds();
			music.nextLevel();
			storm.nextLevel();
		}
		
		
		public function tintBackgrounds():void
		{
			for (var i:int = 0; i<bgLayers.length; ++i)
			{
				var lyr:FlxLayer = bgLayers[i];
				var sprites:Array = lyr.children()
				for (var j:int =0; j<sprites.length; ++j)
				{
					var s:FlxSprite = sprites[j];
					s.color = Const.BG_TINTS[level][i];
				}
			}
		}
		
		
		public function onClick(x:Number, y:Number):void
		{
			trace("match icon showing? "  + MatchIcon.showing.toString());
			if (! MatchIcon.showing)
			{
				cupid.doShootAnimation();
				var arrowX:int
				if (cupid.facing == FlxSprite.RIGHT)
				{
					arrowX = cupid.x + Const.ARROW_START_XOFF;
				}
				else
				{
					arrowX = cupid.x + cupid.width - Const.ARROW_START_XOFF;
				}
				arrow.shoot(arrowX, 
						    cupid.y + Const.ARROW_START_YOFF,
						    0, Const.ARROW_SPEED);
			}
		}
		
		public function onCollision(person:Person, arrow:Arrow):void
		{

			// only hit one person at a time:			
			if (! arrow.exists)
			{
				return; 
			}
			arrow.exists = false;

			// do nothing if we hit same person twice:
			if (person.stopped)
			{
				return;
			}
			
			person.onArrow();
			if (lastHit == null)
			{
				lastHit = person;
			}
			else
			{
 				this.timer = new Timer(Const.BUBBLE_DURATION, 1);

				// use these aliases so we create a closure below
				var p1:Person = person;
				var p2:Person = lastHit;
				
 				if (person.symbol == lastHit.symbol)
 				{
 					nextLevel();
 					goodMatchIcon.show();
 					this.timer.addEventListener(TimerEvent.TIMER, 
 						function (e:TimerEvent):void { 
 							goodMatch(p1, p2);
 						});
				}
				else
				{
					badMatchIcon.show();
					this.timer.addEventListener(TimerEvent.TIMER,
					function (e:TimerEvent):void {
						// @TODO: bad match animation 
						p1.resume();
						p2.resume();
					});
				}
				timer.start();
				
				// either way, forget about both of them:
				lastHit = null;
			}			
		}
		

		private function goodMatch(p1:Person, p2:Person):void
		{
			// @TODO: good match animation
			p1.dissolve();
			p2.dissolve();
			if (--couplesLeft == 0)
			{
				var text:FlxText = new FlxText(Const.STAGE_WIDTH/2, Const.STAGE_HEIGHT /2, 
								Const.STAGE_WIDTH,
								"YOU WON!");
				text.scrollFactor.x = 0;
				lyrHUD.add(text);
			}
		}
		
	}
}
