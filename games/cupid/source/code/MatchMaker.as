package
{

	public class MatchMaker
	{
		
		public var symbols:Array;
		public var matches:Array;
		
		
		public function MatchMaker()
		{
			generateSymbols();
			shuffle(symbols);
			generateMatches();
			shuffle(matches);
		}


		private function generateSymbols():void
		{
			symbols = [];
			while (symbols.length < Const.NUM_COUPLES)
			{
                //var sym:int = Math.floor(Math.random() * 512);
			    var sym:int = symbols.length;
				if (symbols.indexOf(sym) == -1)
				{
					symbols.push(sym);
				}
			}
		}

		private function generateMatches():void
		{
			matches = [];
			for (var i:int = 0; i<symbols.length; ++i)
			{
				matches.push(symbols[i]);
			}
		}
		
		public function shuffle(arr:Array):void
		{
			for (var i:int=0; i<arr.length * 10; ++i)
			{
				var a:int = Math.floor(Math.random() * arr.length);
				var b:int = Math.floor(Math.random() * arr.length);
				var tmp:Object = arr[b];
				arr[b] = arr[a];
				arr[a] = tmp;
			}	
		}
	}
	
}
