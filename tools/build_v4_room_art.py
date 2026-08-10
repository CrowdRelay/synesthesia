#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import math, random
import numpy as np
import cv2
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance

ROOT=Path(__file__).resolve().parents[1]
ROOMS=ROOT/'assets/rooms/vertical'
EXT=Path('/mnt/data')
random.seed(4129)

W,H=675,1200
BG=(405,720)
FG=(540,960)

def pil(path): return Image.open(path).convert('RGB')
def rgba(size=(W,H)): return Image.new('RGBA',size,(0,0,0,0))

def cover(im:Image.Image,size=(W,H)):
    tw,th=size; sw,sh=im.size; scale=max(tw/sw,th/sh); nw,nh=int(sw*scale),int(sh*scale)
    im=im.resize((nw,nh),Image.Resampling.LANCZOS)
    x=(nw-tw)//2;y=(nh-th)//2
    return im.crop((x,y,x+tw,y+th))

def grade(im, mul=(1.0,1.0,1.0), contrast=1.05, brightness=0.96, sat=0.9):
    arr=np.asarray(im.convert('RGB')).astype(np.float32)
    arr*=np.array(mul,dtype=np.float32)[None,None,:]
    arr=np.clip(arr,0,255).astype(np.uint8)
    out=Image.fromarray(arr)
    out=ImageEnhance.Contrast(out).enhance(contrast)
    out=ImageEnhance.Brightness(out).enhance(brightness)
    out=ImageEnhance.Color(out).enhance(sat)
    return out

def vignette(im, strength=.45):
    a=np.asarray(im).astype(np.float32)
    yy,xx=np.mgrid[0:H,0:W]
    dx=(xx-W/2)/(W/2);dy=(yy-H/2)/(H/2)
    r=np.sqrt(dx*dx+dy*dy)
    v=np.clip(1-strength*np.power(np.clip(r,0,1.5),1.7),0.42,1.0)[...,None]
    return Image.fromarray(np.clip(a*v,0,255).astype(np.uint8))

def noise_overlay(im, amount=5, seed=0):
    rng=np.random.default_rng(seed)
    arr=np.asarray(im).astype(np.int16)
    noise=rng.normal(0,amount,arr.shape[:2])[...,None]
    arr=np.clip(arr+noise,0,255).astype(np.uint8)
    return Image.fromarray(arr)

def mute_party_chroma(im: Image.Image) -> Image.Image:
    bgr=cv2.cvtColor(np.asarray(im.convert("RGB")),cv2.COLOR_RGB2BGR)
    hsv=cv2.cvtColor(bgr,cv2.COLOR_BGR2HSV).astype(np.float32)
    h,s,v=cv2.split(hsv)
    mask=((s>72)&(((h<18)|(h>132)))).astype(np.float32)
    # Keep only rim-like colour information; bodies become near-black/burgundy.
    s=s*(1.0-mask*0.48)
    v=v*(1.0-mask*0.34)
    hsv=cv2.merge([h,s,v]).astype(np.uint8)
    rgb=cv2.cvtColor(cv2.cvtColor(hsv,cv2.COLOR_HSV2BGR),cv2.COLOR_BGR2RGB)
    return Image.fromarray(rgb)

def inpaint(im, ellipses=(), rects=()):
    bgr=cv2.cvtColor(np.asarray(im),cv2.COLOR_RGB2BGR)
    mask=np.zeros((im.height,im.width),np.uint8)
    for x,y,rx,ry in ellipses:
        cv2.ellipse(mask,(int(x),int(y)),(int(rx),int(ry)),0,0,360,255,-1)
    for x0,y0,x1,y1 in rects:
        cv2.rectangle(mask,(x0,y0),(x1,y1),255,-1)
    res=cv2.inpaint(bgr,mask,7,cv2.INPAINT_TELEA)
    return Image.fromarray(cv2.cvtColor(res,cv2.COLOR_BGR2RGB))

