pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- golf escape

function _init()
 --constants
 pixel=0.125
 
 gravity=0.009
 
 treadmillspeed=0.025
 
 --velocity multiplier
 -- when in slow zones
 slowfrac=0.1
 
 --how far active hooks
 -- move each frame
 hookspeed=0.05
 
 --velocity multiplier
 -- when hitting the ground
 xbouncefrac=0.4
 ybouncefrac=-0.6
 
 --frames for wall hit squish
 -- state
 squishpause=4
 
 --vars

 --checkpoint
 xcp=0
 ycp=0
 cpanim=makeanimt(23,10,3)
 
 --hack for top corner collision
 topcoloverwrite=false

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
 
 currentupdate=updateplaying
 currentdraw=drawplaying
 
 aim={
  points={}
 }
 
 --check map and convert
 -- to game objects
 bumpers={}
 for x=0,127 do
  for y=0,63 do
   --defo overkill
   if checkflag(x,y,0) and
      checkflag(x,y,4) and
      checkflag(x,y,5) and
      checkflag(x,y,6) and
      checkflag(x,y,7) then
    createbumper(x,y)
    mset(x,y,0)
   end
  end
 end
 
 hooks={}
 for x=0,127 do
  for y=0,63 do
   if checkflag(x,y,3) then
    createhook(x,y)
    mset(x,y,0)
   end
  end
 end

 initlevels()
 
 --stats for end screen
 deathcount,swingcount=0,0
 frames,seconds,minutes,hours=0,0,0,0
end

function _update60()
 currentupdate()
end

function updateplaying()
 updateplaytime()
 
 updatebackgrounds()
 updatecamera()

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
  
  --release swing
  if btnp(🅾️) then
   sfx(1)
   
   swingcount+=1
  
   cam.free=false
  
   applyswing(av)

   resetswing()
    
   if av.slowstate=="in" then
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
 
 updateaim()

 --collision
 
 --ground col
 if groundcol(av,0,av.yvel,0) then
  moveavtoground()
  
  --if vel low enough, land
  if groundcol(av,0,av.yvel,6) or
     abs(av.yvel)<0.075 then

   if av.colstate!="ground" then
    local cols=avcolours

    if groundcol(av,0,av.yvel,6) then
     cols=sandcolours
    end

    collisionimpact(av.x+(av.w/2),av.y+av.h,
     1,-0.25,false,cols)

    sfx(8)
   end
   
   av.colstate="ground"  
   
	  av.xvel=0
	  av.yvel=0
	  
	  av.canswing=true
	
	  --tredmills
	  if groundcol(av,0,av.yvel,1) then
	   av.xvel+=treadmillspeed
	  end

	  if groundcol(av,0,av.yvel,2) then
	   av.xvel-=treadmillspeed
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
 
 --other sides col
 if not groundcol(av,0,av.yvel,0) then
	 if topcol(av,0,av.yvel,0) then
	  moveavtoroof()
	  av.yvel*=-1
	  
	  av.pauseanim="tsquish"

	  collisionimpact(av.x+(av.w/2),av.y,
	   1,0.25,false,avcolours)
	 elseif leftcol(av,av.xvel,av.yvel,0) then
	  av.pauseanim="lsquish"

	  collisionimpact(av.x,av.y+(av.h/2),
	   0.25,1,true,avcolours)

	  moveavtoleft()
   sidebounce()
	 elseif rightcol(av,av.xvel,av.yvel,0) then
	  av.pauseanim="rsquish"
	  
	  collisionimpact(av.x+av.w,av.y+(av.h/2),
	   -0.75,1,true,avcolours)

	  moveavtoright()
   sidebounce()
	 end
	else --on ground
	 if allleftcol(av,av.xvel,0,0) then
	  --todo:move av to wall?
	  av.xvel=0
	 end
 
	 if allrightcol(av,av.xvel,0,0) then
	  --todo:move av to wall?
	  av.xvel=0
	 end
 end

 --game obj update
 -- update hooks
 for h in all(hooks) do
  if h.avon then
	 if anycol(av,h.xvel,h.yvel,0) then
	  hookreleaseav(av.hook)
	  resetswing()
	 elseif not h.mover then
	  h.x+=h.xvel
	  h.y+=h.yvel
	 end
	end
	
 if h.mover then
	 h.x+=h.xvel
	 h.y+=h.yvel
 end

 for b in all(bumpers) do
  --'bounce' the other way
  if circlecollision(b,h) then
   h.xvel*=-1
   h.yvel*=-1
   
   if not h.mover then
    if h.s<37 then
     h.s+=4
    else
     h.s-=4
    end
   end

   if h.mover then
    if h.s<53 then
     h.s+=4
    else
     h.s-=4
    end
   end
  end
 end

 if circlecollision(av,h) and
   h.active then
	 av.x=h.x+h.r
	 av.y=h.y+h.r+pixel
	  
	 av.xvel=0
	 av.yvel=0
	  
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
 
 --spikes
 if anycol(av.hurtbox,0,0,4) then
  sfx(5)
  deathcount+=1
  resetav()
 end
 
 --checkpoint
 if anycol(av.hurtbox,0,0,5) then

  --if new cp hit
  if xcp!=xhitblock or
     ycp!=yhitblock then
     
   --clear old cp
   -- if not spawn
   if not isspawn(xcp,ycp) then
    mset(xcp,ycp,6)
   end
   
	  --set new cp
	  sfx(7)
	  xcp,ycp=xhitblock,yhitblock
	  mset(xcp,ycp,23)
  end
 end
 
 --float zone
 if allcol(av,av.xvel,av.yvel,6) and
    av.slowstate=="none" then

  av.canswing=true

  av.slowstate="in"
 
 elseif not allcol(av,0,0,6) and
        av.slowstate!="none" then

  --reset on leaving a slowzone
  av.slowstate="none"
 end
 
 --level markers
 if circlecollision(av,currlvl.exit) and
    (not currlvl.haskey or
     currlvl.key.collected) and
    av.colstate=="ground" then
  nextlevel()
 end

 if currlvl.haskey and
    circlecollision(av,currlvl.key) then
  --collect key
  sfx(6)
  currlvl.exit.s=20
  currlvl.key.collected=true
 end
 
 if currlvl.haskey and
    currlvl.key.collected then
    --get out of the way
    currlvl.key.x=-1
    currlvl.key.y=-1

  --todo: have mechanic where
  -- hitting a checkpoint 'saves' the key?
 end

 updateav()

 updateanims()
 
 updateparticleeffects() --tab 6
end

function _draw()
 currentdraw()

 print(debug,cam.xfree*128,cam.yfree*128,1)
end

