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
end

local function saveLastSynced(id)
    lastSyncedId = id
    SetResourceKvp("alpha_records_last_id", tostring(id))
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

    local adapter = AlphaRecordsAdapters[Config.MDT]

    if not adapter then
        print("^1[Alpha Records]^7 Unknown MDT: " .. tostring(Config.MDT))
        return
    end

    local records = adapter.GetNewRecords(lastSyncedId)

    if not records or #records == 0 then
        return
    end

    for _, record in ipairs(records) do

        record.guild_id = Config.GuildId
        record.source = Config.MDT

        sendToBot(record)

        saveLastSynced(record.sync_id)

    end

end

CreateThread(function()

    Wait(5000)

    getLastSynced()

    debugPrint("Bridge started using " .. Config.MDT)

    while true do
        syncIncidents()
        Wait(Config.CheckInterval * 1000)
    end

end)