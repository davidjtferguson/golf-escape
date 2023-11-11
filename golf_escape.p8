pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- golf escape

function _init()
 --constants
 pixel=0.125
 
 gravity=0.009
 
 treadmillspeed=0.020
 
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
 
 factoryx,factoryy=768,256
 --vars

 pausecontrols,pausecamera=false,false
 endingtransition=false

 --checkpoint
 xcp=0
 ycp=0
 cpanim=makeanimt(23,10,3)
 
 --hack for top corner collision
 topcoloverwrite=false
 --lvlhasmovinghooks=false

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
 
 --
 currentupdate=updateplaying
 currentdraw=drawplaying
 
 initlevels()
 menuitem(1,"skip level", skiplvl)
 --]]

 --initstartscreen()

 aim={
  points={}
 }
 
 --game object tables
 corpses={}
 
 --stats for end screen
 deathcount,lvlsskipped,totalswingcount,lvlswingcount=0,0,0,0
 frames,seconds,minutes,hours=0,0,0,0
end

function _update60()
 currentupdate()
  
 --debug=stat(7)..".."..stat(1)
end

function updateplaying()
 if currentupdate!=updateending then
  updateplaytime()
 end

 updatebackgrounds()

 if not pausecontrols then
  handleswinginput()
 end

 --collision
 if currentupdate!=updateending and av.respawnstate=="alive" then
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

  if av.respawnstate=="alive" and circlecollision(av,h) and
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
 
 if av.respawnstate=="alive" then
  --acid
  if anycol(av.hurtbox,0,0,4) then
   sfx(5)
   deathcount+=1

   --could improve how in the acid this is somehow
   createcorpse(av.x-(2*pixel)+av.xvel,av.y-(2*pixel)+av.yvel)
   
   initburst(av.x,av.y,deathcolours)
   
   av.respawnstate="dead"

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
  end
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

 if not pausecamera then
  updatecamera()
 end

 updatecorpses()

 updateanims()
 
 updateparticleeffects() --tab 6
 
 --do last to know how much
 -- cpu space is left
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

 print(debug,cam.xfree*128,cam.yfree*128,7)
 
 print(debug,factoryx,factoryy,7)
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

 if av.canswing and not av.dancing and av.respawnstate!="dead" then
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

 --av draw
 -- -2 for sprite offset
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

function drawaim()
 linecol=13
 
 if swing.currdecaypause>0 then
  linecol=6
 end
 
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

function drawav()
 spr(av.anim.sprite,
  ((av.x-(2*pixel))*8),
  ((av.y-(2*pixel))*8),1,1,av.xflip,av.yflip)
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

    av.colstate="ground"  
    
    av.xvel=0
    av.yvel=0
    
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
	 if allleftcol(av,av.xvel,0,0) then
	  --should move av to wall but w/e
	  av.xvel=0
	 end
 
	 if allrightcol(av,av.xvel,0,0) then
	  --should move av to wall but w/e
	  av.xvel=0
	 end
 end
end

--allcollision
function anycol(box,xvel,yvel,flag)
 return checkanyflagarea(box.x+xvel,box.y+yvel,box.w,box.h,flag)
end

function allcol(box,xvel,yvel,flag)
 return checkallflagarea(box.x+xvel,box.y+yvel,box.w,box.h,flag)
end

function getcollisionpoints(box,xvel,yvel)
 return box.x+xvel,box.y+yvel,box.w,box.h
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

  --if the distance gets longer than a tile,
  -- something's wrong. abort.
  -- (hack - ideally would never occur)
  if abs(distancetowall)>1 then
   debug="collision hack hit!"
   return distancetowall
  end

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
 --only for checkpoints :/
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
  --controls tutorial
  --{xmap=4,ymap=1,w=1,h=2},
  
  --bunkers
  --bunker tutorial
  --{xmap=0,ymap=0,w=1,h=1},
  --bunker tutorial 2
  --{xmap=1,ymap=0,w=1,h=1},
  --static swing power test
  --{xmap=3,ymap=2,w=1,h=1},
  --bounce off walls
  --{xmap=7,ymap=2,w=1,h=1},

  --belts intro
  --convayer belts
  {xmap=3,ymap=3,w=1,h=1},
  --convayers and bunkers
  --{xmap=2,ymap=1,w=2,h=1},
  --belt maze (to be re-done)
  --{xmap=6,ymap=1,w=2,h=1},

  --slows intro
  --slows tutorial
  --{xmap=6,ymap=0,w=1,h=1},
  --wide slows (redo)
  --{xmap=0,ymap=1,w=2,h=1},
  --zig-zag slows
  {xmap=1,ymap=2,w=1,h=1},
  --float zone 3x3
  --{xmap=7,ymap=0,w=1,h=1},
  --float climb
  --{xmap=2,ymap=2,w=1,h=2},

  --hooks intro
  --moving hooks (redo)
  --{xmap=1,ymap=3,w=1,h=1},
  --hook maze newer
  --{xmap=2,ymap=0,w=1,h=1},
  --mover hooks horizontal
  --{xmap=3,ymap=0,w=1,h=1},
  --hook maze older
  --{xmap=0,ymap=3,w=1,h=1},
  --mover hooks horiz&vert
  -- (redo)
  --{xmap=0,ymap=2,w=1,h=1},
  --tall moving hooks climb
  {xmap=5,ymap=1,w=1,h=2},
  --both hook types (redo)
  {xmap=4,ymap=0,w=2,h=1},

  --player knows all mechanics
  --important plob level (replace)
  {xmap=4,ymap=3,w=1,h=1},
  --final gauntlet (todo)
  {xmap=5,ymap=3,w=3,h=1}
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
  lowf=0.205,
  highf=0.45,
  btnf=0.04,
  lowrotangle=1/1200,
  highrotangle=1/300,
  rotanglevel=1/3600,
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
    currlvl.xspawn=x
    currlvl.yspawn=y

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

