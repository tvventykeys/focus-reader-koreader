-- Focus Reader v1.0.0: geometry and navigation; no KOReader dependencies.
local Logic = {}

local function clamp(value, lo, hi)
    if type(value) ~= "number" then return lo end
    return math.max(lo, math.min(hi, math.floor(value)))
end

function Logic.setting(value, lo, hi, fallback)
    if type(value) ~= "number" then return fallback end
    return clamp(value, lo, hi)
end

-- CRe can return several boxes for one visual line (e.g. bidi runs).
-- Normalize boxes in one page area before arranging them into reading order.
function Logic.normaliseLines(boxes, area)
    local candidates = {}
    local min_x, max_x = area.x, area.x + area.w
    local min_y, max_y = area.y, area.y + area.h
    for _, box in ipairs(boxes or {}) do
        if type(box.x) == "number" and type(box.y) == "number"
                and type(box.w) == "number" and type(box.h) == "number"
                and box.w > 0 and box.h > 0 then
            local center = box.x + box.w / 2
            if center >= min_x and center < max_x
                    and box.y + box.h > min_y and box.y < max_y then
                candidates[#candidates + 1] = {
                    x = box.x, y = box.y, w = box.w, h = box.h,
                    area = area,
                }
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.y == b.y then return a.x < b.x end
        return a.y < b.y
    end)
    local lines = {}
    for _, box in ipairs(candidates) do
        local prev = lines[#lines]
        local overlap = prev and math.min(prev.y + prev.h, box.y + box.h)
            - math.max(prev.y, box.y) or 0
        local same_line = prev and overlap > 0
            and (math.abs(prev.y - box.y) <= 4
                or overlap >= math.max(prev.h, box.h) * 0.5)
        if same_line then
            local right = math.max(prev.x + prev.w, box.x + box.w)
            local bottom = math.max(prev.y + prev.h, box.y + box.h)
            prev.x = math.min(prev.x, box.x)
            prev.y = math.min(prev.y, box.y)
            prev.w = right - prev.x
            prev.h = bottom - prev.y
        else
            lines[#lines + 1] = box
        end
    end
    return lines
end

function Logic.maxStart(lines, count)
    return math.max(1, #lines - clamp(count, 1, 5) + 1)
end

-- Inclusive highlight window, never stretching one slot across page areas.
function Logic.slot(lines, index, count, allow_partial)
    if #lines == 0 then return nil end
    count = clamp(count, 1, 5)
    index = clamp(index, 1, allow_partial and #lines or Logic.maxStart(lines, count))
    local first, last = lines[index], lines[index]
    for j = index + 1, math.min(#lines, index + count - 1) do
        if lines[j].area ~= first.area then break end
        last = lines[j]
    end
    local y = math.max(first.area.y, first.y - 2)
    local bottom = math.min(first.area.y + first.area.h, last.y + last.h + 2)
    return { x = first.area.x, y = y, w = first.area.w,
             h = math.max(0, bottom - y), area = first.area }
end

-- Return next index or page-turn direction. The last, short block is visited.
function Logic.advance(lines, current, count, direction, step)
    local last = Logic.maxStart(lines, count)
    current = clamp(current, 1, last)
    step = clamp(step, 1, 5)
    if #lines == 0 then return nil, direction end
    if direction > 0 then
        if current >= last then return nil, 1 end
        return math.min(last, current + step), nil
    elseif direction < 0 then
        if current <= 1 then return nil, -1 end
        return math.max(1, current - step), nil
    end
    return current, nil
end

-- Advance in disjoint groups; never pull a short final group backwards to refill it.
-- Reverse navigation follows the same group boundaries, including the final group.
function Logic.advanceGroup(lines, current, count, direction)
    if #lines == 0 then return nil, direction end
    count = clamp(count, 1, 5)
    local last = 1 + math.floor((#lines - 1) / count) * count
    current = clamp(current, 1, last)
    if direction > 0 then
        if current >= last then return nil, 1 end
        return math.min(last, current + count), nil
    elseif direction < 0 then
        if current <= 1 then return nil, -1 end
        return math.max(1, current - count), nil
    end
    return current, nil
end

-- Return one single bounding rectangle covering all pixels whose mask state
-- can change between two positions. On physical MTK/Kaleido panels, updating
-- the upper/lower edges as separate stripes may produce incomplete refreshes.
-- The rectangular union is intentional: there is no mid-band discontinuity.
function Logic.changedBounds(old_slot, new_slot, padding)
    if not old_slot or not new_slot or old_slot.area ~= new_slot.area then
        return nil -- caller refreshes the whole screen
    end
    local area = old_slot.area
    padding = math.max(0, padding or 0)
    local top = math.max(area.y, math.floor(math.min(old_slot.y, new_slot.y) - padding))
    local bottom = math.min(area.y + area.h,
        math.ceil(math.max(old_slot.y + old_slot.h, new_slot.y + new_slot.h) + padding))
    if bottom <= top then return nil end
    return {x = area.x, y = top, w = area.w, h = bottom - top}
end

-- The Guide moves only one boundary: the lowest currently visible line.
-- Refresh the union of the old and new edge, without touching already
-- revealed text further above it. One region avoids disjoint refresh strips.
function Logic.guideChangedBounds(old_slot, new_slot, padding)
    if not old_slot or not new_slot or old_slot.area ~= new_slot.area then
        return nil -- full-screen fallback
    end
    local area = old_slot.area
    padding = math.max(0, padding or 0)
    local old_edge = old_slot.y + old_slot.h
    local new_edge = new_slot.y + new_slot.h
    if old_edge == new_edge then return nil end
    local top = math.max(area.y, math.floor(math.min(old_edge, new_edge) - padding))
    local bottom = math.min(area.y + area.h,
        math.ceil(math.max(old_edge, new_edge) + padding))
    if bottom <= top then return nil end
    return {x = area.x, y = top, w = area.w, h = bottom - top}
end

-- CRe's native segmented selection boxes can extend beyond the nominal
-- line rectangles. Bound their full vertical extent inside the current page
-- area so that any stale color at word/sentence ends gets repainted.
function Logic.selectionBounds(boxes, area)
    if type(boxes) ~= "table" or not area then return nil end
    local top, bottom
    for _, box in ipairs(boxes) do
        if type(box.x) == "number" and type(box.y) == "number"
                and type(box.w) == "number" and type(box.h) == "number"
                and box.w > 0 and box.h > 0
                and box.x + box.w > area.x and box.x < area.x + area.w
                and box.y + box.h > area.y and box.y < area.y + area.h then
            top = math.min(top or box.y, box.y)
            bottom = math.max(bottom or (box.y + box.h), box.y + box.h)
        end
    end
    if not top then return nil end
    top = math.max(area.y, top)
    bottom = math.min(area.y + area.h, bottom)
    return {x = area.x, y = top, w = area.w, h = bottom - top, area = area}
end

-- A tighter bounding rectangle for native *colored* selections only.
-- CRe returns one or more glyph boxes, which are the only pixels we need
-- to color (or clear).  Clamp to the same page area; add a safety margin for
-- anti-aliasing, side bearings and sentence-end fragments.  When geometry is
-- unavailable the caller keeps the proven full-width selection refresh.
function Logic.tightSelectionBounds(boxes, area, padding)
    if type(boxes) ~= "table" or not area then return nil end
    local x0, x1, y0, y1
    for _, box in ipairs(boxes) do
        if type(box.x) == "number" and type(box.y) == "number"
                and type(box.w) == "number" and type(box.h) == "number"
                and box.w > 0 and box.h > 0
                and box.x + box.w > area.x and box.x < area.x + area.w
                and box.y + box.h > area.y and box.y < area.y + area.h then
            x0 = math.min(x0 or box.x, box.x)
            x1 = math.max(x1 or (box.x + box.w), box.x + box.w)
            y0 = math.min(y0 or box.y, box.y)
            y1 = math.max(y1 or (box.y + box.h), box.y + box.h)
        end
    end
    if not x0 then return nil end
    padding = math.max(0, padding or 0)
    x0 = math.max(area.x, math.floor(x0 - padding))
    x1 = math.min(area.x + area.w, math.ceil(x1 + padding))
    y0 = math.max(area.y, math.floor(y0 - padding))
    y1 = math.min(area.y + area.h, math.ceil(y1 + padding))
    if x1 <= x0 or y1 <= y0 then return nil end
    return {x = x0, y = y0, w = x1 - x0, h = y1 - y0, area = area}
end

-- Coalesce two refresh bounds without splitting into separate flash-prone
-- strips. Both should be for one contiguous page area.
function Logic.unionRefresh(a, b)
    if not a then return b end
    if not b then return a end
    local x = math.min(a.x, b.x)
    local y = math.min(a.y, b.y)
    local right = math.max(a.x + a.w, b.x + b.w)
    local bottom = math.max(a.y + a.h, b.y + b.h)
    return {x = x, y = y, w = right - x, h = bottom - y}
end

-- Precise mode must never update only *part* of a multi-line window.
-- The EPUB engine's reported sboxes can omit visual line margins (or an
-- entire wrapped segment), and it may select one line more tightly than the
-- other. Use the horizontal text extent but guarantee full old+new slot
-- vertical coverage. One region, one refresh, no split top/bottom stripes.
function Logic.preciseWindowBounds(previous_tight, next_tight, previous_slot, next_slot, padding)
    if not previous_tight or not next_tight or not previous_slot or not next_slot
            or previous_slot.area ~= next_slot.area
            or previous_tight.area ~= previous_slot.area
            or next_tight.area ~= next_slot.area then
        return nil
    end
    local area = previous_slot.area
    local union = Logic.unionRefresh(previous_tight, next_tight)
    padding = math.max(0, padding or 0)
    local y0 = math.max(area.y, math.floor(math.min(union.y,
        previous_slot.y, next_slot.y) - padding))
    local y1 = math.min(area.y + area.h, math.ceil(math.max(
        union.y + union.h, previous_slot.y + previous_slot.h,
        next_slot.y + next_slot.h) + padding))
    if y1 <= y0 then return nil end
    return {x=union.x, y=y0, w=union.w, h=y1-y0}
end

return Logic
