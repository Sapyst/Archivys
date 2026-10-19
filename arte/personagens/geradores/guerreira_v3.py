import math, random, os
from PIL import Image, ImageDraw, ImageFont
OUT=os.path.join(os.path.dirname(os.path.abspath(__file__)),'..','sprites','armas_e_ataques')
P={'o':(42,29,34),'h':(178,58,58),'H':(122,36,48),'s':(240,200,160),'S':(201,148,110),'e':(42,29,34),
'r':(230,140,130),'a':(150,156,180),'A':(92,97,124),'c':(168,50,50),'C':(110,31,40),'b':(107,74,47),
'g':(217,164,65),'w':(226,232,242),'W':(150,162,184),'B':(61,47,42)}
ELEM={'fogo':((200,60,30),(250,140,40),(255,235,150)),'agua':((40,90,200),(90,170,240),(215,240,255)),
'eletrico':((210,170,30),(250,235,90),(255,255,240)),'vento':((50,140,90),(130,215,150),(225,255,230))}
W,H=80,56; CX=32; TX=66; GY=47

def mirror(h): return [r+r[::-1] for r in h]
def spr(rows,outline=False,pal=P):
    w=max(len(r) for r in rows); rows=[r.ljust(w,'.') for r in rows]
    if outline:
        rows=['.'*(w+2)]+['.'+r+'.' for r in rows]+['.'*(w+2)]
        g=[list(r) for r in rows]
        for y in range(len(g)):
            for x in range(len(g[0])):
                if g[y][x]=='.' and any(0<=y+dy<len(g) and 0<=x+dx<len(g[0]) and rows[y+dy][x+dx] not in '.o'
                                        for dx,dy in((1,0),(-1,0),(0,1),(0,-1))): g[y][x]='o'
        rows=[''.join(r) for r in g]
    im=Image.new('RGBA',(len(rows[0]),len(rows)),(0,0,0,0))
    for y,r in enumerate(rows):
        for x,c in enumerate(r):
            if c!='.': im.putpixel((x,y),pal[c]+(255,))
    return im

# ---------- corpo (camadas) ----------
head=spr(mirror([".....ooooo","...oohhhhh","..ohhhhhhh",".ohhhhhhhh","ohhhhhHhhh","ohhhHsssss",
 "ohhhssssss","ohhssoesss","ohhssoesss","ohhSssssss","ohhsrrssss",".ohSssssss",".ohsssssss",".ohoSSSSSS","..oooooooo"]))
tr=mirror(["..oAaa","oAaaaa","oAaacc","oaaccc","obbbbb","occccc","occCcc","occccC","oooooo"])
tr[4]=tr[4][:5]+"gg"+tr[4][7:]; torso=spr(tr)
leg=spr(["osso","osso","oBBo","oooo"])

# ---------- armas (mão = pegada; pivô = mão) ----------
WP={}
WP['sword']=(spr([".w."]*3+[".W."]+[".w."]*2+[".W."]+[".w."]*3+["ggg",".b.","sSs","sSs",".g."],True),(2,13))
WP['gsword']=(spr(["..w.."]+[".wwW."]*14+["ggggg","..b..",".sSs.",".sSs.","..g.."],True),(3,18))
for e,(d,m,l) in ELEM.items():
    pal=dict(P); pal['X']=m; pal['x']=l
    rows=[".X.","XxX",".X."]+[".b."]*18; rows[13]=rows[14]="sSs"
    WP['staff_'+e]=(spr(rows,True,pal),(2,14))
bow=[['.']*5 for _ in range(17)]
for y in range(17): bow[y][round(3*math.sin(math.pi*y/16))]='b'
for x,c in zip(range(2,5),"sSs"): bow[8][x]=c; bow[9][x]='sSs'[x-2]
WP['bow']=(spr([''.join(r) for r in bow],True),(4,9))
WP['hand']=(spr(["sSs","sSs"],True),(2,2))

