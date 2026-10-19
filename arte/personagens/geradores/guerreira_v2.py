from PIL import Image
P={'o':(42,29,34),'h':(178,58,58),'H':(122,36,48),'s':(240,200,160),'S':(201,148,110),'e':(42,29,34),
'r':(230,140,130),'a':(150,156,180),'A':(92,97,124),'c':(168,50,50),'C':(110,31,40),'b':(107,74,47),
'g':(217,164,65),'w':(226,232,242),'W':(150,162,184),'B':(61,47,42)}
def mirror(half): return [r+r[::-1] for r in half]
def sprite(rows):
    im=Image.new('RGBA',(len(rows[0]),len(rows)),(0,0,0,0))
    for y,r in enumerate(rows):
        for x,c in enumerate(r):
            if c!='.': im.putpixel((x,y),P[c]+(255,))
    return im
# CABEÇA 18x13 (mais larga que o tronco)
head=sprite(mirror([".....ooooo","...oohhhhh","..ohhhhhhh",".ohhhhhhhh","ohhhhhHhhh","ohhhHsssss",
 "ohhhssssss","ohhssoesss","ohhssoesss","ohhSssssss","ohhsrrssss",".ohSssssss",".ohsssssss",".ohoSSSSSS","..oooooooo"]))
# TRONCO 12x9, sem braços
tr=["..oAaa","oAaaaa","oAaacc","oaaccc","obbbbb","occccc","occCcc","occccC","oooooo"]
tr=mirror(tr); tr[4]=tr[4][:5]+"gg"+tr[4][7:]; torso=sprite(tr)
leg=sprite(["osso","osso","oBBo","oooo"])
# ESPADA com a mão como pegada (pivô = mão)
sw=["..o..",".owo.",".owo.",".oWo.",".owo.",".owo.",".oWo.",".owo.",".owo.",".oWo.",
    "ooooo","ogggo",".obo.","osSso","osSso",".ogo."]
sword=sprite(sw); HAND=(2,13)
def place_sword(canvas,pos,ang,flip=False):
    R=40; big=Image.new('RGBA',(R*2,R*2),(0,0,0,0)); big.paste(sword,(R-HAND[0],R-HAND[1]))
    big=big.rotate(-ang if flip else ang,resample=Image.NEAREST)
    if flip: big=big.transpose(Image.FLIP_LEFT_RIGHT).transform(big.size,Image.AFFINE,(1,0,-1,0,1,0))
    canvas.alpha_composite(big,(pos[0]-R,pos[1]-R))
W,H=56,44; CX=W//2
def frame(t_dy=0,h_dy=0,lL=0,lR=0,angL=0,angR=0,sL=(0,0),sR=(0,0)):
    c=Image.new('RGBA',(W,H),(0,0,0,0))
    for x in range(CX-9,CX+9):  # sombra
        c.putpixel((x,36),(0,0,0,70)); c.putpixel((x,37),(0,0,0,50))
    c.alpha_composite(leg,(CX-5,33+lL)); c.alpha_composite(leg,(CX+1,33+lR))
    c.alpha_composite(torso,(CX-6,25+t_dy))
    place_sword(c,(CX-8+sL[0],31+t_dy+sL[1]),angL+45)
    place_sword(c,(CX+8+sR[0],31+t_dy+sR[1]),angR-45,flip=True)
    c.alpha_composite(head,(CX-10,14+h_dy))
    return c
def bg(f,S=8):
    out=Image.new('RGBA',(W,H),(96,78,60,255)); out.alpha_composite(f)
    return out.resize((W*S,H*S),Image.NEAREST).convert('RGB')
walk=[frame(t,h,a,b) for t,h,a,b in [(0,0,0,0),(1,0,-1,0),(1,1,-1,0),(0,0,0,0),(1,0,0,-1),(1,1,0,-1)]]
atk=[frame(angR=a,sR=s,t_dy=t,h_dy=h) for a,s,t,h in
     [(0,(0,0),0,0),(-35,(1,-1),0,0),(-60,(2,-2),0,0),(40,(-3,0),1,0),(110,(-6,1),1,1),(120,(-6,1),1,1),(60,(-2,0),0,0),(0,(0,0),0,0)]]
def gif(fr,name,ms): 
    im=[bg(f) for f in fr]; im[0].save(name,save_all=True,append_images=im[1:],duration=ms,loop=0)
gif(walk,'walk.gif',130); gif(atk,'ataque.gif',[150,90,90,50,60,120,90,200])
# folha de camadas
S=8; parts=[head,torso,leg,sword]; sheet=Image.new('RGBA',(sum(p.width+4 for p in parts)+4,20),(96,78,60,255))
x=4
for p in parts: sheet.alpha_composite(p,(x,2)); x+=p.width+4
sheet.resize((sheet.width*S,sheet.height*S),Image.NEAREST).save('camadas.png')
bg(walk[0]).save('guerreira_v2.png')
