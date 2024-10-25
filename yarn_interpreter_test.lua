local YarnParser = require("yarn_parser")
local YarnInterpreter = require("yarn_interpreter")

-- Read the script from file
local file = io.open("tests/gold_or_health.yarn", "r")
if not file then
    error("Could not open xxx.yarn")
end
local script = file:read("*all")
file:close()

local parsed_nodes = YarnParser:parse(script)

-- Create interpreter instance
local interpreter = YarnInterpreter.new(parsed_nodes)

-- OPTIONAL: Set up callbacks
interpreter:set_callbacks({
    on_dialogue = function(text)
        -- Custom dialogue display
        print("[DIALOGUE] " .. text)
    end,
    on_choice = function(choices)
        -- Custom choice handling
        print("[CHOICE]")
        for i, choice in ipairs(choices) do
            print(i .. ": " .. choice)
        end
        return tonumber(io.read())
    end,
    on_variable = function(name, value)
        -- Variable change notification
        print("[VARIABLE] " .. name .. " = " .. tostring(value))
    end,
    on_node_enter = function(title)
        print("[ENTER NODE] " .. title)
    end,
    on_node_exit = function(title)
        print("[EXIT NODE] " .. title)
    end
})

-- Run the interpreter
interpreter:run()