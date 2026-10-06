
HAXE_ROOT="d:/haxe-2.07-win"
HAXE_STD_PATH="$(HAXE_ROOT)/std"
haxe = "$(HAXE_ROOT)/haxe.exe"
swfmill = ./tools/swfmill.exe
mxmlc = "d:/flex3.6/bin/mxmlc.exe"

# main : game1.swf
main : assets.swf

assets.swf : assets/assets.swfml
	$(swfmill) simple assets/assets.swfml assets.swf


# march 2020: I don't know why putting these arguments in a .hxml file
# isn't working any more, but it just plain ignores the file for me.
haxe_args = -v \
          -swf-header 800:575:24:eeeeee \
          -swf-version 9 \
          -swf-lib assets.swf \
          -main Game1 \
          -debug \
          -cp lib \
          -cp code

# shep.swf just jumps directly into the first level
shep.swf : assets.swf code/*.hx
	$(haxe) -swf shep.swf $(haxe_args)

# game1 is the version that expects to be wrapped by console.swf
game1.swf : assets.swf code/*.hx
	$(haxe) -swf game1.swf -D FLEX_WRAP $(haxe_args)

# console.swf is the version with flex ui wrappers
console.swf : game1.swf
	$(mxmlc) code/console.mxml -define=CONFIG::kong,false -output console.swf


clean:
	rm -f assets.swf game1.swf unittest.n
	tools\find -name "*~" -exec tools\rm {} ;


debug: game1.swf
	flashdebug10.exe game1.swf

.PHONY : test
test:
	$(haxe) unittest.hxml
#	$(neko) unittest.n