def place(c,key,pos,ang,mir):
    s,pv=WP[key]; R=48
    big=Image.new('RGBA',(R*2,R*2),(0,0,0,0)); big.paste(s,(R-pv[0],R-pv[1]))
    big=big.rotate(-ang if mir else ang,resample=Image.NEAREST)
    if mir: big=big.transpose(Image.FLIP_LEFT_RIGHT).transform(big.size,Image.AFFINE,(1,0,-1,0,1,0))
    c.paste(big,(pos[0]-R,pos[1]-R),big)
def rot(v,ang):
    a=math.radians(ang); return (v[0]*math.cos(a)+v[1]*math.sin(a), -v[0]*math.sin(a)+v[1]*math.cos(a))

# ---------- primitivas de efeito ----------
def px(c,x,y,col,a=255):
    x,y=int(round(x)),int(round(y))
    if 0<=x<W and 0<=y<H: c.putpixel((x,y),tuple(col[:3])+(a,))
def line(c,x0,y0,x1,y1,col,a=255):
    n=max(abs(x1-x0),abs(y1-y0),1)
    for i in range(int(n)+1): px(c,x0+(x1-x0)*i/n,y0+(y1-y0)*i/n,col,a)
def disc(c,x,y,r,col,a=255):
    for yy in range(-r,r+1):
        for xx in range(-r,r+1):
            if xx*xx+yy*yy<=r*r+r*0.8: px(c,x+xx,y+yy,col,a)
WHITE=(255,255,255); SL=((255,255,255),(205,222,255),(140,160,215))
def slash(c,cx,cy,r,a0,a1,th=3,fade=False,cols=SL):
    n=int(abs(a1-a0)/180*math.pi*r*2)+6
    for i in range(n+1):
        f=i/n; a=math.radians(a0+(a1-a0)*f)
        t=max(1,round(th*math.sin(math.pi*(0.15+0.85*f))))
        for k in range(t):
            px(c,cx+(r-k)*math.cos(a),cy-(r-k)*math.sin(a),cols[min(k,2)],140 if fade else 255)
def sparks(c,x,y,r,cols,n=10,seed=0,a=255):
    rnd=random.Random(seed)
    for _ in range(n):
        ang=rnd.uniform(0,2*math.pi); rr=rnd.uniform(r*0.4,r)
        px(c,x+rr*math.cos(ang),y+rr*math.sin(ang)*0.8,rnd.choice(cols),a)
def bolt(c,x0,y0,x1,y1,e,seed):
    d,m,l=ELEM[e]; rnd=random.Random(seed)
    L=math.hypot(x1-x0,y1-y0); n=max(2,int(L/4)); nx,ny=-(y1-y0)/L,(x1-x0)/L
    pts=[(x0,y0)]+[(x0+(x1-x0)*k/n+nx*rnd.uniform(-2.5,2.5),y0+(y1-y0)*k/n+ny*rnd.uniform(-2.5,2.5)) for k in range(1,n)]+[(x1,y1)]
    for (a,b),(p,q) in zip(pts,pts[1:]):
        line(c,a+1,b,p+1,q,m); line(c,a,b+1,p,q+1,d)
    for (a,b),(p,q) in zip(pts,pts[1:]): line(c,a,b,p,q,l)
def arrow(c,x,y,L=9,ang=0,glow=None):
    a=math.radians(ang); dx,dy=math.cos(a),-math.sin(a); nx,ny=-dy,dx
    if glow:
        for k in range(-1,L+1):
            for s in(-1,1): px(c,x+dx*k+nx*s,y+dy*k+ny*s,glow)
    for k in range(L):
        X,Y=x+dx*k,y+dy*k
        if k<2: col=(190,50,50); px(c,X+nx,Y+ny,col); px(c,X-nx,Y-ny,col)
        elif k>=L-2: col=(205,210,220)
        else: col=(150,105,60)
        px(c,X,Y,col)
    px(c,x+dx*(L-2)+nx,y+dy*(L-2)+ny,(205,210,220)); px(c,x+dx*(L-2)-nx,y+dy*(L-2)-ny,(205,210,220))

