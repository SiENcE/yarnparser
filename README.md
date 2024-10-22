# Yarn Parser
A Yarn parser written in Lua to convert Yarn Spinner dialogues into Lua structures.

## Overview

This Lua module provides a parser for Yarn scripts, which are commonly used in interactive narrative games. The parser can handle various elements of Yarn syntax, including dialogue, choices, conditional statements, variable assignments, and commands.

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

## Usage

```lua
local YarnParser = require("yarn_parser")

local script = [[
title: Start
---
Player: Hello, world!

<<declare $goldAmount = 100>>
<<set $health to 100>>
Your health is {$health}.
-> Choose gold, instead of health.
    NPC: You chose {$goldAmount} gold.
    <<set $health to 50>>
-> Choose health.
    NPC: Your health is {$health}.

// Test

<<if $health > 50>>
    You're doing well!
<<else>>
    You might want to heal up.
<<endif>>

<<jump TEST>>

Jump does not work.
===
title: TEST
---
Jump does work.
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

### YarnParser:find_preceding_dialogue(node, choice_group_index)

Finds the dialogue immediately preceding a choice group within a node.

- `node`: A parsed node object.
- `choice_group_index`: The index of the choice group in the node's content.
- Returns: The preceding dialogue object, or nil if not found.

## Node Structure

Each parsed node has the following structure:

```lua
[
	{
		"title": "Start",
		"content": [
			{
				"type": "dialogue",
				"indent": 0,
				"text": "Player: Hello, world!"
			},
			{
				"variable": "goldAmount",
				"type": "declare",
				"indent": 0,
				"value": "100"
			},
			{
				"variable": "health",
				"type": "set",
				"indent": 0,
				"value": "100"
			},
			{
				"type": "dialogue",
				"indent": 0,
				"text": "Your health is {$health}."
			},
			{
				"response": [
					{
						"type": "dialogue",
						"indent": 4,
						"text": "NPC: You chose {$goldAmount} gold."
					},
					{
						"variable": "health",
						"type": "set",
						"indent": 4,
						"value": "50"
					}
				],
				"type": "choice",
				"indent": 0,
				"text": "Choice 1"
			},
			{
				"response": [
					{
						"type": "dialogue",
						"indent": 4,
						"text": "NPC: Your health is {$health}."
					}
				],
				"type": "choice",
				"indent": 0,
				"text": "Choice 2"
			},
			{
				"type": "comment",
				"indent": 0,
				"text": " Test"
			},
			{
				"condition": "$health > 50",
				"indent": 0,
				"type": "conditional",
				"else_block": [
					{
						"type": "dialogue",
						"indent": 4,
						"text": "You might want to heal up."
					}
				],
				"if_block": [
					{
						"type": "dialogue",
						"indent": 4,
						"text": "You're doing well!"
					}
				]
			},
			{
				"target": "TEST",
				"type": "jump",
				"indent": 0
			},
			{
				"type": "dialogue",
				"indent": 0,
				"text": "Jump does not work."
			}
		]
	},
	{
		"title": "TEST",
		"content": [
			{
				"type": "dialogue",
				"indent": 0,
				"text": "Jump does work."
			}
		]
	}
]
```

Content objects can be of various types, including "dialogue", "choice", "conditional", "set", "declare", "jump", and "comment".

## Yarn Syntax

For a detailed description of the Yarn syntax, please refer to [Yarn syntax description](yarn_syntax.md).

## Limitations

- The parser assumes well-formed Yarn syntax. Malformed scripts may lead to unexpected results.
- Complex nested structures (e.g., conditionals within choices within conditionals) may not be handled perfectly and might require additional processing.

## Author

Florian Fischer ( https://github.com/SiENcE )

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
