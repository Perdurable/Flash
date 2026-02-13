--[[
Rules:
1) Do not add silent fallback behavior; if a dependency or helper is missing call `Flash.DebugError(msg)`
2) Keep comments clear and up to date; add brief comments for non-obvious logic and behavior changes.
3) Preserve existing public API names; annotate changes in header comments
4) Do not add silent fallback behavior for unexpected states; prefer explicit logged behavior.
5) To choose icons, open the files under Reference Material/Spell Icons and pick icons from the folder matching the class being edited.

When editing: prefer explicit errors and clear debug messages over hidden fallbacks.
This header instructs any future editor (and the assistant) to emit debug errors
when something fails to load rather than silently providing alternative behavior.
]]

-- luacheck: globals UnitName UnitClass UnitBuff CreateFrame UIParent PlaySoundFile GetTime DEFAULT_CHAT_FRAME SlashCmdList SLASH_FLASH1 FlashOptionsMenu FLASH

Flash = Flash or {}
FlashCharacterConfig = FlashCharacterConfig or {}
Flash.config = Flash.config or {}

-- Debug helper: use for consistent diagnostics when something fails to load
function Flash.DebugError(msg)
    local out = "Flash DEBUG ERROR: " .. tostring(msg or "(no message)")
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(out, 1.0, 0.2, 0.2)
    else
        print(out)
    end
    if debugstack then
        local stack = debugstack(2,6,0)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(stack)
        else
            print(stack)
        end
    end
end

-- Defensive wrapper: protect the global UIDropDownMenu_SetSelectedID from invalid calls
if type(UIDropDownMenu_SetSelectedID) == "function" then
    if not Flash._orig_UIDropDownMenu_SetSelectedID then
        Flash._orig_UIDropDownMenu_SetSelectedID = UIDropDownMenu_SetSelectedID
    end
    local _orig = Flash._orig_UIDropDownMenu_SetSelectedID
    Flash._badUIDropCalls = Flash._badUIDropCalls or {}
    UIDropDownMenu_SetSelectedID = function(frame, id)
        local function looksLikeFrame(x)
            local t = type(x)
            if t == "userdata" or t == "table" then
                return type(x.GetObjectType) == "function" or type(x.IsObjectType) == "function"
            end
            return false
        end
        if looksLikeFrame(frame) then
            return pcall(_orig, frame, id)
        end
        if looksLikeFrame(id) then
            return pcall(_orig, id, frame)
        end
        local key = tostring(frame) .. ":" .. tostring(id)
        if not Flash._badUIDropCalls[key] then
            Flash._badUIDropCalls[key] = true
            if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                DEFAULT_CHAT_FRAME:AddMessage("Flash: blocked invalid UIDropDownMenu_SetSelectedID call; frame type="..type(frame))
            else
                print("Flash: blocked invalid UIDropDownMenu_SetSelectedID call; frame type="..type(frame))
            end
            if debugstack then
                local stack = debugstack(2,6,0)
                if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
                    DEFAULT_CHAT_FRAME:AddMessage(stack)
                else
                    print(stack)
                end
            end
        end
        return nil
    end
end

-- List of available sound files for the menu
Flash.soundFiles = {
    "Alarm.ogg","Alien.ogg","Bell.ogg","Clock.ogg","Dink.ogg","Dink2.ogg",
    "Electronic.ogg","FF7.ogg","MGS.ogg","MGS2.ogg","NefarianDropped.ogg",
    "OnyxiaDropped.ogg","Pop.ogg","Pop2.ogg","RendDropped.ogg","WT.ogg",
    "ZandalarDropped.ogg","Zelda.ogg"
}

-- Note: runtime behavior (event loop, check logic, UI fallback builder,
-- icon/frame creation) now lives in `events.lua` and `icons.lua`.