function drawplaying()
 cls(bg.colour)
 
 drawbackgrounds()

 --draw all of current level
 map(currlvl.xmap*16,currlvl.ymap*16,currlvl.xmap*128,currlvl.ymap*128,currlvl.w*16,currlvl.h*16)
 
 --lvl objs draw
 drawobj(currlvl.exit)
 --drawcirc(currlvl.exit)
 
 if currlvl.haskey then
  if currlvl.key.collected then
   --draw 'key' under player if they have one
   
   --little bounce when on player
   local up=0

   if flr(currlvl.key.anim.sprite)==currlvl.key.anim.basesprite then
    up=1
   end

   spr(22,
     (av.x*8)-(2),
     (av.y*8)-(2)-up,1,1,av.xflip,av.yflip)
  else
   spr(currlvl.key.anim.sprite,
     (currlvl.key.x*8),
     (currlvl.key.y*8))
  end
 end
 
 --game objects
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

 if av.canswing then
  --draw aim
  
  linecol=13
  
  if swing.currdecaypause>0 then
   linecol=6
  end
  
  --todo:consider look. lines?
  for point in all(aim.points) do
   pset(
    (av.w/2+point.x)*8,
    (av.h/2+point.y)*8,linecol)
  end

  --where player should land for debugging 
  -- rect(aim.x*8,aim.y*8,
  --  (aim.x+aim.w)*8,
  --  (aim.y+aim.h)*8,2)
 end
 
 --tab 6
 drawparticles(false)
 
 --av draw
 -- -2 for sprite offset
 spr(av.anim.sprite,
  (av.x*8)-(2),
  (av.y*8)-(2),1,1,av.xflip,av.yflip)

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
   mod=2*pixel
  end
  if currlvl.w>1 then
   --todo:rotate accordingly
   drawobj({s=16,x=(cam.xfree*16)+14+mod,y=(cam.yfree*16)+7})
   drawobj({s=16,x=(cam.xfree*16)+1-mod,y=(cam.yfree*16)+7},true)
  elseif currlvl.h>1 then
   drawobj({s=17,x=(cam.xfree*16)+7,y=(cam.yfree*16)+14+mod})
   drawobj({s=17,x=(cam.xfree*16)+7,y=(cam.yfree*16)+1-mod},false,true)
  end
 end
end

function drawobj(obj,xflip,yflip)
 spr(obj.s,obj.x*8,obj.y*8,1,1,xflip,yflip)
end

function drawcirc(obj)
 circ((obj.x+obj.r)*8,(obj.y+obj.r)*8,obj.r*8)
end
-->8
--collision

--allcollision
function anycol(box,xvel,yvel,flag)
 return checkanyflagarea(box.x+xvel,box.y+yvel,box.w,box.h,flag)
end

function allcol(box,xvel,yvel,flag)
 return checkallflagarea(box.x+xvel,box.y+yvel,box.w,box.h,flag)
end

function groundcol(box,xvel,yvel,flag)
 local x=box.x+xvel
 local y=box.y+yvel
 local w=box.w
 local h=box.h

 return
  checkflag(x,y+h,flag) or
  checkflag(x+w,y+h,flag)
end

function allgroundcol(box,xvel,yvel,flag)
 local x=box.x+xvel
 local y=box.y+yvel
 local w=box.w
 local h=box.h

 return
  checkflag(x,y+h,flag) and
  checkflag(x+w,y+h,flag)
end

function leftcol(box,xvel,yvel,flag)
 local x=box.x+xvel
 local y=box.y+yvel
 local h=box.h

 return
  checkflag(x,y,flag) or
  checkflag(x,y+h,flag)
end

function allleftcol(box,xvel,yvel,flag)
 local x=box.x+xvel
 local y=box.y+yvel
 local h=box.h

 return
  checkflag(x,y,flag) and
  checkflag(x,y+h,flag)
end

function rightcol(box,xvel,yvel,flag)
 local x=box.x+xvel
 local y=box.y+yvel
 local w=box.w
 local h=box.h

 return
  checkflag(x+w,y,flag) or
  checkflag(x+w,y+h,flag)
end

function allrightcol(box,xvel,yvel,flag)
 local x=box.x+xvel
 local y=box.y+yvel
 local w=box.w
 local h=box.h

 return
  checkflag(x+w,y,flag) and
  checkflag(x+w,y+h,flag)
end

function topcol(box,xvel,yvel,flag)
 local x=box.x+xvel
 local y=box.y+yvel
 local w=box.w

 return
  checkflag(x,y,flag) or
  checkflag(x+w,y,flag)
end

function alltopcol(box,xvel,yvel,flag)
 local x=box.x+xvel
 local y=box.y+yvel
 local w=box.w

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
 
 if av.x%pixel != 0 then
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

  if allgroundcol(av,distancetowall,av.yvel,0) then
   --corner collision occured
   -- abort wall collision
   -- with ground collision
   av.pauseanim="gsquish"
   av.xpause=squishpause
   av.ypause=squishpause
   
   moveavtoground()
  
   av.yvel=0
   av.xvel=0
   return distancetowall
  end
  
  if topcheck then
   if alltopcol(av,distancetowall,av.yvel,0) then
    --corner collision occured
    -- abort wall collision
    -- with top collision
    av.pauseanim="tsquish"
    av.xpause=squishpause
    av.ypause=squishpause
    
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

function checkanyflagarea(x,y,w,h,flag)
 return
  checkflag(x,y,flag) or
  checkflag(x+w,y,flag) or
  checkflag(x,y+h,flag) or
  checkflag(x+w,y+h,flag)
end

function checkallflagarea(x,y,w,h,flag)
 return
  checkflag(x,y,flag) and
  checkflag(x+w,y,flag) and
  checkflag(x,y+h,flag) and
  checkflag(x+w,y+h,flag)
end

function checkflag(x,y,flag)
 xhitblock,yhitblock=flr(x),flr(y)
 
 local s=mget(x,y)
 return fget(s,flag)
end

function checkflagclean(x,y,flag)
 local s=mget(x,y)
 return fget(s,flag)
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
  --mover hooks
  --{xmap=3,ymap=0,w=1,h=1},
  --mover hooks 2
  --{xmap=4,ymap=0,w=2,h=1},
  --{xmap=2,ymap=1,w=2,h=1},
  --slows tutorial
  --{xmap=6,ymap=0,w=1,h=1},
  --art test
  {xmap=6,ymap=1,w=2,h=1},
  --wide level bunkers
  --{xmap=2,ymap=1,w=2,h=1},
  --wide level long swings
  --{xmap=2,ymap=2,w=2,h=1},
  --extra wide level golf course
  --{xmap=5,ymap=3,w=3,h=1},
  --tall level camera test
  --{xmap=4,ymap=1,w=1,h=2},
  --tall level design tests
  --{xmap=5,ymap=1,w=1,h=2},
  --hook maze
  --{xmap=0,ymap=3,w=1,h=1},
  --art test
  --{xmap=0,ymap=0,w=3,h=1},
  --hooks and slows
  {xmap=0,ymap=2,w=1,h=1},
  --wide slows
  {xmap=0,ymap=1,w=2,h=1},
  --climb upwards slows
  {xmap=1,ymap=2,w=1,h=1},
  --moving hooks
  {xmap=1,ymap=3,w=1,h=1},
  --static swing power test
  {xmap=2,ymap=3,w=1,h=1},
  --convayer belts
  {xmap=3,ymap=3,w=1,h=1},
  --important plob level
  {xmap=4,ymap=3,w=1,h=1},
  --out of way key
  {xmap=6,ymap=2,w=1,h=1},
  --test level
  {xmap=6,ymap=3,w=1,h=1},
 }
 
 --change to set starting lvl
 lvls.currlvlno=0
 
 nextlevel()
end

