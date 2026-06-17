-- SPDX-FileCopyrightText: 2026 cod3ddot@proton.me
-- SPDX-License-Identifier: MIT

-- Background service for cardwire GPU mode management.
--   Streams dbus-monitor for PropertiesChanged so the bar reflects mode
--     switches made by any client.
--   Falls back to polling every POLL_INTERVAL_MS if the D-Bus stream is lost.
--
-- State keys published (consumed by widget.luau and shortcut.luau):
--   gpu_mode      string  "integrated" | "hybrid" | "manual" | "smart" | "unknown"
--   gpu_list      table   array of { id, name, pci, default, blocked }
--   gpu_daemon_ok bool    false when the cardwired.service daemon is unreachable

local POLL_INTERVAL_MS = 5000   -- fallback poll rate (ms)
local GPU_LIST_EVERY   = 6      -- refresh GPU list every N poll ticks

-- D-Bus identifiers
local BUS_NAME  = "com.github.opengamingcollective.cardwire"
local OBJ_PATH  = "/com/github/opengamingcollective/cardwire"
local MODE_IFACE = "com.github.opengamingcollective.cardwire.Mode"

-- Maps D-Bus uint (0-indexed) → canonical mode string
local MODE_FROM_INT: { string } = { "integrated", "hybrid", "manual", "smart" }

--- Publish mode to shared state if it changed.
local function publishMode(mode: string)
    noctalia.state.set("gpu_mode", mode)
end

--- Read the current mode from the D-Bus Mode property.
--- Output from busctl get-property: "u <N>\n"
local function fetchMode()
    noctalia.runAsync(
        "busctl --system get-property "
            .. BUS_NAME .. " " .. OBJ_PATH .. " " .. MODE_IFACE .. " Mode",
        function(out: string)
            local n = tonumber(out:match("u%s+(%d+)"))
            if n ~= nil then
                local mode = MODE_FROM_INT[n + 1] or "unknown"
                noctalia.state.set("gpu_daemon_ok", true)
                publishMode(mode)
            else
                -- busctl failed — fall back to the cardwire CLI
                noctalia.runAsync("cardwire get", function(o2: string)
                    local lower = o2:lower()
                    local found = false
                    for _, name in ipairs({"integrated", "hybrid", "manual", "smart"}) do
                        if lower:find(name, 1, true) then
                            publishMode(name)
                            noctalia.state.set("gpu_daemon_ok", true)
                            found = true
                            break
                        end
                    end
                    if not found then
                        noctalia.state.set("gpu_daemon_ok", false)
                        publishMode("unknown")
                    end
                end)
            end
        end
    )
end

--- Parse `cardwire list` tabular output into a GPU array.
--- Columns: ID  NAME  PCI  RENDER  CARD  DEFAULT  BLOCKED
local function parseGpuList(out: string): { any }
    local gpus: { any } = {}
    local lineNum = 0
    for line in (out .. "\n"):gmatch("([^\n]*)\n") do
        lineNum += 1
        if lineNum > 1 then  -- skip header row
            -- Split on whitespace; NAME may contain spaces so take first,
            -- last-6 tokens as structured fields, middle as name.
            local parts: { string } = {}
            for tok in line:gmatch("%S+") do
                table.insert(parts, tok)
            end
            if #parts >= 7 then
                -- Reconstruct name from all middle tokens (between ID and PCI)
                local nameParts: { string } = {}
                for i = 2, #parts - 5 do
                    table.insert(nameParts, parts[i])
                end
                local boolVal = function(s: string): boolean
                    return s:lower() == "true" or s == "yes" or s == "✓"
                end
                table.insert(gpus, {
                    id      = parts[1],
                    name    = table.concat(nameParts, " "),
                    pci     = parts[#parts - 4],
                    render  = parts[#parts - 3],
                    card    = parts[#parts - 2],
                    default = boolVal(parts[#parts - 1]),
                    blocked = boolVal(parts[#parts]),
                })
            end
        end
    end
    return gpus
end

--- Refresh the GPU list from `cardwire list`.
local function fetchGpus()
    noctalia.runAsync("cardwire list", function(out: string)
        local gpus = parseGpuList(out)
        if #gpus > 0 then
            noctalia.state.set("gpu_list", gpus)
        end
    end)
end

-- D-Bus stream
-- Monitor PropertiesChanged on the cardwire object so mode changes made by any
-- client (battery_auto_switch, the CLI in another terminal, etc.) are reflected
-- on the bar almost instantly, without waiting for the next poll.

noctalia.runStream(
    "dbus-monitor --system "
        .. "'type=signal,"
        .. "interface=org.freedesktop.DBus.Properties,"
        .. "member=PropertiesChanged,"
        .. "path=" .. OBJ_PATH .. "'",
    function(line: string)
        -- The first line of the signal payload names the changed interface.
        -- Re-fetch whenever the Mode interface is mentioned.
        if line:find("cardwire.Mode", 1, true)
            or line:find("PropertiesChanged", 1, true)
        then
            fetchMode()
        end
    end
)

noctalia.setUpdateInterval(POLL_INTERVAL_MS)

-- Initial data load
fetchMode()
fetchGpus()

-- Periodic fallback poll (keeps state fresh even if the D-Bus stream is quiet)
local _tick = 0
function update()
    _tick += 1
    fetchMode()
    if _tick % GPU_LIST_EVERY == 0 then
        fetchGpus()
    end
end

-- IPC handler — the widget and shortcut post commands here when the user clicks.
-- Format:  event = "set_mode",  payload = "integrated" | "hybrid" | "manual" | "smart"
--          event = "cycle_mode", payload = "" (cycles integrated → hybrid → manual)
--          event = "refresh",    payload = "" (force immediate state refresh)
function onIpc(event: string, payload: string)
    if event == "set_mode" then
        local mode = payload:lower()
        noctalia.runAsync("cardwire set " .. mode, function(out: string)
            -- Confirm the daemon accepted the change
            fetchMode()
            fetchGpus()
        end)

    elseif event == "cycle_mode" then
        local order = { "integrated", "hybrid", "manual" }
        local cur   = noctalia.state.get("gpu_mode") or "hybrid"
        local idx   = 1
        for i, m in ipairs(order) do
            if m == cur then idx = i end
        end
        local next = order[(idx % #order) + 1]
        noctalia.runAsync("cardwire set " .. next, function(out: string)
            fetchMode()
        end)

    elseif event == "refresh" then
        fetchMode()
        fetchGpus()
    end
end
