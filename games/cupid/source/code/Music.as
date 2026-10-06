package
{
	import org.flixel.*;
	
	
	public class Music
	{
	
		private var rainLoop:FlxSound;
		private var tracks:Array;
		public var level:int;
		
		private const kRainVolume:Number = 0.5;
		private const kRainStep:Number = 0.1;
	
		public function Music()
		{
					
			FlxG.volume = 0.7;
			
			rainLoop = new FlxSound();
			rainLoop.loadEmbedded(Assets.RainLoop, true);
			rainLoop.volume = kRainVolume;
			
			level = 0;

			/*
			tracks = [];
			for (var i:int = 0; i < 5; ++i)
			{
				var track:FlxSound = new FlxSound();
				track.loadEmbedded(Assets["CupidSong0" + i], true);
				track.volume = 0;
				tracks.push(track);
			}
			for (i=0; i<5; ++i)
			{
				tracks[i].play();
			}
			*/
		}
		
		
		public function rain():void
		{
			rainLoop.play();
		}


		public function nextLevel():void
		{
			level++;
			var i:int;
			if (6 == level)
			{
				level = 0;
				/*for (i = 0; i<5; ++i)
				{
					tracks[i].volume = 0;
				}
				*/
				rainLoop.volume = kRainVolume;
			}
			else
			{
			  /*
				for (i=0; i<5; ++i)
				{
					var track:FlxSound = tracks[i];
					track.volume = (i == level-1) ? 1.0 : 0.0;
				}
			  */
				rainLoop.volume -= kRainStep;
			}
		}




	}
}