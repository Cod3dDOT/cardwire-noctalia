-- Control-center shortcut for Cardwire GPU mode.
--   Active     = Integrated mode
--   Inactive   = Hybrid mode
--   Disabled   = Manual or Smart mode (per-GPU or auto control)
--
-- Tapping the tile toggles between integrated and hybrid.
-- When in manual or smart mode the tile is shown but grayed out; tapping
-- switches back to hybrid so the user can then toggle normally.

local currentMode = noctalia.state.get("gpu_mode") or "unknown"

local function render()
    local mode = currentMode
    local ok   = noctalia.state.get("gpu_daemon_ok")

    -- Two-state icon: leaf when active (integrated), bolt when inactive (hybrid)
    shortcut.setIcon("leaf", "bolt")

    if ok == false then
        shortcut.setLabel("GPU Off")
        shortcut.setActive(false)
        shortcut.setEnabled(false)
        return
    end

    if mode == "integrated" then
        shortcut.setLabel("iGPU")
        shortcut.setActive(true)
        shortcut.setEnabled(true)
    elseif mode == "hybrid" then
        shortcut.setLabel("Hybrid")
        shortcut.setActive(false)
        shortcut.setEnabled(true)
    elseif mode == "manual" then
        shortcut.setLabel("Manual")
        shortcut.setActive(false)
        shortcut.setEnabled(true)   -- still tappable to exit manual mode
    elseif mode == "smart" then
        shortcut.setLabel("Smart")
        shortcut.setActive(false)
        shortcut.setEnabled(true)
    else
        shortcut.setLabel("GPU")
        shortcut.setActive(false)
        shortcut.setEnabled(false)
    end
end

-- STATE

noctalia.state.watch("gpu_mode", function(value)
    currentMode = value
    render()
end)

noctalia.state.watch("gpu_daemon_ok", function(_)
    render()
end)

-- INTERACTION

function onClick()
    local next: string

    if currentMode == "integrated" then
        -- Turn off battery-saving mode → switch to hybrid
        next = "hybrid"
    elseif currentMode == "hybrid" then
        -- Turn on battery-saving mode → switch to integrated
        next = "integrated"
    else
        -- Escape manual/smart mode back to hybrid, then user can toggle from there
        next = "hybrid"
        noctalia.notify(
            "Cardwire",
            "Exiting " .. currentMode .. " mode — switching to Hybrid"
        )
    end

    -- Optimistic update
    currentMode = next
    render()

    -- Apply via cardwire CLI; service's D-Bus watcher will confirm
    noctalia.runAsync("cardwire set " .. next, function(_: string)
        -- dbus-monitor in service.luau will pick up the PropertiesChanged signal
        -- and call fetchMode(), which will either confirm or correct the state.
    end)
end

render()
