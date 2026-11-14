local checks = 0
local function check(ok, what)
    if not ok then error('FAILED: '..what, 2) end
    checks = checks + 1
end

local stored = {
    line_count=2, legacy_line_count=4, opacity=10, intensity=80,
    color_refresh_mode='wide_wait', refresh_mode='screen',
    color_name='yellow', style='color', spotlight_layout='guide', step_mode='line'
}
local saved = {}
package.preload['gettext']=function() return function(x) return x end end
package.preload['datastorage']=function() return {getSettingsDir=function() return '/test' end} end
package.preload['ffi/blitbuffer']=function() return {COLOR_BLACK='BLACK',COLOR_WHITE='WHITE', ColorRGB32=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end} end
package.preload['device']=function() return {screen={getWidth=function() return 600 end, getHeight=function() return 900 end}} end
package.preload['ui/geometry']=function() return {new=function(_,v) return v end} end
package.preload['luasettings']=function()
   return {open=function() return {
      readSetting=function(_,k) return stored[k] end,
      saveSetting=function(_,k,v) stored[k]=v; saved[k]=v end,
      flush=function() end
   } end}
end
local dirty = {}
package.preload['ui/uimanager']=function() return {
   setDirty=function(_,widget, mode, region) dirty[#dirty+1]={widget=widget,mode=mode,region=region} end,
   show=function(_,msg) error('unexpected InfoMessage') end,
} end
package.preload['ui/widget/widget']=function()
   local Widget={}
   function Widget:extend(fields) return setmetatable(fields,{__index=self}) end
   return Widget
end
package.preload['ui/widget/infomessage']=function() return {new=function(_,arg) return arg end} end
local plugin_path = (arg and arg[0] or 'tests/test_plugin.lua'):gsub('tests/test_plugin.lua$', 'focusreader.koplugin/')
local P = dofile(plugin_path..'main.lua')
local log={}
local page=1
local doc={}
doc._document={setStringProperty=function(_,prop,value) log[#log+1]={kind='color',value=value} end}
function doc:getCurrentPage() return page end
function doc:getCurrentPos() return 0 end
function doc:getVisiblePageCount() return 1 end
function doc:getPageCount() return 3 end
function doc:clearSelection() log[#log+1]={kind='clear'} end
function doc:getTextFromXPointers(a,b,draw) log[#log+1]={kind='select',draw=draw}; return 'hello' end
function doc:getTextFromPositions(a,b,do_not_draw)
    local boxes = {}
    for i=1,12 do boxes[i]={x=40,y=60+40*i,w=380,h=24} end
    return {sboxes=boxes,pos0='xp1',pos1='xp2'}
end
local menu_items
local view={dialog={},view_mode='page',footer_visible=false,registerViewModule=function(self,k,p) self[k]=p end}
local roll={}
local original=function(_,d) page=math.min(3,math.max(1,page+d)); return true end
roll.onGotoViewRel=original
local ui={document=doc,rolling=roll,highlight={setSelectionColor=function() log[#log+1]={kind='restore'} end},menu={registerToMainMenu=function(_,plugin) menu_items={}; plugin:addToMainMenu(menu_items) end}}
local instance=setmetatable({ui=ui,view=view},{__index=P})
instance:init()
check(instance.opacity==56, 'default opacity overrides saved old opacity')
check(instance.refresh_mode=='focused','focused refresh overrides saved screen refresh')
check(instance.color_refresh_mode==nil,'experimental color refresh ignored')
check(instance.line_count==2 and instance.legacy_line_count==4,'line settings retained')
check(instance.color_name=='yellow','saved color retained')
check(instance.spotlight_layout=='guide','spotlight style retained')
instance:onReaderReady()
check(instance.supported and view.focusreader==instance,'plugin loaded and registered')
check(type(menu_items.focusreader)=='table','menu registered')
check(menu_items.focusreader.sorting_hint=='tools','Tools menu location')
local items=menu_items.focusreader.sub_item_table
check(#items==4,'four simple menu sections')
check(items[2].text=='Reading mode' and #items[2].sub_item_table==3,'reading mode includes both spotlight layouts')
check(items[3].text=='Highlight Focus' and #items[3].sub_item_table==5,'highlight includes PDF style, word mode and diagnostics')
check(items[3].sub_item_table[5].text=='Word navigation diagnostic','diagnostic menu item registered')
check(items[4].text=='Spotlight Focus' and #items[4].sub_item_table==2,'spotlight lines and mask color')
check(items[3].sub_item_table[1].text=='Color' and items[3].sub_item_table[2].text=='Focused lines','highlight color + lines labels')
local labels={}
local function scan(a)
 for _,e in ipairs(a) do
   labels[#labels+1]=(e.text or '')
   if e.sub_item_table then scan(e.sub_item_table) end
 end
end
scan(items)
local label_text=table.concat(labels,';'):lower()
check(not label_text:find('opacity') and not label_text:find('refresh') and not label_text:find('test') and not label_text:find('clicker'), 'hidden technical settings')
check(#items[3].sub_item_table[1].sub_item_table==6,'six colors available')
check(#items[3].sub_item_table[2].sub_item_table==5,'highlight lines 1-5 available')
check(items[3].sub_item_table[4].text=='Word-by-word (no speech)','word focus toggle exists')
check(#items[4].sub_item_table[1].sub_item_table==5,'spotlight lines 1-5 available')
instance:start()
check(instance.enabled and roll.onGotoViewRel~=original,'start installs clicker hook')
local selected=false
for _,x in ipairs(log) do if x.kind=='select' and x.draw then selected=true end end
check(selected,'native selection rendered')
local before=instance.index
roll:onGotoViewRel(1)
check(instance.index==before+1,'clicker down advances a line')
roll:onGotoViewRel(-1)
check(instance.index==before,'clicker up returns a line')
local total = #instance.lines
for _=1,total do roll:onGotoViewRel(1) end
check(page==2,'automatic next page')
for _=1,total do roll:onGotoViewRel(-1) end
check(page==1,'automatic previous page')
items[3].sub_item_table[1].sub_item_table[2].callback()  -- orange
check(instance.color_name=='orange' and stored.color_name=='orange','changing color saved')
items[3].sub_item_table[2].sub_item_table[4].callback()
check(instance.line_count==4 and stored.line_count==4,'highlight line count changed and saved')
items[2].sub_item_table[2].callback()  -- window
check(instance.style=='mask' and instance.spotlight_layout=='window','spotlight window selected')
local bb={paints=0, paintRect=function(self,_,_,w,h,color) self.paints=self.paints+1; assert(color=='BLACK') end}
instance:paintTo(bb,0,0)
check(bb.paints>=1,'blackout drawn')
check(instance.spotlight_mask_color=='black','old settings default to black')
items[4].sub_item_table[2].sub_item_table[2].callback()
check(instance.spotlight_mask_color=='white' and stored.spotlight_mask_color=='white','white mask preference saved')
local white_bb={paints=0,paintRect=function(self,_,_,w,h,color) self.paints=self.paints+1; assert(color=='WHITE') end}
instance:paintTo(white_bb,0,0)
check(white_bb.paints>0,'white mask painted')
items[4].sub_item_table[2].sub_item_table[1].callback()
check(instance.spotlight_mask_color=='black','black can be restored')
items[2].sub_item_table[3].callback() -- guide
check(instance.style=='mask' and instance.spotlight_layout=='guide','spotlight guide selected')
items[4].sub_item_table[1].sub_item_table[3].callback()
check(instance.legacy_line_count==3 and stored.legacy_line_count==3,'independent spotlight lines saved')
items[2].sub_item_table[1].callback()
check(instance.style=='color','switch back to highlight focus')
check(instance.opacity==56,'opacity unchanged after style changes')
instance:stop()
check(not instance.enabled and roll.onGotoViewRel==original,'stop restores clicker hook')
-- Word focus must not start without native word geometry.
items[3].sub_item_table[4].callback()
check(instance.word_mode and stored.word_mode,'word mode persists')
local mgr = require('ui/uimanager')
local original_show_word = mgr.show
local word_messages = 0
mgr.show = function() word_messages = word_messages + 1 end
instance:start()
check(not instance.enabled and word_messages == 1,'missing word geometry fails safely')
mgr.show = original_show_word
items[3].sub_item_table[4].callback()
check(not instance.word_mode,'word mode can be disabled')
check(saved.opacity==nil and saved.intensity==nil and saved.color_refresh_mode==nil and saved.refresh_mode==nil, 'retired settings never rewritten')
check(dirty[#dirty].mode=='ui','nonflashing ui refresh mode preserved')

-- A reader without a native selection backend must not silently switch a
-- working Spotlight Focus session to blank colored selection.
instance:setStyle('mask')
instance:start()
check(instance.enabled and instance.style=='mask', 'spotlight starts before fallback test')
local original_color_method = doc.getTextFromXPointers
doc.getTextFromXPointers = nil
-- Test with UIManager.show overridden to record expected message, not crash.
local manager = require('ui/uimanager')
local orig_show = manager.show
local info_count = 0
manager.show = function(_,msg) info_count = info_count + 1; assert(type(msg.text)=='string') end
instance:setStyle('color')
check(instance.style=='mask' and info_count==1, 'missing native selection API preserves spotlight')
doc.getTextFromXPointers = original_color_method
manager.show = orig_show
instance:stop()

-- The actual KOReader TouchMenu keeps an item with checked_func open
-- unless the callback explicitly closes it; check_callback_closes_menu also
-- prevents a stale updateItems() after the menu has closed.
local function driveMenu(item)
    local trace = {}
    local fake = {
        closeMenu = function() trace[#trace + 1] = 'close' end,
        updateItems = function() trace[#trace + 1] = 'update' end,
    }
    local before_dirty = #dirty
    local original_setDirty = require('ui/uimanager').setDirty
    require('ui/uimanager').setDirty = function(self, widget, mode, region)
        trace[#trace + 1] = 'paint'
        original_setDirty(self,widget,mode,region)
    end
    -- Mirror KOReader TouchMenu:onMenuSelect checked/normal leaf logic.
    item.callback(fake)
    if item.checked or item.checked_func then
        if not (item.check_callback_updates_menu or item.check_callback_closes_menu) then
            fake:updateItems()
        end
    elseif not item.keep_menu_open then
        fake:closeMenu()
    end
    require('ui/uimanager').setDirty = original_setDirty
    check(#trace >= 1 and trace[1] == 'close', 'menu closes first')
    check(trace[2] ~= 'close', 'menu closes only once')
    check(not table.concat(trace,','):find('update'), 'no updateItems after checked menu closes')
    if #dirty > before_dirty then
        check(trace[1] == 'close' and trace[2] == 'paint', 'menu closes before repaint')
    end
end
-- Exercise every leaf entry, each with a mock touch menu; this also catches
-- checked entries not flagged check_callback_closes_menu.
local function eachLeaf(list)
    for _, entry in ipairs(list) do
        if entry.sub_item_table then
            eachLeaf(entry.sub_item_table)
        elseif entry.callback and entry.text ~= 'Word navigation diagnostic' then
            -- Informational action deliberately opens InfoMessage; test its
            -- registration separately rather than treating it as a setting.
            if entry.checked_func then
                check(entry.check_callback_closes_menu == true,
                    'checked entry suppresses updateItems on menu close')
            end
            driveMenu(entry)
        end
    end
end
-- Starting from the stopped state makes all options safe; mode and line
-- settings are saved even with Focus Reader stopped.
check(not instance.enabled, 'menu test starts stopped')
eachLeaf(items)
-- Start/Stop was encountered once; if Start left it enabled, stop cleanly.
if instance.enabled then instance:stop() end
check(roll.onGotoViewRel == original, 'menu actions leave clicker clean after stop')

-- Actual ReaderMenu offers onTapCloseMenu(), which closes both the
-- top TouchMenu and the bottom config panel. Prefer it over TouchMenu-only
-- closeMenu to avoid the lingering bottom-toolbar regression.
local reader_closed = 0
local touch_closed = 0
ui.menu.onTapCloseMenu = function() reader_closed = reader_closed + 1 end
local touch = {closeMenu=function() touch_closed = touch_closed + 1 end}
instance:closeSettingsMenu(touch)
check(reader_closed == 1 and touch_closed == 0,
    'ReaderMenu close path preferred to close bottom panel')
-- A checked setting must use the preferred ReaderMenu close pathway too.
items[3].sub_item_table[1].sub_item_table[1].callback(touch)
check(reader_closed == 2 and touch_closed == 0,
    'color selection closes full reader menu and bottom config')
ui.menu.onTapCloseMenu = nil

-- Word navigation must skip whitespace and standalone punctuation, including
-- multi-byte punctuation, without dropping non-ASCII words.
local old_get_word = doc.getWordFromPosition
local original_line_count = instance.line_count
local original_style = instance.style
local original_word_mode = instance.word_mode
local samples = {
    {word='Hello',x=40,w=45},
    {word=' ',x=88,w=9},
    {word=',',x=100,w=8},
    {word='world!',x=112,w=55},
    {word='…',x=170,w=9},
    {word='“',x=180,w=5},
    {word='café',x=185,w=45},
}
function doc:getWordFromPosition(pos)
    if pos.y < 100 or pos.y > 124 then return nil end
    for i,entry in ipairs(samples) do
        if pos.x >= entry.x and pos.x < entry.x+entry.w then
            return {word=entry.word,sbox={x=entry.x,y=100,w=entry.w,h=24},
                pos0='word'..i..'start',pos1='word'..i..'end'}
        end
    end
end
instance:setStyle('color')
instance:setWordMode(true)
instance:start()
check(instance.enabled and #instance.words==3,
    'word focus skips spaces and punctuation but keeps Unicode words')
local w1=instance.words[1].pos0
roll:onGotoViewRel(1)
check(instance.words[instance.index].pos0~=w1 and instance.index==2,
    'one click advances directly to next real word')
roll:onGotoViewRel(1)
check(instance.index==3,'next click reaches accented word without punctuation stop')
-- Reproduce real Kobo diagnostic: identical visible word with different
-- XPointers and widths for trailing space/punctuation.
function doc:getWordFromPosition(pos)
    if pos.y < 100 or pos.y > 124 then return nil end
    if pos.x >= 40 and pos.x < 67 then
        local padded = pos.x >= 53
        return {word=padded and 'I ' or 'I',
            sbox={x=40,y=100,w=padded and 27 or 15,h=24},
            pos0=padded and 'I-space-start' or 'I-start',
            pos1=padded and 'I-space-end' or 'I-end'}
    end
    if pos.x >= 85 and pos.x < 185 then
        local padded = pos.x >= 160
        return {word=padded and 'showered,' or 'showered',
            sbox={x=85,y=100,w=padded and 100 or 92,h=24},
            pos0=padded and 'shower-comma-start' or 'shower-start',
            pos1=padded and 'shower-comma-end' or 'shower-end'}
    end
end
instance.lines={{x=40,y=100,w=150,h=24,area={x=0,y=0,w=400,h=400}}}
instance:refreshWords()
check(#instance.words==2,'real Kobo duplicate XPointers collapse into two visible words')
check(instance.words[1].word_text=='I' and instance.words[2].word_text=='showered',
    'deduplication prefers boxes without trailing space or comma')
-- A punctuation-extended variant may have a shifted start and different
-- XPointers; it must not become an extra button press after the word.
function doc:getWordFromPosition(pos)
    if pos.y < 100 or pos.y > 124 then return nil end
    if pos.x >= 40 and pos.x < 130 then
        local extended = pos.x >= 90
        return {word=extended and 'better,”' or 'better',
            sbox={x=extended and 42 or 40,y=100,w=extended and 88 or 78,h=24},
            pos0=extended and 'better-punct-start' or 'better-start',
            pos1=extended and 'better-punct-end' or 'better-end'}
    end
    if pos.x >= 140 and pos.x < 195 then
        return {word='said',sbox={x=140,y=100,w=55,h=24},pos0='said-start',pos1='said-end'}
    end
end
instance.lines={{x=40,y=100,w=155,h=24,area={x=0,y=0,w=400,h=400}}}
instance:refreshWords()
check(#instance.words==2,'shifted punctuation-extended word box does not add navigation stop')
check(instance.words[1].word_text=='better' and instance.words[2].word_text=='said',
    'punctuation variant is collapsed and next actual word remains')
-- CRengine can split wasn't into [wasn] [’] [t]. A single
-- navigation step must select the whole contraction, not its fragments.
function doc:getWordFromPosition(pos)
    if pos.y < 100 or pos.y > 124 then return nil end
    local parts = {
        {word='wasn',x=40,w=45},
        {word='’',x=85,w=8},
        {word='t',x=93,w=10},
        {word=' ',x=103,w=12},
        {word='ready',x=115,w=55},
    }
    for i,part in ipairs(parts) do
        if pos.x >= part.x and pos.x < part.x + part.w then
            return {word=part.word,sbox={x=part.x,y=100,w=part.w,h=24},
                pos0='contraction'..i..'start',pos1='contraction'..i..'end'}
        end
    end
end
instance.lines={{x=40,y=100,w=130,h=24,area={x=0,y=0,w=400,h=400}}}
instance:refreshWords()
check(#instance.words==2,'apostrophe-separated contraction is one word, adjacent word stays separate')
check(instance.words[1].word_text=='wasnt' and instance.words[1].w==63,
    'curly apostrophe fragments merge into one geometry range')
instance:stop()
doc.getWordFromPosition=old_get_word
instance:setWordMode(original_word_mode)
instance:setLines(original_line_count)
instance:setStyle(original_style)

-- EPUB underline-only uses the same temporary overlay without CRengine
-- selection; switching back restores native selection.
instance:setStyle('color')
instance:setWordMode(false) -- menu sweep toggled word mode; fixture has no word API
instance:setPDFHighlightStyle('underline')
instance:start()
check(instance.enabled and instance:usesOverlayHighlight(),'EPUB underline overlay starts')
local epub_strokes={}
local epubbb={blendRectRGB32=function(_,x,y,w,h,c)
    epub_strokes[#epub_strokes+1]={x=x,y=y,w=w,h=h,c=c}
end}
instance:paintTo(epubbb,0,0)
check(#epub_strokes>0,'EPUB underline paints below text')
check(epub_strokes[1].h==3,'EPUB underline uses strong three-pixel stroke')
instance:setPDFHighlightStyle('tint')
check(not instance:usesOverlayHighlight(),'EPUB returns to native highlighting')
instance:stop()

-- PDF Highlight Focus draws temporary blended rectangles; it never calls
-- CRengine selection and never creates persistent PDF annotations.
local pdfdoc={configurable={text_wrap=0}}
function pdfdoc:getPageCount() return 3 end
function pdfdoc:getTextFromPositions(p0,p1)
    check(p0.page==1 and p1.page==1,'PDF positions include page number')
    return {sboxes={{{x0=30,y0=50,x1=180,y1=70},{x0=190,y0=50,x1=350,y1=70}},
        {{x0=30,y0=90,x1=350,y1=110}}}}
end
local pdfpaging={current_page=1}
local pdfturn=function(self,d) self.current_page=self.current_page+d; return true end
pdfpaging.onGotoViewRel=pdfturn
local pdfview={dialog={},view_mode='page',registerViewModule=function() end,
    screenToPageTransform=function(_,p) return {page=1,x=p.x,y=p.y} end,
    pageToScreenTransform=function(_,_,rect) return rect end}
local pdfui={document=pdfdoc,paging=pdfpaging,menu={registerToMainMenu=function() end}}
local pdf=setmetatable({ui=pdfui,view=pdfview},{__index=P})
pdf:init()
pdf.style='color'
pdf:onReaderReady()
check(pdf.supported,'PDF support without EPUB getCurrentPage')
pdf:start()
check(pdf.enabled and #pdf.lines==2,'PDF text boxes become two focus lines')
local blended={}
local pdfbb={blendRectRGB32=function(_,x,y,w,h,color)
    blended[#blended+1]={x=x,y=y,w=w,h=h,color=color}
end}
pdf:setPDFHighlightStyle('tint') -- earlier menu sweep persisted underline mode
pdf:paintTo(pdfbb,0,0)
check(#blended==4,'PDF Highlight draws faint tint and underline for each text line')
pdf:setPDFHighlightStyle('underline')
check(stored.pdf_highlight_style=='underline','PDF underline preference persists')
blended={}
pdf:paintTo(pdfbb,0,0)
check(#blended==2,'underline-only mode draws no tint over glyphs')
check(blended[1].h==3 and blended[1].color.a==235,'underline-only mode draws high-contrast three-pixel line')
check(blended[1].color.r < 100 and blended[1].color.g < 100,'underline-only darkens yellow for e-ink visibility')
pdf:setPDFHighlightStyle('tint')
blended={}
pdf:paintTo(pdfbb,0,0)
check(blended[1].color.a==26,'PDF text tint remains light enough for readability')
check(blended[2].color.a==165 and blended[2].h==2,'PDF underline is stronger but stays below glyphs')
check(blended[1].color.a>0 and blended[1].color.a<255,'PDF highlight blends transparently')
check(type(blended[1].color.r)=='number','PDF highlight uses configured RGB color')
pdf:stop()
check(pdfpaging.onGotoViewRel==pdfturn,'PDF page-turn hook restored')
print('PASS: '..checks..' mocked KOReader checks')
