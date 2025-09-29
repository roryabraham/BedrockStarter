#include "HelloWorld.h"
#include "../Core.h"

// Static member definitions
const string HelloWorld::_name = "HelloWorld";
const string HelloWorld::_description = "A simple hello world command for the Core plugin";

HelloWorld::HelloWorld(Core& plugin) : BedrockCommand(), _plugin(plugin) {
    // Initialize the command
}

HelloWorld::~HelloWorld() {
    // Cleanup
}

BedrockCommand::RESULT HelloWorld::peekCommand(SQLite& db, BedrockCommand::Command& command) {
    // This command doesn't need to peek at the database
    // Return COMPLETE to indicate we should process it
    return BedrockCommand::RESULT::COMPLETE;
}

BedrockCommand::RESULT HelloWorld::processCommand(SQLite& db, BedrockCommand::Command& command) {
    // Get the name parameter, default to "World"
    string name = command.request["name"];
    if (name.empty()) {
        name = "World";
    }
    
    // Create response
    SData response;
    response["message"] = "Hello, " + name + "!";
    response["from"] = "Bedrock Core Plugin";
    response["timestamp"] = STimeNow();
    response["plugin_version"] = _plugin.getVersion();
    
    // Set the response
    command.response = response;
    
    SINFO("HelloWorld command executed for: " << name);
    
    return BedrockCommand::RESULT::COMPLETE;
}

const string& HelloWorld::getName() const {
    return _name;
}

const string& HelloWorld::getDescription() const {
    return _description;
}
