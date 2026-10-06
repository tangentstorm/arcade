
import os

levels = [fname for fname in os.listdir("levels") 
          if fname.endswith(".svg")]


print "class LevelPack {"

for item in levels:
    num = item.split(".")[0]
    xml = open("levels/" + item).read()
    print '  public static var svg%s = "%s";' % (num, xml.replace('"', '\\"'))

print "}"
