-- @description Render Addictive Drums 2 track as drum multitracks
-- @author myrrc
-- @version 0.02

render_folder = "..\\src_mixing"

CUR_PROJ = 0

function msg(...) reaper.ShowConsoleMsg(string.format("%s\n", string.format(...))) end

function xchg(key, value)
    local k, v = key, value -- to prevent variable overwrite
    if type(v) == "string" then
        local ok, old_v = reaper.GetSetProjectInfo_String(CURR_PROJ, k, "", false)
        if not ok then return nil end
        reaper.GetSetProjectInfo_String(CURR_PROJ, k, v, true)
        return function() reaper.GetSetProjectInfo_String(CURR_PROJ, k, old_v, true) end
    else
        local old_v = reaper.GetSetProjectInfo(CURR_PROJ, k, 0, false)
        reaper.GetSetProjectInfo(CURR_PROJ, k, v, true)
        return function() reaper.GetSetProjectInfo(CURR_PROJ, k, old_v, true) end
    end
end

function render(render_dir, render_file, channels)
    RENDER_SELECTED_TRACKS = 3
    ENTIRE_PROJECT = 1

    d1 = xchg("RENDER_SETTINGS", RENDER_SELECTED_TRACKS)
    d2 = xchg("RENDER_BOUNDSFLAG", ENTIRE_PROJECT)
    d3 = xchg("RENDER_CHANNELS", channels)
    d4 = xchg("RENDER_FILE", render_dir)
    d5 = xchg("RENDER_PATTERN", render_file)
    d6 = xchg("RENDER_FORMAT", "evaw")

    -- if we don't delete file explicitly, Reaper will issue an overwrite warning
    os.remove(render_dir .. "\\" .. render_file .. ".wav")

    RENDER_WITH_AUTO_CLOSE_ID = 42230
    reaper.Main_OnCommandEx(RENDER_WITH_AUTO_CLOSE_ID, 0, CURR_PROJ)

    d1()
    d2()
    d3()
    d4()
    d5()
    d6()
end

function render_many(channels, render_list)
    for name, param_idx in pairs(render_list) do
        ok = reaper.TrackFX_SetParam(drums_track, fx_idx, param_idx, 1.0)
        if not ok then return msg("Error soloing param %d", param_idx) end
        render(record_path, name, channels)
        ok = reaper.TrackFX_SetParam(drums_track, fx_idx, param_idx, 0.0)
        if not ok then return msg("Error unsoloing param %d", param_idx) end
    end
end

-- Unfortunately, track routing buttons (plugin mixer-> out pin) are not automation items in AD2:
-- https://assets.xlnaudio.com/documents/addictive-drums-manual.pdf. 
-- Separate channels guide https://xlnaudio-assets.s3.amazonaws.com/documents/separate-outputs.pdf advises
-- users to click through all buttons (master -> separate out + master).
-- If we don't want user to do that, we have to render each channel separately sacrificing parallel render.
-- Rendering API is partially supported, we can just invoke the render action with some settings.
-- Ultraschal API is cool but too huge
function main()
    if reaper.CountSelectedTracks(CUR_PROJ) ~= 1 then return msg("Drums track must be the only one selected") end
    drums_track = reaper.GetSelectedTrack(CUR_PROJ, 0)
    fx_idx = reaper.TrackFX_GetInstrument(drums_track)
    if fx_idx == -1 then return msg("Virtual instrument not found on selected track") end

    ok, fx_name = reaper.BR_TrackFX_GetFXModuleName(drums_track, fx_idx)
    if not ok then return msg("Error getting fx module name") end
    if not fx_name:lower():find("addictive drums 2") then return msg("Invalid plugin: %s", fx_name) end

    -- not sure whether this should be a subfolder rather than a separate folder; better use path.normalize
    record_path = reaper.GetProjectPathEx() .. "\\" .. render_folder
    reaper.RecursiveCreateDirectory(record_path, 0)

    render_many(1, { kick = 236, snare = 240, hihat = 244,
        hi_tom = 248, med_tom = 252, lo_tom = 256 , floor_tom = 260,
        flexi_1 = 264, flexi_2 = 268, flexi_3 = 272 })

    render_many(2, { overhead = 277, room = 282, bus = 287 })
end

reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
if main() == nil then
    return nil
end
reaper.Undo_EndBlock("AD2 render", -1)
reaper.UpdateArrange()
reaper.PreventUIRefresh(-1)