def add_glow(base, center, radius, color, alpha):
    layer=rgba(); arr=np.zeros((H,W,4),np.uint8)
    yy,xx=np.mgrid[0:H,0:W];d=np.sqrt((xx-center[0])**2+(yy-center[1])**2)
    aa=np.clip(1-d/radius,0,1)**2*alpha
    arr[...,0]=color[0];arr[...,1]=color[1];arr[...,2]=color[2];arr[...,3]=(aa*255).astype(np.uint8)
    return Image.alpha_composite(base.convert('RGBA'),Image.fromarray(arr,'RGBA')).convert('RGB')

def membrane(layer, center, rx, ry, color, alpha=.36, crack=True, seed=0):
    rng=random.Random(seed); d=ImageDraw.Draw(layer,'RGBA');cx,cy=center
    # halo and membrane shell
    for k in range(5,0,-1):
        pad=k*3; a=int(alpha*255*(0.035*k))
        d.ellipse((cx-rx-pad,cy-ry-pad,cx+rx+pad,cy+ry+pad),outline=(*color,a),width=max(1,k))
    d.ellipse((cx-rx,cy-ry,cx+rx,cy+ry),fill=(*color,int(alpha*55)),outline=(*color,int(alpha*180)),width=2)
    d.arc((cx-rx+5,cy-ry+8,cx+rx-5,cy+ry-8),195,315,fill=(235,245,255,int(alpha*150)),width=2)
    d.ellipse((cx-rx*.46,cy-ry*.54,cx-rx*.14,cy-ry*.18),fill=(255,255,255,int(alpha*52)))
    if crack:
        for _ in range(3):
            x=cx+rng.uniform(-rx*.35,rx*.35);y=cy+rng.uniform(-ry*.3,ry*.25)
            pts=[(x,y)]
            for j in range(3):
                x+=rng.uniform(-10,10);y+=rng.uniform(8,18);pts.append((x,y))
            d.line(pts,fill=(*color,int(alpha*130)),width=1)
    # cable-like ribbon
    pts=[]
    for j in range(12):
        yy=cy+ry+j*10; xx=cx+math.sin(j*.62+seed)*7
        pts.append((xx,yy))
    d.line(pts,fill=(*color,int(alpha*95)),width=1)

