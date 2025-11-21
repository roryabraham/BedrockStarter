#pragma once
#include <libstuff/libstuff.h>
#include <BedrockPlugin.h>

class BedrockPlugin_Core : public BedrockPlugin {
public:
    // Constructor
    BedrockPlugin_Core(BedrockServer& s);
    
    // Destructor
    virtual ~BedrockPlugin_Core();
    
    // Required: Create command from SQLiteCommand
    virtual unique_ptr<BedrockCommand> getCommand(SQLiteCommand&& baseCommand) override;
    
    // Plugin name
    [[nodiscard]] const string& getName() const override;
    
    // Plugin version (not an override - plugins don't have getVersion in base class)
    [[nodiscard]] virtual const string& getVersion() const;
    
    // Returns plugin info (required by BedrockPlugin)
    STable getInfo() override;
    
    // Override shouldLockCommitPageOnTableConflict (required by BedrockPlugin)
    bool shouldLockCommitPageOnTableConflict(const string& tableName) const override;
    
private:
    static const string name;
};
