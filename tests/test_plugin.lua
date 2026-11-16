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
package.preload['datastorage']=function() return {
    getSettingsDir=function() return '/test' end,
    getDataDir=function() return '/test/koreader' end
} end
local image_loads, image_frees, image_path = 0, 0, nil
package.preload['ui/renderimage']=function()
    return {renderImageFile=function(_,path,_,width,height)
        image_loads=image_loads+1
        image_path=path
        if path:find('missing') then return nil end
        return {getWidth=function() return width end,
            getHeight=function() return height end,
            getType=function() return 'RGB32' end,
            free=function() image_frees=image_frees+1 end}
    end}
end
local chooser_folder, chooser_filter
package.preload['apps/filemanager/filemanagerutil']=function()
    return {showChooseDialog=function(_,callback,current,_,filter)
        chooser_folder=current
        chooser_filter=filter
        callback('/test/koreader/screensavers/forest.png')
    end}
end
package.preload['ffi/blitbuffer']=function() return {
    COLOR_BLACK='BLACK',COLOR_WHITE='WHITE',
    TYPE_BBRGB32='RGB32',TYPE_BB8A='BB8A',
    ColorRGB32=function(r,g,b,a) return {r=r,g=g,b=b,a=a} end
} end
package.preload['device']=function() return {screen={getWidth=function() return 600 end, getHeight=function() return 900 end}} end
package.preload['ui/geometry']=function() return {new=function(_,v) return v end} end
package.preload['luasettings']=function()
   return {open=function() return {
      readSetting=function(_,k) return stored[k] end,
      saveSetting=function(_,k,v) stored[k]=v; saved[k]=v end,
      flush=function() end
   } end}
end
local registered_actions = {}
package.preload['dispatcher']=function() return {
    registerAction=function(_,name,action)
        -- KOReader's dispatcher is idempotent: a second document instance
        -- registers the same named action without adding it again.
        if not registered_actions[name] then registered_actions[name] = action end
        return true
    end,
} end
local dirty = {}
local next_ticks = {}
local function flushNextTicks()
    while #next_ticks > 0 do
        local cb = table.remove(next_ticks, 1)
        cb()
    end
