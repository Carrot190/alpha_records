AlphaRecordsAdapters = AlphaRecordsAdapters or {}

AlphaRecordsAdapters["custom"] = {
    GetNewRecords = function(lastSyncedId)
        print("^3[Alpha Records]^7 custom adapter selected. Add your own query inside adapters/custom.lua.")

        return {}
    end
}