def ritual_ring(layer, center, radius, color=(215,35,45), alpha=160):
    d=ImageDraw.Draw(layer,'RGBA');cx,cy=center
    for k in range(5):
        r=radius+k*13
        start=195+k*9; end=340-k*7
        d.arc((cx-r,cy-r*.45,cx+r,cy+r*.45),start,end,fill=(*color,max(20,alpha-k*25)),width=2 if k<2 else 1)
    for i in range(12):
        a=i/12*math.tau; x=cx+math.cos(a)*radius*1.28; y=cy+math.sin(a)*radius*.56
        d.ellipse((x-2,y-2,x+2,y+2),fill=(*color,alpha//2))

def _microtexture(layer: Image.Image, seed: int, count: int) -> Image.Image:
    out=layer.convert('RGBA').copy(); d=ImageDraw.Draw(out,'RGBA'); rng=random.Random(seed)
    for _ in range(count):
        x=rng.randrange(out.width); y=rng.randrange(out.height)
        v=rng.randrange(120,230); a=rng.randrange(2,8)
        d.point((x,y),fill=(v,v,v,a))
    return out

def save_layers(room, scene, subject, foreground, bg_source=None):
    # A tiny deterministic film microtexture keeps sparse alpha layers inside the
    # runtime asset budget while remaining visually invisible at normal scale.
    seed=sum(ord(c) for c in room)
    scene=noise_overlay(scene.convert('RGB').resize((W,H),Image.Resampling.LANCZOS),4.5,seed)
    if bg_source is None:
        bg_source=scene.filter(ImageFilter.GaussianBlur(5))
    bg=cover(bg_source,BG).filter(ImageFilter.GaussianBlur(2))
    bg=noise_overlay(bg,2.2,seed+1)
    subj=_microtexture(subject.convert('RGBA').resize((W,H),Image.Resampling.LANCZOS),seed+2,2200)
    fg=subject.copy() if foreground is None else foreground.convert('RGBA')
    fg=_microtexture(fg.resize(FG,Image.Resampling.LANCZOS),seed+3,2000)
    scene.save(ROOMS/f'{room}-scene.webp','WEBP',quality=88,method=4)
    bg.save(ROOMS/f'{room}-bg.webp','WEBP',quality=81,method=4)
    subj.save(ROOMS/f'{room}-subject.webp','WEBP',quality=87,method=4,lossless=False)
    fg.save(ROOMS/f'{room}-foreground.webp','WEBP',quality=85,method=4,lossless=False)

# PARTY — remove oversized glossy party balloons, replace with restrained sensory membranes.
room='party-time'
base=pil(ROOT/'tools/source_art/party-time-v3.webp')
base=inpaint(base,ellipses=[(575,185,118,180),(48,178,88,132),(340,125,64,90),(198,356,64,88),(390,360,52,70),(84,487,50,68),(605,475,58,78),(250,505,38,56),(455,520,40,58),(135,590,38,54),(530,610,42,60)],rects=[(0,40,55,680),(620,20,674,700)])
base=grade(base,(0.92,0.88,1.08),1.12,.90,.88)
base=add_glow(base,(338,560),245,(95,26,112),.21)
sub=rgba(); fg=rgba()
positions=[(125,300,21,34,(91,44,118)),(282,225,16,27,(100,48,128)),(500,300,23,37,(121,32,59)),(550,500,16,27,(82,45,110)),(205,535,14,23,(117,34,58))]
for i,(x,y,rx,ry,c) in enumerate(positions): membrane(sub,(x,y),rx,ry,c,.48,True,21+i)
# foreground: fragments + ribbons, deliberately asymmetric
fd=ImageDraw.Draw(fg,'RGBA')
for i in range(26):
    x=random.randint(20,W-20); y=random.randint(280,H-70); c=(174,49,75) if i%3==0 else (112,53,142)
    fd.line([(x,y),(x+random.randint(-8,8),y+random.randint(8,24))],fill=(*c,random.randint(25,70)),width=1)
for i in range(5):
    x=65+i*135; pts=[]
    for j in range(18): pts.append((x+math.sin(j*.6+i)*13,650+j*19))
    fd.line(pts,fill=(110,42,130,42),width=2)
scene=Image.alpha_composite(base.convert('RGBA'),sub).convert('RGB')
scene=Image.alpha_composite(scene.convert('RGBA'),fg).convert('RGB')
scene=vignette(noise_overlay(scene,3,13),.47)
scene=mute_party_chroma(scene)
save_layers(room,scene,sub,fg)

# THE CALLING — ritual resonance vessel, no wine-glass iconography.
room='the-calling'
base=pil(ROOT/'tools/source_art/the-calling-master.webp')
# Remove literal wine glasses/chairs from the lower ritual table; keep the architectural chamber and central basin.
base=inpaint(base,ellipses=[(85,815,70,125),(190,790,55,115),(490,790,55,115),(590,815,70,125),(132,980,72,135),(545,980,72,135)],rects=[(0,770,70,1199),(605,770,674,1199)])
base=grade(base,(1.02,.91,.93),1.13,.89,.78)
base=add_glow(base,(337,700),265,(123,16,31),.22)
sub=rgba(); fg=rgba(); sd=ImageDraw.Draw(sub,'RGBA')
# heavy ritual table ellipse
sd.ellipse((118,666,557,816),fill=(3,5,7,105),outline=(124,28,40,105),width=2)
ritual_ring(sub,(337,732),128,(185,28,42),175)
# resonance vessel: shallow metal basin, pulsing liquid core
sd.ellipse((265,675,409,720),fill=(7,9,11,225),outline=(206,214,218,82),width=2)
sd.arc((270,672,404,723),185,355,fill=(217,52,60,175),width=3)
sd.ellipse((291,687,383,709),fill=(118,12,26,116),outline=(236,64,69,110),width=1)
for i in range(7):
    x=337+(i-3)*12; h=[6,15,9,21,11,17,7][i]
    sd.line((x,696-h/2,x,696+h/2),fill=(230,67,73,125),width=2)
# candle pins, not literal goblets
for x in (165,230,445,510):
    sd.line((x,650,x,690),fill=(220,220,210,48),width=1)
    sd.ellipse((x-3,641,x+3,653),fill=(255,190,100,80))
fd=ImageDraw.Draw(fg,'RGBA')
for i in range(40):
    x=random.randrange(W); y=random.randrange(350,H); fd.ellipse((x,y,x+1,y+1),fill=(224,66,70,random.randrange(18,55)))
scene=Image.alpha_composite(base.convert('RGBA'),sub).convert('RGB')
scene=Image.alpha_composite(scene.convert('RGBA'),fg).convert('RGB')
scene=vignette(noise_overlay(scene,3,17),.5)
save_layers(room,scene,sub,fg)

# WAVES — intimate room, no human glyphs; window, rain and two abstract resonances.
room='waves'
base=pil(ROOT/'tools/source_art/waves-v3.webp')
base=grade(base,(.86,1.08,1.22),1.10,1.22,.72)
base=add_glow(base,(338,360),310,(74,157,202),.30)
sub=rgba(); fg=rgba(); sd=ImageDraw.Draw(sub,'RGBA')
# two subtle waveform reflections on bed/window plane
for idx,(cx,cy,c) in enumerate([(285,692,(103,190,224)),(390,692,(190,130,177))]):
    sd.arc((cx-33,cy-18,cx+33,cy+18),195,345,fill=(*c,70),width=2)
    for j,h in enumerate([4,9,15,7,19,11,5]):
        x=cx+(j-3)*7; sd.line((x,cy-h/2,x,cy+h/2),fill=(*c,68),width=1)
# window phase rings
for r,a in [(50,28),(78,18),(110,10)]: sd.arc((338-r,355-r*.64,338+r,355+r*.64),190,350,fill=(103,184,220,a),width=1)
fd=ImageDraw.Draw(fg,'RGBA')
# rain / dust, mostly near window
for i in range(38):
    x=random.randint(105,565); y=random.randint(150,720); ln=random.randint(8,26)
    fd.line((x,y,x-random.randint(0,4),y+ln),fill=(154,210,232,random.randint(14,42)),width=1)
# curtain edge accents
for i,x in enumerate((92,130,545,585)):
    pts=[]
    for j in range(22): pts.append((x+math.sin(j*.42+i)*7,130+j*31))
    fd.line(pts,fill=(148,198,217,28),width=2)
scene=Image.alpha_composite(base.convert('RGBA'),sub).convert('RGB')
scene=Image.alpha_composite(scene.convert('RGBA'),fg).convert('RGB')
scene=vignette(noise_overlay(scene,2.5,23),.27)
save_layers(room,scene,sub,fg)

# RISE — use the already-created clean ascension atrium from the experimental V2 pass,
# then make it less portal-like via fragmented vertical light and rising debris.
room='rise'
experimental=ROOT/'tools/source_art/rise-ascension-master.webp'
base=pil(experimental if experimental.exists() else ROOMS/f'{room}-scene.webp')
base=grade(base,(1.02,1.02,.94),1.13,.91,.46)
sub=rgba(); fg=rgba(); sd=ImageDraw.Draw(sub,'RGBA')
# vertical ribbons, intentionally no avatar circles / no drawn person
for i in range(9):
    x=337+(i-4)*19
    a=max(12,72-abs(i-4)*12)
    sd.line((x,170,x+math.sin(i)*9,930),fill=(243,231,190,a),width=1 if i%2 else 2)
for r,a in [(55,92),(92,56),(138,30)]: sd.arc((337-r,274-r*.55,337+r,274+r*.55),190,350,fill=(238,230,200,a),width=2)
# floating fragments rising, narrow and architectural
fd=ImageDraw.Draw(fg,'RGBA')
for i in range(34):
    x=random.randint(90,585); y=random.randint(260,1040); w=random.randint(2,8); h=random.randint(6,24)
    col=(240,228,193,random.randint(22,62)) if i%3 else (117,183,194,random.randint(18,48))
    fd.polygon([(x,y),(x+w,y-random.randint(4,12)),(x+w+random.randint(-3,4),y+h),(x-random.randint(1,4),y+h+random.randint(1,6))],fill=col)
scene=Image.alpha_composite(base.convert('RGBA'),sub).convert('RGB')
scene=Image.alpha_composite(scene.convert('RGBA'),fg).convert('RGB')
scene=vignette(noise_overlay(scene,2.2,31),.38)
save_layers(room,scene,sub,fg)

# HYBRID — remove roster-wall repetition; turn the room into a mechanical frequency core.
room='hybrid'
base=pil(ROOT/'tools/source_art/hybrid-v3.webp')
base=inpaint(base,ellipses=[(112,290,78,90),(558,290,78,90),(112,615,78,90),(558,615,78,90)],rects=[(300,635,375,780)])
base=grade(base,(.94,1.08,1.10),1.18,1.03,.62)
base=add_glow(base,(337,575),260,(51,148,165),.18)
sub=rgba(); fg=rgba(); sd=ImageDraw.Draw(sub,'RGBA')
cx,cy=337,575
for i in range(8):
    r=58+i*23; col=(221,60,49) if i%2==0 else (79,184,196); a=max(18,145-i*15)
    sd.arc((cx-r,cy-r,cx+r,cy+r),18+i*14,290-i*9,fill=(*col,a),width=2 if i<3 else 1)
for i in range(12):
    a=i/12*math.tau; r=210; x=cx+math.cos(a)*r; y=cy+math.sin(a)*r
    sd.line((cx+math.cos(a)*65,cy+math.sin(a)*65,x,y),fill=(165,189,192,32),width=1)
sd.ellipse((cx-30,cy-30,cx+30,cy+30),fill=(4,8,10,210),outline=(226,65,52,160),width=3)
sd.ellipse((cx-8,cy-8,cx+8,cy+8),fill=(86,207,216,150))
fd=ImageDraw.Draw(fg,'RGBA')
for i in range(28):
    a=random.random()*math.tau;r=random.randint(120,320);x=cx+math.cos(a)*r;y=cy+math.sin(a)*r
    fd.line((x,y,x+math.cos(a)*random.randint(5,22),y+math.sin(a)*random.randint(5,22)),fill=(224,70,58,random.randint(20,55)),width=1)
scene=Image.alpha_composite(base.convert('RGBA'),sub).convert('RGB')
scene=Image.alpha_composite(scene.convert('RGBA'),fg).convert('RGB')
scene=vignette(noise_overlay(scene,3,37),.34)
save_layers(room,scene,sub,fg)

# FROM THE ASHES — keep phoenix, lose the roster wall/person/portal repetition.
room='from-the-ashes'
base=pil(ROOT/'tools/source_art/from-the-ashes-v3.webp')
base=inpaint(base,ellipses=[(112,435,75,88),(558,435,75,88),(112,650,75,88),(558,650,75,88)],rects=[(290,740,385,940)])
phoenix=cover(pil(ROOT/'tools/source_art/from-the-ashes-phoenix.webp'),(W,H))
phoenix=grade(phoenix,(1.08,.72,.50),1.10,.82,.78)
# luminance-based phoenix overlay, strongest in upper 2/3
pa=np.asarray(phoenix).astype(np.float32); lum=pa.mean(axis=2); mask=np.clip((lum-45)/130,0,1)
yy=np.linspace(1.0,.18,H)[:,None]; mask*=yy; mask=(mask**1.30*.88)
rgba_arr=np.zeros((H,W,4),np.uint8);rgba_arr[...,:3]=pa.astype(np.uint8);rgba_arr[...,3]=(mask*255).astype(np.uint8)
sub=Image.fromarray(rgba_arr,'RGBA')
fg=rgba(); fd=ImageDraw.Draw(fg,'RGBA')
for i in range(50):
    x=random.randrange(W); y=random.randint(220,1120); r=random.choice([1,1,2,2,3]); col=(240,90+random.randint(0,90),36,random.randint(20,90)); fd.ellipse((x-r,y-r,x+r,y+r),fill=col)
scene=Image.alpha_composite(base.convert('RGBA'),sub).convert('RGB')
scene=Image.alpha_composite(scene.convert('RGBA'),fg).convert('RGB')
scene=add_glow(scene,(337,520),330,(176,61,24),.20)
scene=grade(scene,(1.08,.91,.80),1.12,1.08,.90); scene=vignette(noise_overlay(scene,3,43),.32)
save_layers(room,scene,sub,fg)

print('SYNESTHESIA_V4_ART_BUILD=PASS rooms=6')
