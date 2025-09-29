#pragma once
#include <libstuff/libstuff.h>
#include <BedrockPlugin.h>

class Core : public BedrockPlugin {
public:
    // Constructor
    Core(BedrockServer& s);
    
    // Destructor
    virtual ~Core();
    
    // Plugin initialization
    virtual void initialize() override;
    
    // Plugin name
    virtual const string& getName() const override;
    
    // Plugin version
    virtual const string& getVersion() const override;
    
private:
    static const string _name;
    static const string _version;
};
