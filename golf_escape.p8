pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- golf escape

function _init()

 --constants
 pixel,gravity=0.125,0.009
 treadmillspeed=0.020
 
 --velocity multiplier
 -- when in slow zones
 slowfrac=0.1
 
 --how far active hooks
 -- move each frame
 hookspeed,diaghookspeed=0.05,0.035
 
 --velocity multiplier
 -- when hitting the ground
 xbouncefrac,ybouncefrac=0.4,-0.6
 
 --frames for wall hit squish
 -- state
 squishpause=4
 
 factoryx,factoryy=768,256
 --vars

 pausecontrols,pausecamera=false,false
 endingtransition=false

 --checkpoint
 xcp,ycp,cpanim=0,0,makeanimt(23,10,3)
 
 --hack for top corner collision
 topcoloverwrite=false
 
 lvlhasmovinghooks=false

 resetav()
 
 cam={
  --target x,y
  x=0,
  y=0,
  --free control x,y
  xfree=0,
  yfree=0,
  freedirect="none",
  xvel=0,
  yvel=0,
  prevtiledest=8,
  free=false,
  canmove=true,
  arrowcounter=0,
  arrowcountermax=120,
 }
 
 makebackgrounds()
 
 --[[
 currentupdate,currentdraw=updateplaying,drawplaying
 
 initlevels()
 menuitem(1,"skip level", skiplvl)
 --music(7)
 --]]

 initstartscreen()

 aim={
  points={}
 }
 
 --game object tables
 corpses={}
 
 --stats for end screen
 deathcount,lvlsskipped,totalswingcount,lvlswingcount=0,0,0,0
 frames,seconds,minutes,hours=0,0,0,0

 --scroll texture effect
 
 backupaddr1,backupaddr2=0x4300,0x4310
 scrollcounter,idleframes=0,0
end

function _update60()
 updatescrollingtextures()

 currentupdate()

 --debug=stat(7)..".."..stat(1)..".."..#aim.points
end

function updateplaying()
 if currentupdate!=updateending then
  updateplaytime()
 end

 updatebackgrounds()

 if av.respawnstate=="alive" then
  if not pausecontrols then
   handleswinginput()
  end

 --collision
  if currentupdate!=updateending then
   avwallscollision()
  end
 end

 --game obj update
 -- update hooks
 for h in all(hooks) do
  if h.avon then
	  if anycol(av,h.xvel,h.yvel,0) and
       currentupdate==updateplaying then
	   hookreleaseav(av.hook)
	  elseif h.typ=="moveon" then
	   h.x+=h.xvel
	   h.y+=h.yvel
	  end
	 end

  if h.typ=="mover" then
   h.x+=h.xvel
   h.y+=h.yvel
  end

  for b in all(bumpers) do
   --'bounce' the other way
   if circlecollision(b,h) then
    h.xvel*=-1
    h.yvel*=-1
   
    if h.typ=="moveon" then
     if h.s<37 then
      h.s+=4
     else
      h.s-=4
     end
    end

    if h.typ=="mover" then
     if h.s<53 then
      h.s+=4
     else
      h.s-=4
     end
    end
   end
  end

  if av.respawnstate=="alive" and circlecollision(av,h) and
     h.active and
     currentupdate==updateplaying then

   if not av.hook then
    --normal land
    -- could have special
    -- hook land sfx?
    sfx(8)

    --if in float zone, exit
    -- hook trumps slow zone
    if av.slowstate=="in" then
     sfx(41)
     av.slowstate="escape"
    end
   end

   av.x=h.x+h.r-pixel
   av.y=h.y+h.r

   av.xvel,av.yvel=0,0

   av.colstate="hook"
    
   av.canswing=true
    
   h.avon=true
    
   if av.hook!=nil and
      h!=av.hook then
    --move to new hook
    hookreleaseav(av.hook)
   end
    
  av.hook=h
  elseif not circlecollision(av,h) and
         h.active==false then
   h.active=true
  end
 end
 
 if av.respawnstate=="alive" then
  --acid
  if anycol(av.hurtbox,0,0,4) then
   sfx(5)
   deathcount+=1

   --could improve how in the acid this is somehow
   createcorpse(av.x-0.25+av.xvel,av.y-0.25+av.yvel)
   
   initburst(av.x,av.y,deathcolours)
   
   resetswing()
   av.respawnstate="dead"

   --lose key if not saved
   if currlvl.haskey and
      currlvl.key.collected and
      not currlvl.key.saved then
    dropkey()
   end
  end
 end

 --if we're still alive this frame, check other collisions
 if av.respawnstate=="alive" then
  --checkpoint
  if anycol(av.hurtbox,0,0,5) then

   --save key if held
   if currlvl.haskey and
    currlvl.key.collected and
    not currlvl.key.saved then
    sfx(6)
    currlvl.key.saved=true
   end

   --if new cp hit
   if xcp!=xhitblock or
      ycp!=yhitblock then

    resetpreviouscheckpoint()
    
    --set new cp
    sfx(6)
    xcp,ycp=xhitblock,yhitblock
    mset(xcp,ycp,23)
   end
  end
  
  --float zone
  if allcol(av,0,0,6) and
     av.slowstate=="none" then
   --hook trumps float zone
   if av.colstate=="hook" then
    av.slowstate="escape"
   else
    sfx(40)
    av.canswing=true

    av.slowstate="in"
   end
  elseif not allcol(av,0,0,6) and
         av.slowstate!="none" then
   
   if av.slowstate=="in" then
    sfx(41)
   end

   --reset on leaving a slowzone
   av.slowstate="none"
  end
  
  --level markers
  if circlecollision(av,currlvl.exit) and
     (not currlvl.haskey or
      currlvl.key.collected) and
     av.colstate=="ground" and
     currentupdate==updateplaying then
   initlvlend()
  end

  if currlvl.haskey and
     circlecollision(av,currlvl.key) and
     not currlvl.key.collected then
   --collect key
   sfx(7)
   currlvl.exit.s=20
   currlvl.key.collected=true
  end
 end
 
 if currentupdate!=updateending then
  updateav()
 end

 if currlvl.haskey and
    currlvl.key.collected then

  if av.respawnstate=="alive" then
   currlvl.key.anim.basesprite=17
   currlvl.key.anim.sprites=1
  else  
   currlvl.key.anim.basesprite=-1
  end
  
  --draw 'key' under player if they have one
  --little bounce when on player
  local up=0
  
  --bob each second
  if frames<30 then
   up=1
  end
  
  currlvl.key.x=av.x-0.25 --pixel*2
  currlvl.key.y=av.y-(0.25)-(pixel*up)
  currlvl.key.xflip=av.xflip
 end

 updatecorpses()

 updateanims()
 
 updateparticleeffects() --tab 6
 
 if currentupdate==updateplaying and
    (btn(⬅️) or
    btn(➡️) or
    abs(av.xvel)>0 or
    abs(av.yvel)>0 or
    swing.force>swing.lowf or
    av.hook or
    lvlhasmovinghooks) then
  updateaim()
 end
 
 --update last once positions are finalised for the frame
 if not pausecamera then
  updatecamera()
 end
end

function handleswinginput()
 -- swing controls
 if av.canswing then
  --rotate angle
  if btn(⬅️) then
   rotacc(1)
  elseif btn(➡️) then
   rotacc(-1)
  else
   --reset vel
   swing.currrotangle=swing.lowrotangle
  end

  --power boost swing
  if btnp(❎) then
   boostswing()
  end
  
  --release swing
  if btnp(🅾️) then
   sfx(1)
   
   lvlswingcount+=1
  
   cam.free=false
  
   applyswing(av)

   resetswing()
    
   if av.slowstate=="in" then
   initdustkick(av.x,av.y,
    -0.5,-0.5,
    1,1,
    20,5,floatcolours,true,4)

    sfx(41)
    av.slowstate="escape"
   end

   if av.colstate=="hook" then
    hookreleaseav(av.hook)
   end
  end
  
  if swing.currdecaypause==0 and
     swing.force>swing.lowf then
   swing.decay+=swing.decayvel
   swing.force-=swing.decay
  end
  
  if swing.currdecaypause>0 then
   swing.currdecaypause-=1
  end
  
  if swing.force<swing.lowf then
   swing.force=swing.lowf
  end
 end
end

function _draw()
 currentdraw()

 --print(debug,cam.xfree*128,cam.yfree*128,7)
 
 --print(debug,factoryx,factoryy,7)
end

function drawplaying()
 if currentdraw!=drawtransition then
  cls(bg.colour)
 end

 --factory external has blue sky
 if currlvl.xmap==6 and currlvl.ymap==2 then
  cls(12)
 else
  drawbackgrounds()
 end

 --draw all of current level
 map(currlvl.xmap*16,currlvl.ymap*16,currlvl.xmap*128,currlvl.ymap*128,currlvl.w*16,currlvl.h*16)

 --tutorial text
 if lvls.currlvlno==1 then
  drawtutorialtext()
 end

 drawobj(currlvl.exit)
 
 if currlvl.haskey then
  spr(currlvl.key.anim.sprite,
    (currlvl.key.x*8),
    (currlvl.key.y*8),1,1,currlvl.key.xflip)
 end
 
 --game objects
 for c in all(corpses) do
  drawobj(c,c.xflip,c.yflip)
  
  for p in all(c.particles) do
   circfill(p.x*8,p.y*8,p.r,p.col)
  end
 end
 
 for b in all(bumpers) do
  drawobj(b)
  --drawcirc(b)
  
  --circle collision
  --circ((b.x+b.xcenoff)*8,(b.y+b.ycenoff)*8,b.r*8)
 end

 for h in all(hooks) do
  drawobj(h)
  --drawcirc(h)

  --circle collision
  --circ((h.x+h.xcenoff)*8,(h.y+h.ycenoff)*8,h.r*8)
 end

 if av.canswing and not av.dancing and av.respawnstate=="alive" then
  drawaim()
 end
 
 --tab 6
 drawparticles(false)
 
 --should only exist during ending
 --todo:should split out ending draw bits
 if worms then
  for worm in all(worms) do
   spr(worm.anim.sprite,worm.x*8,worm.y*8,1,1,worm.xflip)
  end
 end

 --draw bubble around av in slowzone
 if av.slowstate=="in" and
    av.colstate!="hook" then
  spr(26,(av.x-0.25)*8, --pixel*2
  (av.y-0.25)*8)
 end

 drawav()

 --hitbox 
 --rect(av.x*8,av.y*8,(av.x+av.w)*8,(av.y+av.h)*8,3)
 
 --hurtbox 
 --[[rect(av.hurtbox.x*8,av.hurtbox.y*8,
  (av.hurtbox.x+av.hurtbox.w)*8,
  (av.hurtbox.y+av.hurtbox.h)*8,3)
 ]]
 
 --cicle collision
 --circ((av.x+av.r)*8,(av.y+av.r)*8,av.r*8)
 
 drawparticles(true)
 
 if cam.free then
  --pulse out and in a little
  local out=cam.arrowcounter>cam.arrowcountermax/2
  local mod=0
  if out then
   mod=0.25 --2*pixel
  end
  if currlvl.w>1 then
   drawobj({s=16,x=(cam.xfree*16)+14+mod,y=(cam.yfree*16)+7})
   drawobj({s=16,x=(cam.xfree*16)+1-mod,y=(cam.yfree*16)+7},true)
  elseif currlvl.h>1 then
   drawobj({s=0,x=(cam.xfree*16)+7,y=(cam.yfree*16)+14+mod})
   drawobj({s=0,x=(cam.xfree*16)+7,y=(cam.yfree*16)+1-mod},false,true)
  end
 end
end

function drawaim() 
 --if swing.currdecaypause>0 then
 -- linecol=6
 --end

 for i=1,#aim.points do
  local dotcol=5
  
  if (i%5==0) dotcol=7

  pset(
   (av.w/2+aim.points[i].x)*8,
   (av.h/2+aim.points[i].y)*8,dotcol)
 end

 --where player should land for debugging 
 -- rect(aim.x*8,aim.y*8,
 --  (aim.x+aim.w)*8,
 --  (aim.y+aim.h)*8,2)
 --circfill(aim.x*8+1,
 -- aim.y*8+1,1.5,7)
 local off=0
 
 if aim.hitdeath then
  off=4
 end
 
 sspr(48+off,8+off,
  4,4,
  aim.x*8,aim.y*8)
 
 --spr(22,
 -- aim.x*8,aim.y*8)
end

function drawav()
 -- -pixel*2 for sprite offset
 spr(av.anim.sprite,
  (av.x-0.25)*8,
  (av.y-0.25)*8,1,1,av.xflip,av.yflip)
end

function drawobj(obj,xflip,yflip)
 spr(obj.s,obj.x*8,obj.y*8,1,1,xflip,yflip)
end

function drawcirc(obj)
 circ((obj.x+obj.r)*8,(obj.y+obj.r)*8,obj.r*8)
end

function drawfactory()
 cls(12)

 map(96,32,factoryx,factoryy,16,16)
 camera(factoryx,factoryy)
end

-->8
--collision

function avwallscollision()
 groundcollisioncalculations()

 --other sides col
 if not groundcol(av,0,av.yvel,0) then
	 if topcol(av,0,av.yvel,0) then
	  moveavtoroof()
	  av.yvel*=-1
	  
	  av.pauseanim="tsquish"

	  collisionimpact(av.x+(av.w/2),av.y,
	   1,0.25,false,avcolours)
	 else
   --only check collision for current direction
   if av.xvel<=0 and leftcol(av,av.xvel,av.yvel,0) then
    av.pauseanim="lsquish"

    collisionimpact(av.x,av.y+(av.h/2),
     0.25,1,true,avcolours)

    moveavtoleft()
    sidebounce()
   end

   if av.xvel>=0 and rightcol(av,av.xvel,av.yvel,0) then
    av.pauseanim="rsquish"
    
    collisionimpact(av.x+av.w,av.y+(av.h/2),
     -0.75,1,true,avcolours)

    moveavtoright()
    sidebounce()
   end
  end
	else --on ground
	 if allleftcol(av,av.xvel,0,0) or allrightcol(av,av.xvel,0,0) then
	  --should move av to wall but w/e
	  av.xvel=0
	 end
 end
