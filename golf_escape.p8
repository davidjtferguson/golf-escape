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
 
 --checkpoint
 xcp=0
 ycp=0
 
 --set a lvl in initlevels()
 -- to set player spawn point
 
 cpanim=makeanimt(23,10,3)
 
 resetav()
 
 --todo:make camera an obj
 xcamera,ycamera=0,0
 
 xcameravel,ycameravel=0,0
 
 makebackgrounds()
 
 currentupdate=updateplaying
 currentdraw=drawplaying
 
 aim={
  points={}
 }
 
 --check map and convert
 -- to game objects
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

  --power swing
  if btnp(❎) then
   swing.currdecaypause=swing.decaypause
   swing.force+=swing.btnf
   
   swing.decay=swing.basedecay
   
   if swing.force>swing.highf then
    swing.force=swing.highf
   end
  end
  
  --release swing
  if btnp(🅾️) then
   sfx(1)
  
   swingcount+=1
  
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
 --hack to help with corners
 if allcol(av,av.xvel,av.yvel,0) then
  av.xvel=0
  av.yvel=0
 end
 
 --ground col
 if groundcol(av,0,av.yvel,0) then
  moveavtoground()
  
  --if vel low enough, land
  if groundcol(av,0,av.yvel,6) or
     abs(av.yvel)<0.075 then
   
   if av.colstate!="ground" then
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

   sfx(0)
   av.pauseanim="gsquish"
   av.xpause=squishpause
   av.ypause=squishpause
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
	  
   sfx(0)
	  av.pauseanim="tsquish"
	  av.xpause=squishpause
	  av.ypause=squishpause
	 end
 
  if leftcol(av,av.xvel,av.yvel,0) then
	  
   sfx(0)
	  av.pauseanim="lsquish"
	  av.xpause=squishpause
	  av.ypause=squishpause
	  
	  moveavtoleft()
	  av.xvel*=-1
	  
	 elseif rightcol(av,av.xvel,av.yvel,0) then
   sfx(0)
	  av.pauseanim="rsquish"
	  av.xpause=squishpause
	  av.ypause=squishpause
	  
	  moveavtoright()
	  av.xvel*=-1
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
 for h in all(hooks) do
  if h.avon then
	  if anycol(av,h.xvel,h.yvel,0) then
	   hookreleaseav(av.hook)
	   resetswing()
	  else
	   h.x+=h.xvel
	   h.y+=h.yvel
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
  --todo:what should 'inventory' look like?
  -- show key is in inventory
  currlvl.key.x=(xcamera*16)+7
  currlvl.key.y=(ycamera*16)+15

  --todo: have mechanic where
  -- hitting a checkpoint 'saves' the key?
 end

 updateav()

 updateanims()
end

function _draw()
 currentdraw()

 print(debug,xcamera*128,ycamera*128,1)
end

function drawplaying()
 cls(bg.colour)
 
 drawbackgrounds()

 --draw all of current level
 map(currlvl.xmap*16,currlvl.ymap*16,currlvl.xmap*128,currlvl.ymap*128,currlvl.w*16,currlvl.h*16)
 
 --lvl objs draw
 drawobj(currlvl.exit)
 --drawcirc(currlvl.exit)
 
 if (currlvl.haskey) then
  drawobj(currlvl.key)
  --drawcirc(lvls.currlvl.key)
 end
 
 
 if av.canswing then
  --draw aim
  
  --todo:consider look. lines?
  for point in all(aim.points) do
   pset(
    (av.w/2+point.x)*8,
    (av.h/2+point.y)*8,linecol)
  end
 
  rect(aim.x*8,aim.y*8,
   (aim.x+aim.w)*8,
   (aim.y+aim.h)*8,2)
 end
 
 --game objects
 for h in all(hooks) do
  drawobj(h)
  
  --circle collision
  --circ((h.x+h.xcenoff)*8,(h.y+h.ycenoff)*8,h.r*8)
 end

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
 
 linecol=9
 
 if swing.currdecaypause>0 then
  linecol=10
 end
end

function drawobj(obj)
 spr(obj.s,obj.x*8,obj.y*8)
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

function moveavtoground()
 av.y+=av.yvel
 av.y+=distanceinwall(
  av,0,1,-1,groundcol)+pixel
 
 av.y-=av.y%pixel
end

function moveavtoroof()
 av.y+=distancetowall(
  av,0,1,-1,topcol)
 av.y+=pixel-av.y%pixel
end

