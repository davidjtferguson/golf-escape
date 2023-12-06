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
 diaghookspeed=0.035
 
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
 
 --
 currentupdate=updateplaying
 currentdraw=drawplaying
 
 initlevels()
 menuitem(1,"skip level", skiplvl)
 --music(7)
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

 --debug=stat(7)..".."..stat(1)..".."..#aim.points
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
   --normal land
   -- could have special
   -- hook land sfx?
   if not av.hook then
    sfx(8)
   end

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
 end

 --if we're still alive this frame, check other collisions
 if av.respawnstate=="alive" then
  --checkpoint
  if anycol(av.hurtbox,0,0,5) then

   --save key if held
   if currlvl.haskey and
    currlvl.key.collected then
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
   sfx(40)
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
  
  currlvl.key.x=av.x-(pixel*2)
  currlvl.key.y=av.y-(pixel*2)-(pixel*up)
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

 --draw bubble around av in slowzone
 if av.slowstate=="in" and
    av.colstate!="hook" then
  spr(26,(av.x-(2*pixel))*8,
  (av.y-(2*pixel))*8)
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
 -- -2 for sprite offset
 spr(av.anim.sprite,
  (av.x-(2*pixel))*8,
  (av.y-(2*pixel))*8,1,1,av.xflip,av.yflip)
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
  --{xmap=4,ymap=1,h=2},
  
  --bunkers
  --bunker tutorial
  --{xmap=0,ymap=0},
  --bunker tutorial 2
  --{xmap=1,ymap=0},
  --static swing power test
  --{xmap=3,ymap=2},
  --bounce off walls
  --{xmap=7,ymap=2},

  --belts intro
  --convayer belts
  --{xmap=3,ymap=3},
  --convayers and bunkers
  --{xmap=2,ymap=1,w=2},
  --belt maze
  --{xmap=6,ymap=1,w=2},

  --hooks intro
  --moving hooks
  --{xmap=1,ymap=3},
  --hook maze newer
  --{xmap=2,ymap=0},
  --mover hooks horizontal
  --{xmap=3,ymap=0},
  --hook maze older
  --{xmap=0,ymap=3},
  --diag mover hooks
  {xmap=0,ymap=2},
  --tall moving hooks climb
  --{xmap=5,ymap=1,h=2},

  --slows intro
  --slows tutorial
  --{xmap=6,ymap=0},
  --zig-zag slows
  --{xmap=0,ymap=1},
  --float zone 3x3
  --{xmap=7,ymap=0},
  --float climb
  --{xmap=2,ymap=2,h=2},

  --player knows all mechanics
  --belts and death hooks
  --{xmap=4,ymap=3},
  --wide slows with mover hooks
  --{xmap=4,ymap=0,w=2},
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
  h.yvel=-diaghookspeed
  h.xvel=diaghookspeed
  h.s=34
 elseif checkflag(x,y,5) and
        checkflag(x,y,6) then
  h.yvel=diaghookspeed
  h.xvel=diaghookspeed
  h.s=36
 elseif checkflag(x,y,6) and
        checkflag(x,y,7) then
  h.yvel=diaghookspeed
  h.xvel=-diaghookspeed
  h.s=38
 elseif checkflag(x,y,7) and
        checkflag(x,y,4) then
  h.yvel=-diaghookspeed
  h.xvel=-diaghookspeed
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
 
  lvlhasmovinghooks=true
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
   
   sfx(28)

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
  if introtimer>=200 then
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
   sfx(9)
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
 mset(104,45,7)
 
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
00066000000000000000000001111100111001100001110000000000886666888866668800044000000440000000000000040400004004000040400000400400
000660000006600000000000117777117711171001117710007022008615156886566568004444000044440000000000000ff000000ff000000ff000000ff000
000660000008dd6006d8e0d0177dd717dd717d101177dd1100712200644111466445644667744777677447770000000004f1f100001f1f00001f1f4000f1f100
0006600000ded80000dddd0017d11d17d171710017dd1771007122006551111665566556600700076007e0e70000000000fffe0000feff0000efff0000ffef40
0666666000dddd0006d8ddd0171177171171d71017777dd10071000064111116644654467807e0e7708708070000000000fffff004ffff000fffff0000ffff00
05666650000ddd00000dd6001771d77d77d11d7117ddd11000700000655111566556655678070807780708070000000000f0000000f00f0000000f0000f00f00
005665000060d000000000001d777d71dd1001d71711100000700000641414466445644660878007608780070000000000000000000000000000000000000000
00055000000000000000000001ddd1d11100001d1d71000000700000655555566556655666777766667777660000000000000000000000000000000000000000
00000000e0e00000000000000066660000666600006666000660000000000000000000000000000000cccc000000000000000000000000000000040400000000
0000660008000000e0e000000611116006ccac6006555560676600000070770000700700007000000c1111c0000040400000404000004040000007f700004040
000066600800000008000000611111166ccacac66515155667770000007677000076770000767700c111111c0040fff00040fff00040fff00000717100000fff
666666660800080080088000611111166cccaca66551555607700000007677000076770000767700c111111c000f1f10000f1f10000f1f100040f7e70400f1f1
555566650088800080800800611111166ccacac66551555600000220007600000076700000706700c111111c040ffe000f0ffe00040ffe00040fff0000ffffe0
000066500000000080080000611111166cccccc66551551600002822007000000070000000700000c111111cf04ff000004ff000400ff000f04ff000400fff00
000055000000000008800000611111166cccccc665551156000028880070000000700000007000000c1111c000000000040000000f0000000000000004ff0000
000000000000000000000000611111166cccccc6655555560000088000700000007000000070000000cccc000000000000000000000000000000000000000000
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
0222222200000000222222200222222009aaa9a9aaa9aaaaaa9a9aa0aaa9aa9ad666666655555550000555006666666600000000000000000000000000000000
22888288000000008288828225888282aa9a9a499a4a549a9a45a49a29dad6a92dddd6d65aa11ab05555d550655555560049bbbbbbbb44949bbbbb0000bbbb00
2588828800000000858882822588828222888588828885888288828227766c7627766c765aaa1a30555ddd50651155160bbbb3393433333333333bb00b3343b0
255522220000000025552222255225522222222222555522555522222cccccc72cccccc735a1a5005551dd50651115110b33333333333333333334b00b3333b0
285888280000000088588822285888522828885888588828885888522cccccc22cccccc2311a1a5055511d50655111110b33333343b333333b3333b00b3333b0
2858882800000000885888222828885228288858882888288828885222222c2622222c2651aa1150155bbb50655511110b33333333333333333333b004b339b0
2828885800000000882888222828885228288858882888288828882225ddd2d625ddd2d65aaaaabb11553bb0615511110b33b33333333333333339b000bbbb00
222222550000000022222222022222200222222222222222222222202222222d2222222d5555533b0b3553b0611111110b43333bb333333bb33b33b000000000
228882888288828882888282022222200aaa9aaa00555000aa9aaaa0a9a9aa9a6666666d5555555500000002200000000b33333bb333333bb33333b000000000
22888288828885888288828222888282a9a44a59055d55555aa4a95aa9aad9d26d6dddd25565555500000022220000000b333b333333b333333393b000bbbb00
228885888288858885888582228885822288828805ddd5558288828267866772678667725d55555500000228822000000b33333333333333333333b00b3bbbb0
255555522255555255555552255555522222222205dd15552225555278888882788888825555555500002222222200000b333333b3333393333333b00b333b40
285888588858882888588852285888222828882805d115558858885228888882288888825555556500022882882220000433333333333333333333400b333bb0
285888288858882888588822282888222828882805bbb55188588822628222226282222255555d55002288828828220004333933333433333b3333b00b333bb0
28288828882888288828882228288822285888280bb35511885888226d2ddd526d2ddd525555555502228882882882200b33333333333333333333400b3333b0
22222222222222222222222222222222225555520b3553b022222222d2222222d22222225555555522222222222222220b33333bb333333bb33333400b3333b0
228882880000000082888582228885820aa9a4a00aaaaa9000cccccccccccccccccccc008288828802000020666666660b33333bb333333bb33333b00b3333b0
25888288000000008288858222888582a94aaa5aa9a49a590c111111c1c1c1c1c1c1c1c08288858802555520655555560b3333333b333333333343b00b3333b0
258882880000000082888582228885822588828222888582c11111111c1c1c1c1c1c1c1c8288858802588520655555560b433333343333333b3333b0043b3390
255522220000000022225552225555522555222222225552c111111111c1c1c1c1c1c1cc2252255202588520655555560b33339333333393333333b0043333b0
285888280000000088288822285888222858882228288852c1111111111111111c1c1c1c8858882802588520655555560b33333333333333333333b00b3333b0
285888280000000088288822282888222828882228288852c1111111111111111111c1cc8858882802522520655555160b43333333333333339334b00b3333b0
282888280000000088288822282888222828882228288822c11111111111111111111c1c8828882802588520655111160044bbbbbbbb49444bbbbb000b3334b0
022222220000000022222220222222220222222022222222c1111111111111111111c1cc2222222225222552666666660000000000000000000000000b3333b0
02222222222222222222222025888282c111111111111111c11111111111111111111c1c1111111c01000000333333330000000000000000000000000b33b3b0
22888288858885888588828225888282c111111111111111c1111111111111111111c1cc1111111c111000003333343300b4bbbbb4bbbbbbbbbbbb000b3333b0
22888588858885888588858225888282c111111111111111c11111111111111111111c1c1111111c00000100333333330b333333bbbb3333393b33400b333340
22225555252255222555552225552222c111111111111111c1111111111111111111c1cc1111111c0111111033933b330b3333333333333b333333b009333340
28288858882888288858882228588822c111111111111111c11111111111111111111c1c1111111c00100100333333430b333b3333333333333333b0043333b0
28288858885888288828882228288822c111111111111111c1111111111111111111c1cc1111111c00100100333433330b3333333333333333b334b0043333b0
282888288858882888288822282888220c11111111111111c11111111111111111111c1c111111c0011111103b3333330043494bbb4944bbbbbbbb0000bbbb00
0222222222222222222222200222222000ccccccccccccccc111111111111111111111cccccccc00000000003333333300000000000000000000000000000000
1515151515d6d6d6d6d6d6d615151515d5d4d7e6000005e5000000f7006686c51515151515151515151515151515151515151515151515151515151515151515
a40094000000c7d7d7d7d7d4d7e4941525000300071717d6d5b7b7e5030003c50000000000000000a60000000000000015151515151515151515151515151515
25000000000000000000000000000005d5e60000000005e500000000006787c5250066860000c6d6e60000000000000525000000000000000000000000000615
d5d4d5e400000000000000f700c6d5152500000000000003c6b794e5000000c500000000000000a596b5a6000000000015152600000000000000000000000005
25000000000003009000030000000005e50000858585152566868484846787c52500479700667686000000000090000515e40000000000000000000000900005
1515152500000000000000000000c605250000000000001300c6b7e5030003c500000000a6a6a596969696b50000000015260000000000000000000000000005
25000000006300000000004300000005e56686f70000003647970000f74797c5250000c7e4475797000000006000000515e50000000000c4d7e7000000600005
15151525000000f5000000009000000525000000000000000000c6e5000000c5000000a59696969696b4b696b500000025000000000000600000003500000005
25000000000000c7d7e7000000000015e5678700000000360000000000c7d7d525668600c5d7d7e7000000000417171515e500410000c4e60000000200445415
151515250000003500000000000000052500530000000000000003f6000000c50000a5969696969696b6b61596b50000250000000000004564000036e4000005
250000000000f4000000f40000000015e54797f500000005e46686000000000525479700f700000000000000f700000515d6e746c7d7e6000000000000000005
151515250000003600000000000000052500030000000000000000c5e70000c500000096969696969696151596000000250000000000042600000036e6000005
2500030000f40000000000f400000305d5d7d7e600000005e5678700000000052500000000000000000000f50000000525000000000000000000000000000005
151515260000003600000000071717152500000000000003f4000036000000c500000096b6b69696969696969600000025000007171725000090003600000005
2500000000000000f5000000f40000052500000000006005e54797f5000000052500006676860000000000f7000060052500000000000000c4e40000c4e40005
1515250000000036000000000006151515d4d4d4d7d4d7e703001336000000c500000096b6b69696969696969600000025000000000036000000003600000005
1584848484848417e6000000600051152500000000000715d6d7d7e60000000515a4006777870000000000667686071525000000000000c4d5e54565c5d5e405
1515260000000036000000000000061515b7b7e503f7030000000036000000c500000096969696969696b6b69600000025000000000036000000c4e600000005
25000000000003000003008484841715250000000000000000000000000000c515f600475797000000000067777786c525000000000044151515151515151515
15250000000000360000000000000005151515260000000000000336000000c500000096969696969696b6b696000000250000000000055465d7e60000000005
25a40000006300000000430000005515e56676860000006676860000667686c515d5d4d7d7d7e70000000047575797c525000000000000000000000000000005
152600000000003600000000000000052500000000000000000000360000c7d500000096969696969696969696a4000025000000000005152500000000600005
25f6000000000000000000000000f605e5677787c4e40047579700f5677787c51515260066768600000000000000c4d525000000000000000000000000000005
250000000000000617270000000000052500000013001300130000361300130500000096b6b696969696969696f6000025000007171715152500000044545415
15f600000000c7e4000000000000f605e5475797c5b7e4009000c4e5475797c51526000067778700000000667686c51525000000000000000000000000000005
2500000000000000000000000000000525000000000000000300c4250090000500000096b6b69693a3b3969696f6940025000000000000052500000000000015
25f60300000000f6000000000003f605d5d4d4d4d5b7e5667686c5d5d4d4d4d52500000047579700000000677787c51515650000000000000000350031000415
15240000000000000000000000000415250031000300030000c4d525030003050000009696969696809696969694940025000000000000052500000000000005
25f60000000031c6e40000000000f60515b7b7b7b7b7e5475797c5b7b7b7b71525000000000000000000f5475797c51515151724d4d4d4d4d4d4151717171515
1515240051000000000000000004151515171717d4d4d4d4d4d5b725006000059595959595959595959595959595959525000031000000c5e500000000410005
15d5d4d4d4041724d5d4d4d4d4d4d515151515151515d5d4d4d4d51515151515250000006686f5000000c6d7d7d7d61515151515151515151515151515151515
15151517171717171717171717151515151515151515151515151515171717159595959595959595959595959595959515d4d4171717d4d5d5d4d4d445545415
1515151515151515151515151515151515d6d6d6d6d6d5d5d6d6d6d515151515256686004797f7000000000000000005b7d5b7b7d6d6d6d6d6d6d6d615151515
1515d5d6d6d6d6d6d515d5d6d6d6d5151515151515151515d6d6d6d6d51515d6d5d6d6d6d6d6d5d615151515b7d5d5d6d6d6e6f7c6d615151515151515151515
2500000000c6d5360000000000c6d505250000520000c5e6005200f70000000525479700000000000000000000000005b7b7d5e6000000000000000000000005
15d5e60000000000c6d5e6000000c6d525000000c6d6d6e600000000c6d5e503f60300000003f6000000c4d5b7d5e60032000000668600b6b60000b6b6000005
250000000000c536000000000000c6052500000000c7e600000000000000000525000000000000000000000000000005b7d5e600000000000000000000000005
15e500000000000000f60000000000c525000000000000000000000000c6d5d4e60000000000f60000c4d6d5d5e6000000f500f5479700b6b60000b6b6000005
250000000000c636005100340000000525320000000000000000000000000005256676768600000000006686f5668605b7e500000000c4d4e400000000000005
15e500000060000000f64103f53303c5250000000060000000c4e400000005e5000000000000f600c4e600c6e5000000c7d5e43600c7e4000000000000000005
25000000000000c617172700000000052600000000c7e40000900000004100052567777787c4e70000004797f6479705d5e60085858585d6d685858500006005
15e50084842400f500c65475e60000c5250000008484848484d6d6e7000005e5000000f50000f6c4e6005200f600000000c6d5366686f600c417172700410006
25000000f4000000c5e6000000000005d4e400000000c5e4000000f5071717152567777787f600000000c7d7e6000005e64100c5b7e500000000000002000715
03f733f603f700f600000000000000c5e50000000036000000000000000005e50000c7d5e700c5e5000000c7e50000000000c52567873600c6d6d6e5071727c5
2500000000f50000f700000000000005b7e500000000c6e5001200f600061515254757579736000000000000000000051717858585250000000000000000c5b7
e40000c5e40000c67474748484841717e500000000058400c78585858585d5e6000000f60000c5e500f50000f60000000000c52547973600667686c5d7d7d7d5
2500000000f60000000000000012c405d5e60012000000c6d7d7d4e500000615250000000036000000000000000000052500000000370000000000000000c5b7
e50000c6e60000000000000000000005270000c74425000000000000c6d5e5000000c4e50000c5e500f60000c5e412f40000c5d5e7003600677787f7667686c5
2500000000f6000000000012c7d4d505e5000000000000000000c5d6d7d7d4d4250000000425000000f56676767686052500000000000000000000000000c5b7
e5000000000000009000000000600005e5000000003600000000000000c525000000c5e60000c5e500f60000c6d5e7000000c5256686366067778700677787c5
251200f400f600000000000000c6d505e5000060000000000000f7000000c6d5250060000525000000f64757575797052500000000000000c4d4848484848484
17178585858585858585000000071715e500000000360000000000f500c6250000c4e5000000c5e500f6000000f700000000c52567870524677787f5677787c5
25d4e70000f6000000f400000000c605d5d7071727e4000000000000720000c5151717171525510000f60000000000052500000084848484d5e6000000000005
d6d5e6000000c6d5d6e6030033f703c52700000000058484848484e600003600c4d6e5000053c5e600f600000000000000c4e6364797c5e5475797f6475797c5
25e6000000f600004200f400000000052500000000c6d7d7d7e70000000000c5151515d6d615270000f76676767686c525000000000000c6e500000000000005
03f63300000003f6000000000000c7d5e50000c74415e5000000000000003600f713f60000c4e50000f6000000000000c4e6003600c7d6d6d7d7d7d5e700c7d5
2500000000c5e4000000000000820005250000320000000000000000000000c5150000000000000000006777777787c52500000000000000f700000000000005
d4e60000f50000f600000000000000c5e50000000005270000c78585858526130000f60000c6d5e700f600f5220000c4e60000f666768600667686f7667686c5
2500000000c5d5e4000090000000c41525000000000000c4d4d4e4000000c4b7150000000000000000006777777787c51517240000000000000000f500310005
e5000000f60000f700848484270000c5e50000000005e50000000000000000030003f6000003f70000f600f60000c4e60094c4e5677787f567778790677787c5
2531c4e412c594d5e400000000c4d515250000310000c4d594b7d5e400c4d5b71500003100c4e400c4e44757575797c5151515d4d48585858585858517171715
e5003100f600000000000000000000c5e50000310005e50000000000000000006000f6000000600012f600f600c4e6009494c5e5475797f6475797f5475797c5
1524c5d5d4e5c5d5d5d4d4d4d4d5d51515d4041724d4d5b7b7b7b7d5d4d5b7b71517171724c5e535c5e5c4d4d4d4d4d5151515b7b71515151515151515151515
d5171717d57474748484848484841717d5d4e435c415d5d4d484848484848484171717848484848417d5d4d5d4d517171717d5d5d4d4d4d5d4d4d4d5d4d4d4d5
__label__
88888888888222222288888888888888888828888888888888882888888888888888888288888888888888822888888888850000000000000000000000000000
88888888888222222288888888888888888828888888888888882888888888888888888288888888888888882888888888850008888888888888888888888000
88888888888822222222888888888888888822888888888888882288888888888888888288888888888888882888888888850087777777777777777777777800
88888888888822222222888888888888888882888888888888888288888888888888888228888888888888882288888888850878887777777777777777777780
88888888888882222222288888888888888882888888888888888288888888888888888828888888888888888288888888850877878777777777778777777780
88888888888882222222288888888888888888288888888888888288888888888888888828888888888888888288888888850877877877887787878777787780
88888888888888222222228888888888888888288888888888888288888888888888888828888888888888888288888888850877877878787787878877878780
88888888888882222222222888888888888888288888888888888828888888888888888822888888888888888228888888850877878778787788878787878780
22888888888822822222222288888888888888828888888888888822888888888888888882888888888888888828888888850878887777878778778877787780
82288888888828822222222288888888888888828888888888888882888888888888888882888888888888888828888888850087777777777777777777777800
88228888888228882222222228888888888888822888888888888882888888888888888888288888888888444444422222250008888888888888888888888000
88822888882288888222222222888888888888882888888888222222222222222222222222222222222224442244448888850000000000000000000000990000
88882288882888888222222222288888888888822222222222888888888888828888888888888888888284442224444888850000000000000000000000000000
88888228882888888822222222288888888822222288888828888888888888828888888888888888888284444222444488850000000000000000000000000000
88888882228888888822222222222222222288888888888828888888888888828888888888888888888288444422244448850000000000000000000000000000
88888888228888888882222222288888822888888888888828888888888888828888888888888888888288844442224448850000000000000000000000000000
88888888828888888888222222228888882888888888888828888888888888822888888888888844888228844442222444850000000000000000000000990000
88888888828888888888222222228888882888888888888828888888888888882888888888884444448828884444222244850000000000000000000000990000
88888888828888888888822222222888882888888888888828888888888888882888888888884422444828888444442224450000000000000000000000000000
888888888288888888888822222228888828888888888888228888888888888828888888888444222448288888444442244f0000000000000000000000000000
888888888288888888888822222222888822888888888888828888888888888828888888888444222244488888ff444444ffff00000000000000000000000000
88888888828888888888888222222288888288888888888882888888888888882888888888884442222444888fffffffffffffff000000000000000000000000
888888888288888888888888222222888882288888888888828888888888888822888888888888442222244fffffffffffffffffff0000000000000000990000
88888888828888888888888822222228888828888888888882288888888888888288888888888884442224fffffffffffffffffff11111000000000000990000
88888888828888888888888882222228888828888888888888288888888888888288888888888888844424fffffffffffffffff1111111110000000000000000
88888888828888888888888882222222888882888888888888288888888888888288888888888888884444ffffffffffffffff11111117110000000000000000
8888888882228888888888888222222228888288888888888882888888888888828888888882222222844fffffffffffffffff11111177711000000000000000
8888888882822288888888882222222228888828888888888888222222222222222222222222888888884fffffffffffffffff11111117111000000000000000
888888888288822888888888282222222222222222222222222228888288888888888888288888888888ffffffffff11ffffff11111111111000000000990000
2228888882888882288888882882222222888888888828888888888882288888888888882888888888ffffffffff11111ffffc11111111111100000000990000
8822288882888888228888882888222222288888888828888888888888288888888888882888888888fffffffff1111711fffc11111111111100000000000000
888822288288888888228888288882222228888888882888888888888828888888888888228888888ffffffffff11177711fffc1111111111100000000000000
888888222288888888882228288882222222888888882288888888888828888888888888828888888fffffffff111117111fffc1111111111100000000000000
888888882288888888888822288888222222888888888288888888888828888888888888828888888fffffffff111111111ffffc111111111100000000000000
888888888288888888888888288888222222288888888228888888888828888888888888828888888ffffffffc111111111fffccc11111111000000000990000
888888888288888888888888288888822222288888888828888888888822888888888888822888888ffffffffc111111111fffcffc1111110000000000990000
88888888828888888888888828888882222222888888882288888888888288888888888888288888fffffffffc111111111fcfffffcccccff000000000000000
88888888828888888888888828888888222222888888888288888888888288888888888888288888fffffffffc111111111ffffffffffffff000000000000000
88888888828888888888888828888888822222288888888228888888888828888888888888828888fffffffffc11111111ffffffffffffffff00000000000000
88888888822288888888888222288888822222288888888828888888888828888822222222222222fffffccfcccc11111fffffffffffffffff00000000000000
88888888828822288888888288222888882222228828888882888888888222222222888888888888ffffffffcffccccfffffffffffffffffff00000000990000
88888888882888222888888288882288882222222222222222222222222888888882288888888888ffccfffffffffffffffffffffffffffffff0000000990000
88888888882888888228888288888228888222222222888888888882888888888888288888888888fffffffffffffffffffffffeeefffffffff0000000000000
888888888828888888828882888888228882822222228888888888828888888888882888888888888fffffffffffeeeeeffffeee7eeffffffff0000000000000
888888888828888888882282888888822882882222222888888888882888888888882888888888888ffffffffffeeeee7eeffee777efffffffff000000000000
2888888888288888888882228888888882828822222222888888888828888888888882888888888888fffffffffeeee777effcee7eefffffffff000000000000
22222888882888888888888288888888882288822222228888888888288888888888828888888888666ffffffffceeee7eeffceeeeefffffffff000000990000
88882222882888888888888288888888888288882222222888888888828888888888828888888866666fffffffccceeeee88cceeeeefffffffeeee0000990000
888888882228888888888882888888888882888822222228888888888228888888888828888866666666fffccffccccce8cc8ceeeefffffeeeeeeee000000000
888888888828888888888882888888888882888882222222888888888828888888888828888666666668fffffffffff8888888cccffffeeeeeeeeeee00000000
8888888888288888888888828888888888228888822222222888888888222222222222222666666666588ffffffffff5888888fffffffeeeeeeeeeee00000000
88888888882888888888888288888888882288888822222222222222222228882888888866666660668588ffffffff85888858ffffffeeeeeeeeeeeee0000000
88888888882888888888888288888888882222888882222288888828888888882888866666666006688856ffffff858855558fffffffeeeeeeeeeeeee0990000
888888888828888888888882228888888828822888882222888888288888888822886666666600666888858f8885858888888fffffffeeeeeeeeeeeee0990000
8888888888288888888888828222288888288822888282222888888288888888828666666660066668855885885888588855ffffffffeeeeeeeeeeeeee000000
888888888828888888888882888822288828888228828222228888828888888862666666600666666758885888588885558fffffffffeeeeeeeeee222e000000
88888888822222888888882888888822882888882282882222888882888886666666666000666667778888588885888888ffffffffffeeeee222ee222e000000
88888888882888222288882888888882222888888222888222222222228866667766660066667777666888858888588ffffffffffffffeeee222ee32ee000000
88888888882888888222222888888888822888888882888822228888886666677666666666777666666666666ffffffffffffffffffffeee332ee3eee0990000
8888888888288888888882288888888888288888888288888222228866666676666666666776666666666666fffffffffffffffffffffe3eeeeeeeee00990000
8888888888288888888882888888888888288888888288888822222666667766666666677666666446666666ffffffffffffffffffffffffeeeeee0000000000
8888888888288888888882888888888888288888888288888822226667776666666666776666664444666666fffffffffffffffffffffffffff0000000000000
8888888888288888888882888888888888288888882228888882267776660066666677766666644444466666ffffffffffffffff88888800ff00000000000000
8888888888288888888882888888888888288888882882288886777666600666667776666666644444446664ffffffffffffff88880000000000000000000000
2222888888288888888882888888888888222888882888222867766660066666677666666666664444444444fffffffffffff888000000000000000000990000
8888222222288888888882222228888888282228882888882677666606666666776666666666664444444444ffffffffffff8888000000000000000000990000
8888888888288888888882888822228888288882222888867766660066666666666666066666666444444444ffffffffffff8880000000000000000000000000
888888888828888888888288888882222828888882288887766660066666666666000006666666664444444ffffffffffff88880000000000000000000000000
8888888888288888888828888888888822288888882886776666006666666660000666666666666bb444444ffffffffffff88880000000000000000000000000
888888888828888888882888888888888828888888886776666006666666000066666666666666bbbb44444ffffffffffff88888000000000000000000000000
8888888888288888888828888888877778288888886677666006666660006666666666677766bbbbbbb4444ffffffffffff88888000000000000000000990000
8888888888288888888877888888776678288886666676600066666666666666677777776bbbbb4bbbbbbbbffffffffffff88888800000000000000000990000
8888888888288888888876778877766678288866666666006666666666667777776666bbbbbbbbbbbb9bbbfffffffffffff88888800000000000000000000000
8888888888288888888876666666666778866666666666666666666777777666666bbbbbbbbbbbbbbbbbbfffffffffffffff8888880000000000000000000000
8888888888288888888227666666666788666666666666666667777666666666bbbbbbbbbb333bbbbbbbbffffffffffffffff888888800000000000000000000
8888888888288888888287766066066766666666666666777776666666666bbbbbb9bbbbb3333b9bbbbbffffffffffffffffff888888ff000000000000990000
88888888828888888882887766606666666666000067776666666682bbb333bbbbbbb4bbb3b3bbbbbbfffffffffffffffffffff88ffff0000000000000990000
88888888828888888882888766606666660000066666666688288882bbbbb33bbbbbbbbbbbbbbbbbbffffffffffffffffffffffffff000000000000000000000
88888888822222222222888866000666600666666668888888288882bbbb9bbbbbbbb9bbbbbbbbbffffffffffffffffffffffffff00000000000000000000000
88888888828888888882888860666066666666888882888882288882bbbbbbbddbbbbbbbb9bbbbffffffffffffffffffffffffff000000000000000000000000
888888888288888888828886666666666666666888822222222888822b9bbbdaadbbbbbbbbbbbffffffffffffffffffffffffff0000000000000000000990000
888888888288888888828766666677666666666668828888882888882bbbbdaa00dbbbbbbbbbfffffffffffffffffffffffff000000000000000000000990000
888888888288888888827766687678866776006666688888882222222bbbdaaa0aadbbbbbbbffffffffffffffffffffffffff000000000000000000000000000
888888888288888888777666887678886677600066668888882888882bbda0a0aaaadbbbbbfffffffffffffffbbfffffffff0000000000000000000000000000
888888888288888887766667887678888667776000666688882888882bbda00a00aadbbbbbffffffffffffffbbfffffffff50000000000000000000000000000
888888222288888888877778887678888886677760066666882888882bbbdaaaa0ddbbb4bbfffffffffffffbbffffffffff50000099999900000000000990000
88882228828888888888288888876788882866677766666666888882bbbbbddaaadbbbbbbbbffffffffffbbbbfffffffffb50000099999900000000000990000
22228888828888888888288888876788882222666776666666668882bbbbbbddddbb9bbbbbbbfffffffbbbbfffffffffffb50000009999000000000000000000
88888888828888888888288888887778882288886666600666666882b4bbbbbbbbbb333bbbbbbbfff4bbbbfffffffffffbb50000000990000000000000000000
88888888828888888822288888888878822888888866660006676682bbbbbbbbbbbb3933bbbbbbbbbbbbfffffffffffffbb50000000000000000000000990000
88888888828222222228288888888888828888888882866660067762bbbbbbbbb4bb3333bbbbbbbbbbbffffffffffffbbb450000000000000000000000990000
888888888222888888882888888888888288888888828888866666666bbbbbbbbbbbbbbbbbb33bbbbbbfffffffffffbbbbb50000000000000000000000000000
88888888828888888888288888888888828888888822288222866660066bbbbbbbbbbbbbb4433333bbbbfffffffffbbbbbb50000000000000000000000000000
8888888882888888888828888888882222888888882822228288866660666bbbbbbbbbbbbbbbbbbbbbbbbffffffbbbbbbbb50000000000000000000000990000
888888888288888888882222222222288288888888288888828888826666666bbbbbbbbbbbbbbbbbbbbbbbffffbb9bbb4bb50000000000000000000000990000
88888888828888888888288888888888828888888828888882882222bbb6666bbbbbb22222222bbbbbbb9bbbbbbbbbbbbbb50000000000000000000000000000
88888888828888888888288888888888828888882228888882222882bbbb6666bbbb22882882222222bbbbb4bbbbbbbbb9b50000000000000000000000000000
88888882228888888888288888888888828882228828888882888882bbb4bb666bbb22882882882882bbbbbbbbbbbbbbbbb50000000000000000000000990000
88882222828888888888288888888888822228888828888882888882bbbbbbbbb662662222222222222bbbbbbbbb333bbbb50000000000000000000000990000
82222888828888888822288888888888828888888828888222888882bbbbbbbbb286662882882882882bbbb44bbb333bbbb50000000000000000000000000000
22888888828888822228288888888888828888888822222282888882bbbbbbbbb282882882882882882bbbbb444bb33b9bb50000000000000000000000000000
88888888828882228888288888888888828888888822888882888222bbbb933bb222222222222222222bbbbbbbb9bbbbbbb50000000000000000000000000000
88888888828222888888288888888882228888888828888882222882bbbb333bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb50000000000000000000000000000
88888888822288888888288222222222828888888828888882888882bb9bbbbbbbbbbbbbbbbbbbbb9bbbbbbbbbbbbbbbbbb50000000000000000000008800000
88888888828888888888222288888888828888222228888882888882bbbbbbbbbbbbbbbbb4bbbbbbbbbbbbbbbbbbbbbbbbb50000000000000000000008800000
88888888828888888888288888888888822222288828888882888882bbbbbbbbb44bbbbbbbbbbbbbbbbbbbbb22222222222500000000000000000009977ff000
888888888288888888882888888888888288888888288888828822222bbbbbbbbbbbbbb2222222222222222288888888828500000000000000000009977ff000
888888888288888888882888888888888288888888288882222222222222222222222222888888228888888228888888882500000000000000000aa777777ee0
888888888288888888882888888888888288888882222222222222228888288888882888888888828888888828888888882500000000000000000aa777777ee0
88888888828888888888288888888888822222222222222222228888888228888888288888888882888888882888888888850000000000000000000bb77dd000
88888888228888888888288888888822222222222222222222288888882288888882888888888822888888882288888888850000000000000000000bb77dd000
8888822282888888888828888222222222222222222222228888888882288888888288822222222222222222222222222225000000000000000000000cc00000
8882228882888888888828222222222222222222222888882222222222222222222222222888888888882888888882288885000000000000000000000cc00000
22288888828888888822222222222222222222222888888888882288888888288888888828888888888828888888882288850000000000000000000000000000
28888888828888888222222222222222222222288888888888228888888882888888888828888888888828888888888288850000000000000000000000000000
88888888828888882222222222222222222288888888888888288888888882888888888828888888888822888888888228850000777777000000000077777700
88888888828888222222222222222222222228888888888882288888888822888822222222222222222222222222222222250007777777000000000077777700
88888888828822222222222222222228888882222222222222222222222222222228888888888828888888888828888888850077700777000000000070007700
88888888828222222222222222222888888888888828888888888828888888888228888888888882888888888822888888850077700777000000000770007700
88888888822222222222222222288888888888888288888888888228888888888288888888888882888888888882288888850077777777007777007777777700
88888888222222222222222288888888888888882288888888888288888888888288888888888882888888888888288888850077777777007777007777777700
88888822222222222228888888888888888888822888888888888288888888888288888888888888288888888222222222250077700000000000007770007700
88888222222222288222222222222222222222222222222222222222222222222222222222222222222222222288888888850077700000000000007770007700
88822222222228888888888888882288888888888888228888888888882888888888888828888888888888288888888888850077700000000000007777777700
82222222228888888888888888822888888888888888288888888888882888888888888828888888888888228888888888850077700000000000007777777700
82222222288888888888888888828888888888888888288888888888822888888888888882888888888888828888888888850000000000000000000000000000
22222888888888888888888888228888888888888882288888888888828888888888888882888888888888828888888888850000000000000000000000000000
22222888888888888888888888288888888888888882888888888888828888888888888882288888888888822888888888850000000000000000000000000000

