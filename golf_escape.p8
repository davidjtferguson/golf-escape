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

 pausecontrols=false

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
 
 --game object tables
 bumpers={}
 hooks={}
 
 initlevels()
 
 --stats for end screen
 deathcount,swingcount=0,0
 frames,seconds,minutes,hours=0,0,0,0
end

function _update60()
 currentupdate()
end

function updateplaying()
 if currentupdate!=updateending then
  updateplaytime()
 end

 updatebackgrounds()
 updatecamera()

 if not pausecontrols then
  handleswinginput()
 end
 
 updateaim()

 --collision
 if currentupdate!=updateending then
  avwallscollision()
 end

 --game obj update
 -- update hooks
 for h in all(hooks) do
  if h.avon then
	  if anycol(av,h.xvel,h.yvel,0) and
       currentupdate==updateplaying then
	   hookreleaseav(av.hook)
	   resetswing()
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

  if circlecollision(av,h) and
     h.active and
     currentupdate==updateplaying then
   --todo:sfx for land on hook
   --just use normal land?
   
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
  
  --lose key if not saved
  if currlvl.haskey and
     currlvl.key.collected and
     not currlvl.key.saved then
   currlvl.exit.s=21
   currlvl.key=resetkey(currlvl.key.spawnx,currlvl.key.spawny)
  end
 end
 
 --checkpoint
 if anycol(av.hurtbox,0,0,5) then

  --save key if held
  if currlvl.haskey and
   currlvl.key.collected then
   --todo:sfx here? for 'key saved'?
   currlvl.key.saved=true
  end

  --if new cp hit
  if xcp!=xhitblock or
     ycp!=yhitblock then

   --clear old cp
   -- if not spawn
   if not isspawn(xcp,ycp) then
    mset(xcp,ycp,6)
   end
   
	  --set new cp
	  sfx(6)
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
  currlvl.key.anim.basesprite=17
  currlvl.key.anim.sprites=1
 end
 
 if currlvl.haskey and
    currlvl.key.collected then
   --draw 'key' under player if they have one
  --little bounce when on player
  local up=0

  if flr(currlvl.key.anim.sprite)==currlvl.key.anim.basesprite then
   up=1
  end
  
  currlvl.key.x=av.x-(pixel*2)
  currlvl.key.y=av.y-(pixel*2)-(pixel*up)
  currlvl.key.xflip=av.xflip
 end

 if currentupdate!=updateending then
  updateav()
 end

 updateanims()
 
 updateparticleeffects() --tab 6
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
end

function avwallscollision()
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
end

