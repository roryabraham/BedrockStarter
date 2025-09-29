#pragma once
#include <libstuff/libstuff.h>
#include <BedrockCommand.h>

// Forward declaration
class Core;

class HelloWorld : public BedrockCommand {
public:
    // Constructor
    HelloWorld(Core& plugin);
    
    // Destructor
    virtual ~HelloWorld();
    
    // Command execution
    virtual BedrockCommand::RESULT peekCommand(SQLite& db, BedrockCommand::Command& command) override;
    virtual BedrockCommand::RESULT processCommand(SQLite& db, BedrockCommand::Command& command) override;
    
    // Command name
    virtual const string& getName() const override;
    
    // Command description
    virtual const string& getDescription() const override;
    
private:
    Core& _plugin;
    static const string _name;
    static const string _description;
};