# ---------- quadro ----------
def anchors(fr): return {'L':(CX-8+fr['dx'],41+fr['t']),'R':(CX+8+fr['dx'],41+fr['t'])}
def mk(wpn,R=None,L=None,**kw):
    d=dict(t=0,h=0,lL=0,lR=0,dx=0,fx=None,shake=(0,0),pull=False,nock=False); d.update(kw); items=[]
    for side,ov in(('L',L),('R',R)):
        key,ang,off,mir=wpn[side]
        if ov: ang,off=ov
        items.append((key,side,off,ang,mir))
    d['items']=items; return d
def render(fr):
    c=Image.new('RGBA',(W,H),(0,0,0,0)); dx=fr['dx']
    for x in range(CX-9+dx,CX+9+dx): px(c,x,46,(0,0,0),70); px(c,x,47,(0,0,0),45)
    c.paste(leg,(CX-5+dx,43+fr['lL']),leg); c.paste(leg,(CX+1+dx,43+fr['lR']),leg)
    c.paste(torso,(CX-6+dx,35+fr['t']),torso)
    g=anchors(fr); pos={}
    for key,side,off,ang,mir in fr['items']:
        pos[side]=((g[side][0]+off[0],g[side][1]+off[1]),ang,key)
        if key!='hand': place(c,key,pos[side][0],ang,mir)
    if pos['R'][2]=='bow':
        p=pos['R'][0]; t1,t2=(p[0]-3,p[1]-8),(p[0]-3,p[1]+8); q=pos['L'][0]; sc=(225,220,200)
        if fr['pull']: line(c,*t1,*q,sc); line(c,*q,*t2,sc)
        else: line(c,*t1,*t2,sc)
        if fr['nock']:
            tail=q[0] if fr['pull'] else p[0]-3
            arrow(c,tail,p[1]-1,p[0]+6-tail,glow=fr.get('glow'))
    for key,side,off,ang,mir in fr['items']:
        if key=='hand': place(c,key,pos[side][0],ang,mir)
    c.paste(head,(CX-10+dx,24+fr['h']),head)
    if fr['fx']: fr['fx'](c,g,pos)
    return c

rng=random.Random(7); NOISE=[[rng.random() for _ in range(W)] for _ in range(H)]
def ground(ox=0,oy=0):
    im=Image.new('RGBA',(W,H))
    for y in range(H):
        for x in range(W):
            n=NOISE[(y+oy)%H][(x+ox)%W]
            col=(96,78,60) if 0.08<n<0.93 else ((82,66,50) if n<=0.08 else (112,92,72))
            im.putpixel((x,y),col+(255,))
    return im
def compose(fr,ox=0,oy=0):
    bg=ground(ox,oy); c=render(fr); bg.paste(c,fr['shake'],c); return bg

# ---------- poses base ----------
IDLE_T=[0,0,1,1,1,1,0,0]; IDLE_H=[0,0,0,1,1,0,0,0]
WALK=[(0,0,0,0),(1,0,-1,0),(1,1,-1,0),(0,0,0,0),(1,0,0,-1),(1,1,0,-1)]
def idle(w): return [mk(w,t=t,h=h) for t,h in zip(IDLE_T,IDLE_H)]
def walk(w): return [mk(w,t=t,h=h,lL=a,lR=b) for t,h,a,b in WALK]
def orb(pos): p,a,_=pos['R']; v=rot((0,-12),a); return (p[0]+v[0],p[1]+v[1])

HAND_FREE=('hand',0,(0,0),False)
W_SWORD={'L':HAND_FREE,'R':('sword',-45,(0,0),True)}
W_GS={'L':HAND_FREE,'R':('gsword',-55,(1,0),True)}
W_DUAL={'L':('sword',45,(0,0),False),'R':('sword',-45,(0,0),True)}
W_BOW={'L':HAND_FREE,'R':('bow',0,(2,-2),False)}
def W_STAFF(e): return {'L':HAND_FREE,'R':('staff_'+e,-15,(0,0),False)}

def S(cx,cy,r,a0,a1,th=3,fade=False): return lambda c,g,p:slash(c,g['R'][0]+cx,g['R'][1]+cy,r,a0,a1,th,fade)
def SL_(side,cx,cy,r,a0,a1,th=3,fade=False): return lambda c,g,p:slash(c,g[side][0]+cx,g[side][1]+cy,r,a0,a1,th,fade)
def both(*fs): return lambda c,g,p:[f(c,g,p) for f in fs if f]
DUST=((165,140,110),(130,108,84),(190,170,140))

