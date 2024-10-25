# Yarn Parser & Interpreter
A Yarn parser written in Lua to convert Yarn Spinner dialogues into Lua structures. There is also a [interpreter](yarn_interpreter.lua) to demonstrate how to interpret the parsed node structures.

## Overview

This Lua module provides a parser for Yarn scripts, which are commonly used in interactive narrative games. The parser can handle various elements of Yarn syntax, including dialogue, choices, conditional statements, variable assignments, and commands.

The supplied interpreter is only an example of how the parsed structure can be interpreted. You must adapt it or implement your own interpreter that meets your requirements.

## Features

- Parse Yarn scripts into structured node objects
- Support for:
  - Dialogue lines
  - Choices (including nested choices)
  - Conditional statements (if/else)
  - Variable assignments, declarations, and interpolation
  - Commands (including jump, set, declare)
  - Comments (single-line and multi-line)
- Grouping of related content (e.g., choices and their responses)
- Ability to find dialogue preceding choice groups
- Sample interpreter with callbacks to run the dialogues.

## Usage Sample

main.lua
```lua
local YarnParser = require("yarn_parser")

local script = [[
title: Start
---
Player: Hello, world!

<<declare $goldAmount = 100>>
<<set $health to 100>>
Your health is {$health}.
-> Choice 1: gold
    NPC: You chose {$goldAmount} gold.
    <<set $health to 50>>
-> Choice 2: health
    NPC: Your health is {$health}.

NPC: You have {$health} health.

<<jump TEST>>

Jump does not work.
===
title: TEST
---
Jump: Test.
===
]]

-- Function to print the content of a node
local function print_content(content, indent)
    indent = indent or ""
    for _, item in ipairs(content) do
        if item.type == "dialogue" then
            print(indent .. item.text)
        elseif item.type == "choice" then
            print(indent .. "    -> " .. item.text)
            print_content(item.response, indent .. "  ")
        elseif item.type == "set" then
            print(indent .. "Set: " .. item.variable .. " to " .. item.value)
        elseif item.type == "conditional" then
            print(indent .. "If: " .. item.condition)
            print(indent .. "Then:")
            print_content(item.if_block, indent .. "  ")
            if #item.else_block > 0 then
                print(indent .. "Else:")
                print_content(item.else_block, indent .. "  ")
            end
        elseif item.type == "jump" then
            print(indent .. "Jump to: " .. item.target)
        elseif item.type == "declare" then
            print(indent .. "Declare: " .. item.variable .. " = " .. item.value)
        elseif item.type == "comment" then
            print(indent .. "Comment: " .. item.text)
        else
            print(indent .. "Unknown type: " .. tostring(item.type))
        end
    end
end

local parsed_nodes = YarnParser:parse(script)

-- Print the parsed structure
if parsed_nodes then
    for i, node in ipairs(parsed_nodes) do
        print("Node: " .. node.title)
        print_content(node.content, "  ")
        print("") -- Empty line between nodes for readability
    end
end
```

## API

### YarnParser:parse(script)

Parses a Yarn script and returns an array of node objects.

- `script`: A string containing the entire Yarn script.
- Returns: An array of parsed node objects.

## Node Structure

Each parsed node has the following structure (exported json table):

