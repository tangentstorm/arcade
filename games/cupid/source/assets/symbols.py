import Image, ImageDraw
import math

black = 0x000000
white = 0xffffff

cornflower = 0xCC9966
color = cornflower

pixelSize = 1
gutterSize = 2

power = 2 # each symbol is a power * power  grid

# odd powers won't be square, so make half a grid:
oddPower = (power % 2 == 1)
if oddPower:
    numcols = 2**((power*power/2)+1)
    numrows = 2**(power*power/2)
else:
    numcols = numrows = int(math.sqrt(2**((power)**2)))

symbolSize = power * pixelSize
imageW = gutterSize + (numcols * (symbolSize + gutterSize))
imageH = gutterSize + (numrows * (symbolSize + gutterSize))

img = Image.new("RGB", (imageW, imageH))

draw = ImageDraw.Draw(img)
draw.rectangle(((0,0), (imageW, imageH)), fill=color)


for y in range(numrows):
    print "working on row %s of %s" % (y, numrows)
    for x in range(numcols):

        # generate 16 digit binary representation
        num = y * numcols + x
        digits = bin(num)[2:]
        while len(digits) < (power*power):
            digits = "0" + digits
        digits = "".join(reversed(digits))

        # break into a power*power grid
        rows = []
        for d in range(power):
            rows.append(digits[ power*d:power*(d+1)  ])

        # (a, b) is upper left
        a = gutterSize + x * (symbolSize + gutterSize)
        b = gutterSize + y * (symbolSize + gutterSize)

        # draw the pixels
        for i, row in enumerate(rows):            
            for j, digit in enumerate(row):
                color = black if digit == '1' else white
                
                px = a + (i * pixelSize)
                py = b + (j * pixelSize)

                draw.rectangle(((px, py), (px+pixelSize-1, py+pixelSize-1)),
                               fill=color)
        
#img.show()
name = "c:/temp/%sx%s-symbols.png" % (power, power)
print "wrote %s" % name
img.save(name, "PNG")
        