function _draw()
 currentdraw()

 print(debug,cam.xfree*128,cam.yfree*128,1)
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

 --lvl objs draw
 -- if we're outside the factory
 -- draw red corners
 -- otherwise,transparent
 -- (pretty overkill to save one sprite, will probably change)
 if currlvl.xmap==6 and currlvl.ymap==2 then
  palt(0,false)
  pal(0,8)
 end
 
 drawobj(currlvl.exit)
 
 pal()
 
 if currlvl.haskey then
  spr(currlvl.key.anim.sprite,
    (currlvl.key.x*8),
    (currlvl.key.y*8),1,1,currlvl.key.xflip)
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

 if av.canswing and not av.dancing then
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
   drawobj({s=16,x=(cam.xfree*16)+14+mod,y=(cam.yfree*16)+7})
   drawobj({s=16,x=(cam.xfree*16)+1-mod,y=(cam.yfree*16)+7},true)
  elseif currlvl.h>1 then
   drawobj({s=0,x=(cam.xfree*16)+7,y=(cam.yfree*16)+14+mod})
   drawobj({s=0,x=(cam.xfree*16)+7,y=(cam.yfree*16)+1-mod},false,true)
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
  --float zone test
  --{xmap=7,ymap=0,w=1,h=1},
  --polly art test
  {xmap=6,ymap=1,w=2,h=1},
  --factory external
  {xmap=6,ymap=2,w=1,h=1},
  --wide level bunkers
  --{xmap=2,ymap=1,w=2,h=1},
  --wide level long swings
  --{xmap=2,ymap=2,w=2,h=1},
  --extra wide level golf course
  --{xmap=5,ymap=3,w=3,h=1},
  --slows tutorial
  --{xmap=6,ymap=0,w=1,h=1},
  --tall level camera test
  --{xmap=4,ymap=1,w=1,h=2},
  --tall level design tests
  --{xmap=5,ymap=1,w=1,h=2},
  --mover hooks
  --{xmap=3,ymap=0,w=1,h=1},
  --mover hooks 2
  --{xmap=4,ymap=0,w=2,h=1},
  --hook maze
  --{xmap=0,ymap=3,w=1,h=1},
  --art test
  --{xmap=0,ymap=0,w=3,h=1},
  --hooks and slows
  --{xmap=0,ymap=2,w=1,h=1},
  --wide slows
  --{xmap=0,ymap=1,w=2,h=1},
  --climb upwards slows
  --{xmap=1,ymap=2,w=1,h=1},
  --moving hooks
  --{xmap=1,ymap=3,w=1,h=1},
  --static swing power test
  --{xmap=2,ymap=3,w=1,h=1},
  --convayer belts
  --{xmap=3,ymap=3,w=1,h=1},
  --important plob level
  --{xmap=4,ymap=3,w=1,h=1},
  --out of way key
  --{xmap=7,ymap=2,w=1,h=1},
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
  s=48,
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
  typ="moveon",
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
 else
  h.typ="still"
 end
 
 if checkflag(x,y,0) then
  h.typ="mover"
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
  s=122,
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
 
 --delete previous level's game objects
 -- (this means no going back levels
 -- since the game object level data is deleted)
 bumpers={}
 hooks={}
 
 currlvl=lvls[lvls.currlvlno]
 
 currlvl.haskey=false
 
 --scan area for level game objects
 for x=(16*currlvl.xmap),(16*currlvl.xmap)+(16*currlvl.w) do
  for y=(16*currlvl.ymap),(16*currlvl.ymap)+(16*currlvl.h) do

		 --load this lvls bumpers and hooks
		 if checkflag(x,y,0) and
		    checkflag(x,y,4) and
		    checkflag(x,y,5) and
		    checkflag(x,y,6) and
		    checkflag(x,y,7) then
		  createbumper(x,y)
		  mset(x,y,0)
		 end
		 
		 if checkflag(x,y,3) then
		  createhook(x,y)
		  mset(x,y,0)
		 end
		 
   if checkflag(x,y,1) and
      checkflag(x,y,7) then
    --found spawn
    xcp=x
    ycp=y
    
    resetav()
   end
   
   if checkflag(x,y,4) and
      checkflag(x,y,7) then
    --found key
    currlvl.haskey=true
    
    currlvl.key=resetkey(x,y)
    
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

function resetkey(x,y)
 local keyanim=makeanimt(9,40,2)

 local key={
  --consts
  spawnx=x,
  spawny=y,
  r=pixel*4,
  
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

 if not pausecontrols then
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
  r=av.r,
  points={},
  hitdeath=false,
 }

 if av.canswing then
	local wallhit=false

  applyswing(aim)

  --move a couple frames first
  -- so we're not drawing
  -- over our av.
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
    
   resethurtbox(aim)

   if anycol(aim.hurtbox,aim.xvel,aim.yvel,4) then
    wallhit=true
    aim.hitdeath=true
   end

	  if anycol(aim,aim.xvel,aim.yvel,0)
	     or #aim.points>100 then
	   wallhit=true
	  end
   
   for h in all(hooks) do
    if circlecollision(aim,h) then
     wallhit=true
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

function hookreleaseav(hook)
 hook.active=false
 
 if hook.typ=="moveon" then
  sfx(9)
  --smoke puff
  initdustkick(hook.x+4*pixel,hook.y+4*pixel,
   -0.5,-0.5,
   1,1,
   10,5,hookcolours,true,4)

  hook.x=hook.spawnx
  hook.y=hook.spawny

  --smoke puff
  initdustkick(hook.x+4*pixel,hook.y+4*pixel,
   -0.5,-0.5,
   1,1,
   10,5,hookcolours,true,4)

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
 t.basesprite=46
 t.sprites=2
 t.speed=19

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
-- transition and ending state

function initlvlend()
 currentupdate=updatelvlend
 currentdraw=drawlvlend

 pausecontrols=true
 av.dancing=true
end

function updatelvlend()
 updateplaying()

 if btnp(🅾️) then
  inittransition()
 end
end

function drawlvlend()
 drawplaying()
end

function inittransition()
 currentupdate=updatetransition
 currentdraw=drawtransition

 transition=resettransition()
end

function resettransition()
 local t={
  phase=0,
  
  cir={
   x=64,
   y=0,
   r=5,
   c=0,
   speed=5
  }
 }
 return t