function skiplvl()
 lvlsskipped+=1
 nextlevel()
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
   av.x=xcp+pixel*2
   av.y=ycp+pixel*2
   
   sfx(13)

   initcollect(av.x+(2*pixel),av.y+(2*pixel),avcolours)

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

   --if we're running out of cpu,
   -- don't check every position.
   if stat(1)<0.5 or stat(1)>=0.5 and #aim.points%3==0 then
    resethurtbox(aim)

    --simulate av collision
    if anycol(aim.hurtbox,aim.xvel,aim.yvel,4) then
     wallhit=true
     aim.hitdeath=true
    end

    if groundcol(aim,0,aim.yvel,0) or
       topcol(aim,0,aim.yvel,0) or
       leftcol(aim,aim.xvel,aim.yvel,0) or
       rightcol(aim,aim.xvel,aim.yvel,0) or
       #aim.points>100 then
     wallhit=true
    end
    
    --Don't check every point against hooks,
    -- and stop checking if out of cpu budget
    -- because of performance issues.
    -- not ideal.
    --aim count is hack to prevent collision with hook when on hook
    if #aim.points>2 and #aim.points%3==0 and stat(1)<0.3 then
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

function drawtutorialtext()
 local xorigin,yorigin=4*128,1*128
 local c1,c2=0,7
 outline("⬅️ aim ➡️",xorigin+11.3*8,yorigin+5.5*8,c1,c2)
 outline("swing 🅾️",xorigin+6*8,yorigin+0.5*8,c1,c2)
 outline("charge ❎",xorigin+0.2*8,yorigin+13.5*8,c1,c2)
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
 resetav()
 
 av.x=(6*16)+1.5
 av.y=(2*16)+1
 
 currentupdate=updatestartscreen
 currentdraw=drawstartscreen
end

function updatestartscreen()
 updatebeginning()

 if btnp()>0 and av.colstate=="ground" then
  initintro()
 end
end

function drawstartscreen()
 drawbeginning(false)

 if av.colstate=="ground" then
  s="i must save the worms!"
  outline(s,
   factoryx+hw(s),factoryy+48,0,7)

  s="press any button"
  outline(s,
   factoryx+hw(s),factoryy+72,0,7)
 end
end

function initintro()
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

  if introtimer>=100 then
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
   sfx(9)
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

 --circfill(introwindow.x*8,introwindow.y*8,introwindow.r,2)
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
 currentupdate=updatelvlend
 currentdraw=drawlvlend

 pausecontrols=true
 pausecamera=true
 av.dancing=true
end

function updatelvlend()
 updateplaying()

 --next level
 if btnp(🅾️) then
  totalswingcount+=lvlswingcount
  lvlswingcount=0

  inittransition({0},backtoplaying,nextlevel)
 end

 --reset level
 if btn(⬅️) and btn(❎) then
  inittransition({5,0},backtoplaying,resetcurrlvl)
 end
end

