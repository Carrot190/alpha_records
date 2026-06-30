AlphaRecordsAdapters = AlphaRecordsAdapters or {}

local function getCharacterName(citizenid)
    local result = MySQL.single.await(
        "SELECT fullname FROM mdt_profiles WHERE citizenid = ?",
        { citizenid }
    )

    if result and result.fullname then
        return result.fullname
    end

    return citizenid or "Unknown"
end

local function getCharges(reportId, citizenid)
    local rows = MySQL.query.await(
        [[
            SELECT charge, count, time, fine
            FROM mdt_reports_charges
            WHERE reportid = ?
            AND citizenid = ?
        ]],
        { reportId, citizenid }
    )

    local charges = {}
    local totalFine = 0
    local totalTime = 0

    if rows then
        for _, row in ipairs(rows) do
            local count = row.count or 1
            local chargeName = row.charge or "Unknown Charge"

            table.insert(charges, chargeName .. " x" .. tostring(count))

            totalFine = totalFine + ((row.fine or 0) * count)
            totalTime = totalTime + ((row.time or 0) * count)
        end
    end

    return table.concat(charges, ", "), totalFine, totalTime
end

AlphaRecordsAdapters["ps_mdt"] = {
    GetNewRecords = function(lastSyncedId)
        local rows = MySQL.query.await(
            [[
                SELECT
                    r.id,
                    r.title,
                    r.type,
                    r.authorplaintext,
                    r.datecreated,
                    i.citizenid
                FROM mdt_reports r
                INNER JOIN mdt_reports_involved i
                    ON i.reportid = r.id
                WHERE r.id > ?
                AND r.type = 'Incident'
                ORDER BY r.id ASC
            ]],
            { lastSyncedId }
        )

        local records = {}

        if not rows or #rows == 0 then
            return records
        end

        for _, row in ipairs(rows) do
            local charges, fine, jailTime = getCharges(row.id, row.citizenid)

            if charges and charges ~= "" then
                table.insert(records, {
                    sync_id = row.id,
                    citizenid = row.citizenid,
                    character_name = getCharacterName(row.citizenid),
                    officer_name = row.authorplaintext or "Unknown Officer",
                    charges = charges,
                    fine = fine,
                    jail_time = jailTime,
                    case_number = "PS-" .. tostring(row.id)
                })
            end
        end

        return records
    end
}