function moveavtoleft()

 av.x+=distancetowall(
  av,1,0,-1,leftcol)
 
 if av.x%pixel != 0 then
  --round to pixel
  av.x+=pixel-av.x%pixel
 end
end

function moveavtoright()
 av.x+=distancetowall(av,1,0,1,rightcol)
 
 --round to pixel + out of wall
 av.x-=(av.x%pixel)+0.001
end

function distancetowall(box,checkx,checky,direction,colfunc)
 local distancetowall=0

 while not colfunc(box,distancetowall*checkx,distancetowall*checky,0) do
  distancetowall+=(pixel*direction)

  if allgroundcol(av,distancetowall,av.yvel,0) then
   --corner collision occured
   -- abort wall collision
   -- with ground collision
   
   --todo:tidy ground collision
   -- trigger with function.
   
   av.pauseanim="gsquish"
   av.xpause=squishpause
   av.ypause=squishpause
   
   moveavtoground()
  
   av.yvel=0
   av.xvel=0
   return distancetowall
  end
  
  --todo:also check
  -- top collision?
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
  --wide level
  --{xmap=2,ymap=1,w=2,h=1},
  --tall level
  --{xmap=4,ymap=1,w=1,h=2},
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
  {xmap=2,ymap=3,w=1,h=1},
  --convayer belts
  --{xmap=3,ymap=3,w=1,h=1},
  --important plob level
  --{xmap=4,ymap=3,w=1,h=1},
  --out of way key
  --{xmap=5,ymap=3,w=1,h=1},
  --test level
  --{xmap=6,ymap=3,w=1,h=1},
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
  
  --todo:make ground box
  -- 2 pixels thick
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
  
  framesidle=0,
  
  xflip=false,
  yflip=false,
 }
 
 resethurtbox(av)
 
 --lock movement
 av.xpause,av.ypause=0,0
 
 --todo:not used. test or remove
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

