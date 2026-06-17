-- SPDX-FileCopyrightText: 2026 cod3ddot@proton.me
-- SPDX-License-Identifier: MIT

-- Bar widget for Cardwire GPU mode.
--   Left-click     cycle modes: integrated | hybrid | manual
--   Right-click    send IPC refresh to service; tooltip updates on next poll
--   Tooltip        current mode + per-GPU name / status
--
-- color:
--   integrated  green    dGPU blocked, battery-saving mode
--   hybrid      orange   full GPU access
--   manual      slate    per-GPU blocking, user-controlled
--   smart       indigo   daemon-managed automatic switching
--   unknown     red      daemon unreachable or mode not yet read

local GLYPH: { [string]: string } = {
    integrated = "leaf",
    hybrid     = "bolt",
    manual     = "adjustments-horizontal",
    smart      = "sparkles",
    unknown    = "alert-circle",
}

local LABEL: { [string]: string } = {
    integrated = "iGPU",
    hybrid     = "dGPU",
    manual     = "Manual",
    smart      = "Smart",
    unknown    = "?",
}

local COLOR: { [string]: string } = {
    integrated = "#4ade80",  -- green-400
    hybrid     = "#fb923c",  -- orange-400
    manual     = "#94a3b8",  -- slate-400
    smart      = "#818cf8",  -- indigo-400
    unknown    = "#f87171",  -- red-400
}

local CYCLE_ORDER: { string } = { "integrated", "hybrid", "manual" }

local function buildTooltip(mode: string, gpus: any): string
    local title = "GPU Mode: " .. mode:sub(1, 1):upper() .. mode:sub(2)
    if type(gpus) ~= "table" or #gpus == 0 then
        return title
    end
    local lines: { string } = { title, "" }
    for _, gpu in ipairs(gpus) do
        local tag = gpu.default and " [display]" or ""
        local status: string
        if gpu.blocked then
            status = "blocked (D3cold)"
        else
            status = "active"
        end
        table.insert(lines, ("  • %s%s"):format(gpu.name, tag))
        table.insert(lines, ("    PCI %s — %s"):format(gpu.pci, status))
    end
    table.insert(lines, "")
    table.insert(lines, "Left-click: cycle mode  •  Right-click: refresh")
    return table.concat(lines, "\n")
end

local function render()
    local mode    = noctalia.state.get("gpu_mode")  or "unknown"
    local ok      = noctalia.state.get("gpu_daemon_ok")
    local gpus    = noctalia.state.get("gpu_list")

    if ok == false then
        barWidget.setGlyph("alert-circle")
        barWidget.setText("!")
        barWidget.setColor("#f87171")
        barWidget.setGlyphColor("#f87171")
        barWidget.setTooltip(
            "Cardwire daemon not running\n"
                .. "Run: sudo systemctl start cardwired.service"
        )
        return
    end

    local glyph = GLYPH[mode] or GLYPH.unknown
    local label = LABEL[mode] or mode
    local color = COLOR[mode] or COLOR.unknown

    barWidget.setGlyph(glyph)
    barWidget.setText(label)
    barWidget.setColor(color)
    barWidget.setGlyphColor(color)
    barWidget.setTooltip(buildTooltip(mode, gpus))
end

-- STATE

noctalia.state.watch("gpu_mode",      function(_) render() end)
noctalia.state.watch("gpu_daemon_ok", function(_) render() end)
noctalia.state.watch("gpu_list",      function(_) render() end)

-- Render once on load (service may have already published state from a prior run)
render()

-- INTERACTION

function onClick()
    local cur = noctalia.state.get("gpu_mode") or "hybrid"
    -- Find current position in cycle order
    local idx = 1
    for i, m in ipairs(CYCLE_ORDER) do
        if m == cur then idx = i end
    end
    local next = CYCLE_ORDER[(idx % #CYCLE_ORDER) + 1]

    -- Optimistic UI update so the bar feels instant
    noctalia.state.set("gpu_mode", next)

    -- Issue the actual switch; the service's D-Bus watcher will confirm/correct
    noctalia.runAsync("cardwire set " .. next, function(_: string)
        -- No extra action needed — dbus-monitor will trigger fetchMode() in service
    end)
end

function onRightClick()
    -- Ask the service to re-fetch GPU list (tooltip will update on next watch fire)
    noctalia.runAsync("cardwire list", function(out: string)
        -- Parse inline so the tooltip is updated from this VM too
        if out and #out > 0 then
            noctalia.notify("Cardwire GPU Mode", out:match("^(.-)%s*$") or out)
        end
    end)
end
