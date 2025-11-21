#include "HelloWorld.h"
#include "../Core.h"

// Static member definitions
const string HelloWorld::_name = "HelloWorld";
const string HelloWorld::_description = "A simple hello world command for the Core plugin";

HelloWorld::HelloWorld(SQLiteCommand&& baseCommand, BedrockPlugin_Core* plugin)
    : BedrockCommand(std::move(baseCommand), plugin) {
    // Initialize the command
}

HelloWorld::~HelloWorld() {
    // Cleanup
}

bool HelloWorld::peek(SQLite& db) {
    // This command doesn't need to peek at the database
    (void)db; // Unused
    return false;
}

void HelloWorld::process(SQLite& db) {
    (void)db; // Unused

    // Get the name parameter, default to "World"
    string name = request["name"];
    if (name.empty()) {
        name = "World";
    }

    // Create response
    response["message"] = "Hello, " + name + "!";
    response["from"] = "Bedrock Core Plugin";
    response["timestamp"] = STimeNow();
    response["plugin_name"] = _plugin->getName();
    response["plugin_version"] = static_cast<BedrockPlugin_Core*>(_plugin)->getVersion();

    SINFO("HelloWorld command executed for: " << name);
}

string HelloWorld::serializeData() const {
    // HelloWorld doesn't need to serialize any data
    return "";
}

void HelloWorld::deserializeData(const string& data) {
    // HelloWorld doesn't need to deserialize any data
    (void)data; // Suppress unused parameter warning
}