end

function updatetransition()
 updateplaying()

 transition.cir.r+=transition.cir.speed
 
 if transition.cir.r>160 and transition.phase==0 then
  --screen is black - switch

  av.dancing=false
  nextlevel()

  --now bring screen back in
  transition=resettransition()

  transition.phase=1
  
 end

 if transition.cir.r>160 and transition.phase==1 then
  --screen is back up - move to playing

  currentupdate=updateplaying
  currentdraw=drawplaying
  pausecontrols=false
 end
end

function drawtransition()
 cls()

 if transition.phase==0 then
  drawplaying()

  circfill((cam.x*128)+transition.cir.x,(cam.y*128)+transition.cir.y,transition.cir.r,transition.cir.c)
 elseif transition.phase==1 then
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
 ycredits=-64
 
 currentupdate=updateending
 currentdraw=drawending

 --factory external
 currlvl.xmap=6
 currlvl.ymap=2
 currlvl.w=1
 currlvl.h=1
 currlvl.haskey=false
 currlvl.exit.s=20
 
 av.x=(currlvl.xmap*16)+8
 av.y=(currlvl.ymap*16)+15
 av.dancing=true

 --todo:init and update
 -- white circle expanding
 -- perhaps multiple circles expanding
 --
end

function updateending()
 updateplaying()

 if ycredits<32 then
  ycredits+=0.25
 end
end