end
package.preload['ui/uimanager']=function() return {
   setDirty=function(_,widget, mode, region) dirty[#dirty+1]={widget=widget,mode=mode,region=region} end,
   show=function(_,msg) error('unexpected InfoMessage') end,
   nextTick=function(_,cb) next_ticks[#next_ticks+1] = cb end,
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
local focus_action = registered_actions.focusreader_toggle
check(focus_action and focus_action.category=='none'
    and focus_action.event=='FocusReaderToggle'
    and focus_action.title=='Toggle Focus Reader'
    and focus_action.reader==true,
    'reader-only gesture action registered on initialization')
check(not instance.enabled, 'dispatcher registration does not auto-start')
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
check(#items==3,'main menu has only Start/Stop, Focus mode and current settings')
check(items[2].text=='Focus mode' and #items[2].sub_item_table==4,
    'Focus mode contains Highlight, both Spotlight layouts and Freeform')
local mode_choices=items[2].sub_item_table
check(mode_choices[4].text=='Freeform Focus (no text needed)',
    'no-text Freeform mode remains available')
check(type(items[3].text_func)=='function'
    and type(items[3].sub_item_table_func)=='function',
    'current mode settings are generated dynamically')
local current_settings=items[3]
local highlight_settings=current_settings.sub_item_table_func()
check(current_settings.text_func()=='Highlight settings'
    and #highlight_settings==6,
    'highlight settings include color, lines, advance, style, word and advanced')
check(highlight_settings[1].text=='Color'
    and highlight_settings[2].text=='Focused lines'
    and highlight_settings[3].text=='Advance by',
    'shared text navigation is nested in Highlight settings')
check(#highlight_settings[1].sub_item_table==6
    and #highlight_settings[2].sub_item_table==5,
    'six highlight colors and one to five lines remain')
check(#highlight_settings[3].sub_item_table==3
    and highlight_settings[3].sub_item_table[1].text=='One line'
    and highlight_settings[3].sub_item_table[2].text=='Whole focused group'
    and highlight_settings[3].sub_item_table[3].text=='Whole paragraph',
    'advance settings expose all three navigation modes')
check(highlight_settings[5].text=='Word-by-word (no speech)'
    and highlight_settings[6].text=='Advanced'
    and highlight_settings[6].sub_item_table[1].text=='Word navigation diagnostic',
    'word navigation controls remain but diagnostic is tucked under Advanced')
local initial_style=instance.style
local initial_mask=instance.spotlight_mask_color
instance.style='mask'
local spotlight_settings=current_settings.sub_item_table_func()
check(current_settings.text_func()=='Spotlight settings'
    and #spotlight_settings==3
    and spotlight_settings[1].text=='Focused lines'
    and spotlight_settings[2].text=='Advance by'
    and spotlight_settings[3].text=='Mask background',
    'Spotlight settings expose only relevant text and mask controls')
check(#spotlight_settings[1].sub_item_table==5
    and #spotlight_settings[3].sub_item_table==5,
    'Spotlight line sizes and all masks/chooser are preserved')
instance.style='freeform'
local freeform_settings=current_settings.sub_item_table_func()
check(current_settings.text_func()=='Freeform settings'
    and #freeform_settings==2
    and freeform_settings[1].text=='Window height'
    and #freeform_settings[1].sub_item_table==8
    and freeform_settings[2].text=='Mask background',
    'Freeform only shows window height and applicable masking controls')
instance.spotlight_mask_color='image'
local image_settings=current_settings.sub_item_table_func()
check(#image_settings==3 and image_settings[3].text=='Image background color'
    and #image_settings[3].sub_item_table==2,
    'image backing choices only appear when an image mask is chosen')
instance.style='mask'
local spotlight_image_settings=current_settings.sub_item_table_func()
check(#spotlight_image_settings==4
    and spotlight_image_settings[4].text=='Image background color',
    'Spotlight image masks also expose their backing color')
instance.spotlight_mask_color=initial_mask
instance.style=initial_style
local labels={}
local function scan(a)
  for _,e in ipairs(a) do
    labels[#labels+1]=(e.text or '')
    if e.sub_item_table then scan(e.sub_item_table) end
  end
end
scan(items)
scan(highlight_settings)
scan(spotlight_settings)
scan(freeform_settings)
local label_text=table.concat(labels,';'):lower()
check(not label_text:find('opacity') and not label_text:find('refresh')
    and not label_text:find('test') and not label_text:find('clicker'),
    'technical options stay out of visible focus settings')
instance:onFocusReaderToggle()
check(instance.enabled and roll.onGotoViewRel~=original,
    'gesture toggle starts focus and installs page-control hook')
instance:onFocusReaderToggle()
check(not instance.enabled and roll.onGotoViewRel==original,
    'gesture toggle stops focus and restores page controls')
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
highlight_settings[1].sub_item_table[2].callback()  -- orange
check(instance.color_name=='orange' and stored.color_name=='orange','changing color saved')
highlight_settings[2].sub_item_table[4].callback()
check(instance.line_count==4 and stored.line_count==4,'highlight line count changed and saved')
mode_choices[2].callback()  -- window
check(instance.style=='mask' and instance.spotlight_layout=='window','spotlight window selected')
local bb={paints=0, paintRect=function(self,_,_,w,h,color) self.paints=self.paints+1; assert(color=='BLACK') end}
instance:paintTo(bb,0,0)
check(bb.paints>=1,'blackout drawn')
check(instance.spotlight_mask_color=='black','old settings default to black')
spotlight_settings[3].sub_item_table[2].callback()
check(instance.spotlight_mask_color=='white' and stored.spotlight_mask_color=='white','white mask preference saved')
local white_bb={paints=0,paintRect=function(self,_,_,w,h,color) self.paints=self.paints+1; assert(color=='WHITE') end}
instance:paintTo(white_bb,0,0)
check(white_bb.paints>0,'white mask painted')
spotlight_settings[3].sub_item_table[1].callback()
check(instance.spotlight_mask_color=='black','black can be restored')
mode_choices[3].callback() -- guide
check(instance.style=='mask' and instance.spotlight_layout=='guide','spotlight guide selected')
spotlight_settings[1].sub_item_table[3].callback()
check(instance.legacy_line_count==3 and stored.legacy_line_count==3,'independent spotlight lines saved')
mode_choices[1].callback()
check(instance.style=='color','switch back to highlight focus')
check(instance.opacity==56,'opacity unchanged after style changes')
instance:stop()
check(not instance.enabled and roll.onGotoViewRel==original,'stop restores clicker hook')
-- Word focus must not start without native word geometry.
highlight_settings[5].callback()
check(instance.word_mode and stored.word_mode,'word mode persists')
local mgr = require('ui/uimanager')
local original_show_word = mgr.show
local word_messages = 0
mgr.show = function() word_messages = word_messages + 1 end
instance:start()
check(not instance.enabled and word_messages == 1,'missing word geometry fails safely')
mgr.show = original_show_word
highlight_settings[5].callback()
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

-- KOReader's checked settings stay open and refresh their checkmarks by
-- default. Only Start/Stop and informational diagnostics deliberately close.
local function driveMenu(item)
    local trace = {}
    local fake = {
        closeMenu = function() trace[#trace + 1] = 'close' end,
        updateItems = function() trace[#trace + 1] = 'update' end,
    }
    local original_setDirty = require('ui/uimanager').setDirty
    require('ui/uimanager').setDirty = function(self, widget, mode, region)
        trace[#trace + 1] = 'paint'
        original_setDirty(self, widget, mode, region)
    end
    local was_enabled = instance.enabled
    item.callback(fake)
    local is_start_stop = item.text == nil and item.text_func ~= nil
    if is_start_stop then
        check(instance.enabled == was_enabled and #next_ticks == 1,
            'Start/Stop waits for TouchMenu to dismiss before starting')
    end
    -- Mirrors KOReader TouchMenu:onMenuSelect: close automatically for an
    -- unchecked leaf item unless keep_menu_open is set.
    if item.checked or item.checked_func then
        if not (item.check_callback_updates_menu or item.check_callback_closes_menu) then
            fake:updateItems()
        end
    elseif not item.keep_menu_open then
        fake:closeMenu()
    end
    flushNextTicks()
    require('ui/uimanager').setDirty = original_setDirty
    if is_start_stop then
        check(trace[1] == 'close' and instance.enabled ~= was_enabled,
            'Start/Stop toggles after native menu close')
        local first_paint = table.concat(trace, ','):find('paint')
        check(not first_paint or first_paint > #'close',
            'Start/Stop never repaints before native menu close')
    else
        check(not table.concat(trace, ','):find('close'),
            'adjusting a setting never closes the configuration')
        if item.checked_func then
            check(trace[#trace] == 'update', 'checked setting refreshes menu')
        else
            check(item.keep_menu_open == true,
                'non-checked file picker leaves settings open')
        end
    end
end
local function eachLeaf(list)
    for _,entry in ipairs(list) do
        if entry.sub_item_table then
            eachLeaf(entry.sub_item_table)
        elseif entry.callback and entry.text ~= 'Word navigation diagnostic' then
            if entry.checked_func then
                check(not entry.check_callback_closes_menu,
                    'checked setting uses native menu refresh')
            end
            driveMenu(entry)
        end
    end
end
check(not instance.enabled, 'menu test starts stopped')
eachLeaf(mode_choices)
eachLeaf(highlight_settings)
eachLeaf(spotlight_settings)
eachLeaf(freeform_settings)
eachLeaf(image_settings)
if instance.enabled then instance:stop() end
check(roll.onGotoViewRel == original, 'menu sweep restores page controls')

local reader_closed = 0
ui.menu.onTapCloseMenu = function() reader_closed = reader_closed + 1 end
local native_close_count = 0
local touch = {closeMenu=function() native_close_count = native_close_count + 1 end}
-- Choosing a color must leave the full settings stack open.
highlight_settings[1].sub_item_table[1].callback(touch)
check(reader_closed == 0 and native_close_count == 0,
    'color change keeps ReaderMenu open')
-- The native menu closure occurs after callback, before the next UI tick.
items[1].callback(touch)
check(not instance.enabled and #next_ticks == 1,
    'Start defers activation until native TouchMenu has closed')
check(items[1].keep_menu_open ~= true, 'Start/Stop allows automatic menu close')
if not items[1].keep_menu_open then touch:closeMenu() end
check(native_close_count == 1 and reader_closed == 0,
    'KOReader TouchMenu performs closure without a second X tap')
flushNextTicks()
check(instance.enabled and roll.onGotoViewRel ~= original,
    'Start activates immediately after dismissal and hooks page navigation')
-- The same menu action also stops focus without leaving the menu visible.
items[1].callback(touch)
check(instance.enabled and #next_ticks == 1,
    'Stop defers deactivation until after native menu dismissal')
if not items[1].keep_menu_open then touch:closeMenu() end
flushNextTicks()
check(native_close_count == 2 and not instance.enabled
    and roll.onGotoViewRel == original,
    'Stop also closes menu and restores page turning')
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

-- A selected screensaver image paints only masked areas, never the reading
-- window; loading is cached and failures revert safely to a black mask.
instance:setStyle('mask')
instance.spotlight_image_path=nil
instance:chooseSpotlightImage()
check(instance.spotlight_mask_color=='image' and
    instance.spotlight_image_path=='/test/koreader/screensavers/forest.png',
    'image chooser stores the chosen image and enables custom mask')
check(chooser_folder=='/test/koreader/screensavers',
    'image chooser opens KOReader screensavers directory')
check(chooser_filter('foo.PNG') and chooser_filter('image.jpeg')
    and not chooser_filter('document.pdf'), 'chooser filters supported image formats')
instance:setSpotlightImageBaseColor('black')
instance:start()
local image_blits, black_backings = {}, 0
local image_bb={
    pmulalphablitFrom=function(_,image,dx,dy,sx,sy,w,h)
        image_blits[#image_blits+1]={x=dx,y=dy,w=w,h=h}
    end,
    blitFrom=function() error('RGBA image must not be flattened by plain blit') end,
    paintRect=function(_,x,y,w,h,color)
        check(color=='BLACK','custom image defaults to black underlay')
        black_backings=black_backings+1
    end,
}
instance:paintTo(image_bb,0,0)
check(#image_blits>0 and image_loads==1,
    'RGBA background uses premultiplied-alpha compositing')
check(black_backings>0,'black backing painted behind transparency')
instance:paintTo(image_bb,0,0)
check(image_loads==1,'subsequent focus repaints reuse decoded image')
instance:setSpotlightImageBaseColor('white')
check(instance.spotlight_image_base_color=='white' and
    stored.spotlight_image_base_color=='white','image backing color saved separately')
local white_underlay, white_blits = 0, 0
local image_white_bb={
    pmulalphablitFrom=function() white_blits=white_blits+1 end,
    blitFrom=function() error('white RGBA mode must preserve alpha') end,
    paintRect=function(_,x,y,w,h,color)
        if color=='WHITE' then white_underlay=white_underlay+1 end
    end,
}
instance:paintTo(image_white_bb,0,0)
check(white_underlay>0 and white_blits>0,
    'white backing shows through PNG transparency without altering artwork')
check(instance.spotlight_mask_color=='image','changing image backing retains custom image mode')

instance:setSpotlightImageBaseColor('black')
check(instance.spotlight_mask_color=='image' and instance.spotlight_image_base_color=='black',
    'custom image can return to black backing without changing image selection')
instance:stop()
check(image_frees>=1,'image memory released when focus stops')
instance.spotlight_image_path='/test/koreader/screensavers/missing.png'
instance:setSpotlightMaskColor('black')
instance:setSpotlightMaskColor('image')
instance:start()
local fallback={painted=0,paintRect=function(self,_,_,_,_,color)
    self.painted=self.painted+1
    check(color=='BLACK','unavailable image falls back to black')
end}
instance:paintTo(fallback,0,0)
check(fallback.painted>0,'unreadable image falls back to a safe black mask')
instance:setSpotlightImageBaseColor('white')
local missing_white={painted=0,paintRect=function(self,_,_,_,_,color)
    check(color=='WHITE','missing image follows white backing preference')
    self.painted=self.painted+1
end}
instance:paintTo(missing_white,0,0)
check(missing_white.painted>0,'missing image safely falls back to white backing')
instance:setSpotlightImageBaseColor('black')
instance:stop()
instance:setSpotlightMaskColor('black')
instance:setStyle(original_style)

-- Book-cover masks use KOReader's native, in-memory current-book cover API.
-- A cover is decoded once and freed on Stop, never written to the filesystem.
doc.file = '/test/books/example.epub'
local covers_requested, covers_freed = 0, 0
ui.bookinfo = {
    getCoverImage = function(_, current_doc, filename)
        check(current_doc == doc and filename == doc.file,
            'book cover request uses the currently opened book')
        covers_requested = covers_requested + 1
        return {
            getWidth = function() return 600 end,
            getHeight = function() return 900 end,
            getType = function() return 'RGB32' end,
            free = function() covers_freed = covers_freed + 1 end,
        }
    end,
}
instance:setStyle('mask')
instance:setSpotlightMaskColor('cover')
check(instance.spotlight_mask_color == 'cover'
    and stored.spotlight_mask_color == 'cover',
    'book cover mode persists as a separate mask choice')
instance:start()
local cover_before = #image_blits
instance:paintTo(image_bb, 0, 0)
instance:paintTo(image_bb, 0, 0)
check(#image_blits > cover_before and covers_requested == 1,
    'current cover is drawn and cached during repeated focus steps')
instance:stop()
check(covers_freed == 1, 'cached current cover is freed on Stop')
-- Missing artwork is a safe fallback and failed lookups are cached.
local no_cover_calls = 0
ui.bookinfo.getCoverImage = function()
    no_cover_calls = no_cover_calls + 1
    return nil
end
instance:start()
instance:paintTo(fallback, 0, 0)
instance:paintTo(fallback, 0, 0)
check(no_cover_calls == 1,
    'missing cover uses black fallback without repeated extraction attempts')
instance:stop()
ui.bookinfo = nil
doc.file = nil
instance:setSpotlightMaskColor('black')
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

-- A PDF that has diagrams/scans or no extractable text must never trap the
-- page-turn hook or crash when geometry disappears after a successful start.
local original_pdf_text = pdfdoc.getTextFromPositions
pdfdoc.getTextFromPositions = function() return {sboxes={}} end
local original_show_pdf = mgr.show
mgr.show = function() end
pdf:start()
mgr.show = original_show_pdf
check(not pdf.enabled and pdfpaging.onGotoViewRel==pdfturn,
    'PDF with no text refuses to start and leaves native turning intact')
pdfdoc.getTextFromPositions = original_pdf_text

-- Backend failures during a page update must not escape into KOReader.
pdf:start()
check(pdf.enabled,'PDF restarted for backend failure test')
pdfdoc.getTextFromPositions = function() error('MuPDF text position unavailable') end
local ok_update = pcall(function() pdf:onPageUpdate() end)
check(ok_update and not pdf.enabled and pdfpaging.onGotoViewRel==pdfturn,
    'PDF backend exception stops focus and restores native page turning')
pdfdoc.getTextFromPositions = original_pdf_text

-- Landscape can put the extreme corners outside the page; inset probe
-- coordinates must still find usable text.
local first_probe = true
pdfview.screenToPageTransform = function(_,p)
    if p.x < 15 or p.x > 585 then return nil end
    first_probe = false
    return {page=1,x=p.x,y=p.y}
end
pdf:start()
check(pdf.enabled and #pdf.lines==2 and not first_probe,
    'landscape inset probes retain readable PDF text')
pdf:stop()

-- Rotation/reflow to geometry-less output must stop safely and not leave
-- the clicker intercepted. A later valid page can start a new focus session.
pdfview.screenToPageTransform = function(_,p) return {page=1,x=p.x,y=p.y} end
pdf:start()
pdfdoc.getTextFromPositions = function() return {sboxes={}} end
local rotated_ok = pcall(function() pdf:onScreenResize() end)
check(rotated_ok and not pdf.enabled and pdfpaging.onGotoViewRel==pdfturn,
    'PDF rotation losing text positions restores reading controls')
pdfdoc.getTextFromPositions = original_pdf_text
pdf:start()
check(pdf.enabled and #pdf.lines==2,
    'PDF focus can restart after returning to a supported layout')
pdf:stop()

-- EPUB paragraph integration: CRengine XPointers identify seven-line
-- paragraphs, while the mock still supplies its original text-box geometry.
instance:setStyle('color')
instance:setPDFHighlightStyle('tint')
instance:setWordMode(false)
instance:setStepMode('line')
doc.getWordFromPosition = function(_,pos)
    local p = pos.y < 345 and '2' or '3'
    return {pos0='/body/DocFragment/body/div/p['..p..']/span/text().12'}
end
instance:start()
check(instance.enabled and #instance.lines==12,
    'paragraph integration fixture started with twelve visual lines')
instance:setStepMode('paragraph')
check(instance.step_mode=='paragraph' and stored.step_mode=='paragraph',
    'paragraph setting persists and is activated immediately')
check(#instance.paragraph_starts==2 and instance.paragraph_starts[1]==1
    and instance.paragraph_starts[2]==7,
    'structural EPUB paragraphs detected from CRe positions')
local first_para=instance:getSlot()
check(first_para.h>200,'paragraph focus highlights six lines, not just 1–5')
roll:onGotoViewRel(1)
check(instance.index==7,'clicker next advances to next paragraph')
local next_para=instance:getSlot()
check(next_para.y>first_para.y,'second paragraph has separate highlight window')
roll:onGotoViewRel(-1)
check(instance.index==1,'clicker previous returns to prior paragraph')
roll:onGotoViewRel(1)
roll:onGotoViewRel(1)
check(page==2 and instance.index==1,
    'paragraph next at final page anchor advances to next page')
roll:onGotoViewRel(-1)
check(page==1 and instance.index==7,
    'paragraph previous from next page returns to last visible paragraph')
roll:onGotoViewRel(-1)
check(instance.index==1,'reverse clicker returns to first EPUB paragraph')
instance:setStyle('mask')
instance:setSpotlightLayout('guide')
check(instance:getSlot().h==first_para.h,
    'Spotlight Reading Guide retains original paragraph bounds')
instance:setSpotlightLayout('window')
local clean_window = instance:getSlot()
check(clean_window.y == instance.lines[instance.index].y,
    'paragraph Reading Window omits unnecessary top padding')
check(clean_window.h == first_para.h - 2,
    'paragraph Reading Window retains all measured text lines')
roll:onGotoViewRel(1)
check(instance.index == 7, 'paragraph next still advances in Reading Window')
check(dirty[#dirty].mode == 'ui' and dirty[#dirty].region == nil,
    'paragraph Reading Window requests nonflashing viewport redraw')
roll:onGotoViewRel(-1)
check(instance.index == 1, 'paragraph reverse still navigates properly')
instance:setSpotlightLayout('guide')
instance:setStepMode('line')
check(instance.step_mode=='line' and stored.step_mode=='line',
    'line mode remains selectable after paragraph mode')
instance:setStepMode('paragraph')
roll:onGotoViewRel(-1)
check(page>=1,'backward boundary delegates page control safely')
instance:stop()
doc.getWordFromPosition = nil

-- The PDF fallback also uses paragraph anchors without touching XPointers.
pdfdoc.getTextFromPositions = original_pdf_text
pdf:setStepMode('paragraph')
pdf:start()
check(pdf.enabled and #pdf.paragraph_starts>=1,
    'PDF paragraph fallback produces at least one safe focus unit')
local pdf_para_first=pdf:getSlot()
check(pdf_para_first and pdf_para_first.h>0,
    'PDF paragraph highlight has bounded geometry')
pdf:stop()
pdf:setStepMode('line')
check(pdfpaging.onGotoViewRel==pdfturn,
    'paragraph PDF controls are restored when plugin stops')

-- Freeform Focus must work with *no text backend at all*. No extraction,
-- transforms or OCR should be invoked on image-only PDF pages.
pdfpaging.current_page = 1
pdfdoc.getTextFromPositions = function()
    error('Freeform mode must not query text positions')
end
pdf:setStyle('freeform')
pdf:setFreeformHeight(25)
check(pdf.freeform_height==25 and stored.freeform_height==25,
    'Freeform height setting is separate and persists')
pdf:setSpotlightMaskColor('black')
pdf:start()
check(pdf.enabled and #pdf.lines==0 and pdfpaging.onGotoViewRel~=pdfturn,
    'image-only PDF Freeform starts and intercepts clicker without text')
local one=pdf:getSlot()
check(one and one.h==225 and one.y==0 and one.w==600,
    'Freeform starts with quarter-page clear band')
local blackout={}
local freeform_bb={paintRect=function(_,x,y,w,h,color)
    blackout[#blackout+1]={x=x,y=y,w=w,h=h,color=color}
end}
pdf:paintTo(freeform_bb,0,0)
check(#blackout==1 and blackout[1].y==225 and blackout[1].h==675
    and blackout[1].color=='BLACK',
    'Freeform masks below the clear first band even with zero text')
pdfpaging:onGotoViewRel(1)
check(pdf.freeform_index==2 and pdf:getSlot().y==225,
    'clicker advances one geometric window')
blackout={}
pdf:paintTo(freeform_bb,0,0)
check(#blackout==2 and blackout[1].h==225
    and blackout[2].y==450 and blackout[2].h==450,
    'middle window masks above and below without touching clear band')
pdfpaging:onGotoViewRel(-1)
check(pdf.freeform_index==1,
    'reverse clicker returns to previous geometric window')
for _=1,3 do pdfpaging:onGotoViewRel(1) end
check(pdf.freeform_index==4 and pdf:getSlot().y==675,
    'last Freeform window reaches bottom without missing text/image pixels')
pdfpaging:onGotoViewRel(1)
check(pdfpaging.current_page==2 and pdf.freeform_index==1,
    'Freeform automatically turns the real page at bottom')
pdf:onPageUpdate()
check(pdf.freeform_index==1 and pdf.enabled,
    'delayed page updates do not reset or stop Freeform')
pdfpaging:onGotoViewRel(-1)
check(pdfpaging.current_page==1 and pdf.freeform_index==4,
    'reverse page-turn begins at final Freeform window')
pdf:setFreeformHeight(50)
check(pdf:getSlot().h==450 and pdf.freeform_index==2,
    'changing window height preserves approximate reading position')
pdf:setSpotlightMaskColor('white')
blackout={}
pdf:paintTo(freeform_bb,0,0)
check(#blackout>0 and blackout[1].color=='WHITE',
    'Freeform reuses Spotlight white mask preference')
pdf.spotlight_image_path='/test/koreader/screensavers/forest.png'
pdf:setSpotlightMaskColor('image')
local freeform_image_blits=0
local image_freeform={
    paintRect=function() end,
    pmulalphablitFrom=function() freeform_image_blits=freeform_image_blits+1 end,
}
pdf:paintTo(image_freeform,0,0)
check(freeform_image_blits>0,
    'Freeform reuses alpha-aware custom image masks')
pdf:setSpotlightMaskColor('black')
pdfview.footer_visible = true
pdfview.footer={getHeight=function() return 80 end}
pdf:onReaderFooterVisibilityChange()
check(pdf:getSlot().area.h==820 and pdf:getSlot().y+pdf:getSlot().h<=820,
    'Freeform avoids reader footer after a layout change')
pdfview.footer_visible = false
pdf:onScreenResize()
check(pdf:getSlot().area.h==900,
    'Freeform restores full viewport after screen resizing')
pdf:stop()
check(pdfpaging.onGotoViewRel==pdfturn,
    'stopping Freeform restores original page-turn implementation')

-- A PDF without even an exposed getTextFromPositions API is still accepted
-- for Freeform; selecting a text mode fails safely without trapping buttons.
pdfdoc.getTextFromPositions=nil
check(pdf:isSupported(),'PDF Freeform requires no text extraction API')
pdf:setStyle('freeform')
pdf:start()
check(pdf.enabled,'Freeform works without any PDF text API')
pdf:onPageUpdate()
check(pdf.enabled,'image-only Freeform page update is harmless')
local show_before=manager.show
local freeform_warning=0
manager.show=function() freeform_warning=freeform_warning+1 end
pdf:setStyle('color')
manager.show=show_before
check(not pdf.enabled and freeform_warning==1
    and pdfpaging.onGotoViewRel==pdfturn,
    'switching to unavailable text focus stops safely and restores controls')
pdfdoc.getTextFromPositions=original_pdf_text
pdf:start()
check(pdf.enabled and #pdf.lines==2,
    'normal PDF text focusing works again after leaving Freeform')
pdf:setStyle('freeform')
check(pdf.enabled and #pdf.lines==0,
    'switching live from text focus to Freeform clears text dependency')
pdf:setStyle('color')
check(pdf.enabled and #pdf.lines==2,
    'switching live back to text focus rebuilds text geometry')
pdf:stop()
check(pdfpaging.onGotoViewRel==pdfturn,
    'existing PDF turning restored after live mode changes')
print('PASS: '..checks..' mocked KOReader checks')
