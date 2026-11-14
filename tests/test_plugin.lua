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
package.preload['ffi/blitbuffer']=function() return {COLOR_BLACK='BLACK',COLOR_WHITE='WHITE'} end
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
check(items[3].text=='Highlight Focus' and #items[3].sub_item_table==3,'highlight includes word mode')
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
check(items[3].sub_item_table[3].text=='Word-by-word (no speech)','word focus toggle exists')
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
items[3].sub_item_table[3].callback()
check(instance.word_mode and stored.word_mode,'word mode persists')
local mgr = require('ui/uimanager')
local original_show_word = mgr.show
local word_messages = 0
mgr.show = function() word_messages = word_messages + 1 end
instance:start()
check(not instance.enabled and word_messages == 1,'missing word geometry fails safely')
mgr.show = original_show_word
items[3].sub_item_table[3].callback()
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
        elseif entry.callback then
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
print('PASS: '..checks..' mocked KOReader checks')