function resetav()
 if av!=nil and
    av.colstate=="hook" then
  hookreleaseav(av.hook)
 end

 av={
  --consts
  w=pixel*3,
  
  h=pixel*4,
  
  r=pixel*2,
  
  --vars
  x=xcp+pixel*2,
  y=ycp+pixel*2,
  
  xvel=0,
  yvel=0,
  
  colstate="air",
  
  slowstate="none",

  canswing=false,
  
  xflip=false,
  yflip=false,
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
 local xoff=pixel*1
 local yoff=pixel*1
 
 obj.hurtbox={
  x=obj.x+xoff,
  y=obj.y+yoff,
  w=pixel*1,
  h=pixel*1,
 }
end

function resetswing()
 swing={
  --consts
  lowf=0.2,
  highf=0.45,
  btnf=0.04,
  lowrotangle=1/1200,
  highrotangle=1/300,
  rotanglevel=1/3600,
  basedecay=0.0002,
  decayvel=0.00005,
  decaypause=7,

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
  xcenoff=pixel*4,
  ycenoff=pixel*6,
  r=pixel*2,
  s=57,
 }

 add(bumpers,b)
end

function createhook(x,y)
 h={
  --consts
  spawnx=x,
  spawny=y,
  xcenoff=pixel*4,
  ycenoff=pixel*6,
  r=pixel*2,
  s=32,
  
  spawns,
  spawnxvel,
  spawnyvel,

  --vars
  x=x,
  y=y,
  active=true,
  mover=false,
  avon=false,
  xvel=0,
  yvel=0,
 }
 
 if checkflag(x,y,4) and
    checkflag(x,y,5) then
  h.yvel=-hookspeed
  h.xvel=hookspeed
  h.s=34
 elseif checkflag(x,y,5) and
        checkflag(x,y,6) then
  h.yvel=hookspeed
  h.xvel=hookspeed
  h.s=36
 elseif checkflag(x,y,6) and
        checkflag(x,y,7) then
  h.yvel=hookspeed
  h.xvel=-hookspeed
  h.s=38
 elseif checkflag(x,y,7) and
        checkflag(x,y,4) then
  h.yvel=-hookspeed
  h.xvel=-hookspeed
  h.s=40
 elseif checkflag(x,y,4) then
  h.yvel=-hookspeed
  h.s=33
 elseif checkflag(x,y,5) then
  h.xvel=hookspeed
  h.s=35
 elseif checkflag(x,y,6) then
  h.yvel=hookspeed
  h.s=37
 elseif checkflag(x,y,7) then
  h.xvel=-hookspeed
  h.s=39
 end
 
 if checkflag(x,y,0) then
  h.mover=true
  h.s+=16
 end
 
 h.spawns=h.s
 h.spawnxvel=h.xvel
 h.spawnyvel=h.yvel

 add(hooks,h)
end

function makebackgrounds()
 
 --background colour
 bg={
  --consts
  s=108,
  colour=0,
  
  --vars
  x=0,
  y=0,
  xvel=0.05,
  yvel=0.05,
 }
end

function nextlevel()
 lvls.currlvlno+=1
 
 if lvls.currlvlno>#lvls then
  initending()
  return
 end
 
 currlvl=lvls[lvls.currlvlno]
 
 currlvl.haskey=false
 
 --scan area for level game objects
 for x=(16*currlvl.xmap),(16*currlvl.xmap)+(16*currlvl.w) do
  for y=(16*currlvl.ymap),(16*currlvl.ymap)+(16*currlvl.h) do

   if checkflag(x,y,1) and
      checkflag(x,y,7) then
    --found spawn
    xcp=x
    ycp=y
    
    resetav()
    
    --todo:make some sort of
    -- initial spawn point
    -- that won't overwrite
    -- with flag
   end
   
   if checkflag(x,y,4) and
      checkflag(x,y,7) then
    --found key
    currlvl.haskey=true
    
    local keyanim=makeanimt(9,40,2)

    currlvl.key={
     x=x,
     y=y,
     r=pixel*4,
     collected=false,
     anim=keyanim,
    }
    
    --could we avoid this
    -- so levels can repeat?
    mset(x,y,0)
   end

   if checkflag(x,y,5) and
      checkflag(x,y,7) then
    --found exit
    currlvl.exit={
     x=x,
     y=y,
     s=20,
     r=pixel*4,
    }

    mset(x,y,0)
   end
  end
 end
 
 if currlvl.haskey then
  currlvl.exit.s=21
 end
end
-->8
--update logic

function updateav()
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

 if btn(⬆️) and cam.canmove and av.canswing then
  cam.free=true
  
  if cam.freedirect=="none" then
		 cam.freedirect="up"
		end

  if currlvl.w>1 then
   --todo:have short accel
   cam.xfree-=cammovespeed
   
   if cam.xfree<cam.x and cam.freedirect=="down" then
    cam.free=false
    cam.canmove=false
				cam.freedirect="none"
   end
  elseif currlvl.h>1 then
   cam.yfree-=cammovespeed
   
   if cam.yfree<cam.y and cam.freedirect=="down" then
	   cam.free=false
	   cam.canmove=false
				cam.freedirect="none"
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
    cam.free=false
    cam.canmove=false
				cam.freedirect="none"
   end
  elseif currlvl.h>1 then
   cam.yfree+=cammovespeed
   
   if cam.yfree>cam.y and cam.freedirect=="up" then
	   cam.free=false
	   cam.canmove=false
				cam.freedirect="none"
	  end
  end
 end

 if not cam.canmove and not btn(⬆️) and not btn(⬇️) then
  cam.canmove=true
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

function movetopoint(from,to)
 local scrollfrac=0.25
 local maxscrollspeed=0.1

	local cameradiff=to-from
	
 if abs(cameradiff)<0.01 then
	 return to
	end

	cameradiff*=scrollfrac
	
	if cameradiff>maxscrollspeed then
		cameradiff=maxscrollspeed
	elseif cameradiff<-maxscrollspeed then
		cameradiff=-maxscrollspeed
	end
	
	return from+cameradiff
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
  points={},
 }

 if av.canswing then
	local wallhit=false

  applyswing(aim)

  --move a couple frames first
  -- so we're not drawing
  -- over our av.
  --todo:tidy
  updatemovement(aim)
  aim.yvel+=gravity
  
  updatemovement(aim)
  aim.yvel+=gravity
	  
	 while wallhit==false do
		 local point={
		  x=aim.x,
		  y=aim.y,
		 }
		 
		 add(aim.points,point)
	 
	  updatemovement(aim)
	  
	  aim.yvel+=gravity
	  
	  if anycol(aim,aim.xvel,aim.yvel,0)
	     or #aim.points>100 then
	   wallhit=true
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

function hookreleaseav(hook)
 hook.active=false
 
 if not hook.mover then
  --todo:smoothly return
  hook.x=hook.spawnx
  hook.y=hook.spawny

  hook.xvel=hook.spawnxvel
  hook.yvel=hook.spawnyvel
  hook.s=hook.spawns
 end

 hook.avon=false
 
 --remove reference
 av.hook=nil
end

function isspawn(x,y)
 return
  checkflagclean(xcp,ycp,1) and
  checkflagclean(xcp,ycp,7)
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
 t.basesprite=12
 t.sprites=2
 t.speed=20

 --flying through air
 if av.colstate!="ground" then
  t.basesprite=59
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
  t.basesprite=12
  t.sprites=1
 end

 local flipval=-1
 
 if av.xflip then
  flipval=1
 end
 
 local lx,ly=feetpos()
 
 --charge anim when adding force
 if swing.force>swing.lowf then
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
 
 if not isspawn(xcp,ycp) then
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

-->8
-- ending state

function initending()
 ycredits=-64
 
 currentupdate=updateending
 currentdraw=drawending
end

function updateending()
 if ycredits<32 then
  ycredits+=0.25
 end
end

function drawending()
 drawplaying()
 
 --credits
 
 local c1=2
 local c2=11
 
 s="golf!"
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+ycredits,c1,c2)
 
 s="by davbo and rory"
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+ycredits+8,c1,c2)
 
 s="deaths: "..deathcount
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+ycredits+16,c1,c2)

 s="swings: "..swingcount
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+ycredits+24,c1,c2)

 s="playtime: "..
 twodigit(hours)..":"..
 twodigit(minutes)..":"..
 twodigit(seconds).."."..
 twodigit(frames)
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+ycredits+32,c1,c2)

 s="thanks for playing!"
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+ycredits+40,c1,c2)
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

