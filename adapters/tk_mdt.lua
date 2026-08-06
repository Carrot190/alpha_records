AlphaRecordsAdapters = AlphaRecordsAdapters or {}

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

AlphaRecordsAdapters["tk_mdt"] = {

    GetNewRecords = function(lastSyncedId)

        local rows = MySQL.query.await([[
            SELECT
                id,
                title,
                creator,
                date,
                criminals,
                content
            FROM tk_mdt_incidents
            WHERE id > ?
            ORDER BY id ASC
        ]], {
            lastSyncedId
        })

        local records = {}

        if not rows then
            return records
        end

        for _, incident in ipairs(rows) do

            local criminals = decodeJson(incident.criminals)

            if criminals and type(criminals) == "table" then

                for _, criminal in ipairs(criminals) do

                    if criminal.processed == true then

                        table.insert(records, {

                            sync_id = incident.id,

                            citizenid = criminal.identifier,

                            character_name = criminal.name,

                            officer_name = incident.creator,

                            charges = getChargeNames(criminal.charges),

                            fine = criminal.fine or 0,

                            jail_time = criminal.sentence or 0,

                            case_number = "TK-" .. tostring(incident.id)

                        })

                    end

                end

            end

        end

        return records

    end

}