# ---------- espada ----------
def atk_sword():
    w=W_SWORD; r=mk(w)
    a1=[r,mk(w,R=(20,(-2,-1))),mk(w,R=(50,(-4,-2))),mk(w,R=(-20,(0,-1)),fx=S(-1,-1,14,150,70)),
        mk(w,R=(-95,(2,0)),t=1,fx=S(-1,-1,14,150,-15)),mk(w,R=(-115,(2,1)),t=1,h=1,fx=S(-1,-1,14,40,-15,2,True)),
        mk(w,R=(-90,(1,0))),mk(w,R=(-60,(0,0))),r]
    dust=lambda i:(lambda c,g,p:sparks(c,g['R'][0]+12,GY,2+2*i,DUST,8,i))
    a2=[r,mk(w,R=(-10,(0,-4))),mk(w,R=(10,(-1,-7))),mk(w,R=(10,(-1,-7))),
        mk(w,R=(-70,(2,-2)),fx=S(0,-6,15,95,10)),
        mk(w,R=(-140,(3,1)),t=1,h=1,shake=(0,1),fx=both(S(0,-6,15,95,-70),dust(0))),
        mk(w,R=(-140,(3,1)),t=1,h=1,fx=both(S(0,-6,15,-10,-70,2,True),dust(1))),
        mk(w,R=(-100,(2,0)),fx=dust(2)),r]
    def streak(n,spark=False):
        def f(c,g,p):
            q,_,_=p['R']; tx,ty=q[0]+13,q[1]
            for k,(yy,L) in enumerate([(-2,5),(0,9),(2,6)][:n]): line(c,tx+2,ty+yy,tx+2+L,ty+yy,SL[k%2])
            if spark: sparks(c,tx+3,ty,4,(WHITE,(255,240,170)),10,3)
        return f
    a3=[r,mk(w,R=(-90,(-4,0))),mk(w,R=(-90,(-5,0)),t=1),mk(w,R=(-90,(6,0)),dx=2,fx=streak(3)),
        mk(w,R=(-90,(8,0)),dx=3,fx=streak(3,True)),mk(w,R=(-90,(7,0)),dx=3,fx=streak(1,True)),
        mk(w,R=(-80,(3,0)),dx=1),r,r]
    return a1,a2,a3

