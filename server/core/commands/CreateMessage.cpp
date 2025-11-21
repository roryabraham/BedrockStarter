#include "CreateMessage.h"

#include "../Core.h"

#include <libstuff/libstuff.h>
#include <fmt/format.h>

CreateMessage::CreateMessage(SQLiteCommand&& baseCommand, BedrockPlugin_Core* plugin)
    : BedrockCommand(std::move(baseCommand), plugin) {
}

bool CreateMessage::peek(SQLite& db) {
    (void)db;
    validateRequest();
    return false;
}

void CreateMessage::process(SQLite& db) {
    validateRequest();

    const string& name = request["name"];
    const string& message = request["message"];
    const string createdAt = SToStr(STimeNow());

    const string query = fmt::format(
        "INSERT INTO messages (name, message, createdAt) VALUES ({}, {}, {});",
        SQ(name), SQ(message), createdAt
    );

    if (!db.write(query)) {
        STHROW("502 Failed to insert message");
    }

    SQResult result;
    const string selectQuery = "SELECT last_insert_rowid()";
    if (!db.read(selectQuery, result) || result.empty() || result[0].empty()) {
        STHROW("502 Failed to retrieve inserted messageID");
    }

    response["result"] = "stored";
    response["messageID"] = result[0][0];
    response["name"] = name;
    response["message"] = message;
    response["createdAt"] = createdAt;
}

void CreateMessage::validateRequest() const {
    BedrockPlugin::verifyAttributeSize(request, "name", 1, BedrockPlugin::MAX_SIZE_SMALL);
    BedrockPlugin::verifyAttributeSize(request, "message", 1, BedrockPlugin::MAX_SIZE_QUERY);
}

