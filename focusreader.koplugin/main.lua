-- Focus Reader v1.0.1: offline reading-focus accessibility tool for KOReader.
-- Native CRe selection for gentle color highlight; pure black masking
-- for Reading Window / Reading Guide. No network, audio, or annotations.
local Blitbuffer = require("ffi/blitbuffer")
local DataStorage = require("datastorage")
local Device = require("device")
local Geom = require("ui/geometry")
local LuaSettings = require("luasettings")
local UIManager = require("ui/uimanager")
local Widget = require("ui/widget/widget")
local _ = require("gettext")

local plugin_dir = debug.getinfo(1, "S").source:match("^@(.*/)") or "./"
local Logic = dofile(plugin_dir .. "logic.lua")
local Screen = Device.screen

local FocusReader = Widget:extend{
    name = "focusreader",
    is_doc_only = true,
    enabled = false,
    supported = false,
    line_count = 3,         -- Native color mode; existing v0.4.2 setting.
    opacity = 56,         -- Fixed original default; never read old opacity preferences.
    legacy_line_count = 3, -- Independent Spotlight Focus reading window.
    spotlight_layout = "window", -- window (above & below) or guide (below only).
    spotlight_mask_color = "black", -- backward-compatible default; optional white.
    step_mode = "line",
    word_mode = false, -- optional native CRengine word selection
    refresh_mode = "focused", -- fixed smooth area refresh; no experimental modes
    style = "color",
    color_name = "yellow",
    pdf_highlight_style = "tint", -- tint + underline, or underline only
    index = 1,
}

function FocusReader:init()
    self.settings = LuaSettings:open(DataStorage:getSettingsDir() .. "/focusreader.lua")
    self.line_count = Logic.setting(self.settings:readSetting("line_count"), 1, 5, 3)
    -- Fixed gentle highlight strength: 56% RGB blending over white.
    -- Ignore previous opacity/intensity keys even if still on disk; the user
    -- chose one stable highlight strength, not a hidden adjustable option.
    self.opacity = 56
    -- The modes keep separate line-count preferences.
    self.legacy_line_count = Logic.setting(
        self.settings:readSetting("legacy_line_count"), 1, 5, 3)
    -- Ignore old legacy_intensity preferences, including
    -- settings saved below 100: Spotlight Focus is now ALWAYS fully black.
    self.spotlight_layout = self.settings:readSetting("spotlight_layout") == "guide"
        and "guide" or "window"
    self.spotlight_mask_color = self.settings:readSetting("spotlight_mask_color") == "white"
        and "white" or "black"
    self.step_mode = self.settings:readSetting("step_mode") == "block" and "block" or "line"
    self.word_mode = self.settings:readSetting("word_mode") == true
    self.pdf_highlight_style = self.settings:readSetting("pdf_highlight_style") == "underline"
        and "underline" or "tint"
    -- One refresh path only, regardless of previously saved experiment keys.
    -- Never start precise/wide_wait, screen-wide or accelerated refreshes.
    self.refresh_mode = "focused"
    self.style = self.settings:readSetting("style") == "mask" and "mask" or "color"
    local chosen = self.settings:readSetting("color_name")
    self.color_name = ({yellow=true, orange=true, green=true, cyan=true,
        blue=true, pink=true})[chosen] and chosen or "yellow"
    self.lines, self.areas = {}, {}
    self._native_bounds = nil
    -- Deliberately do not auto-start a previous session.
end