__gff__
0000000000002000009090000000000000000082a0a000202020000000000000081838286848c8889800000000000000f11939296949c989990000000000000001100101414141430310100010101010010101014110414505010000101010100110010141414040400000001010101001010101404040404040001010101010
0101010101010101000000000000000001010101010101010000000000000000010101010101010100000000000000000101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
6d6d6d6d6d6d5151515d5d515151515d7b5d6d6d6d6d6d6d6d6d5d515151515d515151515151515d5d5d515151515151515151515151515151515151515151517b7b7b7b7b7b7b7b5d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d6d5d5d515151515151515151515151515151515151515151515151515151515151515151
4a00000000000000006c6e000000005c5d6e00000000000000007f000000005c520000000000006c6d6e000000000050520000000000000000000000000000507b6d6d6d6d6d6d6d6e00000000000000000000000000000000000000006c5d5d5200000000000000000000000000005052666800630000666768000900666850
5e00000000000000000000000000005c5e00000000000000000000000000005052000000000000002500000000000050523053140000000033000000000030505e66676800666768000000000000000000000000000000000000000000006c5d5200000000000000000000000000005052747900630000767778000000767850
5e00000000000000000000001400005c5e00000000060000004c4d4e0000145052001400000000000000000006000050517171717d7d7d7e0000007c7d4d7d5d5e76777830767778000000000000000000330000004c4e00000000000000305c52130000006667676767680000000051520000007306007475797c7d7e747950
5e00004c71420000007c7d5445564d5d5e000000404200007c6d516d7e44455151717142000000000000000040420050520000000000000000000000007f00505e747579007475790000000000004c4d4d4d7d7d4d5d5d4e0000000000004c5d5171727d7e767777777778000000155052000000007072000000000000000050
5e09006c5d6e00000000006051626d5d5e0009005c5e0000000073000000005c516d6d6d4e00000000004c7d6d6e005c523000000000330000000000000030505d7d7d7d7d7d7d7d7e000000004c5d51516200006c6d6d6d7e66680066686c5d52000000007475757575797c7071715052150000000000000000000000000050
5e0000006f000000000000000000005c5e0000005c5e00000000000000000050520000006c4e000000006f250027005c5200000000007c7d7d4d7d7d7d7d7d5d520000003000000000000000005c51620037000000000000007479007479305c5200000000000000000000000000005051460000000000000000666768000050
5d5600496f000006000000000000005c5e0000005c5e0000000000000000135052000000006f002100216f000000005c5200000000000000007f0000000000505200000000000000000000004c5d52001400404d4d4d4d7d7d7d7d7d7d7d4d5d52000000000000000000000000000050515e666768006667685f767778000050
5d6d7d5d6d7d70424d5446000000005c5e0000005c6e0000000000000070715152000000256f000000006f000000215c52300000330000000000000000003050520000000000000000004c7d6d6d51717171515d7b5d6e000000000000005c7b520000004c5300000000534e00000050515e7475795f7677786f747579000050
5200007f0000006c6e007f000000005c51564d7d6e00000000004c7d4e00005c52001300005c4e0009006f000000005c5d7d4d7d7d7d7d7d7e000000000000505200000000007c7d7d7d6e00000000000000006c6d6e00000009000000005c7b520000006c6071717171626e00000050516d7d7d7d5e7475795c7d7d7e000050
5200000000000000000000000000005c516d5e0000000000004c434a6c7d495c51717142006c5d4e004c6e2300214c5d52007f000000000000000000000000505200060000000000000000000000000000000000000000000000000000005c7b5266676768000000000000666767685052000000006c7d4d7d6e000000000050
5200000000000000000000000000005c52006f0000000000006c5e6f00006c5d5d6d6d6e00006c6d7d6e00007c7d6d5d52303300000000000000000000003050517172000000000000000000000000000000000000000000004c4e0000006c5d52767777780000000000007677777850520000000000007f0000000000000650
5213005f0000005f0000004c40424d5d52007f000000000000006f5c7d7d4d5d5e250000270000002300000000000050520000000000004c7d7d4d4d7d4d7d5d515200000000000000000000004c4e666768000000000000006c6e666768005c5276777778000000090000767777785052130000000000000000000000407151
5171715d4d40715d4d54455d51517b7b520000545600004042006f6f40426f5c5e007c7e00000000000000007c7e005c520000000000006f49007f6f007f0050515200130030666768000000375c5e767778000000000000000000767778305c5276777778000000000000767777785051426667685f6667685f6667685c7b51
5151517b7b51517b7b51517b51517b7b520000505200005052006f6f50525c5d5e230000000000004c495f210000275c520013000000006f4949007f49000050515171714230747579000000375c5e747579000000000000000000747579305c5274757579000006000000747575795051527475796f7475796f7475795c7b51
51515151515151515151517b51517b7b514d4d51514d4d51514d5d5d51515d7b5d4d4d4d4d4d4d4d5d5d5d4d4d4d4d5d5171717171717171717171717171715151515151514d4d4d4d4d4d4d4d5d5d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d5d514c4d4d4e4071717171424c4d4d4e5151514d4d4d5d4d4d4d5d4d4d4d5d7b51
5d5d51516d6d6d515151515151515151515151515151515151515151515151515151515151515151515151515d51515151515151626d6d6d6d6d6d6d60515151515151515151515151515151515151515151515151515151515151515151515152515151515151515151515151516d6d6d6d6d6d6d6d6d5d6d6d515151515151
5d6e666767676800000000000000505152000000000000630000000000000050515d5e0000000000000000007f000000005062000000000000000000000000505151626b6b6051515151624b6b6051515200000000000000000000000000005052000000005c5e000000000000000000000000000000006f0000000000000050
5266777777777800000900000000505152000000000000630000000000000050515d6e00000000000000000000000000006300090000000000000000000000505200006b6b0000000000006b6b006051520000000000000000000000002500505200005f005c5e00000000000000000000004c484848006f0000000000150050
5276777777777800000000060000505152001300000000630000000000140050515e000000000000000000000000000000630000000000000000000000000050520000000000000000000000000000505200150000000000000000000000006052005f6f005c5e0000000000004c484848486e00006f006f0000000048715851
52747575757579004c4d4d4071715151517171727e6668636668407171717151515e0000005f0000000000005f00000000630000002000005f00000000004c515200000000000000000000001300005051717142300000000000370000004330527d6d6d7d6d6e0000484848486e000000000000006f006f0000000000000050
520000004c4d4e005c497b5d6d6d5d5d6e0000000076786f767873000000005c515e0000006f0000000000006f00001300504546000000005c4d7e00007c6d51520000530000005300000040717171515d6d6d6d4d4e000000000000300030405200000000000000000000000000000000000000006f006f0000000000000050
520000006c6d6e006c6d6d6e66686c5d720000000076786f767800000000005c516e00004c5e00004457574d6d57454547515d7d7e007c7d6d5e000000000050520000630000005071717151515151515e0030006c5e0000300000000000005052000000000000000000000000000000004c4800585e096c585858000000005c
526667676800006668000066777768504e0000004f74796f7479585800000050520000005c5e00006c6d6d5e000000006c6d6e0000000000006f0000000000505200006071717162000000000000605152000000007f00000000000000000050520013004c4d4e0000000000004c4848486e6300505e00006f0000000000005c
527677777800007678000076777778505e000000007c7d6d4d7e00004f000050520000005c6d7d7e0000007f000000000000000000000000005c7d7e00007c5152000000000000000000000000000050520000000000000000004c4e35003550517171716d6d5e004c4d4747476e000000007300505e00006f0000000000005c
52747575794c4e7479000074757579505e00000000000000630000000066685c5200007c6e00000000000000000000000000000000000000006f0000000000505200000000000000000000000600005052000000000000000000505e00007c5d5200000000006f005c5e00007f00000000000000505e00006f0000004848485d
5d7d7d7d7d6d6d7e007c7e00000000505147474747470000630000484874795c5200000000000000000000000000000000005f0000060000005c7d7d7e000050520000004071717142004071717171515200000000000000000050520000005c5200000000007f005c6e000000004c4e00000000506e00006f00000000000050
52000000000000000000006667676850520000000000000063000000007c7d7b5200000000000000000000000000000000006f0047455700006f000000000050520000005062000073007300006051515200000000000000000050620000005c5e000000000000066f00005858585d5d58585858620000007f00000000000050
5200000000000000000000767777785052000000000066686f6668000000005052000006000000000000005f0047474747006f006f000000006f005f00150050520000006300000000200000000060515200000000007c4e0000504a0000005c5e000000484848716e0000006c6d6d6d6d6d6d6e00000000005858580000005c
520013000000005f666800747777795052666800005f76786f76780000000050514747465f0047474747006f00006f6f00006f006f005f00006f495c4745577b51717171520000000000000000000050520035000000006f3500505d7e00005c5e0000006c6d6d6e00000000000000000000000000000000000000000000005c
517171420015005374794c4e74794c5d5e767800007f74796f74795f00000050524a00006f00006f6f00005c49006f6f4c4d5e006f4c5e004c5d7b5d7b7b5d7b51515151620000000000000000000050520030000000006f304c5d5e0000005c5e0000000000000000000000000000000058585858584206000000000000005c
51515151717171524d4d5d5d4d4d5d7b5e74795f00004c4d6d7d7d5e0000005c515d4d4d5d4d4d5d5d4d4d5d5d4d5d5d5d7b5d4d5d5d5d4d5d7b7b7b5d5d7b5d62000000000000000000000000000050520000000600005c4d5d7b5e0000005c5d585858584d4d585858584d4d58585858515151515151714848484848484851
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
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
011000003055224520245150000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010e00001d3521d355000001d3521d3550e3051d3521d355083051c3551d3521d3550f3051330512f0011f0010f0010f0029a000ff000ef000ef000ef000ef000ef000ef000df000df000df000df000000000000
b10200002574026330203210e32108011045110101100011000150860005600006000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

