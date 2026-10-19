from PIL import Image, ImageDraw, ImageFont
import random
P={'o':(42,29,34),'h':(178,58,58),'H':(122,36,48),'s':(240,200,160),'S':(201,148,110),'e':(42,29,34),
'a':(150,156,180),'A':(92,97,124),'c':(168,50,50),'C':(110,31,40),'b':(107,74,47),'g':(217,164,65),
'w':(226,232,242),'W':(150,162,184),'B':(61,47,42)}
half=["..........oooooo","........oohhhhhh",".......ohhhhhhhh","......ohhhhhhhhh","......ohhHHhhhhh",
".....ohhHsssssss",".....ohhsoesssss",".....ohhsoesssss",".....ohhssssssss",".....ohhSsssssss",
"......ohhSsssssS","......ohhooooooo",".....ohhoAaaaaaa","....ohhoaaaaAccc","....ohoAaaaaAccc",
".....oAaoaaaAccc",".....oaaooaaAccc",".....oaaocccbbbg",".....ossoccccccc",".....ossoCcccccc",
"......oocccccccc","......occcccCccc",".....occcccCcccc",".....oooooooocco","..........osso..",
"..........oBBo..",".........oBBBo..",".........ooooo.."]
W,H=32,30; g=[['.']*W for _ in range(H)]
for y,r in enumerate(half):
    for x,c in enumerate(r): g[y+2][x]=c; g[y+2][W-1-x]=c
def put(x,y,c):
    if 0<=x<W and 0<=y<H: g[y][x]=c; g[y][W-1-x]=c
# espada: lâmina diagonal da mão (6,20) para cima-esquerda
blade=[(5-i//3,19-i) for i in range(14)]
for x,y in blade:
    for dx,dy in((-1,0),(1,0),(0,-1),(0,1)):
        if 0<=y+dy<H and 0<=x+dx<W and g[y+dy][x+dx]=='.': put(x+dx,y+dy,'o')
for i,(x,y) in enumerate(blade): put(x,y,'w' if i%4 else 'W')
for x,y in[(4,20),(5,21),(7,19),(3,19),(8,18)]: put(x,y,'g')
put(7,22,'b'); put(8,23,'g')
S=10; img=Image.new('RGB',(W*S+160,H*S+120),(0,0,0)); d=ImageDraw.Draw(img)
random.seed(3); cx,cy=img.width//2,img.height//2+30
for y in range(0,img.height,S//2):
    for x in range(0,img.width,S//2):
        dist=((x-cx)**2+(y-cy)**2)**.5; k=max(0,1-dist/260)
        base=(120+random.randint(-8,8),98+random.randint(-6,6),74)
        col=tuple(int(v*(0.55+0.6*k)) for v in base)
        d.rectangle([x,y,x+S//2-1,y+S//2-1],fill=col)
ox,oy=80,80
d.ellipse([ox+8*S,oy+28*S,ox+24*S,oy+31*S],outline=(120,220,140),width=4)
for y in range(H):
    for x in range(W):
        if g[y][x]!='.': d.rectangle([ox+x*S,oy+y*S,ox+x*S+S-1,oy+y*S+S-1],fill=P[g[y][x]])
bx=ox+9*S; d.rectangle([bx-3,oy-17,bx+14*S+3,oy-1],fill=(42,29,34)); d.rectangle([bx,oy-14,bx+14*S,oy-4],fill=(70,170,110))
try: f=ImageFont.truetype("DejaVuSerif.ttf",26)
except: f=ImageFont.load_default()
d.text((img.width//2,oy-38),"Kaelis",font=f,fill=(240,230,215),anchor="mm",stroke_width=2,stroke_fill=(42,29,34))
img.save('/mnt/d/pixelart/guerreira.png')