```json
[
	{
		"title": "Start",
		"content": [
			{
				"text": "Player: Hello, world!",
				"indent": 0,
				"type": "dialogue"
			},
			{
				"variable": "goldAmount",
				"value": "100",
				"indent": 0,
				"type": "declare"
			},
			{
				"variable": "health",
				"value": "100",
				"indent": 0,
				"type": "set"
			},
			{
				"text": "Your health is {$health}.",
				"indent": 0,
				"type": "dialogue"
			},
			{
				"response": [
					{
						"text": "NPC: You chose {$goldAmount} gold.",
						"indent": 4,
						"type": "dialogue"
					},
					{
						"variable": "health",
						"value": "50",
						"indent": 4,
						"type": "set"
					}
				],
				"text": "Choice 1: gold",
				"indent": 0,
				"type": "choice"
			},
			{
				"response": [
					{
						"text": "NPC: Your health is {$health}.",
						"indent": 4,
						"type": "dialogue"
					}
				],
				"text": "Choice 2: health",
				"indent": 0,
				"type": "choice"
			},
			{
				"text": "NPC: You have {$health} health.",
				"indent": 0,
				"type": "dialogue"
			},
			{
				"target": "TEST",
				"indent": 0,
				"type": "jump"
			},
			{
				"text": "Jump does not work.",
				"indent": 0,
				"type": "dialogue"
			}
		]
	},
	{
		"title": "TEST",
		"content": [
			{
				"text": "Jump: Test.",
				"indent": 0,
				"type": "dialogue"
			}
		]
	}
]
```

Content objects can be of various types, including "dialogue", "choice", "conditional", "set", "declare", "jump", and "comment".

## Yarn Syntax

For a detailed description of the Yarn syntax, please refer to [Yarn syntax description](yarn_syntax.md).

## Interpreter

The included interpreter demonstrates how to run parsed Yarn scripts with callback support for various events.

### Basic Usage

```lua
local YarnParser = require("yarn_parser")
local YarnInterpreter = require("yarn_interpreter")

-- Parse your Yarn script
local nodes = YarnParser:parse(your_script)

-- Create a new interpreter instance
local interpreter = YarnInterpreter.new(nodes)

-- Define callbacks
local callbacks = {
    on_dialogue = function(text)
        print("Dialogue:", text)
    end,
    on_choice = function(choices, path)
        print("Choice path:", path or "root")
        for i, choice in ipairs(choices) do
            print(i .. ": " .. choice)
        end
        io.write("Select (1-" .. #choices .. "): ")
        return tonumber(io.read())
    end,
    on_variable = function(name, value)
        print("Variable changed:", name, "=", value)
    end,
    on_node_enter = function(title)
        print("Entering node:", title)
    end,
    on_node_exit = function(title)
        print("Exiting node:", title)
    end
}

-- Set the callbacks
interpreter:set_callbacks(callbacks)

-- Start the interpretation
interpreter:run()
```

### Available Callbacks

- `on_dialogue(text)`: Called when dialogue text is encountered
- `on_choice(choices, path)`: Called when choices are presented. Must return the selected choice index
- `on_variable(name, value)`: Called when a variable is set or declared
- `on_node_enter(title)`: Called when entering a new node
- `on_node_exit(title)`: Called when exiting a node

### Variable Management

The interpreter maintains its own variable state, but you can interact with it:

```lua
-- Get a variable value
local value = interpreter:get_variable("health")

-- Set a variable value
interpreter:set_variable("health", 100)
```

### Handling Choices

The `on_choice` callback receives:
- An array of choice texts with variables already interpolated
- A path string showing the hierarchy of nested choices (e.g., "Choice 1 > Nested Choice 2")

The callback must return a number indicating the selected choice (1-based index).

### Error Handling

The interpreter will emit warnings (via print) when:
- Invalid choices are selected
- Jump targets are not found
- Variables are undefined
- Conditions cannot be evaluated

## Limitations

- The parser handles choices up from level 2 at the same level. Level 2 & 3 are put on the same level in the structure. Via ident you can still put them on a different level in your interpreter.
Test Sample:
```
-> Choice 2: health
    NPC: Your health is {$health}.
    -> Level 2 Test
        Level 2 works?
        -> Level 3 Test
            Level 3 works?
```

- The parser assumes well-formed Yarn syntax. Malformed scripts may lead to unexpected results.
- Complex nested structures (e.g., conditionals within choices within conditionals) may not be handled perfectly and might require additional processing.

## Author

Florian Fischer ( https://github.com/SiENcE )

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