function FocusReader:supportDiagnostics()
    local ui = self.ui
    local doc = ui and ui.document
    local checks = {
        {"reader controller", ui ~= nil},
        {"paging or rolling", ui and (ui.paging ~= nil or ui.rolling ~= nil)},
        {"document", doc ~= nil},
        {"getTextFromPositions", doc and type(doc.getTextFromPositions) == "function"},
        {"getCurrentPage (EPUB only)", ui and (ui.paging or (doc and type(doc.getCurrentPage) == "function"))},
        {"getCurrentPos (EPUB only)", ui and (ui.paging or (doc and type(doc.getCurrentPos) == "function"))},
        {"getVisiblePageCount (EPUB only)", ui and (ui.paging or (doc and type(doc.getVisiblePageCount) == "function"))},
        {"getPageCount", doc and type(doc.getPageCount) == "function"},
        {"view", self.view ~= nil},
        {"screenToPageTransform (PDF)", not (ui and ui.paging) or
            (self.view and type(self.view.screenToPageTransform) == "function")},
        {"pageToScreenTransform (PDF)", not (ui and ui.paging) or
            (self.view and type(self.view.pageToScreenTransform) == "function")},
    }
    local lines = {"Focus Reader diagnostic (no changes made):"}
    for _, check in ipairs(checks) do
        lines[#lines + 1] = (check[2] and "OK: " or "MISSING: ") .. check[1]
    end
    if ui and ui.paging then
        lines[#lines+1] = "PDF page: " .. tostring(ui.paging.current_page)
        lines[#lines+1] = "Reflow: " ..
            tostring(doc and doc.configurable and doc.configurable.text_wrap)
    end
    return table.concat(lines, "\n")
end

function FocusReader:isSupported()
    local doc = self.ui and self.ui.document
    return self.ui and (self.ui.rolling or self.ui.paging) and doc
        and type(doc.getTextFromPositions) == "function"
        and (self.ui.paging or type(doc.getCurrentPage) == "function")
        and (self.ui.paging or type(doc.getCurrentPos) == "function")
        and (self.ui.paging or type(doc.getVisiblePageCount) == "function")
        and type(doc.getPageCount) == "function"
        and self.view ~= nil
end

-- Only the base EPUB/rolling APIs decide whether the reader can register.
-- The newer selection API is optional: never hide the menu if unavailable.
function FocusReader:canUseNativeColor()
    local doc = self.ui and self.ui.document
    if not doc or type(doc.getTextFromXPointers) ~= "function"
            or type(doc.clearSelection) ~= "function" then return false end
    local ok, available = pcall(function()
        return doc._document ~= nil and type(doc._document.setStringProperty) == "function"
    end)
    return ok and available == true
end

function FocusReader:onReaderReady()
    self.supported = not not self:isSupported()
    -- Always add the menu for an open book, even if a specific highlighting
    -- backend cannot be used. A visible menu can provide a useful explanation.
    if self.ui and self.ui.menu then
        self.ui.menu:registerToMainMenu(self)
    end
    if not self.supported then return end
    self.view:registerViewModule("focusreader", self)
    self.location = self:getLocation()
end

function FocusReader:getLocation()
    if not self.supported or not self.ui.document then return nil end
    if self.ui.paging then return self.ui.paging.current_page end
    if self.view.view_mode == "scroll" then return self.ui.document:getCurrentPos() end
    return self.ui.document:getCurrentPage(true)
end

function FocusReader:getViewport()
    local height = Screen:getHeight()
    if self.view.footer_visible and self.view.footer then
        height = height - self.view.footer:getHeight()
    end
    return { x = 0, y = 0, w = Screen:getWidth(), h = math.max(0, height) }
end

function FocusReader:getPageAreas(viewport)
    local doc = self.ui.document
    if self.ui.paging or self.view.view_mode == "scroll" or doc:getVisiblePageCount() == 1 then
        return { viewport }
    end
    local half = math.floor(viewport.w / 2)
    local areas = { { x = 0, y = 0, w = half, h = viewport.h } }
    if doc:getCurrentPage(true) < doc:getPageCount(true) then
        areas[#areas + 1] = { x = half, y = 0, w = viewport.w - half, h = viewport.h }
    end
    return areas
end

function FocusReader:refreshLines(reset_index)
    self.lines = {}
    self.areas = {}
    if not self.supported or not self.ui.document then return end
    self.location = self:getLocation()
    if not self.enabled then return end
    local viewport = self:getViewport()
    local areas = self:getPageAreas(viewport)
    self.areas = areas
    local end_area = areas[#areas]
    if self.ui.paging then
        -- MuPDF/KOPT requires page-numbered coordinates, not EPUB screen
        -- positions. Screen/page transforms account for zoom and reflow.
        local page = self.ui.paging.current_page
        if type(page) == "number"
                and type(self.view.screenToPageTransform) == "function"
                and type(self.view.pageToScreenTransform) == "function" then
            local p0ok, p0 = pcall(self.view.screenToPageTransform, self.view,
                {x=viewport.x+2, y=viewport.y+2})
            local p1ok, p1 = pcall(self.view.screenToPageTransform, self.view,
                {x=end_area.x+end_area.w-2, y=end_area.y+end_area.h-2})
            if p0ok and p1ok and p0 and p1 and p0.page == p1.page then
                local ok, result = pcall(self.ui.document.getTextFromPositions,
                    self.ui.document, p0, p1)
                if ok and result and type(result.sboxes) == "table" then
                    local boxes = {}
                    for _, line_boxes in ipairs(result.sboxes) do
                        local group = type(line_boxes) == "table"
                            and line_boxes.x == nil and line_boxes or {line_boxes}
                        for _, b in ipairs(group) do
                            if type(b) == "table" then
                                local x0,y0 = b.x0 or b.x, b.y0 or b.y
                                local x1,y1 = b.x1 or (b.x and b.w and b.x+b.w),
                                    b.y1 or (b.y and b.h and b.y+b.h)
                                if x0 and y0 and x1 and y1 then
                                    local transformed, rect = pcall(self.view.pageToScreenTransform,
                                        self.view, page, {x=x0,y=y0,w=x1-x0,h=y1-y0})
                                    if transformed and rect and rect.w and rect.h then
                                        boxes[#boxes+1] = rect
                                    end
                                end
                            end
                        end
                    end
                    for _, area in ipairs(areas) do
                        for _, line in ipairs(Logic.normaliseLines(boxes, area)) do
                            self.lines[#self.lines+1] = line
                        end
                    end
                end
            end
        end
    else
        local ok, text_boxes = pcall(self.ui.document.getTextFromPositions, self.ui.document,
            { x = viewport.x, y = viewport.y },
            { x = end_area.x + end_area.w, y = end_area.y + end_area.h }, true)
        if ok and text_boxes and type(text_boxes.sboxes) == "table" then
            for _, area in ipairs(areas) do
                for _, line in ipairs(Logic.normaliseLines(text_boxes.sboxes, area)) do
                    self.lines[#self.lines + 1] = line
                end
            end
        end
    end
    if self.word_mode and self.style == "color" and not self.ui.paging then
        self:refreshWords()
    else
        self.words = nil
    end
    local active_count = self:getFocusLineCount()
    local sequence = self.word_mode and self.style == "color" and not self.ui.paging and self.words or self.lines
    if reset_index then
        self.index = self._page_direction == -1
            and Logic.maxStart(sequence, active_count) or 1
    else
        self.index = math.min(self.index, Logic.maxStart(sequence, active_count))
    end
end

function FocusReader:getFocusLineCount()
    if self.word_mode and self.style == "color" and not self.ui.paging then return 1 end
    return self.style == "mask" and self.legacy_line_count or self.line_count
end

-- Ignore whitespace and punctuation-only CRengine tokens. Keep UTF-8
-- letters (non-ASCII bytes) and digits, and preserve punctuation attached
-- to actual words. Lua 5.1's %w alone does not reliably match Unicode.
local function hasReadableWordContent(value)
    if type(value) ~= "string" then return false end
    local i = 1
    while i <= #value do
        local first = value:byte(i)
        local codepoint, width
        if first < 128 then
            codepoint, width = first, 1
        elseif first >= 194 and first <= 223 then
            width = 2
            local b2 = value:byte(i+1)
            if not b2 or b2 < 128 or b2 > 191 then return false end
            codepoint = (first-192)*64 + (b2-128)
        elseif first >= 224 and first <= 239 then
            width = 3
            local b2,b3 = value:byte(i+1,i+2)
            if not b2 or not b3 or b2 < 128 or b2 > 191 or b3 < 128 or b3 > 191 then return false end
            codepoint = (first-224)*4096 + (b2-128)*64 + (b3-128)
        elseif first >= 240 and first <= 244 then
            width = 4
            local b2,b3,b4 = value:byte(i+1,i+3)
            if not b2 or not b3 or not b4 or b2 < 128 or b2 > 191
                    or b3 < 128 or b3 > 191 or b4 < 128 or b4 > 191 then return false end
            codepoint = (first-240)*262144 + (b2-128)*4096 + (b3-128)*64 + (b4-128)
        else
            return false
        end
        local punctuation = (codepoint >= 0x2000 and codepoint <= 0x206F)
            or (codepoint >= 0x2E00 and codepoint <= 0x2E7F)
            or (codepoint >= 0x3000 and codepoint <= 0x303F)
            or (codepoint >= 0xFF00 and codepoint <= 0xFF0F)
            or (codepoint >= 0xFF1A and codepoint <= 0xFF20)
            or (codepoint >= 0xFF3B and codepoint <= 0xFF40)
            or (codepoint >= 0xFF5B and codepoint <= 0xFF65)
            or (codepoint >= 0xFE10 and codepoint <= 0xFE1F)
            or (codepoint >= 0xFE30 and codepoint <= 0xFE6F)
            or (codepoint >= 0x2190 and codepoint <= 0x21FF)
            or (codepoint >= 0x1F300 and codepoint <= 0x1FAFF)
        if not punctuation and ((codepoint >= 48 and codepoint <= 57)
                or (codepoint >= 65 and codepoint <= 90)
                or (codepoint >= 97 and codepoint <= 122)
                or (codepoint >= 0x00C0 and codepoint <= 0x1FFF)
                or (codepoint >= 0x2070 and codepoint <= 0x2FFF)
                or (codepoint >= 0x3040 and codepoint <= 0xD7FF)
                or (codepoint >= 0xF900 and codepoint <= 0xFAFF)) then
            return true
        end
        i = i + width
    end
    return false
end

-- Discover real words from CRengine, never estimate word widths from text.
-- Each candidate is checked against the engine-provided word box.
function FocusReader:refreshWords()
    self.words = {}
    local doc = self.ui.document
    if type(doc.getWordFromPosition) ~= "function" then return end
    local seen = {}
    for _, line in ipairs(self.lines) do
        local y = math.floor(line.y + line.h / 2)
        local stride = math.max(2, math.floor(line.h / 3))
        for x = math.floor(line.x + 1), math.floor(line.x + line.w - 1), stride do
            local ok, word = pcall(doc.getWordFromPosition, doc, {x=x,y=y})
            local b = ok and word and word.sbox
            if b and word.pos0 and word.pos1 and type(word.word) == "string"
                    and hasReadableWordContent(word.word) and b.w and b.h and b.w > 0 and b.h > 0
                    and x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h then
                local key = tostring(word.pos0) .. ":" .. tostring(word.pos1)
                if not seen[key] then
                    seen[key] = true
                    self.words[#self.words+1] = {x=b.x,y=b.y,w=b.w,h=b.h,
                        area=line.area,pos0=word.pos0,pos1=word.pos1,word_text=word.word}
                end
            end
        end
    end
    table.sort(self.words, function(a,b)
        if math.abs(a.y-b.y) <= math.min(a.h,b.h)/2 then
            if a.x ~= b.x then return a.x < b.x end
            return a.w < b.w
        end
        return a.y < b.y
    end)
    -- CRengine can return different XPointers for the same visible word,
    -- including variants with a trailing space or comma. Deduplicate by
    -- actual screen position and word content, not XPointers alone.
    local unique = {}
    local function wordCore(value)
        return (value or ""):gsub("[%s%p]", "")
    end
    for _, candidate in ipairs(self.words) do
        local duplicate = false
        for j = #unique, math.max(1, #unique - 4), -1 do
            local previous = unique[j]
            if math.abs(previous.y - candidate.y) <= 2
                    and wordCore(previous.word_text) == wordCore(candidate.word_text)
                    and math.min(previous.x + previous.w, candidate.x + candidate.w)
                        - math.max(previous.x, candidate.x) >= math.min(previous.w, candidate.w) * 0.75
                    then
                duplicate = true
                -- Prefer the narrower box, which excludes trailing punctuation
                -- or whitespace when CRengine exposes both alternatives.
                if candidate.w < previous.w then unique[j] = candidate end
                break
            end
        end
        if not duplicate then unique[#unique + 1] = candidate end
    end
    -- CRengine may expose a contraction as two word boxes with a separate
    -- apostrophe token. Join only when the intervening glyph is an apostrophe,
    -- never merely because two word boxes are close together.
    local merged = {}
    local function hasApostrophe(value)
        return type(value) == "string" and (value:find("'", 1, true)
            or value:find("’", 1, true) or value:find("ʼ", 1, true))
    end
    local function joinsContraction(left, right)
        if math.abs(left.y - right.y) > 2 then return false end
        local gap = right.x - (left.x + left.w)
        if gap < -2 or gap > math.max(12, math.floor(left.h * 0.6)) then return false end
        if hasApostrophe(left.word_text) or hasApostrophe(right.word_text) then
            return true
        end
        -- Probe the actual engine text between boxes: ordinary spaces must
        -- never cause adjacent words to merge.
        local y = math.floor(left.y + left.h / 2)
        for x = math.floor(left.x + left.w), math.ceil(right.x) do
            local ok, token = pcall(doc.getWordFromPosition, doc, {x=x,y=y})
            if ok and token and hasApostrophe(token.word) then return true end
        end
        return false
    end
    for _, candidate in ipairs(unique) do
        local previous = merged[#merged]
        if previous and joinsContraction(previous, candidate) then
            local right = math.max(previous.x + previous.w, candidate.x + candidate.w)
            previous.w = right - previous.x
            previous.pos1 = candidate.pos1
            previous.word_text = previous.word_text .. candidate.word_text
        else
            merged[#merged + 1] = candidate
        end
    end
    self.words = merged
end

-- Read-only, on-screen diagnostic for real-device word navigation.
-- No book text is saved, transmitted or written to a log.
function FocusReader:showWordDiagnostics()
    local entries = self.words or {}
    local output = {
        _("Word navigation diagnostic (current page only)"),
        _("Accepted words: ") .. tostring(#entries),
        _("Current index: ") .. tostring(self.index or 1),
        _("Mode: ") .. (self.word_mode and "word" or "line"),
    }
    local first = math.max(1, (self.index or 1) - 3)
    local last = math.min(#entries, (self.index or 1) + 5)
    for i = first, last do
        local entry = entries[i]
        local value = tostring(entry.word_text or "?")
        value = value:gsub("\n", " "):gsub("\r", " ")
        if #value > 45 then value = value:sub(1,45) .. "..." end
        output[#output+1] = string.format("%s%d: [%s] x=%d y=%d w=%d",
            i == self.index and "> " or "  ", i, value,
            entry.x or -1, entry.y or -1, entry.w or -1)
    end
    UIManager:show(require("ui/widget/infomessage"):new{
        text = table.concat(output, "\n"),
    })
end

function FocusReader:getSlot()
    local sequence = self.word_mode and self.style == "color" and not self.ui.paging and self.words or self.lines
    return Logic.slot(sequence or {}, self.index, self:getFocusLineCount())
end

-- Solid RGB is what the EPUB engine accepts for a native selection.
-- Blending toward the typical white page background before passing that RGB
-- color is an *opacity simulation*, not actual alpha compositing over content.
-- Color-native highlighting retains the no-black-flash advantage.
local PALETTE = {
    yellow = { 255, 215, 35 }, orange = { 255, 165, 55 },
    green = { 127, 212, 116 }, cyan = { 100, 214, 225 },
    blue = { 113, 166, 240 }, pink = { 235, 130, 189 },
}

function FocusReader:getNativeColor()
    local base = PALETTE[self.color_name] or PALETTE.yellow
    local alpha = self.opacity / 100
    local function channel(v)
        return math.floor(255 + (v - 255) * alpha + 0.5)
    end
    return string.format("#%02X%02X%02X",
        channel(base[1]), channel(base[2]), channel(base[3]))
end

function FocusReader:setNativeSelectionColor()
    if not self.ui or not self.ui.document or not self.ui.document._document then return false end
    return pcall(self.ui.document._document.setStringProperty,
        self.ui.document._document, "crengine.highlight.selection.color", self:getNativeColor())
end

function FocusReader:restoreNativeSelectionColor()
    -- Delegate restoration to KOReader rather than changing any global settings.
    if self.ui and self.ui.highlight and self.ui.highlight.setSelectionColor then
        pcall(self.ui.highlight.setSelectionColor, self.ui.highlight)
    end
end

function FocusReader:clearNativeSelection()
    self._native_bounds = nil
    if self.ui and self.ui.document and self.ui.document.clearSelection then
        pcall(self.ui.document.clearSelection, self.ui.document)
    end
end

-- Use CRe's native selection drawing API instead of a translucent
-- screen-wide overlay.
-- One selection spans the visible lines, with text-coordinate endpoints.
function FocusReader:applyNativeSelection()
    if not self.enabled or self.style ~= "color" then return false end
    local first = self.word_mode and self.words and self.words[self.index] or self.lines[self.index]
    if not first then
        self:clearNativeSelection()
        return false
    end
    local last = first
    for j = self.index + 1, self.word_mode and self.index or math.min(#self.lines, self.index + self.line_count - 1) do
        if self.lines[j].area ~= first.area then break end
        last = self.lines[j]
    end
    local start_pos = {
        x = math.floor(first.x + math.min(2, first.w / 3)),
        y = math.floor(first.y + first.h / 2),
    }
    local end_pos = {
        x = math.floor(last.x + math.max(1, last.w - 2)),
        y = math.floor(last.y + last.h / 2),
    }
    local doc = self.ui.document
    local ok, range
    if self.word_mode then
        ok, range = true, {pos0=first.pos0,pos1=first.pos1,sboxes={first}}
    else
        ok, range = pcall(doc.getTextFromPositions, doc,
            start_pos, end_pos, true)
    end
    if not ok or type(range) ~= "table" or not range.pos0 or not range.pos1 then
        self:clearNativeSelection()
        return false
    end
    -- Explicitly retire the old CRe selection before installing the new one.
    -- Never repaint between clearSelection() and getTextFromXPointers(): this
    -- ensures a single atomic visible update with no white/black intermediate.
    -- Without the clear, segmented selection fragments near the old endpoint
    -- can remain rendered after the reading window advances or reverses.
    self:clearNativeSelection()
    local selected = pcall(doc.getTextFromXPointers, doc, range.pos0, range.pos1, true)
    if not selected then
        self:clearNativeSelection()
        return false
    end
    -- The native selection can extend slightly beyond the geometry of the
    -- three-line reading window. Track CRe's real text boxes to refresh the
    -- previous and new endpoints as well as the core focus window.
    self._native_bounds = Logic.selectionBounds(range.sboxes, first.area)
    return true
end

-- Only solid black paint is used in Spotlight Focus. No alpha blending,
-- gray artifacts or adjustable darkness settings remain in this mode.
function FocusReader:shade(bb, x, y, w, h)
    w, h = math.floor(w), math.floor(h)
    if w <= 0 or h <= 0 then return end
    local color = self.spotlight_mask_color == "white"
        and Blitbuffer.COLOR_WHITE or Blitbuffer.COLOR_BLACK
    return bb:paintRect(x, y, w, h, color)
end

function FocusReader:usesOverlayHighlight()
    return self.style == "color" and (self.ui.paging or self.pdf_highlight_style == "underline")
end

function FocusReader:paintTo(bb, x, y)
    if not self.supported or not self.enabled then return end
    if self:usesOverlayHighlight() then
        -- Temporary, non-annotation PDF overlay. Unlike CRengine, MuPDF does
        -- not expose a mutable selection color. Blend over the rendered page.
        -- Restrict painting to actual text line boxes, not the full row.
        local count = self:getFocusLineCount()
        local sequence = self.word_mode and not self.ui.paging and self.words or self.lines
        local first = self.index
        local last = math.min(#sequence, first + count - 1)
        local rgb = PALETTE[self.color_name] or PALETTE.yellow
        -- KOReader composites this AFTER the PDF glyphs are rendered.
        -- Strong blending washes out black text; use a very faint tint
        -- and a more visible underline below each text box instead.
        local tint = Blitbuffer.ColorRGB32(rgb[1], rgb[2], rgb[3], 26)
        -- Underline-only needs more contrast on e-ink, especially yellow.
        -- Use a dark, nearly opaque stroke while retaining the chosen hue
        -- in tint mode. Keep it below the glyphs.
        local underline_only = self.pdf_highlight_style == "underline"
        local underline = underline_only
            and Blitbuffer.ColorRGB32(
                math.floor(rgb[1] * 0.32), math.floor(rgb[2] * 0.32),
                math.floor(rgb[3] * 0.32), 235)
            or Blitbuffer.ColorRGB32(rgb[1], rgb[2], rgb[3], 165)
        local stroke = underline_only and 3 or 2
        for i = first, last do
            local line = sequence[i]
            if line and sequence[first] and line.area == sequence[first].area then
                local left = x + math.floor(line.x)
                local top = y + math.floor(line.y)
                local width = math.ceil(line.w)
                local height = math.ceil(line.h)
                if self.ui.paging and self.pdf_highlight_style ~= "underline" then
                    bb:blendRectRGB32(left, top, width, height, tint)
                end
                -- One-pixel separation keeps descenders readable.
                local baseline = top + height + 1
                local bottom = y + line.area.y + line.area.h
                if baseline + stroke <= bottom then
                    bb:blendRectRGB32(left, baseline, width, stroke, underline)
                end
            end
        end
        return
    end
    if self.style ~= "mask" then return end
    local slot = self:getSlot()
    if not slot then return end -- No text: do not blackout an image-only page.
    for _, area in ipairs(self.areas) do
        if area == slot.area then
            local top = math.max(area.y, math.min(slot.y, area.y + area.h))
            local bottom = math.max(area.y, math.min(slot.y + slot.h, area.y + area.h))
            if self.spotlight_layout == "window" then
                -- Reading Window: keep only N lines clear; above AND below
                -- are black, as in legacy v0.5.
                self:shade(bb, x + area.x, y + area.y, area.w, top - area.y)
            end
            -- Reading Guide: leave everything already read above the focus
            -- line completely untouched, like sliding a sheet down a page.
            self:shade(bb, x + area.x, y + bottom,
                area.w, area.y + area.h - bottom)
        elseif self.spotlight_layout == "window" or area.x > slot.area.x then
            -- Two-page layout: in Guide, leave earlier pages visible and
            -- black out not-yet-read right-hand pages.
            self:shade(bb, x + area.x, y + area.y, area.w, area.h)
        end
    end
end

-- A *single* medium-fidelity update for the union of the old and new focus
-- windows. Never submit top/bottom strips separately: on the Kobo MTK e-ink
-- driver those can update at different moments and visibly leave stale bars.
-- Never use "fast" or "a2" for greyscale dimming: they lose grey detail.
-- 'ui' does not request a deliberate black-flash or count toward KOReader's
-- automatic periodic full-refresh promotion. The device's panel may still
-- perform waveform transitions that aren't under plugin control.
function FocusReader:redraw(whole_view, previous_slot, previous_native_bounds)
    if not self.view or not self.view.dialog then return end
    local region
    if not whole_view and previous_slot then
        local new_slot = self:getSlot()
        local combined
        if self.style == "mask" and self.spotlight_layout == "guide" then
            -- Only ONE horizontal boundary changes when exposing each line.
            -- A single narrow nonflashing region reduces unnecessary e-ink
            -- transitions compared with the moving two-edge Reading Window.
            combined = Logic.guideChangedBounds(previous_slot, new_slot, 10)
        else
            combined = Logic.changedBounds(previous_slot, new_slot, 8)
        end
        if self.style == "color" then
            -- Stable full-width smooth UI refresh, including both selections.
            local native_region = Logic.changedBounds(
                previous_native_bounds, self._native_bounds, 12)
            combined = Logic.unionRefresh(combined, native_region)
        end
        if combined then region = Geom:new(combined) end
    end
    UIManager:setDirty(self.view.dialog, "ui", region)
end

-- Local interception: only the current document's ReaderRolling instance.
-- Forward the original page-turn implementation when the spotlight reaches
-- its end; restore the exact original function on Stop or document close.
function FocusReader:installTurnHook()
    local rolling = self.ui.rolling or self.ui.paging
    if self._turn_wrapper then return end
    self._original_turn = rolling.onGotoViewRel
    self._hooked_rolling = rolling
    local plugin = self
    self._turn_wrapper = function(controller, difference, ...)
        if controller ~= rolling or not plugin.enabled or type(difference) ~= "number"
                or math.abs(difference) ~= 1 then
            return plugin._original_turn(controller, difference, ...)
        end
        return plugin:moveFocus(difference)
    end
    rolling.onGotoViewRel = self._turn_wrapper
end

function FocusReader:restoreTurnHook()
    if self._hooked_rolling and self._hooked_rolling.onGotoViewRel == self._turn_wrapper then
        self._hooked_rolling.onGotoViewRel = self._original_turn
    end
    self._turn_wrapper = nil
    self._hooked_rolling = nil
    self._original_turn = nil
end

function FocusReader:turnPage(direction)
    local before = self:getLocation()
    self._page_direction = direction
    local result = self._original_turn(self._hooked_rolling, direction)
    -- Some versions send PageUpdate during the turn; others may defer it.
    local after = self:getLocation()
    if after ~= before and self.location ~= after then
        -- A platform that did not synchronously emit PageUpdate still needs
        -- the new page's text boxes. Avoid a duplicate repaint otherwise.
        self:refreshLines(true)
        if self.style == "color" and not self:usesOverlayHighlight() then self:applyNativeSelection() end
        self:redraw(false)
    elseif after == before and self.style == "color" then
        -- End-of-book or failed turn: restore our visible temporary selection.
        self:applyNativeSelection()
        self:redraw(false)
    end
    self._page_direction = nil
    return result == nil and true or result
end

function FocusReader:moveFocus(direction)
    if not self.enabled then return false end
    local active_count = self:getFocusLineCount()
    local sequence = self.word_mode and self.style == "color" and not self.ui.paging and self.words or self.lines
    local step = self.step_mode == "block" and active_count or 1
    local index, page_direction = Logic.advance(sequence, self.index,
        active_count, direction, step)
    if page_direction then return self:turnPage(page_direction) end
    if index ~= self.index then
        local old_slot = self:getSlot()
        local old_native_bounds = self._native_bounds
        self.index = index
        if self.style == "color" and not self:usesOverlayHighlight() then self:applyNativeSelection() end
        self:redraw(false, old_slot, old_native_bounds)
    end
    return true
end

function FocusReader:start()
    if not self.supported then
        UIManager:show(require("ui/widget/infomessage"):new{
            text = self:supportDiagnostics(),
        })
        return
    end
    if self.enabled then return end
    if self.style == "color" and not self.ui.paging and not self:usesOverlayHighlight() and not self:canUseNativeColor() then
        UIManager:show(require("ui/widget/infomessage"):new{
            text = _("This KOReader build does not expose the native selection API. Choose Spotlight Focus instead."),
        })
        return
    end
    self.enabled = true
    self._page_direction = nil
    self:refreshLines(true)
    if #self.lines == 0 or (self.word_mode and self.style == "color" and not self.ui.paging and #(self.words or {}) == 0) then
        self.enabled = false
        UIManager:show(require("ui/widget/infomessage"):new{
            text = _("No readable text positions were found on this page."),
        })
        return
    end
    if self.style == "color" and not self:usesOverlayHighlight() then
        self:setNativeSelectionColor()
        self:applyNativeSelection()
    end
    self:installTurnHook()
    self:redraw(true)
end

function FocusReader:stop(skip_redraw)
    local was_enabled = self.enabled
    self.enabled = false
    self._page_direction = nil
    self:restoreTurnHook()
    if was_enabled and self.style == "color" then
        self:clearNativeSelection()
        self:restoreNativeSelectionColor()
    end
    if was_enabled and not skip_redraw then self:redraw(true) end
end

-- Color and legacy focus windows are intentionally separate. Preserve the
-- original setLines() name for existing bindings/settings and native mode.
function FocusReader:setLines(count)
    self.line_count = Logic.setting(count, 1, 5, 3)
    self.settings:saveSetting("line_count", self.line_count)
    if self.enabled and self.style == "color" then
        self.index = math.min(self.index, Logic.maxStart(self.lines, self.line_count))
        if not self:usesOverlayHighlight() then self:applyNativeSelection() end
        self:redraw(true)
    end
end

function FocusReader:setLegacyLines(count)
    self.legacy_line_count = Logic.setting(count, 1, 5, 3)
    self.settings:saveSetting("legacy_line_count", self.legacy_line_count)
    if self.enabled and self.style == "mask" then
        self.index = math.min(self.index,
            Logic.maxStart(self.lines, self.legacy_line_count))
        self:redraw(true)
    end
end

function FocusReader:setSpotlightMaskColor(color)
    color = color == "white" and "white" or "black"
    if self.spotlight_mask_color == color then return end
    self.spotlight_mask_color = color
    self.settings:saveSetting("spotlight_mask_color", color)
    if self.enabled and self.style == "mask" then self:redraw(true) end
end

function FocusReader:setSpotlightLayout(layout)
    layout = layout == "guide" and "guide" or "window"
    if self.spotlight_layout == layout then return end
    self.spotlight_layout = layout
    self.settings:saveSetting("spotlight_layout", layout)
    if self.enabled and self.style == "mask" then self:redraw(true) end
end

function FocusReader:setPDFHighlightStyle(style)
    style = style == "underline" and "underline" or "tint"
    if self.pdf_highlight_style == style then return end
    if self.enabled and self.style == "color" and not self.ui.paging then
        self:clearNativeSelection()
        self:restoreNativeSelectionColor()
    end
    self.pdf_highlight_style = style
    self.settings:saveSetting("pdf_highlight_style", style)
    if self.enabled and self.style == "color" then
        if not self:usesOverlayHighlight() then
            self:setNativeSelectionColor()
            self:applyNativeSelection()
        end
        self:redraw(true)
    end
end

function FocusReader:setColor(name)
    if not PALETTE[name] then return end
    self.color_name = name
    self.settings:saveSetting("color_name", name)
    if self.enabled and self.style == "color" then
        if not self:usesOverlayHighlight() then
            self:setNativeSelectionColor()
            self:applyNativeSelection()
        end
        self:redraw(true)
    end
end

function FocusReader:setStyle(style)
    style = style == "mask" and "mask" or "color"
    if self.style == style then return end
    -- On some KOReader/device builds native selection is unavailable. Never
    -- replace a working Spotlight session with a blank color highlight.
    if self.enabled and style == "color" and not self.ui.paging and self.pdf_highlight_style ~= "underline" and not self:canUseNativeColor() then
        UIManager:show(require("ui/widget/infomessage"):new{
            text = _("Native color highlighting is unavailable in this KOReader build. Spotlight Focus still works."),
        })
        return
    end
    if self.enabled and self.style == "color" then
        self:clearNativeSelection()
        self:restoreNativeSelectionColor()
    end
    self.style = style
    self.settings:saveSetting("style", style)
    if self.enabled then
        -- Changing modes can also change the active focus window size.
        self.index = math.min(self.index,
            Logic.maxStart(self.lines, self:getFocusLineCount()))
    end
    if self.enabled and style == "color" and not self:usesOverlayHighlight() then
        self:setNativeSelectionColor()
        self:applyNativeSelection()
    end
    if self.enabled then self:redraw(true) end
end

function FocusReader:setWordMode(enabled)
    enabled = enabled == true
    if self.word_mode == enabled then return end
    local was_enabled = self.enabled
    if was_enabled then self:stop() end
    self.word_mode = enabled
    self.settings:saveSetting("word_mode", enabled)
    if was_enabled then self:start() end
end

function FocusReader:setStepMode(mode)
    self.step_mode = mode == "block" and "block" or "line"
    self.settings:saveSetting("step_mode", self.step_mode)
end

function FocusReader:onPageUpdate()
    if not self.enabled then return end
    local new_location = self:getLocation()
    local changed = new_location ~= self.location
    self:refreshLines(changed)
    if self.style == "color" and not self:usesOverlayHighlight() then self:applyNativeSelection() end
    if changed then self:redraw(false) end
end
FocusReader.onPosUpdate = FocusReader.onPageUpdate

function FocusReader:onScreenResize()
    if not self.enabled then return end
    self:refreshLines(false)
    if self.style == "color" and not self:usesOverlayHighlight() then self:applyNativeSelection() end
    self:redraw(true)
end

function FocusReader:onReaderFooterVisibilityChange()
    if not self.enabled then return end
    self:refreshLines(false)
    if self.style == "color" and not self:usesOverlayHighlight() then self:applyNativeSelection() end
    self:redraw(true)
end

function FocusReader:onCloseDocument()
    self:stop(true)
    self.supported = false
end

function FocusReader:onFlushSettings()
    self.settings:flush()
end
FocusReader.onSaveSettings = FocusReader.onFlushSettings

-- Called by checkmarked menu items. KOReader deliberately keeps checked
-- selections open unless the callback closes them. Close BEFORE repainting
-- the page, so the reader is visible when highlighting/masking is redrawn.
-- Using the TouchMenu instance supplied to callbacks is the normal path;
-- fall back to ReaderMenu when a different KOReader menu version does not
-- supply an instance.
function FocusReader:closeSettingsMenu(menu)
    -- ReaderMenu:onTapCloseMenu closes *both* the main TouchMenu and the
    -- bottom configuration menu. Prefer it when available so neither bar
    -- remains over the book after selecting a checked option.
    if self.ui and self.ui.menu
            and type(self.ui.menu.onTapCloseMenu) == "function" then
        self.ui.menu:onTapCloseMenu()
    elseif menu and type(menu.closeMenu) == "function" then
        menu:closeMenu()
    end
end

function FocusReader:addToMainMenu(menu_items)
    -- Keep the top-level menu focused on reading, not refresh internals.
    local color_line_items, spotlight_line_items = {}, {}
    for n = 1, 5 do
        local count = n
        local label = tostring(count) .. (count == 1 and _(" line") or _(" lines"))
        color_line_items[#color_line_items + 1] = {
            text = label,
            checked_func = function() return self.line_count == count end,
            check_callback_closes_menu = true,
            callback = function(menu)
                self:closeSettingsMenu(menu)
                self:setLines(count)
            end,
        }
        spotlight_line_items[#spotlight_line_items + 1] = {
            text = label,
            checked_func = function() return self.legacy_line_count == count end,
            check_callback_closes_menu = true,
            callback = function(menu)
                self:closeSettingsMenu(menu)
                self:setLegacyLines(count)
            end,
        }
    end

    local color_items = {}
    for color_index, color_entry in ipairs({
        {"Yellow", "yellow"}, {"Orange", "orange"},
        {"Green", "green"}, {"Cyan", "cyan"},
        {"Blue", "blue"}, {"Pink", "pink"},
    }) do
        local label, value = color_entry[1], color_entry[2]
        color_items[#color_items + 1] = {
            text = _(label),
            checked_func = function() return self.color_name == value end,
            check_callback_closes_menu = true,
            callback = function(menu)
                self:closeSettingsMenu(menu)
                self:setColor(value)
            end,
        }
    end

    menu_items.focusreader = {
        text = _("Focus Reader"),
        sorting_hint = "tools",
        sub_item_table = {
            {
                text_func = function()
                    return self.enabled and _("Stop Focus Reader") or _("Start Focus Reader")
                end,
                keep_menu_open = true,
                callback = function(menu)
                    self:closeSettingsMenu(menu)
                    if self.enabled then self:stop() else self:start() end
                end,
            },
            {
                text = _("Reading mode"),
                sub_item_table = {
                    {
                        text = _("Highlight Focus"),
                        checked_func = function() return self.style == "color" end,
                        check_callback_closes_menu = true,
                        callback = function(menu)
                            self:closeSettingsMenu(menu)
                            self:setStyle("color")
                        end,
                    },
                    {
                        text = _("Spotlight Focus: Reading Window"),
                        checked_func = function()
                            return self.style == "mask" and self.spotlight_layout == "window"
                        end,
                        check_callback_closes_menu = true,
                        callback = function(menu)
                            self:closeSettingsMenu(menu)
                            self:setSpotlightLayout("window")
                            self:setStyle("mask")
                        end,
                    },
                    {
                        text = _("Spotlight Focus: Reading Guide"),
                        checked_func = function()
                            return self.style == "mask" and self.spotlight_layout == "guide"
                        end,
                        check_callback_closes_menu = true,
                        callback = function(menu)
                            self:closeSettingsMenu(menu)
                            self:setSpotlightLayout("guide")
                            self:setStyle("mask")
                        end,
                    },
                },
            },
            {
                text = _("Highlight Focus"),
                sub_item_table = {
                    { text = _("Color"), sub_item_table = color_items },
                    { text = _("Focused lines"), sub_item_table = color_line_items },
                    { text = _("Highlight style (EPUB / PDF)"), sub_item_table = {
                        { text = _("Native EPUB highlight / PDF light tint"),
                          checked_func = function() return self.pdf_highlight_style == "tint" end,
                          check_callback_closes_menu = true,
                          callback = function(menu)
                              self:closeSettingsMenu(menu)
                              self:setPDFHighlightStyle("tint")
                          end },
                        { text = _("Underline only (EPUB / PDF)"),
                          checked_func = function() return self.pdf_highlight_style == "underline" end,
                          check_callback_closes_menu = true,
                          callback = function(menu)
                              self:closeSettingsMenu(menu)
                              self:setPDFHighlightStyle("underline")
                          end },
                    } },
                    { text = _("Word-by-word (no speech)"),
                      checked_func = function() return self.word_mode end,
                      check_callback_closes_menu = true,
                      callback = function(menu)
                          self:closeSettingsMenu(menu)
                          self:setWordMode(not self.word_mode)
                      end },
                    { text = _("Word navigation diagnostic"),
                      callback = function(menu)
                          self:closeSettingsMenu(menu)
                          self:showWordDiagnostics()
                      end },
                },
            },
            {
                text = _("Spotlight Focus"),
                sub_item_table = {
                    { text = _("Focused lines"), sub_item_table = spotlight_line_items },
                    { text = _("Mask color"), sub_item_table = {
                        { text = _("Black (default)"),
                          checked_func = function() return self.spotlight_mask_color == "black" end,
                          check_callback_closes_menu = true,
                          callback = function(menu)
                              self:closeSettingsMenu(menu)
                              self:setSpotlightMaskColor("black")
                          end },
                        { text = _("White"),
                          checked_func = function() return self.spotlight_mask_color == "white" end,
                          check_callback_closes_menu = true,
                          callback = function(menu)
                              self:closeSettingsMenu(menu)
                              self:setSpotlightMaskColor("white")
                          end },
                    } },
                },
            },
        },
    }
end

return FocusReader