function createhook(x,y)
 h={
  --consts
  spawnx=x,
  spawny=y,
  xcenoff=pixel*4,
  ycenoff=pixel*6,
  r=pixel*2,
  s=32,
  
  --vars
  x=x,
  y=y,
  active=true,
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
    
    currlvl.key={
     x=x,
     y=y,
     s=22,
     r=pixel*4,
     collected=false,
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
 --todo:calculate idle better
 if av.xvel==0 and
    av.yvel==0 and
    av.colstate=="ground" and
    swing.force==swing.lowf then
  av.framesidle+=1
 else
  av.framesidle=0
 end

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
 -- don't allow camera off map
 if av.x>0 and av.x<127 then
  xcamera=camera1d(xcamera,currlvl.xmap,currlvl.w,av.x,av.w,swing.xvec)
 end
 
 if av.y>0 and av.y<63 then
  ycamera=camera1d(ycamera,currlvl.ymap,currlvl.h,av.y,av.h,swing.yvec)
 end

 camera(xcamera*128,ycamera*128) 
end

function camera1d(camera,lvlpos,lvllength,avpos,avlength,swingvec)
 local lowbound=3
 --account for player width
 local highbound=12.5
 local scrollfrac=0.25
 local maxscrollspeed=0.1

	if lvllength==1 then
		camera=flr((avpos+avlength*0.5)/16)
	else
		--scrolling camera
		local tiledestination=8
		
		if av.canswing then
			if swingvec<0 then
				tiledestination=highbound
			else
				tiledestination=lowbound
			end
			
			local cameradest=(avpos-tiledestination)/16
			
			--smooth scroll to level bounds
			if cameradest<lvlpos then
				cameradest=lvlpos
			end
		
			if cameradest>lvlpos+lvllength-1 then
				cameradest=lvlpos+lvllength-1
			end

			local cameradiff=cameradest-camera
			
			cameradiff*=scrollfrac
			
			if cameradiff>maxscrollspeed then
				cameradiff=maxscrollspeed
			elseif cameradiff<-maxscrollspeed then
				cameradiff=-maxscrollspeed
			end
			
			camera+=cameradiff
		else
			--camera only moves if
			-- player gets past deadzone
			if avpos/16<camera+(lowbound/16) then
				camera=(avpos-lowbound)/16   
			end

			if avpos/16>camera+(highbound/16) then
				camera=(avpos-highbound)/16
			end
		end
		
		--don't scroll off level
		if camera<lvlpos then
			camera=lvlpos
		end
		
		if camera>lvlpos+lvllength-1 then
			camera=lvlpos+lvllength-1
		end
	end
	return camera
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
 
 --todo:smoothly return
 hook.x=hook.spawnx
 hook.y=hook.spawny
 
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
 --default
 t.basesprite=13
 t.sprites=1
 t.speed=20

 --idle animation
 if av.framesidle>300 then
  t.basesprite=11
  t.sprites=2
 end

 --flying through air
 if av.colstate!="ground" then
  t.basesprite=59
  t.sprites=3
  t.speed=7
 end

 --on hook
 if av.colstate=="hook" then
  t.basesprite=14
  t.sprites=1
 end

 --charge anim when adding force
 if swing.force>swing.lowf then
  --bottom half of swing force
  if swing.force<((swing.highf-swing.lowf)/2)+swing.lowf then
   t.basesprite=27
   t.sprites=3
   t.speed=10
   
   lsfx(2)
  elseif swing.force<=swing.highf-((swing.highf-swing.lowf)/10) then
   --top half
   t.basesprite=43
   t.sprites=3
   t.speed=8
   
   lsfx(3)
  else
   --top 10%
   t.basesprite=43
   t.sprites=3
   t.speed=2
   
   lsfx(4)
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
 
 if not isspawn(xcp,ycp) then
  mset(xcp,ycp,cpanim.sprite)
 end
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
 debug="you win!"
 
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
  (xcamera*128)+hw(s),(ycamera*128)+ycredits,c1,c2)
 
 s="by davbo and rory"
 outline(s,
  (xcamera*128)+hw(s),(ycamera*128)+ycredits+8,c1,c2)
 
 s="deaths: "..deathcount
 outline(s,
  (xcamera*128)+hw(s),(ycamera*128)+ycredits+16,c1,c2)

 s="swings: "..swingcount
 outline(s,
  (xcamera*128)+hw(s),(ycamera*128)+ycredits+24,c1,c2)

 s="playtime: "..
 twodigit(hours)..":"..
 twodigit(minutes)..":"..
 twodigit(seconds).."."..
 twodigit(frames)
 outline(s,
  (xcamera*128)+hw(s),(ycamera*128)+ycredits+32,c1,c2)

 s="thanks for playing!"
 outline(s,
  (xcamera*128)+hw(s),(ycamera*128)+ycredits+40,c1,c2)
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

__gfx__
0000000022222222aaa9aaa9d66666666666666d686868680000000000000000c0c0c0c000000000000000000060000000000000000000000040040000000000
000000002bbbbbb209aaa1a02dddd6d66d6dddd28585858600702200000000000c0c0c0c0000000000070000000777000060000000404000000ff00000000000
000770002bbbbbb20000000027766c7667866772685858580071220000000000c0c0c0c000777700006770000007707000077700000ff000001ff10000000000
006777002bbbbbb2001100002cccccc7788888828585858600712200000000000c0c0c0c0677777000677000000707700007707000f1f10000ffef0000000000
006677002bbbbbb2001100002cccccc228888882685858580071000000000000c0c0c0c00067770000777000000777000007077004fffe00000ff00000000000
000d60002bbbbbb20000000022222c26628222228585858600700000000000000c0c0c0c0000000000070000000606000067776000ffff0004ffff0000000000
000000002bbbbbb20000000025ddd2d66d2ddd52685858580070000000000000c0c0c0c00000000000000000000000000000000000f0f0000f0000f000000000
0000000022222222000000002222222dd22222228686868600700000000000000c0c0c0c00000000000000000000000000000000000000000000000000000000
0000000000000000aaa9aaa900666600006666000066660000000a00000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000029aaa2a20611116006ccac60065665600000a0a0007077000070070000700000000000000000404000004040000040400000000000000000
00000000000000002bbbbbb2611111166ccacac6644564460000a00a007677000076770000767700000000000000fff00040fff00000fff00000000000000000
00000000000000002bbbbbb2611111166cccaca665566556000aaaa000767700007677000076770000000000004f1f10000f1f10004f1f100000000000000000
00000000000000002bbbbbb2611111166ccacac66446544600aa0000007600000076700000706700000000000f0ffe00040ffe00040ffe000000000000000000
00000000000000002bbbbbb2611111166cccccc6655665560aa0000000700000007000000070000000000000404ff00000fff000400ff0000000000000000000
00000000000000002bbbbbb2611111166cccccc6644564460a0a00000070000000700000007000000000000000000000040000000f0000000000000000000000
000000000000000022222222611111166cccccc66556655600a00000007000000070000000700000000000000000000000000000000000000000000000000000
000aa000000880000008800000022000000220000002200000022000000220000008800000000000000000000000000000000000000000000000000000000000
009aa900002882000022880000228800002228000022220000822200008822000088220000000000000404000000040400004040000040400000000000000000
092002900022220000222800002288000022880000288200008822000088220000822200041f14f000f1f00000000f1f0040f1f00000f1f00000000000000000
9200002900022000000220000002200000088000000880000008800000022000000220000ffeff0000ff10000004fff1000fff10004fff100000000000000000
90000009000007000000070000000700000007000000070000000700000007000000070000fff00000fe00000800ffe0080ffe00840ffe000000000000000000
0a0000a00700007007000070070000700700007007000070070000700700007007000070000f040000ff00000404ff00404ff000404ff0000000000000000000
00000000007007000070070000700700007007000070070000700700007007000070070000000000000ff00008400000048000000f8000000000000000000000
00000000000770000007700000077000000770000007700000077000000770000007700000000000004000000000000000000000000000000000000000000000
000aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000aa000000000000000000000000000000000000000000000000000000000000000000000000000000000000404000000000000000f0f000000000000000000
009229000000000000000000000000000000000000000000000000000000000000000000000000000000000000fff00004f1e00000fff0000000000000000000
009009000000000000000000000000000000000000000000000000000000000000000000000000000000000000f1f10000ffff0000ffff000000000000000000
090000900000000000000000000000000000000000000000000000000000000000000000000000000000000004ffef00041fff00001fef000000000000000000
090000900000000000000000000000000000000000000000000000000000000000000000000000000000000000fff00000fff0f004ff10000000000000000000
00a00a00000000000000000000000000000000000000000000000000000000000000000000000000000000000f0f000000004000000440000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
11ddd1d1111111111ddddd11111d1d11111111111d1111111dddd11100000001110000000000000000000000000000000000000000dddddddddddddddddddd00
011101100110011111110011011100110011110001110011011100100000001d11000000000000000000000000000000000000000d000000d0d0d0d0d0d0d0d0
000000000000000001100000000000000000000000000000000000000000001d1100000000000000000000000000000000000000d00000000d0d0d0d0d0d0d0d
000000000011000000000000000000000000001100000000000000000000000d10000000000000000000000000000d0000000000d000000000d0d0d0d0d0d0dd
000001000011000000000000001100000000001100000000001000000000000d1100000000000000000000000000d6d000000000d0000000000000000d0d0d0d
000011100000000000001100001100000000000000000000011100000000000111000000000000000000000000000d0000000000d0000000000000000000d0dd
00000100000000000000110000000100000000000000000000100000000000111100000000001000000010000000010000000000d00000000000000000000d0d
000000000000000000000000000000000000000000000000000000000000001d1000000001011111000011100001010000000000d0000000000000000000d0dd
0000000000000000000000000dd11111111111111dddddd000000000000000011000000000000000000000000000000000000000d00000000000000000000d0d
000000000000000000000000d1111101011001110001111d00000000000000111100010000000000000000000000000000000000d0000000000000000000d0dd
00000100000011000011000010111000000000000000111100000000000000111100111000000000000000000000000000000000d00000000000000000000d0d
00000000000011000011000010000000001100000010011100000000000000111000010000000000000000000000000000000000d0000000000000000000d0dd
0000110000000000000000001000000000110100000000010000000000100001d100000000000000000000000000000000000000d00000000000000000000d0d
0000110000000000000000001000110000000000001100010000000001110011d100000000000000000000000000000000000000d0000000000000000000d0dd
0000000101100111100001001000110000000000001100010000000000100011d100000000000000000000000000000000000000d00000000000000000000d0d
00000011111111111100000010000000000000000000000100000000000000011000000000000000000000000000000000000000d000000000000000000000dd
00000011000000001100000010000000000000000000000100000000000000011100000000000000000000000550005005000050d0000000000000000000000d
000000110000000011000000100010000000000000000001000000000000001d1100000000000000000000005500000550000500d0000000000000000000000d
00100001000000001000011010000000000000000000000100000000000110111100000000000000000000005050000000005000d0000000000000000000000d
00000001000000001100011010000000001000000000000100000000000110011000000000000000000000000000000000050000d0000000000000000000000d
000010110000000011000000110000000000000000000001000000000000000d1001100000000000000000000000000000050000d0000000000000000000000d
000000110000000011000000111000000000000000011101000000000000001d1101100000000000000000000000050500005000d0000000000000000000000d
000000110000000011000000111000001110000000111111110011100000001111000000000000000000000050000055500005000d00000000000000000000d0
0000000100000000100000000111111111111111111111101111111100000011100000000000000000000000050005500500005000dddddddddddddddddddd00
00000011111111111100000000000000000000000000000000000000000000111100000000000000000000005050050055000055000000000000000000000000
00110001011101101000000000100000000000000011000000000000000001111100000000000000000000000505005050000005000000000000000000000000
0011000000000000000000000111000000000000001100000000000000000111d000011000000000000000005050500500055000000000000000000000000000
0000000000000000000000000010000000001100000000001100000000000011d000011000000000000000000505050000555500000000000000000000000000
0000000001100000001000000000000000001100000000001100000001100001d100000000000000000000000050505000555500000000000000000000000000
000000000110000001110000000000000000000000000110000000000110000dd110000000000000000000005005050500055000000000000000000000000000
000000000000000000100000011011101110011011001111001111000000001dd110000000000000000000000500505050000005000000000000000000000000
00000000000000000000000011dddd111dd1d111111111111dddd11100000011d100000000000000000000000050050555000055000000000000000000000000
10101010101010101010101010101010101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000
10000000212121212100000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000000000000000000008080808010105080805000000000000000000000100000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000000000000000000008080808010108080808000000000000000006100100000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000000000000000000008080808010108080808000000000000000600000100000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000041000050006100508080808010108080808000000000000010101010100000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10101010101050000200500000000010100000000050505050505050505050100000000000000000000000000000000000000000000000000000000000000000
10000021212100000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000000000050505050500000000010100000000050505050505080808080100000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000000000200000000000000000010108080808000000000000080808080100000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000021210010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000000000010108080808000000000000080808080100000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000021000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000000005000000000000000000010108080808000000000000080808080100000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000000005000000000000000000010105050505050505050500000000000100000000000000000000000000000000000000000000000000000000000000000
10000000212121000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10003100005000000000500000000010105050505000000000000000000000100000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10001010005000000000500000020010100000000000000000000080808080100000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10001010005000000000500000000010100000000000000000000080808080100000000000000000000000000000000000000000000000000000000000000000
10000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10000000005000000000500000000010105100310000505050505050505050100000000000000000000000000000000000000000000000000000000000000000
10000000000000000000005100000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10101010101010101010101010101010101010101010101010101010101010100000000000000000000000000000000000000000000000000000000000000000
10101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
10101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10101010101010101010101010101010105050505050505050101010101010101010101010101010101010101010101000000000000000000000000000000000
10000000005000100000000000500010100000000000000050505000005200101000000000000000000000000000101010005050505000000000000000000010
10000000000000000000000050505010100000000000000000000000000000101000000000000000000000000000001000000000000000000000000000000000
10000000000050100041000000005010100000000000000000005000006100101050000000000000000000000061001010505000000000000000000000000010
10004100002121000000000050505010100000000000000000000000000000101000000000000000000000000000001000000000000000000000000000000000
10000000000000502121210000000010100000000000000000005000000000101050000000000000505000000060001010505000404040405050404000006010
10101010001000100000000000000010100000000000000060000010000000101000000000000000000000000000001000000000000000000000000000000000
10000000000000005000000000000010100000410000000000000000000000101050004100000050000000220010101010500041505000000000000022001010
10101010001010000000000000000010101010500000212121000010500000101000000000000000000000000000001000000000000000000000000000000000
10000000500000000050000000000010101010101010500000000000000000101050502150505000000000000000001010101010101000000000000000000010
10101010001000105000000000000010105050500000100000000010500000101000000000000000000000000000001000000000000000000000000000000000
10000000005000005000000000000010100000000000500000000000000000101000000000000000000000000000001010000000001000000000000000000010
10505050501010000050006000000010105050500000100000000010000000101000000000000000000000000000001000000000000000000000000000000000
10000000005000000000000000120010100000000000500012005000000000101000000000000000505000005050001010000000001000005050000000005050
10000000500000000000502121000010100000000000100000000010000000101000000000000000000000000000001000000000000000000000000000000000
10000000005000000000000050000010100000000000505050505000000000101000000000000050505021215050501010000000000000005050000000005050
10000031500000000000100000100010100000000000100061000010000000101000000000000000000000000000001000000000000000000000000000000000
10120050005000000000000000500010100000000000101010105000000000101000000000002110101010101010101010001230303030305050303030305050
10001010500000000000100000100010100000000000102121505010000000101000000000000000000000000000001000000000000000000000000000000000
10005000005000000050000000005010100032000000000000005000000000101000000000000000000000000000001010000000000000500000000000000010
10001000100000100000100000100010100000000000105050000000000000101000000000000000000000000000001000000000000000000000000000000000
10500000005000004200500000000010100000000050000000005000000000101000000000000000000000000000001010000000000000500000000000000010
10001000100000100042001010001210100000101010101010000000000000101000000000100000000000000000001000000000000000000000000000000000
10000000005050000000000000820010100000000050000032000000000200101000000000000000000000000000001010000000000000500000100000000010
10001010000000100000000000000010100000000000001010000000212121101000000000100061000000000000001000000000000000000000000000000000
10220050005000500000000000005010100000000050000000000000000000101010000000000000000010003100101010000000000000000000100031001010
10001000000000101010003222000010100000000000001010000000000000101000000000101000000000000000001000000000000000000000000000000000
10315050125000005000000000500010100000310050505050505000000000101000101050505050505000101010001010101010505040404040401010101010
10000000006000505050505050505010100000310000001050000000410000101000003100006000600000510000001000000000000000000000000000000000
10101010501010101050505050101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010
10303030303010101010101010101010105050101010101050505010101010101010101010101010101010101010101000000000000000000000000000000000
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
0001414345102000400000000000000000004182a0a090000000000000000000081838286848c88898000000000000000008000000000000000000000000000001010101010101010100000000404040010101010101010101000000004040400101010101010101010000000040404001010101010101010100000000000000
0101010101010101000000000000000001010101010101010000000000000000010101010101010100000000000000000101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
5074737566666673747466757466515201010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
604d4f00000000000000004d4e4e4f4801000000000000000000000000000001010000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
575d5f00000000000000005d5e5e5f6801000000160000000000000000000001010000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
605d5f00000000000000006d6e6e6f5801000000000000000000000000000001010000000000000000010000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
675d5f0000000000000000000000004801000001010000000000000000000001010000000000200001010000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
606d6f00000000004b4a00001300006801000000000000000020000001000001010000000000000001010000200000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4700000000000000534444424571447201000000000000000000000000000001010000000101000001000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
5700000053550000580000000000000000000000000000000000000000000001010000000000000001000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6000000063650000480000000000000000000000000000000000000000000001010000000000000001002000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6000000000000000630000000000000000000000000000000101000000000001010000000000000001140005000500010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6700000000000000000000000000000000000000000000000000000000000001010000000020000000010501050105010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6000000000000000000000200000005301000000010100000000000000200000000000000000000000000100010001010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6700000000000000000000000000007801000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6000000000000000000000000000004801000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
670000490000000000004b000000005801000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
7002020245454644454544454344457201010101010101010101010101010101010101010101010101010101010101010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0100000000000000000000000000000000000000000000000000000000000001010000000000000000000000050000000000000100000000000505050000000101000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0100000000000000000000000000000000000000000000000000000000000001010000000000000000000000000000000000000100000000000000000000000101000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0100000000000000000000000000000000000000000000050500000000000001010000000000000000000000000000000000000100000000001608080500000101000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0100000000000101010101010101010000000006000000050500000000000001010000000000000000000000050000000000000100000000000808080500000101000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0500000000000101010105050505050101010101010101050500000000000001010000000000000000000000050000130000000100000000050808080500000101000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0508080800000000000000000000050101000000000000000000000808080801010000000000000500000501010101010101010100000000050000000000000101000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0508080800000000002800002700050101000000000000000000000808080801010000000000000505050500050000000000000000002100050000000000000101000101001300000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0508080800000101010105000000050101000000000000000000000808080801010000000000000505000000050000000000000000000000000000000500000101000001010101000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0505050505050505050505000000000101000000000000000005050505050501010000001212120500000000000000000000000000000000001212120500000101000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0100000000000000000000000000000101010101010000000005050505050501010000000500000500000000000000000000000000000000000000000000000101000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0100000000000000000000000000000101000000000000000008080808080501010000000000000000000000000000000000000000000000000000000000000101000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0100000000000000000005080808050101000000000000000008081608080501010000000000000600000000050000121212120000000000000000050015000101000000000000000000000016000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0100000000000000000005080808050101000000000000000008080808080501010000000500121212000000050000000000000000000000000000051212120101000000000000000000001212120001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0100001300000000000005080808050101000015000000000505050505050501010000000500000000000000050000000000000000000000000000050000000101000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0101010101010101010105050505050101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101010101000000000000001200000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
