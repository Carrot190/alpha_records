AlphaRecordsAdapters = AlphaRecordsAdapters or {}

local function decodeJson(data)
    if not data or data == "" then return {} end

    local ok, result = pcall(json.decode, data)
    if ok and result then
        return result
    end

    return {}
end

local function formatCharges(charges)
    if not charges or #charges == 0 then
        return "Unknown Charges", 0, 0
    end

    local list = {}
    local totalFine = 0
    local totalJail = 0

    for _, charge in ipairs(charges) do
        local name =
            charge.label or
            charge.name or
            charge.charge or
            "Unknown Charge"

        local count =
            charge.amount or
            charge.count or
            1

        local fine =
            charge.fine or
            charge.price or
            0

        local jail =
            charge.jail or
            charge.time or
            charge.months or
            charge.sentence or
            0

        table.insert(list, ("%s x%s"):format(name, count))

        totalFine = totalFine + (fine * count)
        totalJail = totalJail + (jail * count)
    end

    return table.concat(list, ", "), totalFine, totalJail
end

AlphaRecordsAdapters["qs_mdt"] = {

    GetNewRecords = function(lastSyncedId)

        local incidents = MySQL.query.await([[
            SELECT *
            FROM dispatch_mdt_incidents
            WHERE id > ?
            ORDER BY id ASC
        ]], {
            lastSyncedId
        })

        local records = {}

        if not incidents then
            return records
        end

        for _, incident in ipairs(incidents) do

            local criminals = decodeJson(incident.criminals_involved)

            for _, criminal in ipairs(criminals) do

                local citizenid =
                    criminal.citizenid or
                    criminal.identifier or
                    criminal.cid or
                    ""

                local firstname =
                    criminal.firstname or
                    criminal.first or
                    ""

                local lastname =
                    criminal.lastname or
                    criminal.last or
                    ""

                local fullname = (firstname .. " " .. lastname):gsub("^%s*(.-)%s*$", "%1")

                local charges, fine, jail =
                    formatCharges(criminal.charges)

                table.insert(records, {

                    sync_id = incident.id,

                    citizenid = citizenid,

                    character_name =
                        fullname ~= "" and fullname or
                        criminal.name or
                        citizenid,

                    officer_name =
                        incident.CreatorName or
                        "Unknown Officer",

                    charges = charges,

                    fine = fine,

                    jail_time = jail,

                    case_number = "QS-" .. tostring(incident.id)

                })

            end

        end

        return records

    end

}