function resetcurrlvl()
  lvlswingcount=0
  
  --is duplicated could use function
  if currlvl.haskey then
   currlvl.exit.s=21
   currlvl.key=resetkey(currlvl.key.spawnx,currlvl.key.spawny)
  end

  --is duplicated-could use function
  if not isspawn(xcp,ycp) then
    mset(xcp,ycp,6)
  end  

  xcp=currlvl.xspawn
  ycp=currlvl.yspawn
  
  resetav()
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
 
 s="next level 🅾️"
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

 menuitem(1)

 --factory external
 currlvl.xmap=6
 currlvl.ymap=2
 currlvl.w=1
 currlvl.h=1
 currlvl.haskey=false
 
 --todo:push open door
 -- into map
 --currlvl.exit.s=20
 
 av.x=(currlvl.xmap*16)+8
 av.y=(currlvl.ymap*16)+15
 
 updatecamera()

 pausecontrols=true

 -- go through greyscale colours expanding from top
 -- until on white, then initfade
 inittransition({0,5,6,7},backtoending,nextlevel)
end

function backtoending()
 ycredits=-64
 
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

 if ycredits<32 then
  ycredits+=0.25
 end
end

function drawending()
 drawplaying()
 
 --credits
 
 local c1,c2=0,7
 
 s="i must save the worms!"
 outline(s,
  factoryx+hw(s),factoryy+ycredits,c1,c2)
 
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
 e.x=x*8
 e.y=y*8

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

--todo:use for opening cutscene
-- after entering factory, in from black
function initfade(x,y,col)
 local e=createeffect(updatedustkick)
 e.front=true

 --create a bunch of particles
 for i=-1,16 do
  for j=-1,16 do
  
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

