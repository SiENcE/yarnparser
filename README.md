# Yarn Parser & Interpreter
A Yarn parser written in Lua to convert Yarn Spinner dialogues into Lua structures. There is also a [interpreter](yarn_interpreter.lua) to demonstrate how to interpret the parsed node structures.

## Overview

This Lua module provides a parser for Yarn scripts, which are commonly used in interactive narrative games. The parser can handle various elements of Yarn syntax, including dialogue, choices, conditional statements, variable assignments, and commands.

The supplied interpreter is only an example of how the parsed structure can be interpreted. You must adapt it or implement your own interpreter that meets your requirements.

## Features

- Parse Yarn scripts into structured node objects
- Support for:
  - Dialogue lines
  - Choices (including **arbitrarily deep** nested choices)
  - Conditional choices (`-> Option <<if $cond>>`)
  - Conditional statements (`if` / `elseif` / `else` / `endif`)
  - Variable assignments, declarations, and interpolation
  - Commands: built-in (`jump`, `set`, `declare`) and **generic** (`<<fade_up 1.0>>`, `<<camera ...>>`, ...)
  - Comments (single-line `//` and multi-line `/* */`)
- Grouping of related content (e.g., choices and their responses)
- Robust against malformed input (non-string input, missing `---`/`===` delimiters, CRLF line endings, header tags)
- Sample interpreter with callbacks to run the dialogues, a general expression evaluator for conditions/assignments, and conditional-choice filtering.

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
        elseif item.type == "command" then
            print(indent .. "Command: " .. item.name .. (item.args and (" " .. item.args) or ""))
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

Content objects can be of various types, including "dialogue", "choice", "conditional", "set", "declare", "jump", "command", and "comment".

- A `choice` may also carry an optional `condition` field when written as `-> Option <<if $cond>>`.
- A `command` (any `<<...>>` that isn't `set`/`declare`/`jump`) has `name`, optional `args`, and the original `raw` text.
- `elseif` branches are represented as a nested `conditional` inside the parent's `else_block`, so an interpreter can evaluate the chain by simple recursion.

## Yarn Syntax

For a detailed description of the Yarn syntax, please refer to [Yarn syntax description](yarn_syntax.md).

## Interpreter

The included interpreter demonstrates how to run parsed Yarn scripts with callback support for various events.

### Basic Usage

```lua
local YarnParser = require("yarn_parser")
local YarnInterpreter = require("yarn_interpreter")

-- Parse your Yarn script
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
```

### Available Callbacks

- `on_dialogue(text)`: Called when dialogue text is encountered
- `on_choice(choices, path)`: Called when choices are presented. Must return the selected choice index. Only choices whose condition holds are passed in (conditional choices that fail are filtered out automatically)
- `on_variable(name, value)`: Called when a variable is set or declared
- `on_command(name, args, raw)`: Called for generic commands (e.g. `<<fade_up 1.0>>`)
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

## Testing

A self-contained, assertion-based test suite is provided in [`yarn_tests.lua`](yarn_tests.lua).
Run it from the project root:

```sh
lua yarn_tests.lua
```

It exits with a non-zero status if any test fails (so it can be used in CI) and
covers parsing (deep nesting, conditionals, conditional choices, commands,
multi-line comments), robustness against malformed input, and the interpreter
(expression evaluation, assignments, choice filtering, jumps).

The original demonstration scripts [`yarn_parser_test.lua`](yarn_parser_test.lua)
and [`yarn_interpreter_test.lua`](yarn_interpreter_test.lua) are still available
as runnable, human-readable examples.

## Limitations

- **Multi-line comments** (`/* */`) are not part of the official Yarn Spinner
  syntax; they are a convenience extension of this parser.
- The expression evaluator in the *sample* interpreter compiles conditions to a
  sandboxed Lua chunk. It covers the common Yarn operators (comparison, boolean
  logic, arithmetic, string/boolean literals) but is not a complete
  reimplementation of Yarn Spinner's expression language (e.g. built-in
  functions like `visited()` or `dice()` are not provided). Implement your own
  interpreter for the full feature set.
- The parser focuses on structure. Inline markup/attributes (e.g.
  `[b]...[/b]`, `#line:tags`) are preserved verbatim inside dialogue text rather
  than parsed into separate fields.

> Earlier versions could not handle deeply nested structures or malformed input
> reliably. The parser now uses an indentation-aware recursive descent that
> supports arbitrarily deep nesting (choices within conditionals within
> choices, etc.) and tolerates missing delimiters, non-string input and CRLF
> line endings.

## Author

Florian Fischer ( https://github.com/SiENcE )

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