end

function groundcollisioncalculations()
 if groundcol(av,0,av.yvel,0) then
  moveavtoground()
  
  --if vel low enough, land
  if groundcol(av,0,av.yvel,6) or
     abs(av.yvel)<0.075 then

   if av.colstate!="ground" then
    local cols=avcolours

    --todo:bug where if on sand can shoot downwards
    -- and get burried a frame :(
    if groundcol(av,0,av.yvel,6) then
     cols=sandcolours
    end

    collisionimpact(av.x+(av.w/2),av.y+av.h,
     1,-0.25,false,cols)

    av.colstate="ground"  
    
    av.xvel,av.yvel=0,0
    
    av.canswing=true
	
    updateaim()

    sfx(8)
   end
   
	  --tredmills
	  if groundcol(av,0,av.yvel,1) then
	   av.xvel=treadmillspeed
	  elseif groundcol(av,0,av.yvel,2) then
	   av.xvel=-treadmillspeed
	  else
    av.xvel=0
   end
  else --bounce
   av.xvel*=xbouncefrac
   av.yvel*=ybouncefrac

   av.pauseanim="gsquish"
   
   collisionimpact(av.x+(av.w/2),av.y+av.h,
	   1,-0.25,false,avcolours)
  end
 else
  if av.slowstate=="in" then
   av.yvel+=gravity*slowfrac
  else
   av.yvel+=gravity
  
   av.colstate="air"
   av.canswing=false
  end
 end
end

function getcollisionpoints(box,xvel,yvel)
 return box.x+xvel,box.y+yvel,box.w,box.h
end

function anycol(box,xvel,yvel,flag)
 local x,y,w,h=getcollisionpoints(box,xvel,yvel)

 return
  checkflag(x,y,flag) or
  checkflag(x+w,y,flag) or
  checkflag(x,y+h,flag) or
  checkflag(x+w,y+h,flag)
end

function allcol(box,xvel,yvel,flag)
 local x,y,w,h=getcollisionpoints(box,xvel,yvel)

 return
  checkflag(x,y,flag) and
  checkflag(x+w,y,flag) and
  checkflag(x,y+h,flag) and
  checkflag(x+w,y+h,flag)
end

function groundcol(box,xvel,yvel,flag)
 local x,y,w,h=getcollisionpoints(box,xvel,yvel)

 return
  checkflag(x,y+h,flag) or
  checkflag(x+w,y+h,flag)
end

function allgroundcol(box,xvel,yvel,flag)
 local x,y,w,h=getcollisionpoints(box,xvel,yvel)

 return
  checkflag(x,y+h,flag) and
  checkflag(x+w,y+h,flag)
end

function leftcol(box,xvel,yvel,flag)
 local x,y,w,h=getcollisionpoints(box,xvel,yvel)

 return
  checkflag(x,y,flag) or
  checkflag(x,y+h,flag)
end

function allleftcol(box,xvel,yvel,flag)
 local x,y,w,h=getcollisionpoints(box,xvel,yvel)

 return
  checkflag(x,y,flag) and
  checkflag(x,y+h,flag)
end

function rightcol(box,xvel,yvel,flag)
 local x,y,w,h=getcollisionpoints(box,xvel,yvel)

 return
  checkflag(x+w,y,flag) or
  checkflag(x+w,y+h,flag)
end

function allrightcol(box,xvel,yvel,flag)
 local x,y,w,h=getcollisionpoints(box,xvel,yvel)

 return
  checkflag(x+w,y,flag) and
  checkflag(x+w,y+h,flag)
end

function topcol(box,xvel,yvel,flag)
 local x,y,w,h=getcollisionpoints(box,xvel,yvel)

 return
  checkflag(x,y,flag) or
  checkflag(x+w,y,flag)
end

function alltopcol(box,xvel,yvel,flag)
 local x,y,w,h=getcollisionpoints(box,xvel,yvel)

 return
  checkflag(x,y,flag) and
  checkflag(x+w,y,flag)
end

function moveavtoground()
 av.y+=av.yvel
 av.y+=distanceinwall(
  av,0,1,-1,groundcol)+pixel
 
 av.y-=av.y%pixel
end

function moveavtoroof()
 av.y+=distancetowall(
  av,0,1,-1,topcol,false)
 av.y+=pixel-av.y%pixel
end

function moveavtoleft()
 av.x+=distancetowall(
  av,1,0,-1,leftcol,true)
 
 if av.x%pixel!=0 then
  --round to pixel
  av.x+=pixel-av.x%pixel
 end
end

function moveavtoright()
 av.x+=distancetowall(av,1,0,1,rightcol,true)
 
 --round to pixel + out of wall
 av.x-=(av.x%pixel)+0.001
end

function distancetowall(box,checkx,checky,direction,colfunc,topcheck)
 local distancetowall=0

 while not colfunc(box,distancetowall*checkx,distancetowall*checky,0) do
  distancetowall+=(pixel*direction)

  --if the distance gets longer than a tile,
  -- something's wrong. abort.
  -- (hack - ideally would never occur)
  if abs(distancetowall)>1 then
   --debug="collision hack hit!"
   return distancetowall
  end

  if allgroundcol(av,distancetowall,av.yvel,0) then
   --corner collision occured
   -- abort wall collision
   -- with ground collision
   groundcollisioncalculations()

   --re-reverse wall collision vel flip
   av.xvel*=-1
   return distancetowall
  end
  
  if topcheck then
   if alltopcol(av,distancetowall,av.yvel,0) then
    --corner collision occured
    -- abort wall collision
    -- with top collision
    av.pauseanim="tsquish"
    av.xpause,av.ypause=squishpause,squishpause
    
    topcoloverwrite=true
    --moveavtoroof()
   
    --av.yvel=0
    --av.xvel*=1
    return distancetowall
   end
  end
 end

 return distancetowall
end

function distanceinwall(box,checkx,checky,direction,colfunc)
 local distanceinwall=0

 while colfunc
      (box,distanceinwall*checkx,
      distanceinwall*checky,0) do
  distanceinwall+=(pixel*direction)
 end

 return distanceinwall
end

function checkflag(x,y,flag)
 --only for checkpoints :/
 xhitblock,yhitblock=flr(x),flr(y)
 
 local s=mget(x,y)
 return fget(s,flag)
end

function checkflaggroup(x,y,flagtotal,off)
 local off=off or 0
 local s=mget(x,y)
 return fget(s)==flagtotal or fget(s)==flagtotal+off
end

-- https://stackoverflow.com/questions/345838/ball-to-ball-collision-detection-and-handling
function circlecollision(s1,s2)
 local s1x=s1.x+(s1.xcenoff or s1.r)
 local s1y=s1.y+(s1.ycenoff or s1.r)
 
 local s2x=s2.x+(s2.xcenoff or s2.r)
 local s2y=s2.y+(s2.ycenoff or s2.r)
 
 --get distance from cen to cen
 local dx=s1x-s2x
 local dy=s1y-s2y
 
 local distance=(dx*dx)+(dy*dy)
 
 --if radiuses less than c2c, collision
 if distance<=((s1.r+s2.r)*(s1.r+s2.r)) then
  return true
 end
 return false
end

-->8
--inits and resets

function initlevels()

 --should x and y find the
 -- find the enterance
 lvls={
  --controls tutorial
  {xmap=4,ymap=1,h=2},
  
  --bunkers
  --bunker tutorial
  {xmap=0,ymap=0},
  --bunker tutorial 2
  {xmap=1,ymap=0},
  --static swing power test
  {xmap=3,ymap=2},
  --bounce off walls
  {xmap=7,ymap=2},

  --belts intro
  --convayer belts
  {xmap=3,ymap=3},
  --convayers and bunkers
  {xmap=2,ymap=1,w=2},
  --belt maze
  {xmap=6,ymap=1,w=2},

  --hooks intro
  --moving hooks
  {xmap=1,ymap=3},
  --hook maze newer
  {xmap=2,ymap=0},
  --hook maze older
  {xmap=0,ymap=3},
  --mover hooks horizontal
  {xmap=3,ymap=0},
  --diag mover hooks
  {xmap=0,ymap=2},
  --tall moving hooks climb
  {xmap=5,ymap=1,h=2},

  --slows intro
  --slows tutorial
  {xmap=6,ymap=0},
  --float zone 3x3
  {xmap=7,ymap=0},
  --zig-zag slows
  {xmap=0,ymap=1},
  --float climb
  {xmap=2,ymap=2,h=2},

  --player knows all mechanics
  --belts and death hooks
  {xmap=4,ymap=3},
  --wide slows with mover hooks
  {xmap=4,ymap=0,w=2},
  --dive deep-belts and slows
  {xmap=1,ymap=1,h=2},
  --final gauntlet
  {xmap=5,ymap=3,w=3}
 }
 
 --change to set starting lvl
 lvls.currlvlno=0
 
 nextlevel()
end

function resetav()
 if av!=nil and
    av.colstate=="hook" and
    av.hook!=nil then
  hookreleaseav(av.hook)
 end

 av={
  --consts
  w=0.375, --pixel*3
  
  h=0.5, --pixel*4
  
  r=0.25, --pixel*2
  
  --vars
  x=xcp+0.25, --pixel*2
  y=ycp+0.25, --pixel*2
  
  xvel=0,
  yvel=0,
  
  colstate="air",
  
  slowstate="none",

  respawnstate="alive",
  respawncounter=0,
  respawnlength=20,

  canswing=false,
  
  xflip=false,
  yflip=false,

  dancing=false,
 }
 
 resethurtbox(av)
 
 --lock movement
 av.xpause,av.ypause=0,0
 
 --play specific anim
 -- w/o locking movement
 av.animpause=0
 
 --animations when locked
 av.pauseanim="none"

 av.anim=makeanimt()
 
 resetswing()
end

function resethurtbox(obj)
 local xoff=pixel
 local yoff=pixel
 
 obj.hurtbox={
  x=obj.x+xoff,
  y=obj.y+yoff,
  w=pixel,
  h=pixel,
 }
end

function resetswing()
 swing={
  --consts
  lowf=0.212,
  highf=0.45,
  btnf=0.04,
  lowrotangle=1/1200,
  highrotangle=1/300,
  rotanglevel=1/4500,
  basedecay=0.00005,
  decayvel=0.000035,
  decaypause=16,

  --vars
  xvec=0,
  yvec=-1,
  decay=0,
  currdecaypause=0,
 }
 
 swing.force=swing.lowf
 swing.currrotangle=swing.lowrotangle
end

function createbumper(x,y)
 b={
  x=x,
  y=y,
  xcenoff=0.5, --pixel*4
  ycenoff=0.75, --pixel*6
  r=0.25, --pixel*2
  s=48,
 }

 add(bumpers,b)
end

function createhook(x,y)
 h={
  --consts
  spawnx=x,
  spawny=y,
  xcenoff=0.5, --pixel*4
  ycenoff=0.75, --pixel*6
  r=0.375, --pixel*3
  s=32,
  
  spawns,
  spawnxvel,
  spawnyvel,

  --vars
  x=x,
  y=y,
  active=true,
  typ="moveon",
  avon=false,
  xvel=0,
  yvel=0,
 }
 
 if checkflaggroup(x,y,56,1) then --(0)+3+4+5
  h.xvel,h.yvel,h.s=diaghookspeed,-diaghookspeed,34
 elseif checkflaggroup(x,y,104,1) then -- (0)+3+5+6
  h.xvel,h.yvel,h.s=diaghookspeed,diaghookspeed,36
 elseif checkflaggroup(x,y,200,1) then -- (0)+3+6+7
  h.xvel,h.yvel,h.s=-diaghookspeed,diaghookspeed,38
 elseif checkflaggroup(x,y,152,1) then -- (0)+3+4+7
  h.xvel,h.yvel,h.s=-diaghookspeed,-diaghookspeed,40
 elseif checkflag(x,y,4) then
  h.yvel,h.s=-hookspeed,33
 elseif checkflag(x,y,5) then
  h.xvel,h.s=hookspeed,35
 elseif checkflag(x,y,6) then
  h.yvel,h.s=hookspeed,37
 elseif checkflag(x,y,7) then
  h.xvel,h.s=-hookspeed,39
 else
  h.typ="still"
 end
 
 if checkflag(x,y,0) then
  lvlhasmovinghooks,h.typ=true,"mover"
  h.s+=16
 end
 
 h.spawns,h.spawnxvel,h.spawnyvel=h.s,h.xvel,h.yvel

 add(hooks,h)
end

function makebackgrounds()
 --background colour
 bg={
  --consts
  s=122,
  colour=0,
  
  --vars
  x=0,
  y=0,
  xvel=0.05,
  yvel=0.05,
 }
end

function createcorpse(x,y)
 c={
  x=x,
  y=y,
  s=1+flr(rnd(2)),
  xflip=rnd()<0.5,
  yflip=rnd()<0.5,
  lifespan=0,
  step=8+flr(rnd(5)),
  stage="start",
  particles={},
 }
 
 add(corpses,c)
end

function nextlevel()

 resetcamera()

 lvlhasmovinghooks=false
 lvls.currlvlno+=1
 
 if lvls.currlvlno>#lvls then
  initending()
  return
 end
 
 --delete previous level's game objects
 -- (this means no going back levels
 -- since the game object level data is deleted)
 bumpers={}
 hooks={}
 
 currlvl=lvls[lvls.currlvlno]
 
 currlvl.w=currlvl.w or 1
 currlvl.h=currlvl.h or 1
 
 currlvl.haskey=false
 
 --scan area for level game objects
 for x=(16*currlvl.xmap),(16*currlvl.xmap)+(16*currlvl.w)-1 do
  for y=(16*currlvl.ymap),(16*currlvl.ymap)+(16*currlvl.h)-1 do

		 --load this lvls bumpers and hooks
   -- 0+4+5+6+7
		 if checkflaggroup(x,y,241) then
		  createbumper(x,y)
		  mset(x,y,0)
		 end
		 
		 if checkflag(x,y,3) then
		  createhook(x,y)
		  mset(x,y,0)
		 end
		 
   -- 1+7
   if checkflaggroup(x,y,130) then
    --found spawn
    currlvl.xspawn,currlvl.yspawn=x,y

    xcp,ycp=x,y
    
    resetav()
   end
   
   -- 4+7
   if checkflaggroup(x,y,144) then
    --found key
    currlvl.haskey,currlvl.key=true,resetkey(x,y)

    mset(x,y,0)
   end

   -- 5+7
   if checkflaggroup(x,y,160) then
    --found exit
    currlvl.exit={
     x=x,
     y=y,
     s=20,
     r=0.5, -- pixel*4
    }

    mset(x,y,0)
   end
  end
 end
 
 if currlvl.haskey then
  currlvl.exit.s=21
 end
end

function resetkey(x,y)
 local keyanim=makeanimt(9,40,2)

 local key={
  --consts
  spawnx=x,
  spawny=y,
  r=0.5, --pixel*4
  
  --vars
  x=x,
  y=y,
  collected=false,
  saved=false,
  anim=keyanim,
  xflip=false,
 }
    
 return key
end

function skiplvl()
 lvlsskipped+=1
 nextlevel()
 effects={}
end

-->8
--update logic

function updateav()
 if av.respawnstate=="alive" then
  if av.canswing then
   av.xflip=swing.xvec<0
  else
   av.xflip=av.xvel<0
  end
  
  --movement
  local frameslowfrac=1
  
  if av.slowstate=="in" then
   frameslowfrac=slowfrac
  end

  if av.xpause<=0 then
   av.x=av.x+(av.xvel*frameslowfrac)
  end
  
  if av.ypause<=0 then
   av.y=av.y+(av.yvel*frameslowfrac)
  end
  
  resethurtbox(av)
 elseif av.respawnstate=="dead" then
  av.respawncounter+=1

  if av.respawncounter>=30 then
   
   --if top of count,
   -- move av to current checkpoint
   av.x=xcp+0.25 --pixel*2
   av.y=ycp+0.25 --pixel*2
   
   sfx(28)

   initcollect(av.x+0.25,av.y+0.25,avcolours) --pixel*2

   av.respawnstate="respawn"
   av.respawncounter=0
  end

 elseif av.respawnstate=="respawn" then
  av.respawncounter+=1

  if av.respawncounter>=av.respawnlength then
   resetav()
  end
 end

 if av.xpause<=0 and
    av.ypause<=0 and
    av.animpause<=0 then
  av.pauseanim="none"
  av.yflip=false
 end

 if av.xpause>0 then
  av.xpause-=1
 end
 
 if av.ypause>0 then
  av.ypause-=1
 end
 
 if av.animpause>0 then
  av.animpause-=1
 end
end

function updatecamera()
 --range for angle to move camera right or left
 local rightrange={low=0.3,high=0.75}
 local leftrange={low=0.75,high=0.2}

 -- don't allow camera off map
 if av.x>0 and av.x<127 then
  cam.x=camera1d(cam.x,currlvl.xmap,currlvl.w,av.x,av.w,rightrange,leftrange)
 end
 
 --range for angle to move camera up or down
 local highrange={low=0.175,high=0.325}
 local lowrange={low=0.45,high=0.05}

 if av.y>0 and av.y<63 then
  cam.y=camera1d(cam.y,currlvl.ymap,currlvl.h,av.y,av.h,highrange,lowrange)
 end

 local cammovespeed=pixel/4

 if not cam.free then
  cam.xfree=movetopoint(cam.xfree,cam.x)
  cam.yfree=movetopoint(cam.yfree,cam.y)
	end

 if not pausecontrols then
  if btn(⬆️) and cam.canmove and av.canswing then
   cam.free=true
   
   if cam.freedirect=="none" then
    cam.freedirect="up"
   end

   if currlvl.w>1 then
    cam.xfree-=cammovespeed
    
    if cam.xfree<cam.x and cam.freedirect=="down" then
     resetcamera()
    end
   elseif currlvl.h>1 then
    cam.yfree-=cammovespeed
    
    if cam.yfree<cam.y and cam.freedirect=="down" then
     resetcamera()
    end
   end
  end
  
  if btn(⬇️) and cam.canmove and av.canswing then
   cam.free=true

   if cam.freedirect=="none" then
    cam.freedirect="down"
   end

   if currlvl.w>1 then
    cam.xfree+=cammovespeed
    
    if cam.xfree>cam.x and cam.freedirect=="up" then
     resetcamera()
    end
   elseif currlvl.h>1 then
    cam.yfree+=cammovespeed
    
    if cam.yfree>cam.y and cam.freedirect=="up" then
     resetcamera()
    end
   end
  end

  if not cam.canmove and not btn(⬆️) and not btn(⬇️) then
   cam.canmove=true
  end
 end

 --todo:call camera1dbounds less? tidy, maybe renaming
 cam.xfree=camera1dbounds(cam.xfree,currlvl.xmap,currlvl.w)
 cam.yfree=camera1dbounds(cam.yfree,currlvl.ymap,currlvl.h)

 camera(cam.xfree*128,cam.yfree*128)
 
 if cam.free then
  cam.arrowcounter+=1

  if cam.arrowcounter>=cam.arrowcountermax then
   cam.arrowcounter=0
  end
 end
end

function resetcamera()
 cam.free,cam.canmove,cam.freedirect=false,false,"none"
end

function camera1dbounds(lcam,lvlpos,lvllength)
	--don't scroll off level
	if lcam<lvlpos then
		lcam=lvlpos
	end
	
	if lcam>lvlpos+lvllength-1 then
		lcam=lvlpos+lvllength-1
	end

	return lcam
end

function camera1d(lcam,lvlpos,lvllength,avpos,avlength,highrange,lowrange)
 local lowbound=3
 --account for player width
 local highbound=12.5

	if lvllength==1 then
		lcam=flr((avpos+avlength*0.5)/16)
	else
		if av.canswing then

			--scrolling camera
			local tiledestination=cam.prevtiledest
			
			local aimangle=atan2(swing.xvec,swing.yvec)

			if angleinrange(aimangle,highrange) then
				tiledestination=highbound
				cam.prevtiledest=tiledestination
			elseif angleinrange(aimangle,lowrange) then
				tiledestination=lowbound
				cam.prevtiledest=tiledestination
			end
			
			local cameradest=(avpos-tiledestination)/16
			
			--smooth scroll to level bounds
			if cameradest<lvlpos then
				cameradest=lvlpos
			end
		
			if cameradest>lvlpos+lvllength-1 then
				cameradest=lvlpos+lvllength-1
			end

   lcam=movetopoint(lcam,cameradest)

		else --can't swing
			--camera only moves if
			-- player gets past deadzone
			if avpos/16<lcam+(lowbound/16) then
				lcam=(avpos-lowbound)/16   
			end

			if avpos/16>lcam+(highbound/16) then
				lcam=(avpos-highbound)/16
			end
		end
	end
	
	return lcam
end

function movetopoint(from,to,frac,maxspeed)
 local scrollfrac=frac or 0.25
 local maxspeed=maxspeed or 0.1

	local diff=to-from
	
 if abs(diff)<0.01 then
	 return to
	end

	diff*=scrollfrac
	
	if diff>maxspeed then
		diff=maxspeed
	elseif diff<-maxspeed then
		diff=-maxspeed
	end
	
	return from+diff
end

function angleinrange(angle,range)
 --account for looping
 return angle>range.low and angle<range.high or 
  (range.low>range.high and (angle>range.low or angle<range.high)) 
end

function updateaim()
 -- reset
 aim={
  x=av.x,
  y=av.y,
  xvel=av.xvel,
  yvel=av.yvel,
  h=av.h,
  w=av.w,
  r=av.r,
  points={},
  hitdeath=false,
 }

 if av.canswing then
	 local wallhit=false

  applyswing(aim)

	 while wallhit==false do
		 local point={
		  x=aim.x,
		  y=aim.y,
		 }

   add(aim.points,point)
   
   aim.yvel+=gravity

   updatemovement(aim)

   if #aim.points>105 then
    wallhit=true
   end

   --Lose percision as we go,
   -- since we're hitting cpu limitations
   --if stat(1)<0.5 or stat(1)>=0.5 and #aim.points%3==0 then
   if not lvlhasmovinghooks or
      (#aim.points<20 or
      (#aim.points<30 and #aim.points%2==0) or
      (#aim.points<50 and #aim.points%3==0) or
      #aim.points%4==0) then
    resethurtbox(aim)

    --simulate av collision
    if anycol(aim.hurtbox,aim.xvel,aim.yvel,4) then
     wallhit=true
     aim.hitdeath=true
    end

    if groundcol(aim,0,aim.yvel,0) or
       topcol(aim,0,aim.yvel,0) or
       leftcol(aim,aim.xvel,aim.yvel,0) or
       rightcol(aim,aim.xvel,aim.yvel,0) then
     wallhit=true
    end
    
    --Don't check every point against hooks,
    -- and stop checking if out of cpu budget
    -- because of performance issues.
    -- not ideal.
    --aim count is hack to prevent collision with hook when on hook
    if #aim.points>3 and #aim.points%3==0 and stat(1)<0.3 then
     for h in all(hooks) do
      if circlecollision(aim,h) then
       wallhit=true
      end
     end
    end
   end
	 end
 end
end

function updatemovement(obj)
 obj.x=obj.x+obj.xvel
 obj.y=obj.y+obj.yvel
end

function applyswing(obj)
	obj.xvel=swing.xvec*swing.force
	obj.yvel=swing.yvec*swing.force
end

function rotacc(fact)
 swing.xvec,swing.yvec=rotatevec(swing.xvec,swing.yvec,swing.currrotangle*fact)

 swing.currrotangle+=swing.rotanglevel
 
 if swing.currrotangle>swing.highrotangle then
  swing.currrotangle=swing.highrotangle
 end
end

function rotatevec(x,y,angle)
 local newx=x*cos(angle)-y*sin(angle)
 local newy=x*sin(angle)+y*cos(angle)
 
 return newx,newy
end

function boostswing()
 swing.currdecaypause=swing.decaypause
 swing.force+=swing.btnf
 
 swing.decay=swing.basedecay
 
 if swing.force>swing.highf then
  swing.force=swing.highf
 end

 av.pauseanim="boost"
 av.animpause=10
 resetanimt(av.anim)
end

function hookreleaseav(hook)
 hook.active=false
 
 if hook.typ=="moveon" then
  sfx(9)
  --smoke puff
  -- 4*pixel
  initdustkick(hook.x+0.5,hook.y+0.5,
   -0.5,-0.5,
   1,1,
   20,5,hookcolours,true,4)

  hook.x,hook.y=hook.spawnx,hook.spawny

  --another puff at spawn
  initdustkick(hook.x+0.5,hook.y+0.5,
   -0.5,-0.5,
   1,1,
   20,5,hookcolours,true,4)

  hook.xvel,hook.yvel,hook.s=hook.spawnxvel,hook.spawnyvel,hook.spawns
 end

 hook.avon=false
 
 av.hook=nil
end

function updatebackgrounds()
 bg.x+=bg.xvel
 bg.y+=bg.yvel
 
 if bg.x>=16 then
  bg.x-=16
 end

 if bg.y>=16 then
  bg.y-=16
 end
 
 if bg.x<=-16 then
  bg.x+=16
 end

 if bg.y<=-16 then
  bg.y+=16
 end
end

function updateplaytime()
 frames+=1
 
 if frames==60 then
  seconds+=1
  frames=0
  if seconds==60 then
   minutes+=1
   seconds=0
   if minutes==60 then
    hours+=1
    minutes=0
   end
  end
 end
end

function sidebounce()
 if not topcoloverwrite then
  av.xvel*=-1
 end
 
 topcoloverwrite=false
end

function updatecorpses()
 for c in all(corpses) do
  c.lifespan+=1
  
  if c.lifespan%c.step==0 then
   c.step=7+flr(rnd(5))

   if c.stage=="start" then
    if c.lifespan>=20 then
     c.lifespan=0
     c.stage="grow"
    end
   elseif c.stage=="grow" then
    local p={
     x=c.x+rnd(0.9),
     y=c.y+rnd(0.9),
     r=rnd(2),
     col=deathcolours[1+flr(rnd(#deathcolours))],
    }
    
    add(c.particles,p)
   
    if c.lifespan>=200 then
     c.stage="decay"

     --body is dissolved
     c.s=-1
    end
   elseif c.stage=="decay" then
    del(c.particles,
     c.particles[1+flr(rnd(#c.particles))])
    
    if #c.particles==0 then
     del(corpses,c)
    end
   end
  end
 end
end

function lsfx(no)
 currno=stat(49)
 
 if currno==no then
  return
 end
 
 sfx(no,3)
end
-->8
-- animation and special draws

function avanimfind(t)
 --default idle
 t.basesprite=46
 t.sprites=2
 t.speed=19

 if btnp()>0 then
   idleframes=0
 end

 if currentupdate==updateplaying and av.xvel==0 then
  idleframes+=1

  --sleeping idle anim
  -- after 15 seconds
  if idleframes>900 and
      av.colstate=="ground" then
    --tried a snore but didn't like it
    --lsfx(35)
    
    t.basesprite=7
    t.speed=90
  end
 end

 --flying through air
 if av.colstate!="ground" then
  t.basesprite=60
  t.sprites=4
  t.speed=7
  
  --slowstate
  -- air but slower
  if av.slowstate=="in" then
   t.speed=14
  end
 end

 --on hook
 if av.colstate=="hook" then
  t.basesprite=46
  t.sprites=1
 end

 local flipval=-1
 
 if av.xflip then
  flipval=1
 end
 
 local lx,ly=feetpos()
 
 --charge anim when adding force
 if av.canswing and swing.force>swing.lowf then
  --bottom half of swing force
  if swing.force<((swing.highf-swing.lowf)/2)+swing.lowf then
   t.basesprite=27
   t.sprites=3
   t.speed=5
   
   lsfx(2)
   
   if frames%6==0 then
	   initdustkick(lx,ly,flipval,0.25,
	    0.5,0.5,
	    1,0,sparkcolours,false)
   end
  elseif swing.force<=swing.highf-((swing.highf-swing.lowf)/10) then
   --top half
   t.basesprite=43
   t.sprites=3
   t.speed=4
   
   lsfx(3)
   
   if frames%5==0 then
	   initdustkick(lx,ly,flipval,0.25,
	    0.5,0.5,
	    2,4,sparkcolours,false)
   end
  else
   --top 10%
   t.basesprite=43
   t.sprites=3
   t.speed=2
   
   lsfx(4)
   
   if frames%3==0 then
	   initdustkick(lx,ly,flipval,0.25,
	    0.5,0.5,
	    3,5,sparkcolours,false)
   end
  end
 end

 --sqush anims
 if av.pauseanim=="gsquish" then
  t.basesprite=41
  t.sprites=1
  av.yflip=true
 elseif av.pauseanim=="lsquish" then
  t.basesprite=42
  t.sprites=1
 elseif av.pauseanim=="rsquish" then
  t.basesprite=42
  t.sprites=1
  av.xflip=true
 elseif av.pauseanim=="tsquish" then
  t.basesprite=41
  t.sprites=1
 elseif av.pauseanim=="boost" then
  t.basesprite=30
  t.sprites=2
  t.speed=5
 end
 
 if av.dancing then
	 t.basesprite=12
	 t.sprites=4
	 t.speed=15
 end

 --don't show av if dead
 if av.respawnstate!="alive" then
  t.basesprite=-10
 end
end

function makeanimt(bs,sd,sprs)
 local t={
  basesprite=bs,
  speed=sd,
  sprites=sprs,
  sprite=bs,
  along=0,
  counter=0,
 }
 return t
end

function updateanims()
 avanimfind(av.anim)
 updateanimt(av.anim)

 updateanimt(cpanim)
 
 if currlvl.haskey then
  updateanimt(currlvl.key.anim)
 end
 
 if not checkflaggroup(xcp,ycp,130) then
  mset(xcp,ycp,cpanim.sprite)
 end
end

function resetanimt(t)
 --reset for fresh start on new anim
 t.along=0
 t.counter=0
end

function updateanimt(t)
 t.counter+=1
 
 t.along=t.counter/t.speed
 
 if t.counter>=
    t.speed*t.sprites then
  t.along=0
  t.counter=0
 end
 
 t.sprite=t.basesprite+t.along
end

function drawbackgrounds()
 for i=(128*currlvl.xmap)-32,(128*currlvl.xmap)+(128*currlvl.w),16 do
  for j=(128*currlvl.ymap)-32,(128*currlvl.ymap)+(128*currlvl.h),16 do

   local x=i+bg.x
   local y=j+bg.y
  
   spr(bg.s,x,y)
   spr(bg.s,8+x,y,1,1,true)
   spr(bg.s,8+x,8+y,1,1,true,true)
   spr(bg.s,x,8+y,1,1,false,true)   
  end
 end
end

function drawtutorialtext()
 local xorigin,yorigin=4*128,1*128
 local c1,c2=0,7
 outline("⬅️ aim ➡️",xorigin+11.3*8,yorigin+5.5*8,c1,c2)
 outline("swing z/🅾️",xorigin+6*7.375,yorigin+0.5*8,c1,c2)
 outline("charge ❎",xorigin+0.2*8,yorigin+13.5*8,c1,c2)
 outline("⬆️",xorigin+1.4*8,yorigin+18.5*8,c1,c2)
 outline("camera",xorigin+0.4*8,yorigin+19.5*8,c1,c2)
 outline("⬇️",xorigin+1.4*8,yorigin+20.5*8,c1,c2)
end

function outline(s,x,y,c1,c2)
 for i=0,2 do
  for j=0,2 do
   print(s,x+i,y+j,c1)
  end
 end
 print(s,x+1,y+1,c2)
end

-->8
-- other states

function initstartscreen()
 musicstarted=false

 resetav()
 
 av.x=(6*16)+1.5
 av.y=(2*16)+1
 
 currentupdate=updatestartscreen
 currentdraw=drawstartscreen
end

function updatestartscreen()
 updatebeginning()

 if av.colstate=="ground" then 
  if not musicstarted then
   musicstarted=true
   music(24)
  end

  if btnp()>0 then
   sfx(38)
   initintro()
  end
 end
end

function drawstartscreen()
 drawbeginning(false)

 drawlogo(factoryx+54,av.y*8-58)

 if av.colstate=="ground" then
  s="press any button"
  outline(s,
   factoryx+hw(s),factoryy+72,1,7)
 end
end

function drawlogo(x,y)
 s="e c p "
 outline(s,
  x,y+8,1,7)

 s=" s a e"
 outline(s,
  x,y+9,1,7)

 spr(3,x,y,3,1)
end

function initintro()
 music(-1,2000)

 currentupdate=updateintro
 currentdraw=drawintro

 updateaim()

 introstate="start"
 introtimer=0

 introwindow={
  x=(6*16)+9,
  y=(2*16)+3,
  r=5}
end

function updateintro()
 updateaim()

 updatebeginning()

 --timers
 introtimer+=1

 if introstate=="start" then
  if introtimer>=60 then
   introstate="talk"
   introtimer=0
   sfx(39)
  end
 elseif introstate=="talk" then
  if introtimer>=120 then
   introstate="aim"
   introtimer=0
  end
 elseif introstate=="aim" then
  rotacc(-1)
  
  if introtimer>=20 then
   introstate="aimpause"
   introtimer=0
  end
 elseif introstate=="aimpause" then
  if introtimer>=60 then
   introstate="charge"
   introtimer=0
  end
 elseif introstate=="charge" then
  if introtimer%15==0 then
   boostswing()
  end

  if introtimer>=120 then
   sfx(1)
   
   applyswing(av)
   resetswing()

   introstate="hitwindow"
   introtimer=0
  end
 elseif introstate=="hitwindow" then
  if circlecollision(av,introwindow) then
   --start game
   sfx(17)
   music(7)

   initlevels()

   currentupdate=updateplaying
   currentdraw=drawplaying
   
   menuitem(1,"skip level", skiplvl)

   initfade(currlvl.xmap*16,currlvl.ymap*16,0)
  end
 end
end

function drawintro()
 drawbeginning(true)

 if introstate=="talk" then
  s="i must save the worms!"
  outline(s,
   factoryx+hw(s),factoryy+100,0,7)
 end
end

function updatebeginning()
 --could activate/deactivate this
 -- to allow for using all tiles on
 -- drawing of factory.
 avwallscollision()

 updateav()
 
 avanimfind(av.anim)
 updateanimt(av.anim)
 
 updateparticleeffects()
 
end

function drawbeginning(isdrawaim)
 drawfactory()
 drawparticles(false)

 if isdrawaim then
  drawaim()
 end
 
 drawav()
 drawparticles(true)
end

function initlvlend()
 sfx(37)

 currentupdate,currentdraw=updatelvlend,drawlvlend

 pausecontrols,pausecamera,av.dancing=true,true,true
end

function updatelvlend()
 updateplaying()

 --next level
 if btnp(🅾️) then
  totalswingcount+=lvlswingcount
  lvlswingcount=0
  sfx(14)

  inittransition({0},backtoplaying,nextlevel)
 end

 --reset level
 if btn(⬅️) and btn(❎) then
  sfx(15)
  inittransition({5,0},backtoplaying,resetcurrlvl)
 end
end

function resetcurrlvl()
  lvlswingcount=0
  
  if currlvl.haskey then
   dropkey()
  end

  resetpreviouscheckpoint()

  xcp,ycp=currlvl.xspawn,currlvl.yspawn
  
  resetav()
end

function dropkey()
   currlvl.exit.s=21
   currlvl.key=resetkey(currlvl.key.spawnx,currlvl.key.spawny)
end

function resetpreviouscheckpoint()
  --clear old cp
  -- if not spawn
  if not checkflaggroup(xcp,ycp,130) then
    mset(xcp,ycp,6)
  end  
end

function drawlvlend()
 drawplaying()

 local c1,c2=0,7

 s="level completed!"
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+32,c1,c2)
 
 s="swings: "..lvlswingcount
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+48,c1,c2)
 
 s="next level z/🅾️"
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+56,c1,c2)
 
 s="replay level ⬅️+❎"
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+64,c1,c2)
end

function inittransition(cols,resumefunc,nextstatefunc)
 currentupdate=updatetransition
 currentdraw=drawtransition

 transition=resettransition(cols,resumefunc,nextstatefunc)
end

function resettransition(cols,resumefunc,nextstatefunc)
 local t={
  currcol=1,
  cols=cols,
  resumefunc=resumefunc,
  nextstatefunc=nextstatefunc,
 }
 t.cir=resettransitioncir()
 return t
end

function resettransitioncir()
 return {
  x=64,
  y=0,
  r=5,
  speed=5
 }
end

function updatetransition()
 if not endingtransition then
  updateplaying()
 end

 transition.cir.r+=transition.cir.speed
 
 --once circle fills screen, move to next currcol
 if transition.cir.r>160 then
 
  pausecamera=false

  if transition.currcol<=#transition.cols then
   --move to the next colour
   transition.cir=resettransitioncir()
  end
  
  if transition.currcol==#transition.cols then
   av.dancing=false

   if endingtransition then
    transition.resumefunc()
    return
   else
    transition.nextstatefunc()
   end
  end
  
  if transition.currcol>#transition.cols then
   -- done all colours
   transition.resumefunc()
  end

  transition.currcol+=1
 end
end

function backtoplaying()
 updateaim()
 currentupdate=updateplaying
 currentdraw=drawplaying
 pausecontrols=false
end

function drawtransition()
 if transition.currcol==1 then
  cls()
  drawplaying()
 end

 if transition.currcol<=#transition.cols then
  circfill((cam.x*128)+transition.cir.x,(cam.y*128)+transition.cir.y,transition.cir.r,transition.cols[transition.currcol])
 else
  -- circle transition to show screen
  cls()

  --less itterations than i'd like
  -- because of performance issues
  for i=0.5,0.75,0.05 do
  
   local x=transition.cir.x+transition.cir.r*cos(i)
   local y=transition.cir.y+transition.cir.r*sin(i)

   local xbit=transition.cir.x-x
   local ybit=transition.cir.y-y
   
   --slightly random number
   -- prevents unneeded extra draws
   -- once width is past edges

   if xbit*2<200 then
   
    clip(x,transition.cir.y,xbit*2,-ybit)

    drawplaying()
   
    clip()
   
    --does drop below 60
    -- would be good to improve
    -- performance
    --debug=stat(7)..".."..x..".."..transition.cir.y..".."..(xbit*2)..".."..-ybit
   end
  end
 end
end

function initending()
 endingtransition=true

 music(0)

 menuitem(1)

 --factory external
 currlvl.xmap=6
 currlvl.ymap=2
 currlvl.w=1
 currlvl.h=1
 currlvl.haskey=false
 
 --push open door
 -- into map
 mset(104,45,97)
 
 av.x=(currlvl.xmap*16)+8
 av.y=(currlvl.ymap*16)+15
 
 updatecamera()

 pausecontrols=true

 -- go through greyscale colours expanding from top
 -- until on white, then initfade
 inittransition({0,5,6,7},backtoending,nextlevel)
end

function backtoending()
 ycredits=150
 
 av.dancing=true
 
 initfade(currlvl.xmap*16,currlvl.ymap*16,7)
 
 --create a bunch of wee wormy guys
 worms={}

 --todo:change to number of worms on map
 for i=0,15 do
   for j=0,2 do
   local worm={
    x=(currlvl.xmap*16)+i+rnd(1),
    y=(currlvl.ymap*16)+13.5+j+(rnd(1)),
    anim=makeanimt(17,10+rnd(5),2),
    xflip=rnd()<0.5
   }
   add(worms, worm)
  end
 end

 currentupdate=updateending
 currentdraw=drawending
end

function updateending()
 updateplaying()

 for worm in all(worms) do
  updateanimt(worm.anim)
 end

 if #effects>0 then
  return
 end

 if ycredits>32 then
  ycredits-=0.25
 end
end

function drawending()
 drawplaying()
 
 --credits
 
 local c1,c2=0,7
 
 drawlogo(factoryx+54,factoryy+ycredits-10,y)

 s="by davbo"
 outline(s,
  factoryx+hw(s),factoryy+ycredits+8,c1,c2)
 
 s="with help from rory and polly"
 outline(s,
  factoryx+hw(s),factoryy+ycredits+16,c1,c2)
 
 s="deaths: "..deathcount
 outline(s,
  factoryx+hw(s),factoryy+ycredits+24,c1,c2)

 s="total swings: "..totalswingcount
 outline(s,
  factoryx+hw(s),factoryy+ycredits+32,c1,c2)

  s="levels skipped: "..lvlsskipped
  outline(s,
   factoryx+hw(s),factoryy+ycredits+40,c1,c2)

 s="playtime: "..
 twodigit(hours)..":"..
 twodigit(minutes)..":"..
 twodigit(seconds).."."..
 twodigit(frames)
 outline(s,
  factoryx+hw(s),factoryy+ycredits+48,c1,c2)

 s="thanks for playing!"
 outline(s,
  factoryx+hw(s),factoryy+ycredits+56,c1,c2)
end

function twodigit(val)
 if val>9 then
  return val
 else
  return "0"..val
 end
end

--half width for printing
function hw(s)
 return 64-#s*2
end

-->8
--particle effects

effects={}
sparkcolours={6,7,8}
avcolours={15,15,4,6}
sandcolours={10,10,9,6}
hookcolours={2,5,6,6,6}
deathcolours={3,3,3,5,5,9,11,11,13,13}
floatcolours={1,7,12}

function createeffect(update)
 e={
  update=update,
  front=false,
  particles={}
 }
 add(effects,e)
 return e
end

function createparticle(x,y,xvel,yvel,r,col,decreasestep)
 p={
  x=x,
  y=y,
  xvel=xvel,
  yvel=yvel,
  r=r,
  col=col,
  decreasestep=decreasestep
 }
 return p
end

function updateparticleeffects()
 for e in all(effects) do
  e.update(e)
 end
end

function drawparticles(front)
 for e in all(effects) do
  if e.front==front then
   for p in all(e.particles) do
    circfill(p.x,p.y,p.r,p.col)
   end
  end
 end
end

function initdustkick(x,y,dx,dy,rdx,rdy,no,minlength,cols,front,radius)
 local e=createeffect(updatedustkick)
 e.front=front or false

 radius=radius or 2

 --create a bunch of particles
 for i=0,no do
  local col=cols[1+flr(rnd(#cols))]
  
  local lrdx=rnd(rdx)
  if rdx<0 then
   lrdx=rnd(abs(rdx))*-1
  end
  
  local p=createparticle(
   x*8,
   y*8,
   dx+lrdx,dy+rnd(rdy),
   0+flr(rnd(radius)),col,
   2+rnd(5))
  
  p.timeout=minlength+rnd(5)
  add(e.particles,p)
 end
end

function updatedustkick(e)
 for p in all(e.particles) do
  p.x+=p.xvel
  p.y+=p.yvel
  
  p.timeout-=1
  
  if p.timeout<=0 then
   if p.r>0 then
    p.r-=1
    p.timeout=p.decreasestep
   else
    del(e.particles,p)
   end
  end
 end
 
 if #e.particles==0 then
  del(effects,e)
 end
end

function initburst(x,y,cols)
 local e=createeffect(updatedustkick)

 for i=0,7 do
  local col=cols[1+flr(rnd(#cols))]

  local p=createparticle(
   (x+0.5)*8,(y+0.5)*8,
   rnd(1.6)-0.8,rnd(1.6)-0.8,
   0+flr(rnd(2)),col,
   2+rnd(5))
  
  p.timeout=10+rnd(5)
  add(e.particles,p)
	end
end

function initcollect(x,y,cols)
 local e=createeffect(updatecollect)
 e.x,e.y=x*8,y*8

 local r=4
 
 for i=0,1,(1/16) do
 
  local x=x+r*cos(i)
  local y=y+r*sin(i)

  local col=cols[1+flr(rnd(#cols))]

  local p=createparticle(
   x*8,y*8,
   0,0,
   0,col,av.respawnlength/2)
   
  p.timeout=av.respawnlength/2
  add(e.particles,p)
 end
end

function updatecollect(e)
 for p in all(e.particles) do
  frac,maxspeed=0.25,1.4

  p.x=movetopoint(p.x,e.x,frac,maxspeed)
  p.y=movetopoint(p.y,e.y,frac,maxspeed)

  p.timeout-=1
  
  if p.timeout<=0 and p.r<2 then
    p.r+=1
    p.timeout=p.decreasestep
  end
 end
 
 if av.respawnstate=="alive" then
  del(effects,e)
 end
end

function collisionimpact(x,y,dx,dy,wall,cols)
 sfx(0)

 --could scale based on force

 av.xpause=squishpause
 av.ypause=squishpause
 
 initdustkick(x,y,
  dx,dy,
  0.5,0.5,
  3,5,cols,false)
 
 if wall then
  dy*=-1
 else
  dx*=-1
 end
 
 initdustkick(x,y,
  dx,dy,
  0.5,0.5,
  3,5,cols,false)
end

function feetpos()
 if av.xflip then
  return av.x+av.w,av.y+av.h
 else
  return av.x,av.y+av.h
 end
end

function initfade(x,y,col)
 local e=createeffect(updatedustkick)
 e.front=true

 --create a bunch of particles
 -- 2 screens tall for lvl 1
 for i=-1,16 do
  for j=-1,32 do
  
   local lrdx=i+rnd(1)
   local lrdy=j+rnd(1)

   local p=createparticle(
    (x+lrdx)*8,
    (y+lrdy)*8,
    (-0.5+rnd(1))/10,(-0.5+rnd(1))/10,
    10+rnd(5),
    col,15+rnd(5))
   
   p.timeout=120+rnd(5)
   add(e.particles,p)
  end
 end
end

-->8
--scrolling texture effect

function updatescrollingtextures()
 scrollcounter+=1

 if scrollcounter%10==0 then
	 --downwards pour
	 scrolltiledown()
	end
	
	if scrollcounter%30==0 then
	 --single square
	 scrollareaup(127,2,4,1,2)
	
	 --long thin
	 scrollareaup(124,10,4,1,2)
	 
	 --full inner
	 scrollareaup(123,4,8,0,0)
	 
	 for s=76,79 do
	  scrollareaup(s,2,20,1,2)
  end
 end
 
 if scrollcounter==60 then
  scrollcounter=0
 end
end

function scrolltiledown()
 --tile 65 is down pour
 addr=spradd(65)

 --save row 1 to set buffers up
 memcpy(backupaddr2,addr,4)

 for i=1,6,2 do
  pixelshift(addr+(64*i),addr+(64*(i+1)),4)
 end
 
 pixelshift(addr+(64*7),addr,4)
end

function spradd(sp)
 return 512*(sp\16)+4*(sp%16)
end

function scrollareaup(sp,w,h,woff,hoff)
 addr=spradd(sp)+woff
 
 --save last row to set buffers up
 memcpy(backupaddr2,addr+(64*(h-1+hoff)),w)

 -- h-(1 for last row)-(1 for 0 index)
 for i=(h-2+hoff),hoff,-2 do
  --looping case
  local i2=i-1
  if i2<hoff then
   i2=h-1+hoff
  end

  pixelshift(addr+(64*i),addr+(64*(i2)),w)
 end

 -- copy into last row
 memcpy(addr+(64*(h-1+hoff)),backupaddr1,w)
end

function pixelshift(addr1,addr2,w)
 --save row 1
 memcpy(backupaddr1,addr1,w)

 -- write row 1 to row 2
 memcpy(addr1,backupaddr2,w)

 -- save row 3
 memcpy(backupaddr2,addr2,w)

 -- write row 2 to row 3
 memcpy(addr2,backupaddr1,w)
end

__gfx__
00066000000000000000000000111100111001100001110000000000000c00000000000000022000000220008866668800040400004004000040400000400400
0006600000066000000000000177771177111710011177100070220000c1c00000000000002222000022220086566568000ff000000ff000000ff000000ff000
000660000008dd6006d8e0d0177dd717dd717d101177dd1100712200000c0000000c000067722777677227776445644604f1f100001f1f00001f1f4000f1f100
0006600000ded80000dddd0017d11d17d171711017dd177100712200401ef000001ef000600700076007e0e76556655600fffe0000feff0000efff0000ffef40
0666666000dddd0006d8ddd0171177171171d71117777dd1007100000fffff004ffff0007807e0e7708708076446544600fffff004ffff000fffff0000ffff00
05666650000ddd00000dd6001771d77d77d11d7117ddd110007000004f1ff0000f1fff0078070807780708076556655600f0000000f00f0000000f0000f00f00
005665000060d000000000001d777d71dd1111d7171110000070000000ff4f0040f4ff0060878007608780076445644600000000000000000000000000000000
00055000000000000000000001ddd1d11110011d1d71000000700000000000000000000066777766667777666556655600000000000000000000000000000000
00000000e0e00000000000000066660000666600006666000660000000000000000000000000000000cccc000000000000000000000000000000040400000000
0000660008000000e0e000000611116006ccac6006555560676600000070770000700700007000000c1111c0000040400000404000004040000007f700004040
000066600800000008000000611111166ccacac66515155667770000007677000076770000767700c111111c0040fff00040fff00040fff00000717100000fff
666666660800080080088000611111166cccaca66551555607700000007677000076770000767700c111111c000f1f10000f1f10000f1f100040f7e70400f1f1
555566650088800080800800611111166ccacac66551555600000220007600000076700000706700c111111c040ffe000f0ffe00040ffe00040fff0000ffffe0
000066500000000080080000611111166cccccc66551551600002822007000000070000000700000c111111cf04ff000004ff000400ff000f04ff000400fff00
000055000000000008800000611111166cccccc665551156000028880070000000700000007000000c1111c000000000040000000f0000000000000004ff0000
000000000000000000000000611111166cccccc6655555560000088000700000007000000070000000cccc000000000000000000000000000000000000000000
00022000000770000004770000044000000440000004400000044000000440000077400000000000000000000000000000000000000000000000000000404000
002222000047740000447700004477000044440000444400004444000077440000774400000000000004040000040400000404000004040000040000000ff000
002222000044440000444400004477000044770000477400007744000077440000444400041f14f000f1f0000000fff00000fff00000fff0040ff00000f1f100
0002200000044000000440000004400000047700000770000077400000044000000440000ffeff0000ff1000004f1f10004f1f10004f1f1000f1f10004fffe00
00d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000fff00000fe0000040ffe008f0ffe00040ffe0000fffe0000ffff00
0d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d0000f040000ff0000f04ff000804ff000408ff00004fffff000f0f000
d000000dd000000dd000000dd000000dd000000dd000000dd000000dd000000dd000000d00000000000ff00088000000040000000f8000000000000000000000
66666666666666666666666666666666666666666666666666666666666666666666666600000000004000000000000000000000000000000000000000000000
0000000000077000000e7700000ee000000ee000000ee000000ee000000ee0000077e0008ddddddd88dddddddd88ddd500000000000000000000000000000000
000ee00000e77e0000ee770000ee770000eeee0000eeee0000eeee000077ee000077ee00d1111111dd11111111dd111d0404000000000000000f0f0000040000
00e72e0000eeee0000eeee0000ee770000ee770000e77e000077ee000077ee0000eeee00da1a1aa111a11a1a1aa1aa1d00fff00004f1e00000fff0000f0fff00
0e7222e0000ee000000ee000000ee000000e7700000770000077e000000ee000000ee000d1a11a1a1a1a1a1a1aa1a1ad00f1f10000ffff0000ffff0000fff140
0e2222e000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d00da1a1aa11a1a1aaa1a11aad804ffef00041fff00001fef0000ffff00
00e22e000d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d0da1a1a1111a11aaa1aa1a1ad00fff00000fff0f004ff1000000e1f40
000ee000d000000dd000000dd000000dd000000dd000000dd000000dd000000dd000000dddddd1111111ddddd111111d0f0f0000000040000004400000000000
0000000066666666666666666666666666666666666666666666666666666666666666662dd2dddddddd2222ddddddd200000000000000000000000000000000
022222220b3333b0222222200222222009aaa9a9aaa9aaaaaa9a9aa0aaa9aa9ad666666655555550000555006666666600000000000000000000000000000000
228882880b3343b08288828225888282aa9a9a499a4a549a9a45a49a29dad6a92dddd6d65aa11ab05555d5506dddddd60049bbbbbbbb44949bbbbb0000bbbb00
258882880b3333b0858882822588828222888588828885888288828227766c7627766c765aaa1a30555ddd506d11dd160b33333333333333333333b00b3333b0
255522220b343bb025552222255225522222222222555522555522222cccccc72cccccc735a1a5005551dd506d111d110b3b333333333333333333b00b343340
285888280b333bb088588822285888522828885888588828885888522cccccc22cccccc2311a1a5055511d506dd111110b33333333b33333334333b00b3333b0
285888280b9333b0885888222828885228288858882888288828885222222c2622222c2651aa1150155bbb506ddd11110b33433333333933333333b00b9333b0
282888580b3343b0882888222828885228288858882888288828882225ddd2d625ddd2d65aaaaabb11553bb061dd11110b33333333333333333393b00b3334b0
222222550b3333b022222222022222200222222222222222222222202222222d2222222d5555533b0b3553b0611111110b33333bb333333bb33333b00b3333b0
228882888288828882888282022222200aaa9aaa00555000aa9aaaa0a9a9aa9a6666666d5555555500000002200000000b33333bb333333bb33333b00b3333b0
22888288828885888288828222888282a9a44a59055d55555aa4a95aadadd9d26d6dddd25565555500000022220000000b333b3333333333333333b00b3333b0
228885888288858885888582228885822288828805ddd5558288828267866772678667725d55555500000228822000000b33333333333b33333333b0043b3390
255555522255555255555552255555522222222205dd15552225555278888882788888825555555500002222222200000b34333333333333334333b0043333b0
285888588858882888588852285888222828882805d115558858885228888882288888825555556500022882882220000433333333333333333333400b3333b0
285888288858882888588822282888222828882805bbb55188588822628222226282222255555d5500228882882822000433333333333333333333b00b3333b0
28288828882888288828882228288822285888280bb35511885888226d2ddd526d2ddd525555555502288882882882200b33333333343333333333400b3334b0
22222222222222222222222222222222225555520b3553b022222222d2222222d22222225555555522222222222222220b34333bb333333bb33b33400b3333b0
228882888866668882888582228885820aa9a4a00aaaaa9000cccccccccccccccccccc008288828802000020666666660b33333bb333333bb33333b00b33b3b0
25888288861515688288858222888582a94aaa5aa9a49a590c111111c1c1c1c1c1c1c1c082888588025555206dddddd60b33333333333433333343b00b3333b0
258882886441114682888582228885822588828222888582c11111111c1c1c1c1c1c1c1c82888588025885206dddddd60b33333333333333333333b00b333340
255522226551111622225552225555522555222222225552c111111111c1c1c1c1c1c1cc22522552025885206dddddd60b33933333393333333333b009333340
285888286411111688288822285888222858882228288852c1111111111111111c1c1c1c88588828025885206dddddd60b33333333333333339333b0043933b0
285888286551115688288822282888222828882228288852c1111111111111111111c1cc88588828025225206ddddd560b43333333333333333333b0043333b0
282888286414144688288822282888222828882228288822c11111111111111111111c1c88288828025885206dd555560044bbbbbbbb49444bbbbb0000bbbb00
022222226555555622222220222222220222222022222222c1111111111111111111c1cc22222222252225526666666600000000000000000000000000000000
02222222222222222222222025888282c111111111111111c11111111111111111111c1c1111111c010000003333333300000000000000000000000000000000
22888288858885888588828225888282c111111111111111c1111111111111111111c1cc1111111c111000003333433300b4bbbbb4bbbbbbbbbbbb0000bbbb00
22888588858885888588858225888282c111111111111111c11111111111111111111c1c1111111c00000100333333390b33333333333333393333400b3343b0
22225555252255222555552225552222c111111111111111c1111111111111111111c1cc1111111c01111110339333330b9333333333333b333333b00b3333b0
28288858882888288858882228588822c111111111111111c11111111111111111111c1c1111111c0010010033333b330b333b3334333333333b33b00bb333b0
28288858885888288828882228288822c111111111111111c1111111111111111111c1cc1111111c00100100333433330b3333333333b333333334b0043339b0
282888288858882888288822282888220c11111111111111c11111111111111111111c1c111111c001111110333333430043494bbb4944bbbbbbbb0000bbbb00
0222222222222222222222200222222000ccccccccccccccc111111111111111111111cccccccc00000000003b33333300000000000000000000000000000000
1515151515d6d6d6d5d6d61515151515d5d4d7e6000005e5000000f6006686c51515151515151515151515151515151515151515151515151515151515151515
a40094000000c7d7d7d7d7d4d7e4140525000300071717d6d594e514030003140000000000000000a60000000000000015151515151515151515151515151515
1515152600000000f600000006151515d5e60000000005e500000000006787c5250066860000c6d6e6000000000000051515d5e6000000000000000000000615
d5d4d5e400000000000000f600c6d5152500000000000003c6d5e5140000001400000000000000a596b5a6000000000015152600000000000000000000000615
15152600000003009000030000061515e50000858585152566868484846787c52500479700667686000000000090000515d5e600000000000000000000000005
1515152500000000000000000000c615250000000000001300c6e5140300031400000000a6a6a596969696b50000000015260000000000000000000000000005
1526000000630000f400004300000615e56686f60000003647970000f64797c5250000c7e4475797000000006000000515e50000000000c4d7e7000000000005
15151525000000f4000000009000000525000000000000000000f61400000014000000a59696969696b4b696b500000025000000000000600000003500000005
25000000000000c7d6e7000000000005e5678700000000360000000000c7d7d525668600c5d7d7e7000000000417171515e500410000c4e60000000000600005
15151525000000350000000000000005250053000000000000000314000000140000a5969696969696b6b61596b50000250000000000004564000036e4000005
250000000000f7000000f70000000005e54797f700000005e46686000000000525479700f600000000000000f600000515d6e746c7d7e6000090000055445415
15151525000000360000000000000005250003000000000000000014f700001400000096969696969696151596000000250000000000042600000036e5000005
2500030000f70000000000f700000305d5d7e70000000005e5678700000000052500000000000000000000f40000000525000000000000000000000014000005
151515260000003600000000071717152500000000000003f70000360000001400000096b6b696969696969696000000250000071717250000900036e6000005
2500000000000000f4000000f70000052500000000006005e54797f4000000052500006676860000000000f600006005250000000000000000f4000014940005
1515250000000036000000000006151515d4d4d4d7d7d7e7030013360000001400000096b6b69696969696969600000025000000000036000000003600000005
1584848484848417e6000000600051052600000000000715d6d7d7e60000000615a400677787000000000066768607152500000000000000c4e5456514949405
1515250000000036000000000000061515b7b7e503000300000000360000001400000096969696969696b6b69600000025000000000036000000c4e600000005
25000000000003000003008484841715a4000000000000000000000000000055151400475797000000000067777786c5250000000000445415151515d6171715
151526000000003600000000000000051515152600000000000003360000001400000096969696969696b6b696000000250000000000055465d7e60000000005
25a400000063000000004300000055051466768600000066768600000066861415d5d4d7d7d7e70000000047575797c525000000000000000000000000000005
152500000000003600600000000000052500000000000000000000360000f71400000096969696969696969696a4000025000000000005152500000000600005
2514000000000000000000000000140514677787c4e40047579700c4e46787141515260066768600000000000000551525000000000000000000000000000005
152500000000000617270000000000052500000013001300130000361300130500000096b6b69696969696969614000025000007171715152500000044545415
251400000000c7e4000000000000140514475797c5d5e4009000c4d5e54797141526000067778700000000667686140525000000000000000000000000000005
1525000000000000000000000000000525000000000000000300c4250090000500000096b6b69693a3b396969614940025000000000000052500000000000015
25140300000000f50000000000031405d5d4d4d4d5d5e5667686c5d5d5d4d4d52500000047579700000000677787140525005600000000000000350031000415
152500000000000000000000000004152500310003f4030000c4d525030003050000009696969696b09696969694940025000000000000052500000000000005
25140000000031c6e400000000001405b7d5b7b794b7e5475797c5b794d5b7b725000000000000000000f4475797140515171524d4d4d4d4d4d4151717171515
1515240051000000000000000004151515171717d4d5d4d4d4d5b725006000059595959595959595959595959595959525000031000000c5e500000000410005
15d5d4d4d4041724d5d4d4d4d4d4d515b7b7b7d5b794d5d4d4d4d594b7b7d5b7250000006686f4000000c6d7d7d7d61515151515151515151515151515151515
15151517171717171717171717151515151515151515151515151515171717159595959595959595959595959595959515d4d41717d4d4d5d5d4d4d445545415
1515151515151515151515151515151515d6d6d6d6d6d5d5d6d6d6d515151515256686004797f6000000000000000005b7d5b7d5d6d6d6d6d6d6d6d615151515
1515d5d6d6d6d6d6d515d5d6d6d6d51515151515151515d5d6d6d6d6d51515d6d5d6d6d6d6d6d5d615151515b7d5d6d6d6d6e6f6c6d615151515151515151515
250000000000c5250000000000c6d515250000520000c5e6005200f60000000525479700000000000000000000000005d594d5e6000000000000000000000005
15d5e60000000000c6d5e6000000c6d5250000000000c6e600000000c6d5e503f50300000003f5000000c4d5d6e6000032000000668600b6b60000b6b6000005
250000000000c625000000000000c6152500000000c7e600000000000000000525000000000000000000000000000005d5d5e600000000000000000000000005
15e500000000000000f50000000000c525000000000000000000000000c6d5d4e60000000000f50000c4d6e50000000000f400f4479700b6b60000b6b6000005
2500000000000036005100340000000525320000000000000000000000000005256676768600000000006686f4668605b7e500000000c4e40000000000000005
15e500000060000000f54103f43303c5250000000060000000c4e400000005e5000000000000f500c4e600c6e4000000c7d5e43600c7e4000000000000410005
25000000000000c617172700000000052600000000c7e40000900000000000052567777787c4e70000004797f5479705d5e60085858585d58585850000006005
15e50084842400f400c65475e60000c5260000747484848484d6d6e7000005e5000000f40000f5c4e6005200f500000000c6d5256686f500c417172707172706
25000000f4000000c5e6000000000005d4e400000000c5e400000000004100052567777787f500000000c7d7e6000005e64100c5b7d5d6e60000000002000415
03f633f503f600f500000000000000c5e50000000036000000000000000005e50000c7d5e700c5e5000000c7e60000000000c52567873600c6d6d6d5d6d6d6d5
2500000034a40000f600000000000005b7e500000000c6e5001200f407171715254757579736000000000000000000051717858585250000000000000000c5d5
e40000c5e40000c67474748484841717e500000000058400c78585858585d5e6000000f50000c6e500000000000000000000c52547973600667686f5667686c5
2500000000140000000000000012c415d5e60012000000c6d7d7d4e594061515250000000036000000000000000000052500000000370000000000000000c5b7
e50000c6e6000000000000000000000524000044542500000000000000c5e5000000c4e5000000f500000000000000000000c5d5e7003600677787f6677787c5
250000000014000000000012c7d4d515e5000000000000000000c5d6d6d7d4d4250000000425000000f46676767686052500000000000000000000000000c5d5
e500000000000000900000000060000526000000003600000000000000c525000000c5e6000000f500000000000000008200c5256686366067778700677787c5
25001200001400000000000000c6d515e5000060000000000000f6000000c6d5250060000525000000f54757575797052500000000000000c4d4848484848484
17178585858585858585000000071715e500000000360000000000f400c6250000c4e5000000c4e500000000000000000000c52567870524677787f4677787c5
15d4e4000014000000f700000000c615d5d7071727e4000000000000720000c5151717171525510000f50000000000052500000084848484d5e6000000000615
d5d6d6d6d6d6d6d5d6e6030033f603c52400000000058484848484e600003600c4d6e5000053c5e6000000000000000000c4e6364797c5e5475797f5475797c5
15d6d6e7001400004200f700000000052500000000c6d7d7d7e70000000000c5151515151515270000f66676767686c525000000000000c6e500000000000005
e5030033000000f5030000000000c7d526000044541525000000000000003600f613f50000c4e500000000c4e7000000c4e6003600c7d6d6d7d7d7d5e700c7d5
250000000014f4000000000000820005250000320000000000000000000000c5151526000000000000006777777787c52500000000000000f600000000000005
e5000000f40000f500000000000000c5e50000000005260000858585858526130000f50000c6d5e700f400f5000000c4e60000f566768600667686f6667686c5
250000000014c5e4000090000000c41525000000000000c4d4d4e4000000c4d5152500000000000000006777777787c51517240000000000000000f400310005
e5000000f50000f600848484270000c5e50000000005e50000000000000000030003f5000003f60000f500c6e400c4e60094c4e5677787f467778790677787c5
2531c4e4121494d5e400000000c4d515250000310000c4d59494d5e400c4d5b7152500310000f700f7004757575797c5151515d4d4858585858585d517171715
e5003100f500000000000000000000c5e50000310005e50000000000000000600000f5003100600012c5e400c6d4e6009494c5e5475797f5475797f4475797c5
1524c5d5d4d5b7b7d5d4d4d4d4d5d51515d4041724d4d5b7d5d5b7d5d4d5b7d51515171724c4e735c7e4c4d4d4d4d4d5151515d5b71515151515151515151515
d5171717d57474748484848484841717d5d4e435c415d5d4d484848484848417171717848484848417d5d5d4d4d517171717d5d5d4d4d4d5d4d4d4d5d4d4d4d5
__label__
88888888822222222288888888888888888828888888888888882888888888888888888288888888888888822888888888850000000000000000000000000000
88888888882222222288888888888888888828888888881111188288888888888888811111188888888888882888888888850008888888888888888888888000
88888111111122222222888888888888888882888888811177118228811188888888111111188888888888882888888888850087777777777777777777777800
88811111111111111222888888888881111112888888811777118828811111888111111777188888888888882288888888850878887777777777777777777780
88111777777771111112288888888111111111188888817777118828817711111111777777188888888888888288888888850877878777777777778777777780
81177777777777771111288888881117777777111888117776188828817777111177777766188888888888888288888888850877877877887787878777787780
81177766666777777771118888811177777777711188117761188828817777777777776611188888888888888288888888850877877878787787878877878780
81777611111166677777112888811777666677771181177761888882117767777777661112288888888888888228888888850877878778787788878787878780
21776111888111166777711288117776111167777111177711888882117716666666111888288888888888888828888888850878887777878778778877787780
81776118888228111677771188117761181116677111177618888888117711111111188888288888888888888828888888850087777777777777777777777800
81776118888288881167771128177611888811177711177618888888117718888888888881111888888888444444422222250008888888888888888888888000
81776118888288888116777112177618888888117711177618822222177712222222221111111222222224442244448888850000000000000000000000000000
81776118888288888111777611177618888888817711177112288881177718288888811117771888888284442224444888850000000000000000000000000000
81776128888288888811677611177618888822217771177182888881177618828881111177771888888284444222444488850000000000000000000000000000
81771182888288888821166111177112222288811771177182888881177611111111177777761888888288444422244448850000000000000000000000000000
81771188288288888881111112177118228888881771177182888881177777111117777777611888888288844442224448850000000000000000000000000000
81771188228288888888211222177718828888811771177182888881777777777777777666118844888228844442222444850000000000000000000000990000
81771118822288888888222222177711828888811771177112888881777677777777766111184444448828884444222244850000000000000000000000990000
81777111882288881111111112117761882888117761177711888881776166666666611118884422444828888444442224450000000000000000000000000000
817771118882888111111111111177618828881177611677112888817761111111111188888444222448288888444442244f0000000000000000000000000000
811777111882881177777711111177718882881777111177711888817761111828888888888444222244488888ff444444ffff00000000000000000000000000
88167771118288177777777111111771118281177611116771188881776188882888888888884442222444888fffffffffffffff000000000000000000000000
881177771112881776667777111117761111111776181116771888817711888822888888888888442222244fffffffffffffffffff0000000000000000990000
88116777711188166111677771111777711117776118811177118881771188888288888888888884442224fffffffffffffffffff11111000000000000990000
88811677771118111111177777711177777777761118811167711881771188888288888888888888844424fffffffffffffffff1111111110000000000000000
88881167777111888881117777771117777777611188881117711181771188888288888888888888884444ffffffffffffffff11111117110000000000000000
8888811677771111111117776777711166666611118888111677111177718888828888888882222222844fffffffffffffffff11111177711000000000000000
8888881167777711111777771677761111111111888888111177711167712222222222222222888888884fffffffffffffffff11111117111000000000000000
888888811677777777777776216666122222222222222221116777111771188888888888288888888888ffffffffff11ffffff11111111111000000000990000
2228888811167777777766612111111222888888888882881116777117771888888888882888888888ffffffffff11111ffffc11111111111100000000990000
8822288888111666666611112811111222288888888882888111777116771888888888888288888888fffffffff1111711fffc11111111111100000000000000
888822288882111111111118288882222228888888888288881166611166188111111888828888888ffffffffff11177711fffc1111111111100000000000000
888888222882888888882288288882222222888888888228888111111111111111111188828888888fffffffff111117111fffc1111111111100000000000000
888888882282888888888222288888222222888888888288888888888111111777771118828888888fffffffff111111111ffffc111111111100000000000000
888888888222888888111112288888222222288888888228881111111111111777777118828888888ffffffffc111111111fffccc11111111000000000990000
888888888822888881111111288888811111288888888821111111111111117776777618828888888ffffffffc111111111fffcffc1111110000000000990000
88888888888288881117771118888111111112888888882117777777111111776117761882888888fffffffffc111111111fcfffffcccccff000000000000000
88888888888288811177777718881111777111281111188117777777771111776117761882888888fffffffffc111111111ffffffffffffff000000000000000
88888888888288811777667718811177777771211111118217776667777117771177761882888888fffffffffc11111111ffffffffffffffff00000000000000
88888888888288117776116612117777766771117777111816776111777617777777761282882222fffffccfcccc11111fffffffffffffffff00000000000000
88888881111188117761111111177776611661177777711111777111777617777766611222222888ffffffffcffccccfffffffffffffffffff00000000990000
88888111111118177761888281177661111111777677761181677117777617766611118888888888ffccfffffffffffffffffffffffffffffff0000000990000
88881117777111177711888281777111888111776617771121177777776117711118888888888888fffffffffffffffffffffffeeefffffffff0000000000000
888811777777111777711111117761128888117761177711811777777611177111888111118888888fffffffffffeeeeeffffeee7eeffffffff0000000000000
888117776777611677771111117761122888117761117761111677766118177711881177718888888ffffffffffeeeee7eeffee777efffffffff000000000000
2881177611776111677777711177118882881177611177711711776111181677711117777188888888fffffffffeeee777effcee7eefffffffff000000000000
22117776177761811677777711771188882111777117777777117761888811777711777761888888666ffffffffceeee7eeffceeeeefffffffff000000990000
88117761177761881116667771777188881111677777766776117761888811677777777611888866666fffffffccceeeee88cceeeeefffffffeeee0000990000
881177177776118888111167716771181117711667776116611177618888811677777661188866666666fffccffccccce8cc8ceeeefffffeeeeeeee000000000
8811777777711188888881177117771111177111166661111117761188888811666661118886666666666ffffffffff8888888cccffffeeeeeeeeeee00000000
8811777776611888888881177116777117777111111111111817761188888221111111222666666666666ffffffffff5888888fffffffeeeeeeeeeee00000000
88117777611188888881117771116777777761881111122888166112222222882888888866666660666666ffffffff85888858ffffffeeeeeeeeeeeee0000000
88117761111888888811177761111677766611888882222222111122888888882888866666666006666666ffffff858855558fffffffeeeeeeeeeeeee0990000
881177718828888881117776111111666111188888882222888888828888888822886666666600666666666ff885858888888fffffffeeeeeeeeeeeee0990000
8811777711181111817777611122111111118228888282222288888288888888828666666660066666668885885888588855ffffffffeeeeeeeeeeeeee000000
888167777711177111777611188822288828888228828222228888828888888882666666600666666668885888588885558fffffffffeeeeeeeeee222e000000
88811677777777711166611188888822882888882282882222288882888888886666666000666667766588588885888888ffffffffffeeeee222ee222e000000
88881166777777618111111888888882222888888222888222222222222288667766660066667777668588858888588ffffffffffffffeeee222ee32ee000000
8888811166666611822222288888888882288888882288882222888888886667766666666677766666885886fffffffffffffffffffffeee332ee3eee0990000
8888888111111118888882288888888888288888888288888222228888666676666666666776666666888566fffffffffffffffffffffe3eeeeeeeee00990000
8888888811111888888882888888888888288888888288888822222866667766666666677666666446688866ffffffffffffffffffffffffeeeeee0000000000
8888888888288888888882888888888888288888888288888822226667776666666666776666664444688856fffffffffffffffffffffffffff0000000000000
8888888888288888888882888888888888288888882228888882267776666066666677766666644444468588ffffffffffffffff88888800ff00000000000000
8888888888288888888882888888888888288888882882288886777666600666667776666666644444446888ffffffffffffff88880000000000000000000000
2222888888288888888882888888888888222888882888222867766660066666677666666666664444444444fffffffffffff888000000000000000000990000
8888222222288888888882222228888888282228882888882677666606666666776666660666664444444444ffffffffffff8888000000000000000000990000
8888888888288888888882888822228888288882222888867766660066666666666666006666666444444444ffffffffffff8880000000000000000000000000
888888888828888888888288888882222828888882288887766660066666666666000066666666664444444ffffffffffff88880000000000000000000000000
888888888828888888882888888888882228888888288677666600666666666000066666666766666444444ffffffffffff88880000000000000000000000000
8888888888288888888828888888888888288888888867766660066666660000666666666776666bbb44444ffffffffffff88888000000000000000000000000
8888888888288888888828888888877778288888886677666006666660006666666666777666bbbbbbb4444ffffffffffff88888000000000000000000990000
8888888888288888888877888888776678288886666676600066666666666666677777666bbbbb4bbbbbbbbffffffffffff88888800000000000000000990000
8888888888288888888876778877766678288866666666006666666666667777776666bbbbbbbbbbbb9bbbfffffffffffff88888800000000000000000000000
8888888888288888888876666666666778866666666666666666666777777666666bbbbbbbbbbbbbbbbbbfffffffffffffff8888880000000000000000000000
8888888888288888888227666666666788666666660666666667777666666666bbbbbbbbbb333bbbbbbbbffffffffffffffff888888800000000000000000000
8888888888288888888287766066066766666666006666777776666666666bbbbbb9bbbbb3333b9bbbbbffffffffffffffffff888888ff000000000000990000
88888888828888888882887766606666666666006667776666666682bbb333bbbbbbb4bbb3b3bbbbbbfffffffffffffffffffff88ffff0000000000000990000
88888888828888888882888766006666660000066666666688288882bbbbb33bbbbbbbbbbbbbbbbbbffff888ffffffffffffffffff0000000000000000000000
88888888828882222222888866060666600666666668888888288882bbbb9bbbbbbbb9bbbbbbbbbfffff8888588ffffffffffffff80000000000000000000000
88888888822222288882888860666066666666888882888882288882bbbbbbbddbbbbbbbb9bbbbffffff8885888858ffffffffff888000000000000000000000
888888888288888888828886666666666666666888822222222888822b9bbbdaadbbbbbbbbbbbffffffff85888858888fffffff0888500000000000000990000
888888888288888888828766666677666666666668828888882888882bbbbdaa00dbbbbbbbbbfffffffff85888588888588ff000055880000000000000990000
888888888288888888827766687678866776006666688888882222222bbbdaaa0aadbbbbbbbffffffffffff58858888588885885888880000000000000000000
888888888288888888777666887678886677600066668888882888882bbda0a0aaaadbbbbbfffffffffffffffb85888588858888588800000000000000000000
888888888288888887766667887678888667776000666688882888882bbda00a00aadbbbbbffffffffffffffbbfffff858885888800000000000000000000000
888888222288888888877778887678888886677760066666882888882bbbdaaaa0ddbbb4bbfffffffffffffbbffffffffff50000000000000000000000990000
88882228828888888888288888876788882866677766666666888882bbbbbddaaadbbbbbbbbffffffffffbbbbfffffffffb50000000000000000000000990000
22228888828555558888288888876788882222666776666666668882bbbbbbddddbb9bbbbbbbfffffffbbbbfffffffffffb50000000000000000000000000000
88888885555555aa5555558888887778882288886666600666666882b4bbbbbbbbbb333bbbbbbbfff4bbbbfffffffffffbb50000000000000000000000000000
88888855555aaaaaaaaaa55888888878822888888866660006676682bbbbbbbbbbbb3933bbbbbbbbbbbbfffffffffffffbb50000000000000000000000990000
88888855aaaaa00aaaaaaa5588888888828888888882866660067762bbbbbbbbb4bb3333bbbbbbbbbbbffffffffffffbbb450000000000000000000000990000
8888855aaa00000aaaaaaaa5588888888288888888828888866666666bbbbbbbbbbbbbbbbbb33bbbbbbfffffffffffbbbbb50000099999900000000000000000
8888555aa000000aaaaaaaaa58888888828888888822888222866660066bbbbbbbbbbbbbb4433333bbbbfffffffffbbbbbb50000099999900000000000000000
888555aa0000000aaaaaaa0a5588882222888888882282228288866660666bbbbbbbbbbbbbbbbbbbbbbbbffffffbbbbbbbb50000009999000000000000990000
88855aaa0000000aaaaaa00aa5222228828888888822288882888882666666bbbbbbbbbbbbbbbbbbbbbbbbffffbb9bbb4bb50000000990000000000000990000
88555aaaa000000aaaaa0000a5888888828888888828888882882222bbb6666bbbbbb22222222bbbbbbb9bbbbbbbbbbbbbb50000000000000000000000000000
88555aaaaa00000aaaa00000a5888888828888882228888882222882bbbb6666bbbb22882882222222bbbbb4bbbbb3bbb9b50000000000000000000000000000
88555aaaaaa000aaa0000000a5888888828882228828888882888882bbb4bb666bbb72882882882882bbbbbbbbbb333bbbb50000000000000000000000990000
88555aaaaaaa0aa0aa000000a5888888822228888828888882888882bbbbbbbbb662662222222222222bbbbbbbbbb333bbb50000000000000000000000990000
82555aaaaaaaaa000a000000a5888888828888888828888222888882bbbbbbbbb286606882882882882bbbb44bbbbb3bbbb50000000000000000000000000000
22555aaaaaaaaaa0aa000000a5888888828888888822222282888882bbbbbbbbb282767882882882882bbbbb444bbbbb9bb50000000000000000000000000000
88555aaaaaaaa0aaa0000000a5888888828888888822888882888222bbbb933bb222222222222222222bbbbbbbb9bbbbbbb50000000000000000000000000000
88555aaaaaa0000aaaa00000a5888882228888888828888882222882bbbb333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb50000000000000000000000000000
88855aaaaa00000aaaaa0000a5222222828888888828888882888882bb9bbbbbbbbbbbbbbbbbbbbb9bbbbbbbbbbbbbbbbbb50000000000000000000008800000
88855aaaa000000aaaaaa00aa5888888828888222228888882888882bbbbbbbbbbbbbbbbb4bbbbbbbbbbbbbbbbbbbbbbbbb50000000000000000000008800000
888555aa0000000aaaaaaa0a55888888822222288828888882888882bbbbbbbbb44bbbbbbbbbbbbbbbbbbbbb22222222222500000000000000000009977ff000
888855aa0000000aaaaaaaaa588888888288888888288888828822222bbbbbbbbbbbbbb222222b222222222288888888828500000000000000000009977ff000
8888555aa000000aaaaaaaa558888888828888888828888222222222222222222b222222888888b28888888228888888882500000000000000000aa777777ee0
88888555aa00000aaaaaaa558888888882888888822222222222222288882888b888288888888b628888888828888888882500000000000000000aa777777ee0
888888555aaa000aaaaaa5588888888882222222222222222222888888822888bb88288888888bbb888888882888888888850000000000000000000bb77dd000
88888855555aaa0aaaaa55888888882222222222222222222228888888228dddb4dd888888ddb4b3ddd888882288888888850000000000000000000bb77dd000
8888822255555aaaaaa5528882222222222222222222222288888888822dd53bbbbdd8822dd5bbb355dd2222222222222225000000000000000000000cc00000
8882228882555555555582222222222222222222222888222222222222dd553b9bb5dd22dd55bb43555dd888888882288885000000000000000000000cc00000
2228888882888855588822222222222222222222288888888888228888d55533bb355d88d5555b335555d8888888882288850000000000000000000000000000
2888888882888888822222222222222222222228888888888822888888d55553b4555d88d5555b355555d8888888888288850000000000000000000000000000
8888888882888888222222222222222222228888888888888828888888dd55533b555d88dd555335555dd2888888888228850000777777000000000077777700
8888888882888822222222222222222222222888888888888228888888dddd53335ddd22dddd5335ddddd2222222222222250007777777000000000077777700
88888888828822222222222222222228888882222222222222222222222dddddddddd2822ddddddddddd28888828888888850077700777000000000070007700
888888888282222222222222222228888888888888288888888888288882ddddddddd28225dddddddd5528888822888888850077700777000000000770007700
8888888882222222222222222228888888888888828888888888822888825ddddddd52882555dddd555528888882288888850077777777007777007777777700
88888888222222222222222288888888888888882288888888888288888255555555528822555555552288888888288888850077777777007777007777777700
88888822222222222228888888888888888888822888888888888288888825555555288822555555522288888222222222250077700000000000007770007700
88888222222222288222222222222222222222222222222222222222222222222222222222222222222222222288888888850077700000000000007770007700
88822222222228888888888888882288888888888888228888888888882888888888888828888888888888288888888888850077700000000000007777777700
82222222228888888888888888822888888888888888288888888888882888888888888828888888888888228888888888850077700000000000007777777700
82222222288888888888888888828888888888888888288888888888822888888888888882888888888888828888888888850000000000000000000000000000
22222888888888888888888888228888888888888882288888888888828888888888888882888888888888828888888888850000000000000000000000000000
22222888888888888888888888288888888888888882888888888888828888888888888882288888888888822888888888850000000000000000000000000000

__gff__
0000000000002000009090000000000000000082a0a000202020000000000000081838286848c8889800000000000000f11939296949c989990000000000000001100101414141430310100010101010010101014110414505010000101010100100010141414040400000001010101001010101404040404040001010101010
0101010101010101000000000000000001010101010101010000000000000000010101010101010100000000000000000101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
6d6d6d6d6d6d5151515d5d515151515d7b5d6d6d6d6d6d6d6d6d5d515151515d515151515151515d495d515151515151515151515151515151515151515151515d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d5d515151515151515151515151515151515151515151515151515151515151515151
4a00000000000000006c6e000000005c5d6e00000000000000006f000000005c520000000000006c6d6e000000000050520063000000000000000000000000505266676800666768000000000000000000000000000000000000000000005c7b5200000000000000000000000000005052666800630000666768000900666850
4100000000000000000000000000005c5e0000000000000000000000000000505200000000000000250000000000005052306300000000003300000000003050527677783076777800000000330000000000000000000000003000000000497b5200000000000000000000000000005052747900630000767778000000767850
4100000000000000000000001400005c5e00000000060000004c4d4e000014505200140000000000000000000600005052006314004c7d7e0000007c4d7d7d5d52747579007475790000000000004c4d4d4d4d4d4d7d7d7d7d7e0000007c6d5d52001300006667676767680000000050520000007306007475797c7d7e747950
4100004c71420000007c7d5445564d5d5e000000404200007c6d516d7e444551517171424e0000000000000040420050517151457d6e0000000000006f0000505d7d7d7d7d7d7d7e00000000004c5d5151626d6d6e000000666768006667685c517171727e767777777778000015005052000000007072000000000000000050
4109006c5d6e00000000006051626d5d5e0009005c5e0000000073000000005c526d6d6d6d4e000000004c7d6d6e005c523000000000330000000000000030505e0000000000300000000000005c51620037000000000000767778307677785c52000000007475757575797c7071715152150000000000000000000000000050
410000005f000000000000000000005c5e0000005c5e0000000000000000005052000000005c4e0000005f250027005c5200000000007c7d7d4d7d7d7d7d7d5d520000002000000000004c4d4d5d52001400404d4d4d4e00747579007475795c5200000000000000000000000000005051460000000000000000666768000050
5d5600495f000006000000000000005c5e0000005c5e0000000000000000135052000000255c5e2100215f000000005c5200000000000000006f00000000005052000000007c7d7d7d7d6d6d5d6d51717171517b7b7b5d7d7d7d7d7d7d7d7d6d52000000000000000000000000000050515e666768006667684f767778000050
5d6d7d5d5d7d44564e0000000000005c5e0000005c6e0000000000000070715152001300005c5e0000005f000000215c523000003300000000000000000030505200000030666767676768336330000000006c5d495d6e000000000000000055520000004c5300000000534e00000050515e7475794f7677785f747579000050
5200005c6e00005c6d7142000000005c51564d7d6e00000000004c7d4d4d7d4d51717142006c5e0009005f000000005c5d7d4d7d7d7d7d7d7e00000000000050520006003074757575757933733000000000006c6d6e00000009000000000041520000006c6071717171626e00000050516d7d7d7d5e7475795c7d7d7e000050
5200006f0000006f00006f000000005c516d5e0000000000004c5e006c6e005c5e256c5e00006c4e004c6e2300214c5d52006f00000000000000000000000050517171717200004c7d4e000000000000000000000000000000000000000000415266676768000000000000666767685052000000006c7d4d7d6e000000000050
5200000000000000000000000000005c52005f0000000000006c5e000000005c5e00006f0000006c7d6e00007c7d6d5d52303300000000000000000000003050515200000000005f00630000000000000000000000000000004f00000000004152767777780000000000007677777850520000000000006f0000000000000650
5200000000000000000000000000005c52006f000000000000005f5540424a5c5e000000000000002300000000000050520000000000004c7d7d4d4d7d4d7d5d515200000000005071520006004c7e6667680000000000007c6d7e66676800415276777778000900000000767777785052130000000000000000000000407151
5113004f0000004f0000004c40424d7b520000545600004042005f415052415c5e007f0028000000000000007c7e005c520000000000005f49006f5f006f0050515200001300005051517171725f3076777837000000000000000076777830415276777778000000060000767777785051426667684f6667684f6667685c4951
5171715d4d40715d4d54455d51517b5d520000505200005052005f415052415c5e230000000000004c494f210000275c520013000000005f4949006f49000050515200407142005051520000005f3074757937000000000000000074757930415274757579000000404200747575795051527475795f7475795f7475795c4951
5151517b5d51515d7b51517b51515d7b514d4d51514d4d51514d5d5d51515d7b5d4d4d4d4d4d4d4d5d5d5d4d4d4d4d5d51717171717171717171717171717151515171515151715151514d4d4d5d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d5d514c4d4d4e4071715151424c4d4d4e5151514d4d4d5d4d4d4d5d4d4d4d5d7b51
5d5d51516d6d6d6d6d6d6d5151515151515151515151515151515151515151515151515151515151515151515d51515151515151626d6d6d6d6d6d6d60515151515151515151515151515151515151515151515151515151515151515151515152515151515151515151515151516d6d6d6d6d6d6d6d6d5d6d6d515151515151
5d6e666767676800000000000000505152000000000000630000000000000050515d5e0000000000000000006f000000605152000000000000000000000000505151626b6b6051515151624b6b605151520000000000000000000000000000505200000000005f000000000000000000000000000000005f0000000000000050
5266777777777800000900000000505152000000000000630000000000000050515d6e00000000000000000000000000006052000900000000000000000000505200006b6b0000000000006b6b006051520000000000000000000000002500505200004f49005f00000000000000000000004c474747005f0000000000150050
5276777777777800000000060000505152001300000000630000000000140050515e000000000000000000000000000000006300000000000000000000000050520000000000000000000000000000505200150000000000000000000000006052004f5f49495f0000000000004c4848487d6e00005f005f0000000048715851
52747575757579004c4d4d4071715151517171724e6668636668407171717151515e0000004f0000000000004f00000000006300002000004f00000000004c515200000000000000000000001300005051717142300000000000370000004330527d6d6d6d6d6e00004848487d6e000000000000005f005f0000000000000050
520000004c4d4e005c7b495d6d6d5d5d520000006f76785f7678730000006c5d515e0000005f0000000000005f00001300005046000000005c4d7e00007c6d51520000530000005300000040717171515d6d6d6d4d4e000000000000300030405200000000000000000000000000000000000000005f005f0000000000000050
520000006c6d6e006c6d6d6e66686c5d520000000076785f767800000000005c516e00004c5e00004457574d5d5745454547514d7e007c7d6d5e000000000050520000630000005071717151515151515e0030006c5e0000300000000000005052000000000000000000000000000000004c4800585e096c585857000000005c
52666767680000666800006677776850620000007f74795f7479585800000050520000005c5e00005c6d6d5d6d6e00006c6d6d6e00000000005f0000000000505200006071717162000000000000605152000000006f00000000000000000050520013004c4d4e0000000000004c4848486e6300505e00005f0000000000005c
527677777800007678000076777778505e000000007c7d6d4d7e000000000050520000005c6d7d7d6e00006f000000000000000000000000005c7d7e00007c5152000000000000000000000000000050520000000000000000004c4e350035505171717151515e004c4d4747476e000000007300505e00005f0000000000005c
52747575794c4e7479000074757579505e00000000000000630000000066685c5200007c6e00000000000000000000000000000000000000005f0000000000505200000000000000000000000600005052000000000000000000505e00007f555200000000605e005c5e00006f00000000000000505e00005f0000004748485d
5d7d7d7d7d6d6d7e007c7e00000000505147474747470000630000484874795c5200000000000000000000000000000000004f0000060000005c7d7d7e00005052000000407171714200407171717151520000000000000000005052000000416200000000006f005c6e000000004c4e00000000506e00005f00000000000050
52000000000000000000006667676850520000000000000063000000007c7d7b5200000000000000000000000000000000005f0047455700005f00000000005052000000506200007300730000000050520000000000000000005062000000414a000000000000065f00005858585d5d58585858620000006f00000000000050
5200000000000000000000767777785052000000000066685f6668000000005052000006000000000000004f0047474747005f005f000000005f004f00150050520000006300000000200000000055505200000000007c4e0000504a0000004141000000474747716e0000006c6d6d6d6d6d6d6e00000000005858570000005c
520013000000004f666800747777795052666800004f76785f76780000000050514747464a0047474747005f00005f5f00005f005f004f00005f495c4745577b51717171520000000000000000004150520035000000005f350050417f000041410000006c6d6d6e00000000000000000000000000000000000000000000005c
517171420015005374794c4e74794c5d52767800006f74795f74794f00000050524e00004100005f5f00005c49005f5f4c4d5e005f4c5e494c5d7b5d7b7b5d7b51515151620000000000000000004150520030000000005f304c5e4100000041410000000000000000000000000000000058585858584206000000000000005c
51515151717171524d4d5d5d4d4d5d7b5274794f00004c4d6d7d7d5e0000005c515d4d4d5d4d4d5d5d4d4d5d5d4d5d5d5d7b5d4d5d5d5d5d5d7b5d7b5d5d7b5d62000000000000000000000000004150520000000600005c4d5d5e41000000415d585858584d4d585858584d4d58585858515151515151714848484848484851
__sfx__
050400003374328723107150070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703
01020000036600c660275501b05017050150500f7500c750006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
01020000065100651007510095100b5200d020100201302014020187201f73027740157001b7002070022700007000c7000d7000f700147001a7001e70020700007000c70010700157001a7001e7000070000700
000200000c5100d5100f510115101352016020190201c0201f02024720287302e740157001b700207002270000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000105101251015510185101b5201e0202102024020290202d7203173036740157001b700207002270000000000000000000000000000000000000000000000000000000000000000000000000000000000
150200000a7510a0510c051100511305119751097510e051136511a0510665109055056550b755267013370100001000010000100001000010000100001000010000100001000010000100001000010000100001
000500000f7211172114721177211b7211e721247312a7413475234762347723477234772347623475234742347323472234712347103471034700347001100000000160001e700237002a700000000000000000
0008000011115171151b1351f145231451e12519125211451d155171251e135251552110500005001050010500105001050010500105001050010500105001050010500105001050010500105001050010500105
000200000f0500f0500e0500a05007050050500105000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00030000146501563014620186201f620206101461014610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011700000c7530000002753000000275300000000000c753137530c0000e7530c0000e7530000000000000000c7530000002753000000275300000000000c753137530c0000e7530c7000e753000000000000000
001400000000000000000000000000000000000000000000007170000000000000000072700000000000000000737000000000000000007470000000000000000075700000000000000000767000000000000000
011700001c55200500005001c552005001d5541d5541d5541c552005021c55200500005001d5541c5541a55418552155520050015552005021555200500155541f552005021f552005021c5521c5520070000700
01170000105520c5000c500105520c500115541155411554105520c502105520c5000c50011554105540e5540c55209552005000955200502095520050009554135520c502135520c50210552105520070000700
9004000008610096100a6100a6100b6200c6200d620106301363015630186301c64022640276501a6001a6000760013600156101562017620196301a6301c6301d6301f64022640256502a6502e6603166035670
90060000246602466023650206401e6401a640166300f63006620026000e600206501d6401b6301863015630116200c620086100461000000000001564015630146301363011620106200e6100c6100961003610
90040000000000000000000000001c6201d6201e6201f63021630246302a6402f640356403a6600000000000000000000024640286402c6502f650326603466036670396703b6703c6703d670000000000000000
c3070000396503d6603e670146400e620086100461001600006001060008600056000060000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
01140000187521c7521f7522675224752247522455224552007001c7521f7522675228552285520000000000187521c7521f75226752247522475224552245520000026752247521d75224752247520000000000
03140000187570071700000000000075700717000000000024757007170000000000007570071700000000000c757007170000000000007570071700000000003075700717000000000000757007170000000000
011a000000000000000000000000000000000000000000000e753000000000000000000000000000000000000e753000000000000000000000000000000000000e75300000000000000000000000000000000000
011a00000e753000000e753000001a75300000000000e7530e7530000000000000001a7530000000000137530e753000000e753000001a75300000000000e7530e75300000000000e7531a7530e7530000000000
011a00000e7530c5530e753000001a753000000c5530e7530e753000000c7530c5531a7530000000000137530e7530c5530e753000001a753000000c5530e7530e75300000000000e7531a7530e7530000000000
011a00000e7530000000000000001a75300000000000e7530e7530000000000000001a7530000000000137530e7530000000000000001a75300000000000e7530e7530000000000000001a7530e7530000000000
911a00000e3550e3550000000000000000000000000000000e355113550e35500000000000000000000000000e3550c355093550735500000073550e35500000000000e355103550000000000103551135510355
911a00000000000000000000e3550c3550000000000000000e355113550e3550000000000000000e3550c355000000c355073550000000000073550e35500000000000e355103550000000000103551135510355
911a00000435507355093550e35500000000000e3550e355103550e35500000000000000000000000000000005355043550235500355000000000000000003550035502355000000000000000000000000000000
911a0000263552b3552835526355000000000000000000001a3551d3551c3551a355000000000000000000000e35511355103550e355000000d3550e355000000e35500000000000000000000000000000000000
000300001c7131c7131c7231c7231c7331c7331c7431c7531f7632277323700000001670216702000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
371a00000215500100001000215500100001000215500100021550010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
031700001c756005000050000000000000000000000000001c7560050200000000000000000000000000000018756157560050000000000000000000000000001f756005061f756005061c7561c7560070000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
911200000b0140d0111101113011140111401114011140111401500000000000000000000000000c0010c00112014110110f0110e0110c0110901106011040110201101011000110001100011000150000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001f755180031c7551f75524750247550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000003055224520245150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000001d3521d3551c3521c3551a3521a3551c3551d3521d3550f3051330512f0011f0010f0010f0029a000ff000ef000ef000ef000ef000ef000ef000df000df000df000df000000000000000000000000000
b10200002574026330203210e32108011045110101100011000150860005600006000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
b1020000197401a330143210e32108011045110101100011000150860005600006000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
00 0e4b4344
00 104b4344
00 114b4344
00 0b534344
03 12135544
00 41424344
00 41424344
00 14424344
00 155d4344
01 15184344
00 161d4344
00 151a4344
00 161d4344
00 17194344
00 151d4344
00 151b4344
02 151d4344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 0a0c4d44
00 0a0c0d44
00 0a0d4344
02 0a0d1e44
00 4a424344

