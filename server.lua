local lastSyncedId = 0

local function debugPrint(msg)
    if Config.Debug then
        print("^3[Alpha Records]^7 " .. msg)
    end
end

local function getLastSynced()
    local saved = GetResourceKvpString("alpha_records_last_id")
    if saved then
        lastSyncedId = tonumber(saved) or 0
    end

    debugPrint("Last synced MDT incident ID: " .. lastSyncedId)
end

local function saveLastSynced(id)
    lastSyncedId = id
    SetResourceKvp("alpha_records_last_id", tostring(id))
end

local function decodeJson(value)
    if not value or value == "" then return nil end

    local ok, decoded = pcall(json.decode, value)

    if ok then
        return decoded
    end

    return nil
end

local function getChargeNames(charges)
    if not charges or #charges == 0 then
        return "Unknown Charges"
    end

    local names = {}

    for _, charge in ipairs(charges) do
        local chargeId = charge.id
        local amount = charge.amount or 1

        local result = MySQL.single.await(
            "SELECT name FROM tk_mdt_charges WHERE id = ?",
            { chargeId }
        )

        if result and result.name then
            table.insert(names, result.name .. " x" .. amount)
        else
            table.insert(names, "Charge ID " .. tostring(chargeId) .. " x" .. amount)
        end
    end

    return table.concat(names, ", ")
end

local function sendToBot(data)
    PerformHttpRequest(Config.BotApiUrl, function(statusCode, response)
        if statusCode == 200 then
            debugPrint("Synced arrest record: " .. (data.character_name or "Unknown"))
        else
            print("^1[Alpha Records]^7 Failed to sync record. HTTP: " .. tostring(statusCode))
            print("^1[Alpha Records]^7 Response: " .. tostring(response))
        end
    end, "POST", json.encode(data), {
        ["Content-Type"] = "application/json",
        ["x-alpha-key"] = Config.ApiKey
    })
end

local function syncIncidents()
    local rows = MySQL.query.await(
        [[
            SELECT id, title, creator, date, criminals, content
            FROM tk_mdt_incidents
            WHERE id > ?
            ORDER BY id ASC
        ]],
        { lastSyncedId }
    )

    if not rows or #rows == 0 then
        return
    end

    for _, incident in ipairs(rows) do
        local criminals = decodeJson(incident.criminals)

        if criminals and type(criminals) == "table" then
            for _, criminal in ipairs(criminals) do
                if criminal.processed == true then
                    local charges = getChargeNames(criminal.charges)

                    local record = {
                        guild_id = Config.GuildId,
                        citizenid = criminal.identifier,
                        character_name = criminal.name,
                        officer_name = incident.creator,
                        charges = charges,
                        fine = criminal.fine or 0,
                        jail_time = criminal.sentence or 0,
                        case_number = "TK-" .. tostring(incident.id),
                        source = "tk_mdt"
                    }

                    sendToBot(record)
                end
            end
        end

        saveLastSynced(incident.id)
    end
end

CreateThread(function()
    Wait(5000)

    getLastSynced()

    debugPrint("Bridge started.")

    while true do
        syncIncidents()
        Wait(Config.CheckInterval * 1000)
    end
end)