#include "Core.h"
#include "commands/HelloWorld.h"

#include <BedrockServer.h>

#undef SLOGPREFIX
#define SLOGPREFIX "{" << getName() << "} "

// Static member definitions
const string BedrockPlugin_Core::name("Core");

const string& BedrockPlugin_Core::getName() const {
    return name;
}

// Expose the appropriate function from our shared lib so bedrock can load it
extern "C" BedrockPlugin_Core* BEDROCK_PLUGIN_REGISTER_CORE(BedrockServer& s) {
    return new BedrockPlugin_Core(s);
}

BedrockPlugin_Core::BedrockPlugin_Core(BedrockServer& s) : BedrockPlugin(s) {
    // Initialize the plugin
}

BedrockPlugin_Core::~BedrockPlugin_Core() {
    // Cleanup
}

unique_ptr<BedrockCommand> BedrockPlugin_Core::getCommand(SQLiteCommand&& baseCommand) {
    // Check if this is a command we handle
    if (SIEquals(baseCommand.request.methodLine, "HelloWorld")) {
        return make_unique<HelloWorld>(std::move(baseCommand), this);
    }

    // Not our command
    return nullptr;
}

const string& BedrockPlugin_Core::getVersion() const {
    static const string version = "1.0.0";
    return version;
}

STable BedrockPlugin_Core::getInfo() {
    STable info;
    info["name"] = getName();
    info["version"] = getVersion();
    return info;
}

bool BedrockPlugin_Core::shouldLockCommitPageOnTableConflict(const string& tableName) const {
    // Use default behavior (return false)
    (void)tableName; // Unused
    return false;
}