# ---------- espadão ----------
def atk_gs():
    w=W_GS; r=mk(w)
    a1=[r,mk(w,R=(30,(-2,-2))),mk(w,R=(60,(-4,-3))),mk(w,R=(70,(-5,-3)),t=1),
        mk(w,R=(-10,(0,-1)),fx=S(-2,-2,19,160,60,4)),mk(w,R=(-100,(3,1)),t=1,fx=S(-2,-2,19,160,-30,4)),
        mk(w,R=(-135,(3,2)),t=1,h=1,fx=S(-2,-2,19,40,-40,3,True)),mk(w,R=(-120,(2,1)),t=1,h=1),
        mk(w,R=(-80,(1,0))),r]
    def shock(i):
        def f(c,g,p):
            x0,y0=g['R'][0]+20,GY; rr=3+4*i
            for s in range(60):
                a=2*math.pi*s/60; px(c,x0+rr*math.cos(a),y0+rr*0.4*math.sin(a),DUST[s%3],255-i*50)
            rnd=random.Random(i)
            for k in range(6):
                ang=rnd.uniform(0.3,2.8); d=2+i*3
                px(c,x0+math.cos(ang)*d,y0-math.sin(ang)*d-i,(120,100,80))
            if i<3:
                for k in range(-1,2): line(c,x0,y0,x0+k*5,y0+2,(60,45,35))
        return f
    a2=[r,mk(w,R=(-20,(0,-4))),mk(w,R=(5,(-1,-8)),t=-1),mk(w,R=(5,(-1,-8)),t=-1),
        mk(w,R=(-60,(3,-3)),fx=S(2,-7,19,95,20,4)),
        mk(w,R=(-115,(4,0)),t=1,h=1,shake=(0,2),fx=both(S(2,-7,19,95,-30,4),shock(0))),
        mk(w,R=(-115,(4,0)),t=1,h=1,shake=(0,-1),fx=shock(1)),
        mk(w,R=(-115,(4,0)),t=1,h=1,fx=shock(2)),mk(w,R=(-115,(4,0)),t=1,fx=shock(3)),
        mk(w,R=(-80,(2,0))),r]
    a3=[r,mk(w,R=(20,(-1,-1)))]
    for k,a in enumerate(range(-30,-391,-60)):
        a3.append(mk(w,R=(a,(0,0)),t=k%2,h=(k//2)%2,fx=S(0,0,18,90+a+130,90+a,4)))
    a3+= [mk(w,R=(-400,(0,0)),fx=S(0,0,18,90-400+70,90-400,2,True)),r]
    return a1,a2,a3

# ---------- duas espadas ----------
def atk_dual():
    w=W_DUAL; r=mk(w)
    a1=[r,mk(w,R=(30,(-2,-1))),mk(w,R=(-100,(2,0)),fx=S(-1,-1,14,120,-10)),
        mk(w,R=(-110,(2,1)),L=(70,(-1,-1)),fx=S(-1,-1,14,30,-10,2,True)),
        mk(w,R=(-80,(1,0)),L=(90,(0,-1))),
        mk(w,R=(-60,(0,0)),L=(-60,(5,0)),fx=SL_('L',4,-1,14,140,-20)),
        mk(w,R=(-45,(0,0)),L=(-80,(6,0)),t=1,fx=SL_('L',4,-1,14,30,-20,2,True)),
        mk(w,L=(0,(2,0))),r]
    def X(s,fade=False):
        def f(c,g,p):
            cx,cy=g['R'][0]+8,33
            for o in range(2):
                col=SL[o+1] if fade else SL[o]
                line(c,cx-s,cy-s+o,cx+s,cy+s+o,col); line(c,cx-s,cy+s+o,cx+s,cy-s+o,col)
        return f
    a2=[r,mk(w,L=(30,(0,-3)),R=(-30,(0,-3))),mk(w,L=(15,(1,-6)),R=(-15,(-1,-6))),mk(w,L=(15,(1,-6)),R=(-15,(-1,-6))),
        mk(w,L=(-60,(4,-2)),R=(60,(-4,-2)),fx=X(5)),mk(w,L=(-110,(5,1)),R=(110,(-5,1)),t=1,h=1,fx=X(10)),
        mk(w,L=(-110,(5,1)),R=(110,(-5,1)),t=1,h=1,fx=X(11,True)),mk(w,L=(-60,(3,0)),R=(60,(-3,0))),r,r]
    rnd=random.Random(5); a3=[r]
    for k in range(8):
        cx,cy=rnd.randint(12,20),rnd.randint(-12,-2); a0=rnd.choice([150,30,110,-30])
        hit=lambda c,g,p,cx=cx,cy=cy,a0=a0:slash(c,g['R'][0]+cx-8,g['R'][1]+cy,7,a0,a0-140,2)
        if k%2==0: a3.append(mk(w,R=(-110,(2,0)),L=(60,(-1,-1)),fx=hit,t=k%4//2))
        else: a3.append(mk(w,R=(30,(-1,-1)),L=(-80,(6,0)),fx=hit,t=k%4//2))
    a3+=[r,r]
    return a1,a2,a3

# ---------- arco ----------
def atk_bow():
    w=W_BOW; r=mk(w)
    def draw_seq(extra=0,glowfx=None):
        s=[mk(w,L=(0,(15,-3)),nock=True),mk(w,L=(0,(12,-3)),nock=True,pull=True),
           mk(w,L=(0,(9,-3)),nock=True,pull=True)]
        for i in range(1+extra):
            s.append(mk(w,L=(0,(8,-3)),nock=True,pull=True,glow=(255,225,120) if glowfx else None,
                        fx=(glowfx(i) if glowfx else None)))
        return s
    def fly(d,angs=(0,),impact=None):
        def f(c,g,p):
            q,_,_=p['R']
            for a in angs:
                x=q[0]+6+d*math.cos(math.radians(a)); y=q[1]-1-d*math.sin(math.radians(a))
                if x<TX-2: arrow(c,x,y,9,a)
            if impact is not None:
                for a in angs:
                    y=q[1]-1-(TX-q[0])*math.tan(math.radians(a)); sparks(c,TX+4,y,2+impact*2,((235,225,200),(150,105,60)),6,impact)
        return f
    rel=lambda **k: mk(w,L=(0,(4,-2)),**k)
    a1=[r]+draw_seq()+[rel(fx=fly(2)),rel(fx=fly(14)),mk(w,fx=fly(26)),mk(w,fx=fly(99,impact=0)),mk(w,fx=fly(99,impact=1)),r]
    T=(0,12,-12)
    a2=[r]+draw_seq()+[rel(fx=fly(2,T)),rel(fx=fly(14,T)),mk(w,fx=fly(24,T)),mk(w,fx=fly(99,T,0)),mk(w,fx=fly(99,T,1)),r]
    def glow(i):
        def f(c,g,p):
            q,_,_=p['R']; tx,ty=q[0]+6,q[1]-1
            for k in range(8):
                a=math.radians(k*45+i*30); rr=max(2,9-2*i)
                px(c,tx+rr*math.cos(a),ty+rr*math.sin(a),(255,240,170) if k%2 else (255,200,90))
        return f
    def beam(i):
        def f(c,g,p):
            q,_,_=p['R']; x0,y=q[0]+6,q[1]-1
            if i<2:
                for yy,col in((-1,(255,200,90)),(1,(255,200,90)),(0,WHITE)):
                    if i==1 and yy: continue
                    line(c,x0,y+yy,W,y+yy,col)
                sparks(c,x0,y,4,((255,240,170),WHITE),8,i)
            sparks(c,TX+4,y,3+i*2,((255,240,170),(255,200,90),WHITE),12,i+9,255-i*50)
        return f
    a3=[r]+draw_seq(4,glow)+[mk(w,L=(0,(4,-2)),dx=-1,t=1,fx=beam(0)),mk(w,L=(0,(4,-2)),dx=-1,fx=beam(1)),
        mk(w,fx=beam(2)),mk(w,fx=beam(3)),r]
    return a1,a2,a3

# ---------- cajados ----------
def atk_staff(e):
    w=W_STAFF(e); r=mk(w); d,m,l=ELEM[e]
    def charge(i):
        def f(c,g,p):
            ox,oy=orb(p)
            for k in range(6):
                a=math.radians(k*60+i*25); rr=max(1,6-2*i)
                px(c,ox+rr*math.cos(a),oy+rr*math.sin(a),l if k%2 else m)
            disc(c,ox,oy,1+i%2,l,120)
        return f
    def impact(x,y,i): sparks(c_:=None,0,0,0,()) if False else None
    def burst(c,x,y,i): sparks(c,x,y,2+2*i,(d,m,l),12,i+20,255-i*60)
    def proj(i,start):
        def f(c,g,p):
            sx,sy=start; tx,ty=TX,38; k=min(1,i/4); x=sx+(tx-sx)*k; y=sy+(ty-sy)*k
            if e=='eletrico':
                if i<2: bolt(c,sx,sy,tx,ty,e,i); burst(c,tx,ty,i)
                elif i<4: burst(c,tx,ty,i)
                return
            if i<=4:
                if e=='fogo':
                    for j in range(1,6): px(c,x-2-j,y+random.Random(i*9+j).randint(-1,1),d if j>2 else m,255-j*35)
                    disc(c,x,y,2,m); disc(c,x,y,1,l); px(c,x+2,y,d)
                elif e=='agua':
                    for j in range(3): px(c,x-4-2*j,y+(j%2*2-1),m)
                    disc(c,x,y,2,m); px(c,x-1,y-1,l); px(c,x,y-1,l)
                else:
                    for a in range(-70,71,10):
                        aa=math.radians(a); px(c,x+3*math.cos(aa),y-4*math.sin(aa),m); px(c,x+2*math.cos(aa),y-4*math.sin(aa)*0.9,l)
                    line(c,x-7,y-2,x-3,y-2,l); line(c,x-8,y+2,x-4,y+2,l)
            if i>=4: burst(c,tx,ty,i-4)
        return f
    start=[None]
    def launcher(i):
        def f(c,g,p):
            if start[0] is None: start[0]=orb(p)
            proj(i,start[0])(c,g,p)
        return f
    a1=[r,mk(w,R=(10,(-1,-3)),fx=charge(0)),mk(w,R=(15,(-1,-4)),fx=charge(1)),mk(w,R=(15,(-1,-4)),fx=charge(2))]
    a1+=[mk(w,R=(-60,(2,-1)),fx=launcher(i)) for i in range(3)]+[mk(w,R=(-40,(1,0)),fx=launcher(i)) for i in range(3,7)]+[r]
    def area(i):
        def f(c,g,p):
            rnd=random.Random(i*31)
            if e=='fogo':
                hts=[3,8,13,11,6][i]
                for dx in range(-3,4):
                    hh=hts*(1-abs(dx)/4.5)+rnd.randint(0,2)
                    for k in range(int(hh)):
                        fr=k/max(hh,1); px(c,TX+dx,GY-k,l if fr<0.3 else m if fr<0.7 else d)
                for _ in range(4): px(c,TX+rnd.randint(-4,4),GY-hts-rnd.randint(1,5),d)
            elif e=='agua':
                hts=[4,10,15,15,9][i]
                for k in range(hts):
                    for dx in(-1,0,1): px(c,TX+dx,GY-k,l if dx==0 else m)
                if i>=1:
                    for j in range(10):
                        a=math.radians(j*36); rr=2+i*1.5
                        px(c,TX+rr*math.cos(a),GY-hts+rr*abs(math.sin(a))+i,l if j%2 else m)
            elif e=='eletrico':
                if i<2: bolt(c,TX+rnd.randint(-6,6),0,TX,GY,e,i+40); disc(c,TX,GY,2,l)
                sparks(c,TX,GY,3+i,(d,m,l,WHITE),10,i+50,255-i*40)
                if i>=2:
                    for s in range(20): a=2*math.pi*s/20; px(c,TX+3*math.cos(a),GY+1.2*math.sin(a),(60,45,35))
            else:
                L=[3,6,9,10,8][i]
                for k in range(L):
                    y=GY-k*2; rx=1.5+k*0.7
                    for j in range(3):
                        a=math.radians(i*50+k*35+j*120)
                        px(c,TX+rx*math.cos(a),y+0.4*rx*math.sin(a),l if math.sin(a)>0 else m)
                sparks(c,TX,GY,4,DUST,6,i)
        return f
    marker=lambda c,g,p:[px(c,TX+5*math.cos(2*math.pi*s/24),GY+2*math.sin(2*math.pi*s/24),m,180) for s in range(24)]
    a2=[r,mk(w,R=(0,(0,-4)),fx=charge(0)),mk(w,R=(0,(0,-6)),fx=both(charge(1),marker)),mk(w,R=(0,(0,-6)),fx=both(charge(2),marker))]
    a2+=[mk(w,R=(-30,(1,-3)),fx=area(i)) for i in range(5)]+[r]
    def nova(i):
        def f(c,g,p):
            rnd=random.Random(i*13); cx,cy=g['L'][0]+8,43; rr=5+5*i; n=int(2*math.pi*rr)+8; al=255-i*30
            for s in range(n):
                a=2*math.pi*s/n; j=rnd.choice([-1,0,1]) if e=='eletrico' else 0
                if e=='vento' and (s//3+i)%2==0: continue
                x,y=cx+(rr+j)*math.cos(a),cy+(rr+j)*0.45*math.sin(a)
                px(c,x,y,m if s%2 else l,al)
                if e=='fogo' and s%3==0: px(c,x,y-1-rnd.randint(0,1),l if rnd.random()<.5 else d,al)
                if e=='agua': px(c,cx+(rr-2)*math.cos(a),cy+(rr-2)*0.45*math.sin(a),d,al)
                if e=='eletrico' and rnd.random()<0.08: px(c,x,y-1,WHITE)
        return f
    a3=[r,mk(w,R=(0,(0,-5)),fx=charge(0)),mk(w,R=(0,(0,-6)),fx=charge(1)),
        mk(w,R=(0,(0,1)),t=1,h=1,shake=(0,1),fx=nova(0))]+[mk(w,R=(0,(0,1)),t=1 if i<2 else 0,fx=nova(i)) for i in range(1,6)]+[r]
    return a1,a2,a3

# ---------- saída ----------
SETS=[('Espada',W_SWORD,atk_sword),('Espadão',W_GS,atk_gs),('Duas espadas',W_DUAL,atk_dual),('Arco',W_BOW,atk_bow)]
SETS+=[('Cajado '+n,W_STAFF(e),(lambda e=e:atk_staff(e))) for e,n in(('fogo','de fogo'),('agua','de água'),('eletrico','elétrico'),('vento','de vento'))]
FONT=ImageFont.truetype("DejaVuSans-Bold.ttf",13)
def up(im,S,label=None):
    im=im.convert('RGB').resize((W*S,H*S),Image.NEAREST)
    if label:
        d=ImageDraw.Draw(im); d.text((6,4),label,font=FONT,fill=(245,235,220),stroke_width=2,stroke_fill=(30,22,25))
    return im
def save(frames,name,ms=85):
    frames[0].save(os.path.join(OUT,name),save_all=True,append_images=frames[1:],duration=ms,loop=0,disposal=1)
def seq(name,w,atk):
    a1,a2,a3=atk(); I=idle(w)
    return [(f'{name} · idle',I+I)]+[(f'{name} · ataque {k}',a+I[:4]) for k,a in((1,a1),(2,a2),(3,a3))]
allseq=[]
for name,w,atk in SETS:
    sq=seq(name,w,atk); allseq.append(sq)
    fr=[up(compose(f),6,lab) for lab,fs in sq for f in fs]
    save(fr,'arma_'+name.lower().replace(' ','_').replace('ã','a').replace('á','a').replace('é','e')+'.gif')
# grade com todas as armas
n=max(sum(len(fs) for _,fs in sq) for sq in allseq); tiles=[]
for sq,(name,w,_) in zip(allseq,SETS):
    fl=[(lab,f) for lab,fs in sq for f in fs]; I=idle(w); k=0
    while len(fl)<n: fl.append((f'{name} · idle',I[k%8])); k+=1
    tiles.append([up(compose(f),3,lab) for lab,f in fl])
tw,th=W*3,H*3; grid=[]
for i in range(n):
    g=Image.new('RGB',(tw*4,th*2))
    for j,t in enumerate(tiles): g.paste(t[i],((j%4)*tw,(j//4)*th))
    grid.append(g)
save(grid,'todas_as_armas.gif')
# andando em 8 direções (chão rola; sprite sempre de frente)
DIRS=[('↖',-1,-1),('↑',0,-1),('↗',1,-1),('←',-1,0),(None,0,0),('→',1,0),('↙',-1,1),('↓',0,1),('↘',1,1)]
wk=walk(W_DUAL); idl=idle(W_DUAL); fr=[]
for i in range(24):
    g=Image.new('RGB',(W*3*3,H*3*3))
    for j,(lab,dx,dy) in enumerate(DIRS):
        f=idl[i%8] if lab is None else wk[i%6]
        t=up(compose(f,dx*i,dy*i),3,lab or 'idle'); g.paste(t,((j%3)*W*3,(j//3)*H*3))
    fr.append(g)
save(fr,'andando_8_direcoes.gif',110)
# camadas
parts=[head,torso,leg]+[WP[k][0] for k in('hand','sword','gsword','bow','staff_fogo','staff_agua','staff_eletrico','staff_vento')]
sh=Image.new('RGBA',(sum(p.width+3 for p in parts)+3,26),(96,78,60,255)); x=3
for p in parts: sh.paste(p,(x,2),p); x+=p.width+3
sh.convert('RGB').resize((sh.width*6,sh.height*6),Image.NEAREST).save(os.path.join(OUT,'camadas.png'))
print('ok')