__gfx__
00066000000000000000000000000000000000000000000000000000eeeeeeee88666688000dd000000dd0000000000000040400004004000040400000400400
00066000000660000000000000000000000000000000000000702200eeeeeeee8656656800dddd0000dddd0000000000000ff000000ff000000ff000000ff000
000660000008dd6006d8e0d000000000000000000000000000712200eeeeeeee64456446677dd777677dd7770000000004f1f100001f1f00001f1f4000f1f100
0006600000ded80000dddd0000000000000000000000000000712200eeeeeeee65566556600700076007e0e70000000000fffe0000feff0000efff0000ffef40
0666666000dddd0006d8ddd000000000000000000000000000710000eeeeeeee644654467807e0e7708708070000000000fffff004ffff000fffff0000ffff00
05666650000ddd00000dd60000000000000000000000000000700000eeeeeeee6556655678070807780708070000000000f0000000f00f0000000f0000f00f00
005665000060d0000000000000000000000000000000000000700000eeeeeeee6445644660878007608780070000000000000000000000000000000000000000
00055000000000000000000000000000000000000000000000700000eeeeeeee6556655666777766667777660000000000000000000000000000000000000000
00000000e0e000000000000000666600006666000066660006600000000000000000000000000000000000000000000000000000000000000000040400000000
0000660008000000e0e000000611116006ccac60065555606766000000707700007007000070000000000000000040400000404000004040000007f700004040
000066600800000008000000611111166ccacac665e5e55667770000007677000076770000767700000000000040fff00040fff00040fff00000717100000fff
666666660800080080088000611111166cccaca6655855560770000000767700007677000076770000000000000f1f10000f1f10000f1f100040f7e70400f1f1
555566650088800080800800611111166ccacac6655855560000022000760000007670000070670000000000040ffe000f0ffe00040ffe00040fff0000ffffe0
000066500000000080080000611111166cccccc6655855860000282200700000007000000070000000000000f04ff000004ff000400ff000f04ff000400fff00
000055000000000008800000611111166cccccc665558856000028880070000000700000007000000000000000000000040000000f0000000000000004ff0000
000000000000000000000000611111166cccccc66555555600000880007000000070000000700000000000000000000000000000000000000000000000000000
00044000000aa0000004aa00000440000004400000044000000440000004400000aa400000000000000000000000000000000000000000000000000000404000
00444400004aa4000044aa000044aa0000444400004444000044440000aa440000aa4400000000000004040000040400000404000004040000040000000ff000
0044440000444400004444000044aa000044aa00004aa40000aa440000aa440000444400041f14f000f1f0000000fff00000fff00000fff0040ff00000f1f100
000440000004400000044000000440000004aa00000aa00000aa400000044000000440000ffeff0000ff1000004f1f10004f1f10004f1f1000f1f10004fffe00
00d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000fff00000fe0000040ffe008f0ffe00040ffe0000fffe0000ffff00
0d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d0000f040000ff0000f04ff000804ff000408ff00004fffff000f0f000
d000000dd000000dd000000dd000000dd000000dd000000dd000000dd000000dd000000d00000000000ff00088000000040000000f8000000000000000000000
66666666666666666666666666666666666666666666666666666666666666666666666600000000004000000000000000000000000000000000000000000000
0000000000077000000c7700000cc000000cc000000cc000000cc000000cc0000077c000d2222222222222288888822200000000000000000000000000000000
000ee00000c77c0000cc770000cc770000cccc0000cccc0000cccc000077cc000077cc00da5a555555555522822225220404000000000000000f0f0000040000
00e72e0000cccc0000cccc0000cc770000cc770000c77c000077cc000077cc0000cccc00d5a55aa555a55a5a2aa5aaa200fff00004f1e00000fff0000f0fff00
0e7222e0000cc000000cc000000cc000000c7700000770000077c000000cc000000cc000da5a5a5a5a5a5a5a5a55a5a200f1f10000ffff0000ffff0000fff140
0e2222e000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0025555aa55a5a5aaa5aa5aa2204ffef00041fff00001fef0000ffff00
00e22e000d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d00d0000d0d2555a5555a55aaa5a55a5a200fff00000fff0f004ff1000000e1f40
000ee000d000000dd000000dd000000dd000000dd000000dd000000dd000000dd000000ddd222555555522222aa5a2220f0f0000000040000004400000000000
0000000066666666666666666666666666666666666666666666666666666666666666665dd52222222255552222225200000000000000000000000000000000
0222222200000000222222200222222009aaa9a9aaa9aaaaaa9a9aa0aaa9aa9ad666666600000000000000006666666600000000000000000000000000000000
228882880000000082888282258882822a9a9a499a4a549a9a45a49a29dad6a92dddd6d60000000000000000655555560049bbbbbbbb44949bbbbb0000bbbb00
2588828800000000858882822588828222888588828885888288828227766c7627766c760000000000000000651155160bbbb3393433333333333bb00b3343b0
255522220000000025552222255225522222222222555522555522222cccccc72cccccc70000000000000000651115110b33333333333333333334b00b3333b0
285888280000000088588822285888522828885888588828885888522cccccc22cccccc20000000000000000655111110b33333343b333333b3333b00b3333b0
2858882800000000885888222828885228288858882888288828885222222c2622222c260000000000000000655511110b33333333333333333333b004b339b0
2828885800000000882888222828885228288858882888288828882225ddd2d625ddd2d60000300000003000615511110b33b33333333333333339b000bbbb00
222222550000000022222222022222200222222222222222222222202222222d2222222d0303333300003330611111110b43333bb333333bb33b33b000000000
228882888288828882888282022222200aaa9aaa00000000aa9aaaa0a9a9aa9a6666666d3b333b3300000022220000000b33333bb333333bb33333b000000000
22888288828885888288828222888282a9a44a59000000005aa4a95aa9aad9d26d6dddd2333b333b00000225522000000b333b333333b333333393b000bbbb00
22888588828885888588858222888582228882880000000082888282678667726786677233b333b300002258852200000b33333333333333333333b00b3bbbb0
2555555222555552555555522555555222222222000000002225555278888882788888823333333300222555555222000b333333b3333393333333b00b333b40
2858885888588828885888522858882228288828000000008858885228888882288888823b3333b300255885885552000433333333333333333333400b333bb0
285888288858882888588822282888222828882800000000885888226282222262822222b3333b33022588858858522004333933333433333b3333300b333bb0
282888288828882888288822282888222858882800000000885888226d2ddd526d2ddd52333b333322558885885885220b33333333333333333333400b3333b0
22222222222222222222222222222222225555520000000022222222d2222222d222222233b3333325555555555555520b33333bb333333bb33333400b3333b0
228882880000000082888582228885820aa9a4a00aaaaa9000cccccccccccccccccccc008588858802000020666666660b33333bb333333bb33333b00b3333b0
25888288000000008288858222888582a94aaa5aa9a49a590c111111c1c1c1c1c1c1c1c08588858802555520655555560b3333333b333333333343b00b3333b0
258882880000000082888582228885822588828222888582c11111111c1c1c1c1c1c1c1c8588858802588520655555560b433333343333333b3333b0043b3390
255522220000000022225552225555522555222222225552c111111111c1c1c1c1c1c1cc5555555502588520655555560b33339333333393333333b0043333b0
285888280000000088288822285888222858882228288852c1111111111111111c1c1c1c8858885802588520655555560b33333333333333333333b00b3333b0
285888280000000088288822282888222828882228288852c1111111111111111111c1cc8858885802555520655555160b43333333333333339334b00b3333b0
282888280000000088288822282888222828882228288822c11111111111111111111c1c8858885802588520655111160044bbbbbbbb49444bbbbb000b3334b0
022222220000000022222220222222220222222022222222c1111111111111111111c1cc5555555525555552666666660000000000000000000000000b3333b0
02222222222222222222222025888282c111111111111111c11111111111111111111c1c1111111c15000000333333330000000000000000000000000b33b3b0
22888288858885888588828225888282c111111111111111c1111111111111111111c1cc1111111c555000003333343300b4bbbbb4bbbbbbbbbbbb000b3333b0
22888588858885888588858225888282c111111111111111c11111111111111111111c1c1111111c00000500333333330b333333bbbb3333393b33400b333340
22225555252255222555552225552222c111111111111111c1111111111111111111c1cc1111111c0555555033933b330b3333333333333b333333b009333340
28288858882888288858882228588822c111111111111111c11111111111111111111c1c1111111c00511500333333430b333b3333333333333333b0043333b0
28288858885888288828882228288822c111111111111111c1111111111111111111c1cc1111111c00511500333433330b3333333333333333b334b0043333b0
282888288858882888288822282888220c11111111111111c11111111111111111111c1c111111c0055555503b3333330043494bbb4944bbbbbbbb0000bbbb00
0222222222222222222222200222222000ccccccccccccccc111111111111111111111cccccccc00000000003333333300000000000000000000000000000000
25700000000615151515151515151515d5d51515d6d6d61515151515151515151515151515151515151515151515151515151515151515151515151515151515
d4e4000000000000c7d7d7d4d7d4d41525000300071717d6d5b7b7e5030003c50000000000000000a60000000000000015151515151515151515151515151515
25000000000000000000000000000005d5e66676767686000000000000000515250066860000c6d6e60000000000000525000000000000000000000000000615
d5d5d4e400000000000000f700c6d5152500000000000003c6d5b7e5000000c500000000000000a596b5a6000000000015152600000000000000000000000005
25410003003300000000000003020306256677777777870000900000000005152500479700667686000000000090000515e40000000000000000000000900005
1515152500000000000000000000c605250000000000001300c6b7e5030003c500000000a6a6a596969696b50000000015260000000000000000000000000005
1517e400000003f5330000000000340325677777777787000000006000000515250000c7e4475797000000006000000515e50000000000c4d7e7000000600005
15151525000000f5000000009000000525000000000000000000c6e5000000c5000000a59696969696b4b696b500000025000000000000600000003500000005
1515d6d7d7d7d7e60000c7e40000c7d42547575757579700c4d4d4041717151525668600c5d7d7e7000000000417171515e500410000c4e60000002200445415
151515250000003500000000000000052500530000000000000003f6000000c50000a5969696969696b6b69696b50000250000000000004564000036e4000005
2500000000000000000000360000000525000000c4d4e400c5b7b7d5d6d6d5d525479700f700000000000000f700000515d6e746c7d7e6000000000000000005
151515250000003600000000000000052500030000000000000000c5e70000c500000096969693a3b396969696000000250000000000042600000036e6000005
2503000000003300000003360000000525000000c6d6e600c6d6d6e66686c6d52500000000000000000000f50000000525000000000000000000000000000005
151515260000003600000000071717152500000000000003f4000036000000c50000009696969696969696969600000025000007171725000090003600000005
25000000c7d4d7d7d7d7d43600000005256676768600006686000066777786052500006676860000000000f7000060052500000000000000c4e40000c4e40005
1515250000000036000000000006151515d4d4d4d7d4d7e703001336000000c500000096b6b69696969696969600000025000000000036000000003600000005
2500000000f700000000c6d5e70000052567777787000067870000677777870515e4006777870000000000667686071525000000000000c4d5e54565c5d5e405
1515260000000036000000000000061515b7b7e503f7030000000036000000c500000096b6b696969696b6b69600000025000000000036000000c4e600000005
250300003300000000000336000000052547575797c4e447970000475757970515e500475797000000000067777786c525000000000044151515151515151515
15250000000000360000000000000005151515260000000000000336000000c500000096969696969696b6b696000000250000000000055465d7e60000000005
25d7d4d7d7d7e7000000003600000005d5d7d7d7d7d6d6e700c7e7000000000515d5d4d7d7d7e70000000047575797c525000000000000000000000000000005
152600000000003600000000000000052500000000000000000000360000c7d5000000969696b6b6969696969600000025000000000005152500000000600005
2500f700000000000000003600000005250000000000000000000066767686051515260066768600000000000000c4d525000000000000000000000000000005
2500000000000006172700000000000525000000130013001300003613001305000000969696b6b6969696969600000025000007171715152500000044545415
2503330000000000000003360000c7d5250000000000000000000067777787051526000067778700000000667686c51525000000000000000000000000000005
2500000000000000000000000000000525000000000000000300c425009000050000009696969696969696969600000025000000000000052500000000000015
25000000000000c4d4d7d4361390130525003100000000f566860047777797052500000047579700000000677787c51515650000000000000000350031000415
15240000000000000000000000000415250031000300030000c4d525030003059400009696969696809696969600a40025000000000000052500000000000005
25000031000000f6f700f6360360030515171724005100354797c4e44797c4d525000000000000000000f5475797c51515151724d4d4d4d4d4d4151717171515
1515240051000000000000000004151515171717d4d4d4d4d4d5b725006000059595959595959595959595959595959525000031000000c5e500000000410005
15171717171717171717d515171717151515151517171725d4d4d5b7d4d4b7d5250000006686f5000000c6d7d7d7d61515151515151515151515151515151515
15151517171717171717171717151515151515151515151515151515171717159595959595959595959595959595959515d4d4171717d4d5d5d4d4d445545415
1515151515151515151515151515151570151515151515151515151515151515256686004797f7000000000000000005b7d5b7b7d6d6d6d6d6d6d6d615151515
70151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515
2500000000c6d5360000000000c6d5051500000000000000d5d5d5000052001525479700000000000000000000000005b7b7d5e6000000000000000000000005
150000000000000000000000b7b7b715150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015
250000000000c637004100000000c60515000000000000000000d5000000001525000000000000000000000000000005b7d5e600000000000000000000000005
150041000054540000000000b7b7b715150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015
25000000000000c6171717270000000515000000000000000000000000000015256676768600000000006686f5668605b7e500000000c4d4e400000000000005
15151515001500150000000000000015150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015
2500000000000000f600000000000005150000410000000000000000000000152567777787c4e70000004797f6479705d5e60085858585d6d685858500006005
15151515001515000000000000000015150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015
25000000f4000000c5e7000000000005151515151515d50000000000000000152567777787f600000000c7d7e6000005e64100c5b7e500000000000022000715
1515151500150015b700000000000015150000000000000090000000000000000000000000000000000000000000000000000000000000000000000000000015
2500000000f50000f700000000000005150000000000d5009000000000000015254757579736000000000000000000051717858585250000000000000000c5b7
15b7b7b7b715150000b7006000000015150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015
2500000000f60000000000000012c405150000000000d5001200d50000000015250000000036000000000000000000052500000000370000000000000000c5b7
15000000b70000000000b75454000015150031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015
2500000000f6000000000012c7d4d505150000000000d5d5d5d5d50000000015250000000425000000f56676767686052500000000000000000000000000c5b7
15000031b70000000000150000150015151515000000000000001515000015150000000000000000000000410000000000000000000000000000000000000015
251200f400f600000000000000c6d50515000000000015151515d50000000015250060000525000000f64757575797052500000000000000c4d4848484848484
15001515b70000000000150000150015150000000000000000000000d5d500000000000000000000000015151500000000000000000000000000000000000015
25d4e70000f6000000f400000000c60515003200000000000000d50000000015151717171525510000f60000000000052500000084848484d5e6000000000005
15001500150000150000150000150015150000000000000000000000000000000000000000000000000015151500000000000000000000000000000000000015
25e6000000f600004200f400000000051500000000d500000000d50000000015151515d6d615270000f76676767686c525000000000000c6e500000000000005
15001500150000150042001515001215150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015
2500000000c5e40000000000008200051500000000d500003200000000020015150000000000000000006777777787c52500000000000000f700000000000005
15001515000000150000000000000015150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015
252200f500c5d5e4000000000000c4151500000000d500000000000000000015150000000000000000006777777787c51517240000000000000000f500310005
15001500000000151515003222000015150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015
2531c4e512c5d5d5e400000000c4d5151500003100d5d5d5d5d5d500000000151500003100c4e400c4e44757575797c5151515d4d48585858585858517171715
15000000006000b7b7b7b7b7b7b7b715150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000015
1524c5d5d4e5c5d5d5d4d4d4d4d5d515151515151515151515151515151515151517171724c5e535c5e5c4d4d4d4d4d5151515b7b71515151515151515151515
15151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515
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
0000000000002000009090000000000000000082a0a000202020000000000000081838286848c8889800000000000000f11939296949c989990000000000000001000101414141430300000010101010010101014100414505010000101010100101010141414040400000001010101001010101404040404040001010101010
0101010101010101000000000000000001010101010101010000000000000000010101010101010100000000000000000101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
5d6d6d6d6d6d5151515d5d515151515d7b5d6d6d6d6d6d6d6d6d5d515151515d515151515151515d5d5d5151515151515151515151515151515151515151515107515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151515151
5e00000000000000006c6e000000005c5d6e00000000000000007f000000005c520000000000006c6d6e0000000000505200000000000000000000000000005051000000000000000000000000000000000000000000000000000000000000515200000000000000000000000000005052666800630000666768000900666850
5e00000000000000000000000000005c5e00000000000000000000000000005c520000000000000025000000000000505230531400000000330000000000305051000000000000000000000000000000000000000000000000000000000000515200000000000000000000000000005052747900630000767778000000767850
5e00000000000000000000001400005c5e00000000060000004c4d4e0000145052001400000000000000000006000050517171717d7d7d7e0000007c7d4d7d5d510000000000000000000000000006000000000000000000000000000000005152130000006667676767680000000051520000007306007475797c7d7e747950
5e00004c71420000007c7d5445564d5d5e000000404200007c6d516d7e44455151717142000000000000000040420050520000000000000000000000007f005051000000000000000000000000004545000000000000000000000000000000515171727d7e767777777778000000155052000000007072000000000000000050
5e09006c5d6e00000000006051626d5d5e0009005c5e0000000073000000005c516d6d6d4e00000000004c7d6d6e005c52300000000033000000000000003050510000003033000000000000003000000000000000000000370000300000005152000000007475757575797c7071715052150000000000000000000000000050
5e0000006f000000000000000000005c5e0000005c5e00000000000000000050520000006c4e000000006f250027005c5200000000007c7d7d4d7d7d7d7d7d5d510000000000000000000000005d0000000000000000000000000000000000515200000000000000000000000000005051460000000000000000666768000050
5d5600006f000006000000000000005c5e0000005c5e0000000000000000135052000000006f002100216f000000005c5200000000000000007f0000000000505100000000000000000000005d5d0000007d7d7d7d7d7d7d7d7d7d7d7d7d7d5152000000000000000000000000000050515e666768006667685f767778000050
5d6d7d4d6d7d70424d5446000000005c5e0000005c6e0000000000000070715152000000256f000000006f000000215c523000003300000000000000000030505100303300000000000030005d5d000000002500000025000000000000000051520000004c5300000000534e00000050515e7475795f7677786f747579000050
5200007f0000006c6e007f000000005c51564d7d6e00000000004c7d4e00005c52001300005c4e0009006f000000005c5d7d4d7d7d7d7d7d7e000000000000505100000000000000000000005d00000000000000000000000000000000000051520000006c6071717171626e00000050516d7d7d7d5e7475795c7d7d7e000050
5200000000000000000000000000005c516d5e0000000000004c53006c7d4e5c51717142006c5d4e004c6e2300214c5d52007f000000000000000000000000505100000000000000000000005d000600000000000000000000000000000000515266676768000000000000666767685052000000006c7d4d7d6e000000000050
5200000000000000000000000000005c52006f0000000000006c520000006c5d5d6d6d6e00006c6d7d6e00007c7d6d5d523033000000000000000000000030505100130000000000000000005d4545460000300000003000000000000000005152767777780000000000007677777850520000000000007f0000000000000650
5213005f0000005f0000004c40424d5d52007f000000000000005c45424d4d5d5e250000270000002300000000000050520000000000004c7d7d4d4d7d4d7d5d5100404200000000000000005d0000007d7d7d7d7d7d7d7d7d7d7d00000000515276777778000000090000767777785052130000000000000000000000407151
5171715d4d40715d4d54455d51515d5d520000545600004042005c7b51517b7b5e007c7e00000000000000007c7e005c520000000000006f00007f6f007f00505100606200000000000000005d000000000000000000000000000000000027515276777778000000000000767777785051426667685f6667685f6667685c7b51
5151515d5d51515d5d51515d51515d5d52000050520000505200505151517b7b5e230000000000004c4d4e210000275c520013000000006f0000007f000000505100000000000000000000005d0014007d7d7d7d7d7d7d7d7d7d7d00000000515274757579000006000000747575795051527475796f7475796f7475795c7b51
51515151515151515151515d51515d5d514d4d51514d4d51514d517b51517b7b5d4d4d4d4d4d4d4d5d5d5d4d4d4d4d5d517171717171717171717171717171515151515151515151515151515151515151515151515151515151515151515151514c4d4d4e4071717171424c4d4d4e5151514d4d4d5d4d4d4d5d4d4d4d5d7b51
51515151515151515151515151515151515151515151515151515151515151515151515151515151515151515d51515151515151626d6d6d6d6d6d6d6051515151515151515151515151515151515151515151515151515151515151515151515251515151515151515151515151515151515151515151515151515151515151
5100000000000000000000000000000000000000000000000000000000000051515d5e0000000000000000007f000000006362000000000000000000000000505151626b6b6051515151624b6b605151520000000000000000000000000000505200000000000000000000000000000000005d0000005100000000000000005d
5100000000000000000000000000000000000000000000000000000000000051515d6e00000000000000000000000000006300090000000000000000000000505200006b6b0000000000006b6b006051520000000000000000000000002500505200000000000009000000000000000000005d0000005100000000000000005d
51000000000000000000000000000000000000000000004c4e00000000000051515e00000000000000000000000000000063000000000000000000000000005052000000000000000000000000000050520015000000000000000000000000605200000000001306001400000000000000005d0000005145450000000000005d
51000000000051515151515151515100000000060000005c5e00000000000051515e0000005f0000000000005f00000000630000002800005f00000000004c515200000000000000000000001300005051717142300000000000370000004330524848000000515151515d5d5d5d5d5151515d0000005d000000000048484850
5e0000000000515151516d6d6d6d5d51515151515151516d6e00000000000051515e0000006f0000000000006f00001300505656000000005c4d7e00007c6d51520000530000005300000040717171515d6d6d6d4d4e000000000000300030405200000000005d00000000000000005151005d0000005d00000000000000005d
5e666768000000000000000000005c5151000000000000000000006667676851516e00004c5e00004457574d6d57454547515d7d7e007c7d6d5e000000000050520000630000005071717151515151515e0030006c5e000030000000000000505200000000005d00000000005858585151485d4800005158585800000000005d
5e767778000000000028000027005c5151000000000000000000007677777851510000005c5e00006c6d6d5e000000006c6d6e0000000000006f0000000000505200006071717162000000000000605152000000007f000000000000000000505200000058585d000000000000000000000000000000005d000000000000005d
5e7475790000515151514e0000006c5151000000000000000000007475757951510000005c6d7d7e0000007f000000000000000000000000005c7d7e00007c5152000000000000000000000000000050520000000000000000004c4e350035505200000000000000000000000000000000000000000000000000004848484850
5d7d7d7d7d7d6d6d6d6d6e00000000515100000000000000004c4d4d4d4d4d515100007c6e00000000000000000000000000000000000000006f0000000000505200000000000000000000000600005052000000000000000000505e00007c5d5248480000000000000000585858585858585858585858585d0000005d000050
510000000000000000000000000000515151515151000000006c6d6d6d6d5d5151000000000000000000000000000000005f000000060000005c7d7d7e000050520000004071717142004071717171515200000000000000000050520000005c520000000000000000000000000000000000000000000000000000005d000050
5100000000000000000000000000005151000000000000000066680066685c5151000000000000000000000000000000006f000047455700006f000000000050520000005062000073007300006051515200000000000000000050520000005c52000000000000000000000000000048484848000000000000060000005d5d50
510000000000000000005f6667685f5151000000000000000076780976785c5151000006000000000000005f00474747006f00006f000000006f005f00150050520000006300000000200000000060515200000000007c4e000050520000005c5248484800005858584848480000000000005d0000006d6d5151510000005d50
510000000000000000006f7677786f5151000000000000000074790074795c51514747465f0047474700006f00006f00006f00006f005f00006f005c4745577b51717171524e00000000000000000050520035000000006f3500505d7e00005c5200000000000000000000000000004848484800000000000000000000005d50
510000130000000000006f7475796f5151000015000000004c4d4d4d4d4d5d51510000006f00006f00004c5d4e006f004c5d4e006f4c5e004c5d4d5d7b7b5d7b51515151625e00000000000000000050520030000000006f304c5d5e0000005c5200000000060000000000000000000000000000000000000000000000005d50
515151515151515151515d4d4d4d5d5151515151515151515151515151515151514d4d4d5d4d4d5d4d4d5d7b5d4d5d4d5d7b5d4d5d5d5d4d5d7b7b7b5d5d7b5d62000000007f00000000000000000050520000000600005c4d5d7b5e0000005c515d5d5d5151515d5d4848485d5d4848484848484848484848485d5d57575d51
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
7d17000018653000000e653000000e6530000000000186531f653000001a653000001a65300000000000000018653000000e653000000e6530000000000186531f653000001a653000001a653000000000000000
011700001c55600000000001c556000001d5561d5561d5561c556000001c55600000000001d5561c5561a55618556155560000015556000001555600000155561f556000001c556000001c5561c5560000000000
011700001c05600000000001c056000001d0561d0561d0561c056000001c05600000000001d0561c0561a05618056150560000015056000001505600000150561f056000001c056000001c0561c0560000000000
000300001c7131c7131c7231c7231c7331c7331c7431c7531f7632277323700000001670216702000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000900000e6000e6000d6000d6000d6002a1002610023100201001d1001b100260002700027000280002b0002c0002c00029000000002a0002a0002b000000000000000000000000000000000000000000000000
__music__
01 0a4b4344
00 0a0b4344
00 0a0b4344
00 0a0c4344
02 0a0c4344

