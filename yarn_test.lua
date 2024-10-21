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
<<set $hasClueA to false>>
<<set $hasClueB to false>>
<<set $hasClueC to false>>
<<set $spokenToLeftGrave to false>>
<<set $spokenToCenterGrave to false>>
<<set $spokenToRightGrave to false>>
Ghost: Welcome to the graveyard! Unfortunately, you're just in time for an unsolved mystery...
Ghost: You'll have to speak to these three to figure out what happened!
===
title: Ghost
---
Ghost: Are you ready to tell me what happened?
-> Yes
    Ghost: Well, what do you know?
    -> I have no clues.
    -> I have clue A. <<if $hasClueA>>
    -> I have clues A and B. <<if $hasClueB>>
    -> I have clues A, B and C. <<if $hasClueC>>
        <<jump Ending>>
    Ghost: That doesn't sound right...
-> No
Ghost: Go on and speak to those three!
===
title: LeftGraveLouise
---
<<if not $spokenToLeftGrave>>
    Louise: What do you want to know?
    <<set $spokenToLeftGrave to true>>
<<else>>
    Louise: Back again? What do you want to know now?
<<endif>>
-> Something that will get me no clues?
-> Something that will get me Clue A? <<if not $hasClueA>>
    <<set $hasClueA to true>>
-> Something relating to existing Clue A? <<if $hasClueA>>
-> Something relating to existing Clue B? <<if $hasClueB>>
-> Something relating to existing Clue C? <<if $hasClueC>>
Louise: ~additional dialogue~
Louise: Ok, bye!
===
title: CenterGraveCarol
---
<<if not $spokenToCenterGrave>>
    Carol: What do you want to know?
    <<set $spokenToCenterGrave to true>>
<<else>>
    Carol: Back again? What do you want to know now?
<<endif>>
-> Something that will get me no clues?
-> Something that will get me Clue B? <<if $hasClueA and not $hasClueB>>
    <<set $hasClueB to true>>
-> Something relating to existing Clue A? <<if $hasClueA>>
-> Something relating to existing Clue B? <<if $hasClueB>>
-> Something relating to existing Clue C? <<if $hasClueC>>
Carol: ~additional dialogue~
Carol: Ok, bye!
===
title: RightGraveRuby
---
<<if not $spokenToRightGrave>>
    Ruby: What do you want to know?
    <<set $spokenToRightGrave to true>>
<<else>>
    Ruby: Back again? What do you want to know now?
<<endif>>
-> Something that will get me no clues?
-> Something that will get me Clue C? <<if $hasClueB and not $hasClueC>>
    <<set $hasClueC to true>>
-> Something relating to existing Clue A? <<if $hasClueA>>
-> Something relating to existing Clue B? <<if $hasClueB>>
-> Something relating to existing Clue C? <<if $hasClueC>>
Ruby: ~additional dialogue~
Ruby: Ok, bye!
===
title: Ending
---
<<disable Ghost>>
<<disable LeftGrave>>
<<disable CenterGrave>>
<<disable RightGrave>>
Ghost: You solved it!
===
]]

local parsed_nodes = YarnParser:parse(script)

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

-- Print the parsed structure
if parsed_nodes then
    for i, node in ipairs(parsed_nodes) do
        print("Node: " .. node.title)
        print_content(node.content, "  ")
        print("") -- Empty line between nodes for readability
    end
end