function outline(s,x,y,c1,c2)
 for i=0,2 do
  for j=0,2 do
   print(s,x+i,y+j,c1)
  end
 end
 print(s,x+1,y+1,c2)
end

-->8
--particle effects

effects={}
sparkcolours={6,7,8}
avcolours={15,15,4,6}
sandcolours={10,10,9,6}

function createeffect(update)
 e={
  update=update,
  front=false,
  particles={}
 }
 add(effects,e)
 return e
end

function createparticle(x,y,xvel,yvel,r,col)
 p={
  x=x,
  y=y,
  xvel=xvel,
  yvel=yvel,
  r=r,
  col=col
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

function initdustkick(x,y,dx,dy,rdx,rdy,no,minlength,cols,front)
 local e=createeffect(updatedustkick)
 e.front=front or false

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
   0+flr(rnd(2)),col)
  
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
    p.r=0
    p.timeout=5
   else
    del(e.particles,p)
   end
  end
 end
 
 if #e.particles==0 then
  del(effects,e)
 end
end

function collisionimpact(x,y,dx,dy,wall,cols)
 sfx(0)

 --todo:scale based on force

 av.xpause=squishpause
 av.ypause=squishpause
 
 --todo:scale based on force
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
__gfx__
0000000022222222aaa9aaa9aaa9aa9aa9a9aa9a686868680000000000600600c0c0c0c000033000000330000000000000000000004040000000000000000000
000000002bbbbbb219aaa2a129dad6a9a9aad9d28585858600702200066666600c0c0c0c00333300003333000000000000040000000ff0000000000000000000
000000002bbbbbb21111111127766c7667866772685858580071220066266266c0c0c0c0677337776773377700000000040ff00000f1f1000000000000000000
000000002bbbbbb2112211112cccccc7788888828585858600712200066556600c0c0c0c600700076007e0e70000000000f1f10004fffe000000000000000000
000000002bbbbbb2112211112cccccc228888882685858580071000006655660c0c0c0c07807e0e7708708070000000000fffe0000ffff000000000000000000
000000002bbbbbb21111111122222c26628222228585858600700000662662660c0c0c0c78070807780708070000000004fffff000f0f0000000000000000000
000000002bbbbbb21111111125ddd2d66d2ddd52685858580070000006666660c0c0c0c060878007608780070000000000000000000000000000000000000000
0000000022222222111111112222222dd22222228686868600700000006006000c0c0c0c66777766667777660000000000000000000000000000000000000000
0000000000066000aaa9aaa9006666000066660000666600e0e00000000000000000000000000000000000000000000000000000000000000000040400000000
000066000006600029aaa2a20611116006ccac60065665600800000000707700007007000070000000000000000040400000404000004040000007f700004040
00006660000660002bbbbbb2611111166ccacac66445644608000000007677000076770000767700000000000040fff00040fff00040fff00000717100000fff
66666666000660002bbbbbb2611111166cccaca6655665560800080000767700007677000076770000000000000f1f10000f1f10000f1f100040f7e70400f1f1
55556665066666602bbbbbb2611111166ccacac6644654460088800000760000007670000070670000000000040ffe000f0ffe00040ffe00040fff0000ffffe0
00006650056666502bbbbbb2611111166cccccc6655665560000000000700000007000000070000000000000f04ff000004ff000400ff000f04ff000400fff00
00005500005665002bbbbbb2611111166cccccc664456446000000000070000000700000007000000000000000000000040000000f0000000000000004ff0000
000000000005500022222222611111166cccccc66556655600000000007000000070000000700000000000000000000000000000000000000000000000000000
00033000000880000002880000022000000220000002200000022000000220000088200000000000000000000000000000000000000000000000000000000000
00333300002882000022880000228800002222000022220000222200008822000088220000000000000404000004040000040400000404000000000000000000
003333000022220000222200002288000022880000288200008822000088220000222200041f14f000f1f0000000fff00000fff00000fff00000000000000000
0003300000022000000220000002200000028800000880000088200000022000000220000ffeff0000ff1000004f1f10004f1f10004f1f100000000000000000
00500500005005000050050000500500005005000050050000500500005005000050050000fff00000fe0000040ffe008f0ffe00040ffe000000000000000000
050000500500005005000050050000500500005005000050050000500500005005000050000f040000ff0000f04ff000804ff000408ff0000000000000000000
50000005500000055000000550000005500000055000000550000005500000055000000500000000000ff00088000000040000000f8000000000000000000000
66666666666666666666666666666666666666666666666666666666666666666666666600000000004000000000000000000000000000000000000000000000
00000000000cc0000001cc00000110000001100000011000000110000001100000cc100000000000000000000000000000000000000000000000000000000000
00000000001cc1000011cc000011cc0000111100001111000011110000cc110000cc1100000ee000000000000404000000000000000f0f000004000000000000
0000000000111100001111000011cc000011cc00001cc10000cc110000cc11000011110000e72e000000000000fff00004f1e00000fff0000f0fff0000000000
000000000001100000011000000110000001cc00000cc00000cc100000011000000110000e7222e00000000000f1f10000ffff0000ffff0000fff14000000000
0000000000500500005005000050050000500500005005000050050000500500005005000e2222e00000000004ffef00041fff00001fef0000ffff0000000000
00000000050000500500005005000050050000500500005005000050050000500500005000e22e000000000000fff00000fff0f004ff1000000e1f4000000000
000000005000000550000005500000055000000550000005500000055000000550000005000ee000000000000f0f000000004000000440000000000000000000
00000000666666666666666666666666666666666666666666666666666666666666666600000000000000000000000000000000000000000000000000000000
0aa9a99aaaa99a9aa99aa9a00aaaa9a0aaaaaaaaaaaaaaaaaaaaaaaaaaa9aa9ad66666660000000000000000000000000000000000dddddddddddddddddddd00
a9494249994944949494499a92444249aaaaaaaaaaaaaaaaaaaaaaaa29dad6a92dddd6d6000000000000000000000000000000000d000000d0d0d0d0d0d0d0d0
aa42222222222222222222a9a222224a94222222222222222222222927766c7627766c7600000000000000000000000000000000d00000000d0d0d0d0d0d0d0d
a42222222222222222222249a42222494222222222222222222222292cccccc72cccccc7000000000000000000000b0000000000d000000000d0d0d0d0d0d0dd
9422222222222222222222499922229a9422222222222222222222292cccccc22cccccc200000000000000000000bbb000000000d0000000000000000d0d0d0d
a922222222222222222222299422222994222222222222222222224922222c2622222c26000000000000000000000b0000000000d0000000000000000000d0dd
a9222222222222222222224a9442442992424942244249422442442925ddd2d625ddd2d600003000000030000000030000000000d00000000000000000000d0d
a92222222222222222222249049999400994999994949999999499402222222d2222222d03033333000033300003030000000000d0000000000000000000d0dd
9422222222222222222222490aaaa9a0aaaaaaaaaaaaaaaaaaaaaaaaa9a9aa9a6666666d00000000001111000000000000000000d00000000000000000000d0d
a4222222222222222222224a92444249aaaaaaaaaaaaaaaaaaaaaaaaa9aad9d26d6dddd200000000000110000000000000000000d0000000000000000000d0dd
a42222222222222222222299a222224aaa42222222222222222222a9678667726786677210011001100110001001100000000000d00000000000000000000d0d
9a222222222222222222224aa4222249a42222222222222222222249788888827888888211111111111111001111110000000000d0000000000000000000d0dd
9422222222222222222222499922229a942222222222222222222249288888822888888211111111111111001111110000000000d00000000000000000000d0d
a9222222222222222222222994222229a92222222222222222222229628222226282222210011001100110001001100000000000d0000000000000000000d0dd
a9222222222222222222224a94222229a9222222222222222222224a6d2ddd526d2ddd5200000000000000000001100000000000d00000000000000000000d0d
a4222222222222222222224a94222249a92222222222222222222249d2222222d222222200000000000000000011110000000000d000000000000000000000dd
942222222222222222222249a2222249000000001111114911111111111111499411114900111100000000000011110005000050d0000000000000000000000d
9222222222222222222222499422224a000000001111334911111111111111499411114900011000000000000001100050000500d0000000000000000000000d
942222222222222222222299a2222299000000001111334211111111111111499411114900011000000110010001100100005000d0000000000000000000000d
942222222222222222222299a422224a000000001111114911111111111111499411114900111100001111110011111100050000d0000000000000000000000d
94222222222222222222224999222249000000001111114911111111112111499411114900111100001111110011111100050000d0000000000000000000000d
92422222222222222222244994222229000000001111112911111111122211499411114900011000000110010001100100005000d0000000000000000000000d
9444444944444942444442499422224a0000000044444499444444441121114994444449000110000001100000000000500005000d00000000000000000000d0
0994499994999999949994909422224a00000000999929909999999911111149099999900011110000111100000000000500005000dddddddddddddddddddd00
09aaa99a99aaa99a9aa99aa094222249111111111111111111111111111111490999999999999999999999905050050000000552000000000000000000000000
a4242444242424944442424a92222249111111111122111111111111111111499444444444444444444444490505005000005255000000000000000000000000
942222222222222222222229a4222299111111111122111111111111111111499411111111111111111111495050500530025525000000000000000000000000
42222222222222222222222942222249111122111111111122111111111111499411111111111111111111490505050052525550000000000000000000000000
942222222222222222222229a4222249111122111111111122111111122111499411111111111111111111490050505052552d00000000000000000000000000
9422222222222222222222499422222a1111111111111111111111111221114994111111111111111111114950050505300d2000000000000000000000000000
92424942244249422442442992424929444444444444444444444444111111499444444444444444444444490500505000000000000000000000000000000000
09949999949499999994994009999990999999999999999999999999111111490999999999999999999999900050050500000000000000000000000000000000
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10000000212121212100000000000010100000001010101010000050000000101050505050505050501010101010101000000000000000000000000000000000
10000000000000000000008080808010105080805000000000000000000000101050505050505050000000000000000000000000000000000000000000000010
10000000000000000000000000000010100000000000000000000000500000101000000000000000000000000000001000000000000000000000000000000000
10000000000000000000008080808010108080808000000000000000009000101050000093000050505050500000000000000000000000000000000000000010
10000000000000000000000000000010100000000000000000000000005000101000000000000000000000000000001000000000000000000000000000000000
10000000000000000000008080808010108080808000000000000000600000101050000031000050009300505050505000000000000000000000000000000010
10000000000000000000000000000010100000000000000000000050000000101000000000000000600000100000001000000000000000000000000000000000
10000041000050009000508080808010108080808000000000000010101010101050000013000000000000000000930050505050000000000000000000000010
10000000000000000000000000000010100000006000000010000000500000101010105000002121210000105000001000000000000000000000000000000000
10101010101050000200500000000010100000000050505050505050505050101050000000000000000000000000000000000000505050000000000000000010
10000021212100000000000000000010100000101010000010100000005000101050505000001000000000105000001000000000000000000000000000000000
10000000000050505050500000000010100000000050505050505080808080101050000000000050001300505000000000000000000000505000000000000010
10000000000000000000000000000010105000000000000010000000000000101050505000001000000000100000001000000000000000000000000000000000
10000000000200000000000000000010108080808000000000000080808080101050000093000050000000500050000000000000000000000050000000000010
10000000000000000000000021210010100050000000000000000000000000101000000000001000000000100000001000000000000000000000000000000000
10000000000000000000000000000010108080808000000000000080808080101050000000005050009300500050130050505050000000000000101010000010
10000000000000000000000021000010100000500000000000000000500000101000000000001000900000100000001000000000000000000000000000000000
10000000005000000000000000000010108080808000000000000080808080101000505050500050505050500050930050500000505050000000000000100010
10000000000000000000000000000010100000000000000000000000005000101000000000001021215050100000001000000000000000000000000000000000
10000000005000000000000000000010105050505050505050500000000000101000000000000000000000000050505050000000000000505000000000100010
10000000212121000000000000000010100000001010100000000000000050101000000000001050500000000000001000000000000000000000000000000000
10003100005000000000500000000010105050505000000000000000000000101000000000000000000000000000000000000000000000000050005100100010
10000000000000000000000000000010100050000000000000000000000000101000001010101010100000000000001000000000000000000000000000000000
10001010005000000000500000020010100000000000000000000080808080101000000000000000000000000000000000000000000000000000212121000010
10000000000000000000000000000010100000500000000000000000900000101000000000000010100000002121211000000000000000000000000000000000
10001010005000000000500000000010100000000000000000000080808080101000000000000000000000000000000000000000000000000000000000000010
10000000000000000000000000000010100000005000000000000000000000101000000000000010100000000000001000000000000000000000000000000000
10000000005000000000500000000010105100310000505050505050505050101000000000000000000000000000000000000000000000000000000000000010
10000000000000000000005100000010100000000000000000000060000000101000003100000010500000004100001000000000000000000000000000000000
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101050501010101010505050101010101000000000000000000000000000000000
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10000000005000100000000000500010100000000000000050505000005200101000000000000000000000000000101010005050505000000000000000000010
10000000000000000000000050505010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010
10000000000050100041000000005010100000000000000000005000009000101050000000000000000000000090001010505000000000000000000000000010
10004100002121000000000050505010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010
10000000000000502121210000000010100000000000000000005000000000101050000000000000505000000060001010505000404040405050404000006010
10101010001000100000000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010
10000000000000005000000000000010100000410000000000000000000000101050004100000050000000220010101010500041505000000000000022001010
10101010001010000000000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010
10000000500000000050000000000010101010101010500000000000000000101050502150505000000000000000001010101010101000000000000000000010
10101010001000105000000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010
10000000005000005000000000000010100000000000500000000000000000101000000000000000000000000000001010000000001000000000000000000010
10505050501010000050006000000010100000000000900000000000000000000000101010100000000000000000000000000000000000000000004100001010
10000000005000000000000000120010100000000000500012005000000000101000000000000000505000005050001010000000001000005050000000005050
10000000500000000000502121000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000001010101010
10000000005000000000000050000010100000000000505050505000000000101000000000000050505021215050501010000000000000005050000000005050
10000031500000000000100000100010100000000000000010101010000000000000000000000000000000000000101010000000000000000010101000000010
10120050005000000000000000500010100000000000101010105000000000101000000000002110101010101010101010001230303030305050303030305050
10001010500000000000100000100010100000000000000000000000000000000000000000000000000000000010100010100000000000001010000000000010
10005000005000000050000000005010100032000000000000005000000000101000000000000000000000000000001010000000000000500000000000000010
10001000100000100000100000100010100000000000000000000000000000000000000000000000000000001010000000101000000000101000000000000010
10500000005000004200500000000010100000000050000000005000000000101000000000000000000000000000001010000000000000500000000000000010
10001000100000100042001010001210100000310000000000000000000000001010100000000000000000101000000000001010001010100000000000000010
10000000005050000000000000820010100000000050000032000000000200101000000000000000000000000000001010000000000000500000100000000010
10001010000000100000000000000010100010101000000000000000000010101010001010101010101010000000000000000010100000000000000000000010
10220050005000500000000000005010100000000050000000000000000000101010000000000000000010003100101010000000000000000000100031001010
10001000000000101010003222000010105000500050101010100000101010100000000000100000000000000000000000000000101000000000000000000010
10315050125000005000000000500010100000310050505050505000000000101000101050505050505000101010001010101010505040404040401010101010
10000000006000505050505050505010100050005000000000102121100000000000000000000000000000000000000000000000001010000000000000000010
10101010501010101050505050101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10303030303010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
__label__
80088008800080888800888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
80bbb0b08b0bb0b88bb0bbb88bbbbbb88bbbbbb88ffffff88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88ffffff88bbbbbb88bbbbbb88bbbbbb88bbbbbb8
80bbb0b08b0bb0b88bb0bbb88bbbbbb88bbbbbb88ff4ff488bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88ff4ff488bbbbbb88bbbbbb88bbbbbb88bbbbbb8
80bbb0b08b0bb0b88bb0bbb88bbbbbb88bbbbbb88ffffff88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88ffffff88bbbbbb88bbbbbb88bbbbbb88bbbbbb8
800bb0b08000b0008b00bbb88bbbbbb88bbbbbb88ffffff88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88ffffff88bbbbbb88bbbbbb88bbbbbb88bbbbbb8
8bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88ffffff88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88ffffff88bbbbbb88bbbbbb88bbbbbb88bbbbbb8
8bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88ff986688bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88ff986688bbbbbb88bbbbbb88bbbbbb88bbbbbb8
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
88888888000000000000000005555000000005500000000000000000000000000000000000000000000000000000000000000000000000000000000088888888
8bbbbbb800000000000000005555550000005655000000000000000000000000000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb800000000000000055555555000005565550000000000000000000000000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb800000000000005555555565500000555655000000000000000000000000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb800000000000056555500556555500005565000000000000000000000000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb800000000000055655000055655550000550055000000000000000000000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb800000000000555550000005565550000000565500000000000000000000000000000000000000000000000000000000000000000000000008bbbbbb8
88888888000000000055555000000055565500000005565550000000000000000000000000000000000000000000000000000000000000000000000088888888
88888888000000000555550000000565556500000000555655000000000000000000000000000000000000000000000000000000000000000000000088888888
8bbbbbb800000000555550000055055655555000000000556500000000000000000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb800000005655500000565505505565500000000055005500000000000000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb800000005565000000556500000556550000000000056550000000000000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb800000055550000055055000000055650000000000055650000000000000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb800000565550000565500000000005555000000000005505500000000000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb800000556500000556500000000005565500000000000056550000000000000000000000000000000000000000000000000000000000000008bbbbbb8
88888888000055550005500550000000000005565000000000000556500000000000000000000000000000000000000000000000000000000000000088888888
88888888222565550056550000000000000000555500000000000055005500000000000000000000000000000000000000000000000000000000000088888888
8bbbbbb822255650005565000000000000000055655000000000000005655000000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb822565500550550000000000000000005565000000000000005565000000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb822556505655000000000000000000000555500000000000000550550000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb825555905565000000000000000000000556500000000000000005655000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb856555590550000000000000000000000055550000000000000005565000000000000000000000000000000000000000000000000000000008bbbbbb8
8bbbbbb855556559000000000000000000000000055650000000000000000550055000000000000000000000000000000000000000000000000000008bbbbbb8
88888888056556509900000000000000000000000055550000000000000000005655000000000000000000000000000000000000000000000000000088888888
88888888055555200900000000000000055000000055650000000000000000005565000000000000000000000000000000000000000000000000000088888888
8ffffff856565520009000000000000055550000000555500000000000000000055055000000000000000000000000000000000000000000000000008ffffff8
8ff4ff4855555520000900000000000055550000000556500000000000000000000565500000000000000000000000000000000000000000000000008ff4ff48
8ffffff825556555500090000000000955550000000055550000000000000000000556500000000000000000000000000000000000000000000000008ffffff8
8ffffff822255556550009000000000955550000000055650000000000000000000055005500000000000000000000000000000000000000000000008ffffff8
8ffffff822225655650000999990000955550000000005555000000000000000000000056550000000000000000000000000000000000000000000008ffffff8
8ff9866822225565505509990099000955550000000005565000000000000000000000055650000000000000000000000000000000000000000000008ff98668
88888888222925559565590090009009555500000000005555000000000000000000000055055000000000000000000000000000000000000000000088888888
88888888222925655556590090009909555500000000005565000000000000000000000000565500000000000000000000000000000000000000000088888888
8bbbbbb822292555595599900900090955550000000000055550000000000000000000000055650000000000000000000000000000000000000000008bbbbbb8
8bbbbbb822222256559999559000090956550000000000055650000000000000000000000005500550000000000000000000000000000000000000008bbbbbb8
8bbbbbb820002055559995655990009955550000000000005550000000000000000000000000005655000000000000000000000000000000000000008bbbbbb8
8bbbbbb820002005655995565099909955550000000000005655000000000000000000000000005565000000000000000000000000000000000000008bbbbbb8
8bbbbbb822222005555000559559000955550000000000005565000000000000000000000000000550000000000000000000000000000000000000008bbbbbb8
8bbbbbb800000000565500005655990956550000000000000555500000000000000000000000000000550000000000000000000000000000000000008bbbbbb8
88888888000000005565000055650909555500000000000005565000000000000000000000000000056550000000000000000000000000000000000088888888
88888888000000000555000005599559955500000000000000555000000000000000000000000000055650000000000000000000000000000000000088888888
8bbbbbb800000000056550000000565956550000000000000056550000000000000000000000000000550055000000000000000000000000000000008bbbbbb8
8bbbbbb800000000055550000000556992222000000000000055650000000000000000000000000000000565500000000000000000000000000000008bbbbbb8
8bbbbbb800000000905655000000022922552000000000000005555000000000000000000000000000000556500000000000000000000000000000008bbbbbb8
8bbbbbb800000000905565000000025522552000000000000005565000000000000000000000000000000055000000000000000000000000000000008bbbbbb8
8bbbbbb800000000000555000000056552552000000000000000555000000000000000000000000000000000055000000000000000000000000000008bbbbbb8
8bbbbbb800000009000565500000055652652000000000000000565500000000000000000000000000000000565500000000000000000000000000008bbbbbb8
88888888000000000005565000000255225000000000000000005565000000000000000000000000000000005565000000000000000000000000000088888888
88888888000000090000555000000000888888888888888800000555500000008888888800000000000000000550055000000000000000000000000000000000
8ffffff80000009000005655000000008bbbbbb88bbbbbb800000556500000008bbbbbb800000000000000000000565500000000000000000000000000000000
8ff4ff480000000000005555000000008bbbbbb88bbbbbb800000055500000008bbbbbb800000000000000000000556500000000000000000000000000000000
8ffffff80000009000000565500000008bbbbbb88bbbbbb800000056550000008bbbbbb800000000000000000000055000000000000000000000000000000000
8ffffff80000000000000556500000008bbbbbb88bbbbbb800000055650000008bbbbbb800000000000000000000000055000000000000000000000000000000
8ffffff80000009000000055500000008bbbbbb88bbbbbb800000005550000008bbbbbb800000000000000000000000565500000000000000000000000000000
8ff986680000000000000056550000008bbbbbb88bbbbbb800000005655000008bbbbbb800000000000000000000000556500000000000000000000000000000
88888888000009000000005565000000888888888888888800000005565000008888888800000000000000000000000055005500000000000000000000000000
88888888000000000000000555000000888888888888888800000000555000008888888800000000000000000000000000056550000000000000000000000000
8bbbbbb80000090000000005655000008bbbbbb88bbbbbb800000000565500008bbbbbb800000000000000000000000000055650000000000000000000000000
8bbbbbb80000000000000005565000008bbbbbb88bbbbbb800000000556500008bbbbbb800000000000000000000000000005500000000000000055000000000
8bbbbbb80000900000000000555000008bbbbbb88bbbbbb800000000055500008bbbbbb800000000000000000000000000000005505555550000559500000000
8bbbbbb82222200000000000565500008bbbbbb88bbbbbb800000000056550008bbbbbb800000000000000000000000000000056555555555000559500000000
8bbbbbb82222220000000000556500008bbbbbb88bbbbbb800090000055650008bbbbbb800000000000000000000000000000055555555555500559500000000
8bbbbbb82200220000000000055500008bbbbbb88bbbbbb800090000005222228bbbbbb800000000000000000000000000000005555555555500559500000000
88888888222222000000000005655000888888888888888800090000999222228888888800000000000000000000000000000005555550555550559500000000
88888888222222200000000222225000000252222222552222290099999222228888888800000000000000000000000000000005555655055655559500000000
8bbbbbb8222222200000000265525000000562220225555252290999999992228bbbbbb800000000000000000000000000000055555565005565559500000000
8bbbbbb8222222200000000256525500000552229256555252299900000299228bbbbbb800000000000000000000000000000055550550005555559509090090
8bbbbbb8222299200000000255526500000562220955655252299000000222228bbbbbb800000000000000000000000000000555550000550599999909990909
8bbbbbb8222222200000000222225500000552222255565555290000000222228bbbbbb800000000000000000000000000000555500095999999999990909999
8bbbbbb8222222900005500000056550000565520565556565290000005222228bbbbbb800000000000000000000000000000555599999599999999909090999
8bbbbbb8222229000056550000055650000555500556555552290000005565228bbbbbb800000000000000000000000000005959999999999095959590909999
88888888222290990055650000005500000565505655556555090000005552228888888800000000000000000000000000099999999900000255555500000000
88888888222229990005500000000550000556505555555555590000056559222220000000000000000000000000000099999969000000000265565500000000
8bbbbbb8200029009000000000005655000555505655555656590000055652222220000000000000000000000000009999995550000000000255555500000000
8bbbbbb8200020559000000000005565000565505565595555090000005592229999900000000000000000000000999900055550000000000255565220009099
8bbbbbb8222925655990000000000555000555556556555565590000055929999999990000000000000000000099990000565550000000000225555990999999
8bbbbbb8222295565990000000000565500565555655659555550000565599992299999000000000000000009999000000555500000000000000959999009000
8bbbbbb8000009550090000000000556500556555505590565550000556599000000999900000000000000999900000000565500000000009999595520000000
8bbbbbb8000000009090900000000055500555565555990556590000555990000000099900000000000009900000000000555500000099999990556520000000
88888888055222200900900000000056550565556565500055550005655990000000009990000000000990000000000000555500090990900222222220000000
88888888565500200099900000099055650555655556500055655005565900000000000990000000099000000009900005655599990900000222022288888888
8bbbbbb855650020009009000090090550056556505590000555500555900000000000099900000099000000009099090995990900000009922202228bbbbbb8
8bbbbbb805500020000909900090090055055655055900000565505655900000000000009900009900000099999909999999999999999999092202228bbbbbb8
8bbbbbb800222220000099900090090565955565565500000556505595000000000000009990999000099990909009909556999999090900022222228bbbbbb8
8bbbbbb800000000055000999990090556956550556509990555559599099000000000000999900099990000009909099959000000909090002222208bbbbbb8
8bbbbbb800000000565500999999090055955655055099999556555590990999990000000999009900000000099009999555000999909999922222228bbbbbb8
8bbbbbb800000000556500999999090056955565550999000955565599000999009000009999900000000099009909095655099909999099022222228bbbbbb8
88888888000000000550090099099000559555556550900000565556990099099099000999990000000990999009990999999999999999999222222288888888
8888888800000099999999000090090005956555565900000055655590099000999999999999900000999900999999999999999999999999a222222288888888
8bbbbbb800000990000090550990090000955650559000000005555590090999909999999099990999909999999999999969990990999909922222228bbbbbb8
8bbbbbb822299000000095655099090005965550999000000005565590099000990999909900909999999999000000096550900009900090022222228bbbbbb8
8bbbbbb820902000000905565999909005956555909000000009555590990009009999000099999999990000000000095559550555005592552225528bbbbbb8
8bbbbbb820002000000900550099900000955565590000000009565592900090099009009909999000055005500550056555655565556555655256558bbbbbb8
8bbbbbb820002000009000000009900905955556590000000005556592000900990099999999999550565556555655555655565556555655565255658bbbbbb8
8bbbbbb822222000009000000000990905965955900000000005555592009009009999955005999655556555655565555555550555095502552225528bbbbbb8
88888888000000000900000000055990929225599000000000095565520900090959995655565995655555555555559559955999599959922222222288888888
88888888000000000900000000565590969526559000000000055556529009550569505565556999595565555955556555655655655655652222222288888888
8bbbbbb800000000090000000055659995952565000000000256555590559565555695655555599999555905505505596559550559556556222222228bbbbbb8
8bbbbbb800000000000000000005500925922559000000000255656552655556555222225955029222290099222202295990955a55055555655955658bbbbbb8
8bbbbbb800000000900000000000000099922229200000000225555652265555555299529220229222222222900202299955565565555655522205528bbbbbb8
8bbbbbb800000000900000000000000025522502200000000255225552255556505200220020222022202902200202550565556556595500022222228bbbbbb8
8bbbbbb800000000000000000000000056552552200000000565525655265555000200220020222022202002200205655556555055000000090000008bbbbbb8
8bbbbbb800000009000000000000000055652652200000000556525565252000000222220020222222202002222205565255000000000000009000008bbbbbb8
88888888000000090000000000000000255222222000000002552225522000000000002222202222222222222000025522000000000000000000000088888888
88888888000000000000000000000000888888888888888888888888888888888888888888888888888888888888888888888888000000000090000088888888
8bbbbbb80000000900000000000000008bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb800000000000900008bbbbbb8
8bbbbbb80000000000000000000000008bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb800000000000000008bbbbbb8
8bbbbbb80000229220000000000000008bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb800000000022922008bbbbbb8
8bbbbbb80000200020000000000000008bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb800000000020002008bbbbbb8
8bbbbbb80000200020000000000000008bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb800000000020002008bbbbbb8
8bbbbbb80000200020000000000000008bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb800000000020002008bbbbbb8
88888888000022222000000000000000888888888888888888888888888888888888888888888888888888888888888888888888000000000222220088888888
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888
8bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb8
8bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb8
8bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb8
8bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb8
8bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb8
8bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb88bbbbbb8
88888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888888

