pico-8 cartridge // http://www.pico-8.com
version 41
__lua__

function _init()
 frames=0
 
 --[[
 sp=0
 backupaddr1=512*(sp\16)+4*(sp%16)

 sp=1
 backupaddr2=512*(sp\16)+4*(sp%16)
 ]]
 
 --backup to persistent
 -- cart data memory
 backupaddr1=0x5e00

 backupaddr2=0x5e10
end

function _update()
 frames+=1
 
 scrollarea(17,30,2,8,1,0,direction)

 if frames==60 then
	 -- sp=17
	 -- addr=512*(sp\16)+4*(sp%16)
	 
	 --pixelshiftverboseupwards()

  -- --save row 8
	 -- memcpy(backupaddr2,addr+(64*7),4)

  -- --save row 8 to set buffers up
  -- memcpy(backupaddr2,addr+(64*7),4)
  
  -- pixelshift(addr+(64*6),addr+(64*5))
  
  -- pixelshift(addr+(64*4),addr+(64*3))
  
  -- pixelshift(addr+(64*2),addr+(64*1))
  
  -- pixelshift(addr+(64*0),addr+(64+7))

	 -- memcpy(addr+(64*7),backupaddr1,4)

  -- sp=18
  -- addr=512*(sp\16)+4*(sp%16)

  -- --pixelshiftverbose()

  -- memcpy(backupaddr2,addr,4)
  
  -- pixelshift(addr+64,addr+(64*2))
  
  -- pixelshift(addr+(64*3),addr+(64*4))
  
  -- pixelshift(addr+(64*5),addr+(64*6))
  
  -- pixelshift(addr+(64*7),addr)
   

	 frames=0
 end
end

function scrollarea(spr,speed,w,h,woff,hoff,direction)
 if frames%speed!=0 then
  return
 end

 woff=woff or 0

 hoff=hoff or 0

 direction=direction or -1

 addr=(512*(spr\16)+4*(spr%16))+woff
 
 --save row 8 to set buffers up
 memcpy(backupaddr2,addr+(64*7),w)

 --memcpy(backupaddr2,addr+(64*7),4)
 
 for i=6,0,-2 do
  pixelshift(addr+(64*i),addr+(64*(i-1)),w)
 end

 memcpy(addr+(64*7),backupaddr1,w)
end

-- function pixelshift(addr1,addr2)
--  --save row 1
--  memcpy(backupaddr1,addr1,4)
 
--  -- write row 0 to row 1
--  memcpy(addr1,backupaddr2,4)
 
--  -- save row 2
--  memcpy(backupaddr2,addr2,4)
 
--  -- write row 1 to row 2
--  memcpy(addr2,backupaddr1,4)
-- end


function pixelshift(addr1,addr2,w)
 swap(backupaddr1,backupaddr2,addr1,w)
 swap(backupaddr2,backupaddr1,addr2,w)
end

function swap(backupaddr,pastefromaddr,swapaddr,w)
 memcpy(backupaddr,swapaddr,w)
 memcpy(swapaddr,pastefromaddr,w)
end


function _draw()
 cls(0)
 print(addr)

 spr(0,8,8)
 spr(1,8,16)
 spr(17,32,64)
 spr(17,32,72)
 spr(17,32,80)
 spr(17,32,88)
 spr(18,64,64)
end

function pixelshiftverboseupwards()
	 
  --save row 8
	 memcpy(backupaddr2,addr+(64*7),4)

	 -- save row 7
	 memcpy(backupaddr1,addr+(64*6),4)
	 
	 -- write row 8 to row 7
	 memcpy(addr+(64*6),backupaddr2,4)
	 
	 -- save row 6
	 memcpy(backupaddr2,addr+(64*5),4)
	 
	 -- write row 7 to row 6
	 memcpy(addr+(64*5),backupaddr1,4)
	 
	 -- save row 5
	 memcpy(backupaddr1,addr+(64*4),4)
	 
	 --write row 6 to row 5
	 memcpy(addr+(64*4),backupaddr2,4)
	 
	 --save row 4
	 memcpy(backupaddr2,addr+(64*3),4)
	 
	 --write 5 to 4
	 memcpy(addr+(64*3),backupaddr1,4)
	 	 
	 -- save row 3
	 memcpy(backupaddr1,addr+(64*2),4)
	 
	 --write row 4 to row 3
	 memcpy(addr+(64*2),backupaddr2,4)
	 
	 --save row 2
	 memcpy(backupaddr2,addr+(64*1),4)
	 
	 --write row 3 to 2
	 memcpy(addr+(64*1),backupaddr1,4)
	 
	 -- save row 1
	 memcpy(backupaddr1,addr+(64*0),4)
	 
	 --write 2 to 1
	 memcpy(addr+(64*0),backupaddr2,4)
	 
	 --write 1 to 8
	 memcpy(addr+(64*7),backupaddr1,4)
	 
end

function pixelshiftverbose()
	 
	 -- save row 2
	 memcpy(backupaddr1,addr+64,4)
	 
	 -- write row 1 to row 2
	 memcpy(addr+64,addr,4)
	 
	 -- save row 3
	 memcpy(backupaddr2,addr+(64*2),4)
	 
	 -- write row 2 to row 3
	 memcpy(addr+(64*2),backupaddr1,4)
	 
	 -- save row 4
	 memcpy(backupaddr1,addr+(64*3),4)
	 
	 --write row 3 to row 4
	 memcpy(addr+(64*3),backupaddr2,4)
	 
	 --save row 5
	 memcpy(backupaddr2,addr+(64*4),4)
	 
	 --write 4 to 5
	 memcpy(addr+(64*4),backupaddr1,4)
	 	 
	 -- save row 6
	 memcpy(backupaddr1,addr+(64*5),4)
	 
	 --write row 5 to row 6
	 memcpy(addr+(64*5),backupaddr2,4)
	 
	 --save row 7
	 memcpy(backupaddr2,addr+(64*6),4)
	 
	 --write 6 to 7
	 memcpy(addr+(64*6),backupaddr1,4)
	 
	 -- save row 8
	 memcpy(backupaddr1,addr+(64*7),4)
	 
	 --write 7 to 8
	 memcpy(addr+(64*7),backupaddr2,4)
	 
	 --write 8 to 1
	 memcpy(addr,backupaddr1,4)
	 
end
__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000b1333b077777777000000007a9f6d200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000b3133b044444444000000007a9f6d200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000b3313b099999999000000007a9f6d200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000b3331b0ffffffff000000007a9f6d200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000b6333b066666666000000007a9f6d200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000b3633b0dddddddd000000007a9f6d200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000b3363b022222222000000007a9f6d200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000b3336b088888888000000007a9f6d200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