function drawending()
 drawplaying()
 
 --credits
 
 local c1=2
 local c2=11
 
 s="golf escape"
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+ycredits,c1,c2)
 
 s="by davbo"
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+ycredits+8,c1,c2)
 
 s="with help from rory and polly"
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+ycredits+16,c1,c2)
 
 s="deaths: "..deathcount
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+ycredits+24,c1,c2)

 s="swings: "..swingcount
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+ycredits+32,c1,c2)

 s="playtime: "..
 twodigit(hours)..":"..
 twodigit(minutes)..":"..
 twodigit(seconds).."."..
 twodigit(frames)
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+ycredits+40,c1,c2)

 s="thanks for playing!"
 outline(s,
  (cam.x*128)+hw(s),(cam.y*128)+ycredits+48,c1,c2)
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
hookcolours={2,5,6,6,6}

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
   0+flr(rnd(radius)),col)
  
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
0006600085888588aaa9aaaa000000000000000000000000000000000000000000000000000dd000000dd0000000000000040400004004000040400000400400
00066000858885889a4a549a00000000000000000000000000702200000000000000000000dddd0000dddd0000000000000ff000000ff000000ff000000ff000
000660008588858885888588000000000000000000000000007122000000000000000000677dd777677dd7770000000004f1f100001f1f00001f1f4000f1f100
000660005555555555555555000000000000000000000000007122000000000000000000600700076007e0e70000000000fffe0000feff0000efff0000ffef40
0666666088588858885888580000000000000000000000000071000000000000000000007807e0e7708708070000000000fffff004ffff000fffff0000ffff00
05666650885888588858885800000000000000000000000000700000000000000000000078070807780708070000000000f0000000f00f0000000f0000f00f00
00566500885888588858885800000000000000000000000000700000000000000000000060878007608780070000000000000000000000000000000000000000
00055000555555555555555500000000000000000000000000700000000000000000000066777766667777660000000000000000000000000000000000000000
00000000e0e00000e0e0000000666600006666000066660006600000000000000000000000000000000000000000000000000000000000000000040400000000
0000660008000000080000000611116006ccac60065555606766000000707700007007000070000000000000000040400000404000004040000007f700004040
000066600800000080088000611111166ccacac665e5e55667770000007677000076770000767700000000000040fff00040fff00040fff00000717100000fff
666666660800080080800800611111166cccaca6655855560770000000767700007677000076770000000000000f1f10000f1f10000f1f100040f7e70400f1f1
555566650088800008008000611111166ccacac6655855560000022000760000007670000070670000000000040ffe000f0ffe00040ffe00040fff0000ffffe0
000066500000000000000000611111166cccccc6655855860000282200700000007000000070000000000000f04ff000004ff000400ff000f04ff000400fff00
000055000000000000000000611111166cccccc665558856000028880070000000700000007000000000000000000000040000000f0000000000000004ff0000
000000000000000000000000611111166cccccc66555555600000880007000000070000000700000000000000000000000000000000000000000000000000000
000dd000000aa0000004aa00000440000004400000044000000440000004400000aa400000000000000000000000000000000000000000000000000000404000
00dddd00004aa4000044aa000044aa0000444400004444000044440000aa440000aa4400000000000004040000040400000404000004040000040000000ff000
00dddd0000444400004444000044aa000044aa00004aa40000aa440000aa440000444400041f14f000f1f0000000fff00000fff00000fff0040ff00000f1f100
000dd0000004400000044000000440000004aa00000aa00000aa400000044000000440000ffeff0000ff1000004f1f10004f1f10004f1f1000f1f10004fffe00
00500500005005000050050000500500005005000050050000500500005005000050050000fff00000fe0000040ffe008f0ffe00040ffe0000fffe0000ffff00
050000500500005005000050050000500500005005000050050000500500005005000050000f040000ff0000f04ff000804ff000408ff00004fffff000f0f000
50000005500000055000000550000005500000055000000550000005500000055000000500000000000ff00088000000040000000f8000000000000000000000
66666666666666666666666666666666666666666666666666666666666666666666666600000000004000000000000000000000000000000000000000000000
0000000000077000000d7700000dd000000dd000000dd000000dd000000dd0000077d000d2222222222222288888822200000000000000000000000000000000
000ee00000d77d0000dd770000dd770000dddd0000dddd0000dddd000077dd000077dd00da5a555555555522822225220404000000000000000f0f0000040000
00e72e0000dddd0000dddd0000dd770000dd770000d77d000077dd000077dd0000dddd00d5a55aa555a55a5a2aa5aaa200fff00004f1e00000fff0000f0fff00
0e7222e0000dd000000dd000000dd000000d7700000770000077d000000dd000000dd000da5a5a5a5a5a5a5a5a55a5a200f1f10000ffff0000ffff0000fff140
0e2222e0005005000050050000500500005005000050050000500500005005000050050025555aa55a5a5aaa5aa5aa2204ffef00041fff00001fef0000ffff00
00e22e000500005005000050050000500500005005000050050000500500005005000050d2555a5555a55aaa5a55a5a200fff00000fff0f004ff1000000e1f40
000ee0005000000550000005500000055000000550000005500000055000000550000005dd222555555522222aa5a2220f0f0000000040000004400000000000
0000000066666666666666666666666666666666666666666666666666666666666666665dd52222222255552222225200000000000000000000000000000000
0555555500000000555555500555555009aaa9a9aaa9aaaaaa9a9aa0aaa9aa9ad666666600000000000000006666666600000000000000000000000000000000
558885880000000085888585558885855a9a9a499a4a549a9a45a49a29dad6a92dddd6d60000000000000000655555560049bbbbbbbb44949bbbbb0000bbbb00
5588858800000000858885855588858555888588858885888588858527766c7627766c760000000000000000651155160bbbb3393433333333333bb00b3343b0
555555550000000055555555555555555555555555555555555555552cccccc72cccccc70000000000000000651115110b33333333333333333334b00b3333b0
585888580000000088588855585888555858885888588858885888552cccccc22cccccc20000000000000000655111110b33333343b333333b3333b00b3333b0
5858885800000000885888555858885558588858885888588858885522222c2622222c260000000000000000655511110b33333333333333333333b004b339b0
5858885800000000885888555858885558588858885888588858885525ddd2d625ddd2d60000300000003000615511110b33b33333333333333339b000bbbb00
555555550000000055555555055555500555555555555555555555502222222d2222222d0303333300003330611111110b43333bb333333bb33b33b000000000
558885888588858885888585055555500aaa9aaa00000000aa9aaaa0a9a9aa9a6666666d3b333b3300000022220000000b33333bb333333bb33333b000000000
55888588858885888588858555888585a9a44a59000000005aa4a95aa9aad9d26d6dddd2333b333b00000225522000000b333b333333b333333393b000bbbb00
55888588858885888588858555888585558885880000000085888585678667726786677233b333b300002258852200000b33333333333333333333b00b3bbbb0
5555555555555555555555555555555555555555000000005555555578888882788888823333333300222555555222000b333333b3333393333333b00b333b40
5858885888588858885888555858885558588858000000008858885528888882288888823b3333b300255885885552000433333333333333333333400b333bb0
585888588858885888588855585888555858885800000000885888556282222262822222b3333b33022588858858522004333933333433333b3333300b333bb0
585888588858885888588855585888555858885800000000885888556d2ddd526d2ddd52333b333322558885885885220b33333333333333333333400b3333b0
55555555555555555555555555555555555555550000000055555555d2222222d222222233b3333325555555555555520b33333bb333333bb33333400b3333b0
558885880000000085888585558885850aa9a4a00aaaaa9000cccccccccccccccccccc008588858802000020666666660b33333bb333333bb33333b00b3333b0
55888588000000008588858555888585a94aaa5aa9a49a590c111111c1c1c1c1c1c1c1c08588858802555520655555560b3333333b333333333343b00b3333b0
558885880000000085888585558885855588858555888585c11111111c1c1c1c1c1c1c1c8588858802588520655555560b433333343333333b3333b0043b3390
555555550000000055555555555555555555555555555555c111111111c1c1c1c1c1c1cc5555555502588520655555560b33339333333393333333b0043333b0
585888580000000088588855585888555858885558588855c1111111111111111c1c1c1c8858885802588520655555560b33333333333333333333b00b3333b0
585888580000000088588855585888555858885558588855c1111111111111111111c1cc8858885802555520655555160b43333333333333339334b00b3333b0
585888580000000088588855585888555858885558588855c11111111111111111111c1c8858885802588520655111160044bbbbbbbb49444bbbbb000b3334b0
055555550000000055555550555555550555555055555555c1111111111111111111c1cc5555555525555552666666660000000000000000000000000b3333b0
05555555555555555555555055888585c111111111111111c11111111111111111111c1c1111111c15000000333333330000000000000000000000000b33b3b0
55888588858885888588858555888585c111111111111111c1111111111111111111c1cc1111111c555000003333343300b4bbbbb4bbbbbbbbbbbb000b3333b0
55888588858885888588858555888585c111111111111111c11111111111111111111c1c1111111c00000500333333330b333333bbbb3333393b33400b333340
55555555555555555555555555555555c111111111111111c1111111111111111111c1cc1111111c0555555033933b330b3333333333333b333333b009333340
58588858885888588858885558588855c111111111111111c11111111111111111111c1c1111111c00511500333333430b333b3333333333333333b0043333b0
58588858885888588858885558588855c111111111111111c1111111111111111111c1cc1111111c00511500333433330b3333333333333333b334b0043333b0
585888588858885888588855585888550c11111111111111c11111111111111111111c1c111111c0055555503b3333330043494bbb4944bbbbbbbb0000bbbb00
0555555555555555555555500555555000ccccccccccccccc111111111111111111111cccccccc00000000003333333300000000000000000000000000000000
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
100000002020202020000000000000101000000010101010100000f4000000100000000000000000a60000000000000010d6d6d6d6d6d6d6d610101010101010
1000000000000000000000868686861010d56686d5000000000000000000001010d5d5d5d5d5d5d5000000000000000000000000000000000000000000000010
10000000000000000000000000000010100000000000000000000000f400001000000000000000a596b5a6000000000010000000000000000000000000000005
100000000000000000000086868686101066777786000000000000000090001010d50000030000d5d5d5d5d50000000000000000000000000000000000000010
1000000000000000000000000000001010000000000000000000000000f4001000000000a6a6a596969696b50000000010000000000000000000000000000005
100000000000000000000086868686101067777787000000000000006000001010d50000310000d5000300d5d5d5d5d5d5000000000000000000000000000010
100000000000000000000000000000101000000000000000000000f400000010000000a59696969696b4b696b500000010000000000000006000003500000005
100000410000d5009000d586868686101047575797000000000000101010101010d50000130000000000000000000300d5d5d5d5d50000000000000000000010
10000000000000000000000000000010100000006000000010000000f40000100000a5969696969696b6b69696b50000101010e40000445464000036e4000005
101010101010d5000200d500000000101000000000d5d5d5d5d5d5d5d5d5d51010d5000000000000000000000000000000000000d5d5d5d50000000000000010
1000002020200000000000000000001010000010101000001010000000f4001000000096969693a3b39696969600000010d5d5e50000360000000036e6000005
100000000000d5d5d5d5d500000000101000000000d5d5d5d5d5d5777777771010d50000000000d5001300d5d500000000000000000000d5d5d5000000000010
1000000000000000000000000000001010f400000000000010000000000000100000009696969696969696969600000010d6d6e6000036000000003600000005
100000000002000000000000000000101077777777000000000000777777771010d50000030000d5000000d5d5d50000000000000000000000d5000000000010
100000000000000000000000202000101000f40000000000000000000000001000000096b6b69696969696969600000025000000000036000000003600000005
100000000000000000000000000000101077777777000000000000777777771010d500000000d5d5000300d500d51300d5d5d5d5000000000000101010000010
10000000000000000000000020000010100000f40000000000000000f400001000000096b6b696969696b6b69600000025000000000036009000003600000005
1000000000d5000000000000000000101077777777000000000000777777771010d5d5d5d5d5d5d5d5d5d5d500d50300d5d500d5d5d5d5000000000000100010
1000000000000000000000000000001010000000000000000000000000f4001000000096969696969696b6b696000000250000000000052020d7d72600000005
1000000000d50000000000000000001010d5d5d5d5d5d5d5d5d500000000001010000000000000000000000000d5d5d5d5000000000000d5d500000000100010
100000002020200000000000000000101000000010101000000000000000f410000000969696b6b6969696969600000025000000000005d5e500000000000005
1000310000d500000000d5000000001010d5d5d5d5000000000000000000001010000000000000000000000000000000000000000000000000d5005100100010
100000000000000000000000000000101000f400000000000000000000000010000000969696b6b6969696969600000025000007171710102400000000000005
1000101000d500000000d50000020010100000000000000000000077777777101000000000000000000000000000000000000000000000000000202020000010
10000000000000000000000000000010100000f40000000000000000900000100000009696969696969696969600000025000000000000052500000044545410
1000101000d500000000d50000000010100000000000000000000077777777101000000000000000000000000000000000000000000000000000000000000010
1000000000000000000000000000001010000000f400000000000000000000109431009696969696419696969600a40025000000000000052600000000000010
1000000000d500000000d50000000010105100310000d5d5d5d5d5d5d5d5d5101000000000000000000000000000000000000000000000000000000000000010
1000000000000000000000510000001010000000000000000000006000000010959595959595959595959595959595952500003100000005e500000041000010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010101010101010101010101010101010109595959595959595959595959595959525c4e40417171710d5d4d41010101010
101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010d5d5d5d5d5d506101010101010101010
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
2500000000c6d5360000000000c6d5051000000000000000d5d5d5000052001025000000000000000000000000000610d5d5d5d6d6e600000000000000000005
100000000000000000000000b7b7b710100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010
250000000000c637004100000000c60510000000000000000000d5000090001010e40000000000000000000000900005d5d5e500000000000000000000000005
100041000020200000000000b7b7b710100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010
25000000000000c6542064000000000510000000000000000000d5000000001010e50000000000c4d7e7000000600005d5d5e60075757575d7d7757500006005
10101010001000100000000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010
2500000000000000f6000000000000051000004100000000000000000000001010e500410000c4e60000002200071710d5e60041c5e500000000000022000710
10101010001010000000000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010
25000000f4000000c5e7000000000005101010101010d500000000000000001010d6e746c7d7e600000000000000000515171717172400000000000000000005
1010101000100010b700000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010
2500000000f50000f700000000000005100000000000d50000000000000000102500000000000000000000000000000525000000003600000000000000000005
10b7b7b7b710100000b7006000000010100000000000900000000000000000000000101010100000000000000000000000000000000000000000004100001010
2500000000f60000000000000012c405100000000000d5001200d500000000102500000000000000c4e40000c4e400052500000000370000c4e400000000c4d5
10000000b70000000000b72020000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000001010101010
2500000000f6000000000000c7d4d505100000000000d5d5d5d5d5000000001025000000000000c4d5e54565c5d5e4052500000000000000c5e500000000c5d5
10000031b70000000000100000100010100000000000000010101010000000000000000000000000000000000000101010000000000000000010101000000010
251200f400f600000000000000c6d50510000000000010101010d50000000010250000000000441010101010101010102500128484848484d6d684848484d6d5
10001010b70000000000100000100010100000000000000000000000000000000000000000000000000000000010100010100000000000001010000000000010
25d4e70000f6000000f400000000c60510003200000000000000d500000000102500000000000000000000000000000525000000000000f60000000000000005
10001000100000100000100000100010100000000000000000000000000000000000000000000000000000001010000000101000000000101000000000000010
25e6000000f600004200f400000000051000000000d500000000d500000000102500000000000000000000000000000525000000000000f60000000000000005
10001000100000100042001010001210100000310000000000000000000000001010100000000000000000101000000000001010201010100000000000000010
2500000000c5e40000000000008200051000000000d5000032000000000200102500000000000000000000000000000525000000000000f70000f50000000005
10001010000000100000000000000010100010101000000000000000000010101010001010101010101010000000000000000010100000000000000000000010
252200f500c5d5e4000000000000c4101000000000d5000000000000000000101065000000000000000035003100041025000000000000000000350031000410
1000100000000010101000322200001010b7b7b7b7b7101010100000101010100000000000100000000000000000000000000000101000000000000000000010
2531c4e512c5d5d5e400000000c4d5101000003100d5d5d5d5d5d5000000001010151724d4d4d4d4d4d415171717151010171724d4d485858585151717171010
10000000006000b7b7b7b7b7b7b7b71010b7b7b7b7b7b7b7b7102020100000000000000000000000000000000000000000000000001010000000000000000010
1024c5d5d4e5c5d5d5d4d4d4d4d5d510101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10151515151515101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
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
0001410000002000009090000000000000000082a0a000202020000000000000081838286848c8889800000000000000f11939296949c989990000000000000001000101414141430300000010101010010101014100414505010000101010100101010141414040400000001010101001010101404040404040001010101010
0101010101010101000000000000000001010101010101010000000000000000010101010101010100000000000000000101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101015151515151515151515151515151515101010101010101010101010101010101010101010101010101010101010101015151515151515151515151515151515151515151515151515151515151515151
0100000000000000000000000000000101000000000000000000000000000001010000000000000000000000000000015200000000000000000000000000005001000000000000000000000000000000000000000000000000000000000000015200000000000000000000000000005052666800630000666768000900666850
0100000000000000000000000000000101000000090000000000000000000001010000000000000000000000000000015230531400000000330000000000305001000000000000000000000000000000000000000000000000000000000000015213000000000000000000000000005052747900630000767778000000767850
010000000000000000000000000000010100000000000000000000000000000101000000000000000001000000000001517171717d7d7d7e0000007c7d4d7d5d01000000000000000000000000000600000000000000000000000000000000015171727d7e6667676767680000000051520000007306007475797c7d7e747950
010000000000000000000000000000010100000101000000000000000000000101000000000020000101000000000001520000000000000000000000007f005001000000000000000000000000000202000000000000000000000000000000015200000000767777777778000000155052000000007072000000000000000050
01000000000000000000000013000001010000000000000000200000010000010100000000000000010100002000000152300000000033000000000000003050010000003033000000000000003000000000000000000000370000300000000152000000007475757575797c7071715052150000000000000000000000000050
0100000000000000515151515151515151000000000000000000000000000001010000000101000001000000000000015200000000007c7d7d4d7d7d7d7d7d5d010000000000000000000000005d0000000000000000000000000000000000015200000000000000000000000000005051460000000000000000666768000050
0100000000000000510000000000000000000000000000000000000000000001010000000000000001000000000000015200000000000000007f0000000000500100000000000000000000005d5d0000007d7d7d7d7d7d7d7d7d7d7d7d7d7d0152000000000000000000000000000050515e666768006667685f767778000050
010000000000000051000000000000000000000000000000000000000000000101000000000000000100200000000001523000003300000000000000000030500100303300000000000030005d5d000000002500000025000000000000000001520000004c5300000000534e00000050515e7475795f7677786f747579000050
010000000000000051000000000000000000000000000000010100000000000101000000000000000114005d005d00015d7d4d7d7d7d7d7d7e000000000000500100000000000000000000005d00000000000000000000000000000000000001520000006c6071717171626e00000050516d7d7d7d5e7475795c7d7d7e000050
0100000000000000000000000000000000000000000000000000000000000001010000000020000000015d015d015d0152007f000000000000000000000000500100000000000000000000005d000600000000000000000000000000000000015266676768000000000000666767685052000000006c7d4d7d6e000000000050
600000000000000000000020000000010100000001010000000000000020000000000000000000000000010001000101523033000000000000000000000030500100130000000000000000005d0202460000300000003000000000000000000152767777780000000000007677777850520000000000007f0000000000000050
010000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001520000000000004c7d7d4d4d7d4d7d5d0100404200000000000000005d0000007d7d7d7d7d7d7d7d7d7d7d00000000015276777778000000090000767777785052130000000000000000000000407151
010000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001520000000000006f00007f6f007f00500100606200000000000000005d000000000000000000000000000000000027015276777778000000000000767777785051426667685f6667685f6667685c7b51
010000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000001520013000000006f0000007f000000500100000000000000000000005d0014007d7d7d7d7d7d7d7d7d7d7d00000000015274757579000006000000747575795051527475796f7475796f7475795c7b51
010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101517171717171717171717171717171510101010101010101010101010101010101010101010101010101010101010101514c5d5d4e4071717171424c5d5d4e5151514d4d4d5d4d4d4d5d4d4d4d5d7b51
01010101010101010101010101010101010101010101010101010101010101010101010101010101010101015d01010101010101626d6d6d6d6d6d6d6001010101010101010101010101010101010101010101010101010101010101010101015151515151515151515151515151515151515151515151515151515151515151
0100000000000000000000000000000000000000000000000000000000000001015d5e0000000000000000007f000000006309000000000000000000000000500100000000000000000000000000000101000000000000000000004f000000015200666767680000000000000000000000000000000000000000000000000050
0100000000000000000000000000000000000000000000000000000000000001015d6e0000000000000000000000000000630000000000000000000000000050010000000000000000000000000000010100000000000000000000004f0000015200767777780000000000000000000000000000000000000000004c4d4e0050
01000000000000000000000000000000000000000000004c4e00000000000001015e00000000000000000000000000000063000000000000000000000000005001000000000000000000000000000001010015000000000000000000004f00015200767777780000000000000000000000000000000000530000005c5d5e0050
01000000000001010101010101010100000000060000005c5e00000000000001015e0000005f0000000000005f00000000630000002800005f00000000004c010100000000000000000000000000000101000101001300000000000000004f015200747575790000000006000000000000000000000000630000006c6d6e0050
5e0000000000010101016d6d6d6d5d01010101010101016d6e00000000000001015e0000006f0000000000006f00001300505600000000005c4d7e00007c6d0101000000000000000000000000000001010000010101010000000000000000015200000000000000007071720000000000000000000000730000000000000050
5e666768000000000000000000005c0101000000000000000000006667676801016e00004c5e00004457574d6d57020247015d7d7e007c7d6d5e000000000050010000000000000000000000000000010100000000000000000000000000000152005f0000000000000000000000000044454600000000000000000000000050
5e767778000000000028000027005c0101000000000000000000007677777801010000005c5e00006c6d6d5e000000006c6d6e0000000000006f00000000005001000101001300000000000000000001014f000000000000000000000000000152007f0000007c7d7e0000000000000000000000000000000054455600000050
5e7475790000010101014e0000006c0101000000000000000000007475757901010000005c6d7d7e0000007f000000000000000000000000005c7d7e00007c010100000101010100000000000000000101004f00000000000000000000000001524e00000000000000000000004f000000000000000065000060516200000050
5d7d7d7d7d7d6d6d6d6d6e00000000010100000000000000004c4d4d4d4d4d010100007c5e00000000000000000000000000000000000000006f000000000050010000000000000000000000000000010100004f000000000000000000000001525e004000420000000000000000000000000000640073000000730000000050
010000000000000000000000000000010101010101000000006c6d6d6d6d5d01010000007f0000000000000000000000005f000000060000005c7d7d7e0000500100000000000000000000000000000101000000000000000000000000000001526e005051520000000000000000004300000000000000000000000000000050
0100000000000000000000000000000101000000000000000066680066685c0101000000000000000000000000000000006f000047715700006f00000000005001000000000000000000000000000001010000000000000000000000000000015200006000620000000000000000000000000000000000000000000000000050
010000000000000000005f6667685f0101000000000000000076780976785c0101000000000000060000005f00474746006f00006f000000006f005f0015005001000000000000000000000009000001010000000000000000000000000000015200000000000009000000000000000000000047470057570048480058580050
010000000000000000006f7677786f0101000000000000000074790074795c01014747465f0047474600006f00006f00006f00006f005f00006f005c4771577b01000000000000000000000202020001010000000000000000000001010101015200000000000000000000000000000000000000000000000000000000000050
010000130000000000006f7475796f0101000015000000004c4d4d4d4d4d5d01010000006f00006f00004c5d4e006f004c5d4e006f4c5e004c5d4d5d7b7b5d7b01000000000000000000000000000001010000000000000001000000000000015200000000001300150000000000000000000000000000000000000000000050
010101010101010101015d4d4d4d5d0101010101010101010101010101010101014d4d4d5d4d4d5d4d4d5d7b5d4d5d4d5d7b5d4d5d5d5d4d5d7b7b7b5d5d7b5d01000000000000000200000000000001010000000000000001000000000000015171717171717171717171717171717171717171717171717171717171717151
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
00030000146501563014620186201f620206101461014610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00001c700260002c7000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