__gff__
0001414345102010409090000000000000004182a0a000000000000000000000081838286848c8889800000000000000001939296949c98999f100000000000001010101414141430100000000404040010101014141414501000000004040400101010100010101010000000040404001010101010101000101010000000000
0101010101010101000000000000000001010101010101010000000000000000010101010101010100000000000000000101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
5074737566666673747466757466515201010101010101010101010101010101010101010101010101010101010101015161616161616161616161616161615101010101010101010101010101010101010101010101010101010101010101015161616161616161616161616161615100000000000000000000000000000000
604d4f00000069000000004d4e4e4f4801000000000000000000000000000001010000000000000000000000000000015200000000000000000000000000005001000000000000000000000000000000000000000000000000000000000000015200000000000000000000000000005000000000000000000000000000000000
575d5f00000069000000005d5e5e5f68010000000900000000000000000000010100000000000000000000000000000152395314000000003300000000003950010000000000000000000000000000000000000000000000000000000000000152134b0000000000000000000000155000000000000000000000000000000000
605d5f6a59595a000000006d6e6e6f58010000000000000000000000000000010100000000000000000100000000000151716172050505050000000505050505010000000000000000000000000006000000000000000000000000000000000151717207074d4e4e4e4e4f070770715100000000000000000000000000000000
675d5f69000000000000000000000048010000010100000000000000000000010100000000002000010100000000000152000000000000000000000000000050010000000000000000000000000012120000000000000000000000000000000152000000005d5e5e5e5e5f000000005000000000000000000000000000000000
606d6f69000000004b4a000013000068010000000000000000200000010000010100000000000000010100002000000152390000000033000000000000003950010000003933000000000000003900000000000000000000370000390000000152000000006d6e6e6e6e6f000000005000000000000000000000000000000000
4759595a0000000053444443445444720100000000000000000000000000000101000000010100000100000000000001520000000000050505050505050505050100000000000000000000000005000000000000000000000000000000000001525959595959595b6a5959595959595000000000000000000000000000000000
570000005355000062000000000000000000000000000000000000000000000101000000000000000100000000000001520000000000000000000000000000500100000000000000000000000505000000050505050505050505050505050501520000000000006b5a0000000000005000000000000000000000000000000000
60000000636500006200000000000000000000000000000000000000000000010100000000000000010020000000000152390000330000000000000000003950010039330000000000003900050500000000250000002500000000000000000152000000075300004b0053070000005000000000000000000000000000000000
6000000000000000630000000000000000000000000000000101000000000001010000000000000001140005000500010505050505050505050000000000005001000000000000000000000005000000000000000000000000000000000000015200000007607171717162070000005000000000000000000000000000000000
670000000000000000000000000000000000000000000000000000000000000101000000002000000001050105010501520000000000000000000000000000500100000000000000000000000500060000000000000000000000000000000001524d4e4e4f0000000000004d4e4e4f5000000000000000000000000000000000
600000000000000000000020000000530100000001010000000000000020000000000000000000000000010001000101523933000000000000000000000039500100130000000000000000000512121200003900000039000000000000000001525d5e5e5f0000000000005d5e5e5f5000000000000000000000000000000000
670000000000000000000000000000620100000000000000000000000000000000000000000000000000000000000001520000000000000505050505050505050100404200000000000000000500000005050505050505050505050000000001525d5e5e5f0000000900005d5e5e5f5000000000000000000000000000000000
600000000000000000000000000000620100000000000000000000000000000000000000000000000000000000000001520000000000000500000000000000500100606200000000000000000500000000000000000000000000000000002701526d6e6e6f0000000000006d6e6e6f5000000000000000000000000000000000
670000490000000000004b000000006201000000000000000000000000000000000000000000000000000000000000015200130000000005000000000000005001000000000000000000000005001400050505050505050505050500000000015207070707000006004900070707075000000000000000000000000000000000
7002020244444344447171444344447201010101010101010101010101010101010101010101010101010101010101015141414141414141414141414141415101010101010101010101010101010101010101010101010101010101010101015141414141414141414141414141415100000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101015161616161616161616161616161616161616161616161616161616161616151
0100000000000000000000000000000000000000000000000000000000000001010000000000000000000000050000000001000000260000000000000000000101000000000000000000000000000001010000000000000000000005000000015200000000000000000000000000000000000000000000000000000000000050
0100000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000000001000000000000000000000000000101000000000000000000000000000001010000000000000000000000050000015200000000000000000000000000000000000000000000000000000000000050
0100000000000000000000000000000000000000000000050500000000000001010000000000000000000000000000000001000000090000000000000000000101000000000000000000000000000001010015000000000000000000000500015200000000000000000000000000000000000000000000000000000000000050
0100000000000101010101010101010000000006000000050500000000000001010000000005000000000000050000000001000000210000050000000000000101000000000000000000000000000001010001010013000000000000000005015200000000000000000000000000000000000000000000000000000000000050
0500000000000101010105050505050101010101010101050500000000000001010000000005000000000000050000130001120000000000050505000005050101000000000000000000000000000001010000010101010000000000000000015200000000000000000000000000000000000000000000000000000000000050
0508080800000000000000000000050101000000000000000000000808080801010500000505000012040405000412120301050505000505050500000000000101000000000000000000000000000001010000000000000000000000000000015200000000000000000000000000000000000000000000000000000000000050
0508080800000000002800002700050101000000000000000000000808080801010000000005000005050500000000000005000000000000000500000000000101000101001300000000000000000001010500000000000000000000000000015200000000000000000000000000000000000000000000000000000000000050
0508080800000101010105000000050101000000000000000000000808080801010000000500050500000005000000000000000000000000000505050000050101000001010101000000000000000001010005000000000000000000000000015200000000000000000000000000000000000000000000000000000000000050
0505050505050505050505000000000101000000000000000005050505050501010000050500000000000000000000000000000000000000000500000000000101000000000000000000000000000001010000050000000000000000000000015200000000000000000000000000000000000000000000000000000000000050
0100000000000000000000000000000101010101010000000005050505050501010000000500000000000000000000000005000000060000000505050500000101000000000000000000000000000001010000000000000000000000000000015200000000000000000000000000000000000000000000000000000000000050
0100000000000000000000000000000101000000000000000008080808080501010000000000000000000000000000000005000003120400000500000000000101000000000000000000000000000001010000000000000000000000000000015200000000000000000000000000000000000000000000000000000000000050
0100000000000000000005080808050101000000000000000008080908080501010000000000000600000005000303120005000000000000000500050015000101000000000000000000000009000001010000000000000000000000000000015200000000000000000000000000000000000000000000000000000000000050
0100000000000000000005080808050101000000000000000008080808080501010303120500030312000005000000000005000000000000000500050312040001000000000000000000001212120001010000000000000000000001010101015200000000000000000000000000000000000000000000000000000000000050
0100001300000000000005080808050101000015000000000505050505050501010000000500000000000500050005000500050005000500050005050500050001000000000000000000000000000001010000000000000001000000000000015200000000001300000000000000000000000000000000000014000000000050
0101010101010101010105050505050101010101010101010101010101010101010505050505050505050005000500050005000500050005000500050005000501000000000000001200000000000001010000000000000001000000000000015141414141414141414141414141414141414141414141414141414141414151
__sfx__
050400003374328723107150070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703
01020000036600c660275501b05017050150500f7500c750006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
01020000065100651007510095100b5200d020100201302014020187201f73027740157001b7002070022700007000c7000d7000f700147001a7001e70020700007000c70010700157001a7001e7000070000700
000200000c5100d5100f510115101352016020190201c0201f02024720287302e740157001b700207002270000000000000000000000000000000000000000000000000000000000000000000000000000000000
01020000105101251015510185101b5201e0202102024020290202d7203173036740157001b700207002270000000000000000000000000000000000000000000000000000000000000000000000000000000000
150200000a7510a0510c051100511305119751097510e051136511a0510665109055056550b755267013370100001000010000100001000010000100001000010000100001000010000100001000010000100001
000500000f7211172114721177211b7211e721247312a7413475234762347723477234772347623475234742347323472234712347103471034700347001100000000160001e700237002a700000000000000000
0008000011115171151b1351f145231451e12519125211451d155171251e135251552110500005001050010500105001050010500105001050010500105001050010500105001050010500105001050010500105
000200000f0500f0500e0500a05007050050500105000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
