local base = (arg and arg[0] or 'tests/test_logic.lua'):gsub('tests/test_logic.lua$', 'focusreader.koplugin/')
local L = dofile(base .. 'logic.lua')
local n=0
local function ok(v,msg) assert(v, msg); n=n+1 end
local area={x=0,y=0,w=500,h=800}
local lines={}
for i=1,7 do lines[i]={x=40,y=i*40,w=300,h=25,area=area} end
ok(L.maxStart(lines,3)==5, 'maxStart')
ok(L.slot(lines,1,3).h>0, 'slot rectangle')
ok(select(1,L.advance(lines,1,3,1,1))==2, 'advance forward')
ok(select(1,L.advance(lines,2,3,-1,1))==1, 'advance backward')
ok(select(2,L.advance(lines,5,3,1,1))==1, 'page forward boundary')
ok(select(2,L.advance(lines,1,3,-1,1))==-1, 'page backward boundary')
-- Non-overlapping Reading Guide: final partial group must not repeat old lines.
ok(select(1,L.advanceGroup(lines,1,3,1))==4, 'group 1-3 to 4-6')
ok(select(1,L.advanceGroup(lines,4,3,1))==7, 'group 4-6 to final line 7')
ok(L.slot(lines,7,3,true).y==lines[7].y-2, 'final group begins at line 7')
ok(select(2,L.advanceGroup(lines,7,3,1))==1, 'turn page after short group')
ok(select(1,L.advanceGroup(lines,7,3,-1))==4, 'back to prior full group')
ok(select(1,L.advanceGroup(lines,4,3,-1))==1, 'back to first group')
ok(select(2,L.advanceGroup(lines,1,3,-1))==-1, 'previous page at first group')
local five={}
for i=1,12 do five[i]={x=40,y=i*30,w=300,h=20,area=area} end
ok(select(1,L.advanceGroup(five,1,5,1))==6, 'five line group advances to line 6')
ok(select(1,L.advanceGroup(five,6,5,1))==11, 'five line group advances to last two')
ok(L.slot(five,11,5,true).y==five[11].y-2, 'five line partial group does not repeat')
ok(select(2,L.advanceGroup(five,11,5,1))==1, 'five line group turns page after partial')
local a=L.slot(lines,1,3);local b=L.slot(lines,2,3)
local bounds=L.changedBounds(a,b,8)
ok(bounds.w==500 and bounds.h>0, 'full width changed bounds')
ok(L.guideChangedBounds(a,b,8).h>0, 'guide boundary bounds')
local same=L.unionRefresh({x=1,y=2,w=10,h=20},{x=8,y=16,w=10,h=20})
ok(same.x==1 and same.y==2 and same.w==17 and same.h==34, 'unionRefresh')
local nrm=L.normaliseLines({{x=30,y=100,w=40,h=18},{x=78,y=101,w=30,h=18},{x=30,y=160,w=60,h=18}},area)
ok(#nrm==2 and nrm[1].w==78, 'fragment line merging')
local box=L.selectionBounds({{x=30,y=100,w=30,h=18}},area)
ok(box and box.y==100 and box.h==18, 'selection bounds')
print('PASS: '..n..' logic checks')
