#include "GetMessages.h"

#include "../Core.h"

#include <libstuff/libstuff.h>
#include <fmt/format.h>

GetMessages::GetMessages(SQLiteCommand&& baseCommand, BedrockPlugin_Core* plugin)
    : BedrockCommand(std::move(baseCommand), plugin) {
}

bool GetMessages::peek(SQLite& db) {
    buildResponse(db);
    return true;
}

void GetMessages::process(SQLite& db) {
    buildResponse(db);
}

void GetMessages::buildResponse(SQLite& db) {
    size_t limit = 20;
    if (!request["limit"].empty()) {
        limit = static_cast<size_t>(max<int64_t>(1, min<int64_t>(request.calc64("limit"), 100)));
    }

    const string query = fmt::format(
        "SELECT messageID, name, message, createdAt "
        "FROM messages "
        "ORDER BY messageID DESC "
        "LIMIT {}",
        limit
    );

    SQResult result;
    if (!db.read(query, result)) {
        STHROW("502 Failed to fetch messages");
    }

    list<string> rows;
    for (const auto& row : result) {
        if (row.size() < 4) {
            continue;
        }
        STable item;
        item["messageID"] = row[0];
        item["name"] = row[1];
        item["message"] = row[2];
        item["createdAt"] = row[3];
        rows.emplace_back(SComposeJSONObject(item));
    }

    response["resultCount"] = SToStr(rows.size());
    response["messages"] = SComposeJSONArray(rows);
    response["format"] = "json";
}

