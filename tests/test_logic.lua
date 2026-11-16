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

-- EPUB positions that differ only in wrapping or inline markup have the same
-- structural paragraph identity. Distinct paragraphs have distinct keys.
local akey=L.paragraphKey('/body/DocFragment[1]/body/div/p[2]/span/text().16')
local bkey=L.paragraphKey('/body/DocFragment[1]/body/div/p[2]/em/text().45')
local ckey=L.paragraphKey('/body/DocFragment[1]/body/div/p[3]/text().0')
ok(akey==bkey and akey~=ckey, 'EPUB paragraph boundaries use native DOM')
ok(L.paragraphKey('/body/DocFragment/body/ul/li[4]/text().0')
    ~=L.paragraphKey('/body/DocFragment/body/ul/li[5]/text().0'),
    'list items are independent reading units')
ok(L.paragraphKey('not-an-xpointer')==nil,'unknown position is not misidentified')
local long_lines={}
for i=1,9 do long_lines[i]={x=40,y=40*i,w=360,h=25,area=area} end
local keys={}
for i=1,9 do
    keys[i]=i<=7 and akey or ckey
end
local starts=L.paragraphStarts(long_lines,keys)
ok(#starts==2 and starts[1]==1 and starts[2]==8,
    'seven-line EPUB paragraph stays intact beyond five-line limit')
local first,last=L.paragraphRange(long_lines,starts,4)
ok(first==1 and last==7,'current paragraph range from any member line')
ok(L.slotRange(long_lines,first,last).h>200,'full paragraph visible window')
-- Test the adjusted paragraph top boundary without clipping the text box.
local normal_para = L.slotRange(long_lines,1,7)
local clean_para = L.slotRange(long_lines,1,7,0)
ok(normal_para.y == long_lines[1].y-2, 'default paragraph padding retained')
ok(clean_para.y == long_lines[1].y and clean_para.h == normal_para.h-2,
    'paragraph Reading Window removes only the top clear strip')
ok(clean_para.y + clean_para.h == normal_para.y + normal_para.h,
    'bottom descender protection remains unchanged')
ok(select(1,L.paragraphAdvance(starts,1,1))==8,
    'next advances to next paragraph')
ok(select(1,L.paragraphAdvance(starts,8,-1))==1,
    'previous returns to preceding paragraph')
ok(select(2,L.paragraphAdvance(starts,8,1))==1
    and select(2,L.paragraphAdvance(starts,1,-1))==-1,
    'end-of-page paragraph navigation delegates real page turn')
local contiguous={}
for i=1,4 do contiguous[i]={x=40,y=40*i,w=350,h=25,area=area} end
contiguous[3].y=180
contiguous[4].y=220
local detected=L.paragraphStarts(contiguous,{})
ok(detected[2]==3,'PDF empty-line fallback starts new paragraph')
local short={}
for i=1,4 do short[i]={x=40,y=i*40,w=350,h=25,area=area} end
short[2].w=100
local breaks=L.paragraphStarts(short,{})
ok(breaks[2]==3,'PDF short final line begins following paragraph')
local indented={}
for i=1,4 do indented[i]={x=40,y=i*40,w=350,h=25,area=area} end
indented[3].x=85
ok(L.paragraphStarts(indented,{})[2]==3,'PDF indented paragraph begins new unit')
local right_area={x=500,y=0,w=400,h=800}
long_lines[8].area=right_area
long_lines[9].area=right_area
local columns=L.paragraphStarts(long_lines,keys)
ok(columns[2]==8 and L.slotRange(long_lines,1,9).area==area,
    'separate reading areas never merge into one focus window')

-- Freeform Focus uses only page viewport geometry, never text positions.
local viewport={x=0,y=0,w=600,h=900}
ok(L.freeformWindowHeight(viewport,30)==270,
    '30-percent Freeform window height')
ok(L.freeformLastIndex(viewport,30)==4,
    'ceil last index includes a short final page section')
local all_slots={}
for i=1,4 do all_slots[i]=L.freeformSlot(viewport,30,i) end
ok(all_slots[1].y==0 and all_slots[1].h==270,
    'Freeform begins at top of page')
ok(all_slots[4].y==630 and all_slots[4].y+all_slots[4].h==900,
    'Freeform last window aligns exactly to page bottom')
for i=2,#all_slots do
    ok(all_slots[i].y <= all_slots[i-1].y+all_slots[i-1].h,
        'Freeform windows never skip any page pixels')
end
-- Overlap moves a shorter distance, reverses exactly, and covers the bottom.
ok(L.freeformLastIndex(viewport,30,25)==5,
    'Freeform 25-percent overlap adds the required window')
local overlaps={}
for i=1,5 do overlaps[i]=L.freeformSlot(viewport,30,i,25) end
ok(overlaps[1].y==0 and overlaps[2].y==202,
    'Freeform overlap retains the previous reading band')
ok(overlaps[5].y+overlaps[5].h==900,
    'Overlapping Freeform last window reaches the page bottom')
for i=2,5 do
    ok(overlaps[i].y<=overlaps[i-1].y+overlaps[i-1].h,
        'Overlapping Freeform windows leave no gaps')
end
ok(select(1,L.freeformAdvance(viewport,30,2,-1,25))==1,
    'Freeform overlap reverses one step')
ok(select(2,L.freeformAdvance(viewport,30,5,1,25))==1,
    'Freeform overlap turns page only after final window')
ok(L.freeformLastIndex(viewport,30,0)==L.freeformLastIndex(viewport,30),
    'Zero overlap preserves original navigation')
ok(select(1,L.freeformAdvance(viewport,30,1,1))==2,
    'Freeform next click moves one window')
ok(select(1,L.freeformAdvance(viewport,30,3,-1))==2,
    'Freeform previous click reverses one window')
ok(select(2,L.freeformAdvance(viewport,30,4,1))==1,
    'Freeform last window requests real next page')
ok(select(2,L.freeformAdvance(viewport,30,1,-1))==-1,
    'Freeform first window requests real previous page')
local inset={x=12,y=24,w=400,h=777}
local end_slot=L.freeformSlot(inset,25,999)
ok(end_slot.x==12 and end_slot.y+end_slot.h==801,
    'Freeform respects nonzero origin and bottom viewport bounds')
ok(L.freeformWindowHeight({x=0,y=0,w=0,h=900},25)==nil,
    'invalid viewport cannot show a reading window')
ok(L.freeformLastIndex(viewport,0)==0,
    'out-of-range settings cannot create an invalid window')
local wide=L.freeformSlot(viewport,75,2)
ok(wide.y==225 and wide.h==675,
    '75-percent Freeform window overlaps the bottom without gaps')
print('PASS: '..n..' logic checks')
