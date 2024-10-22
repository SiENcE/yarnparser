--[[
MIT License

Copyright (c) 2024 Florian Fischer ( https://github.com/SiENcE )

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
]]--

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
