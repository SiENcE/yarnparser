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
// This is a single-line comment
Player: Hello, adventurer! Welcome to our town.
NPC: Greetings, traveler! How can I assist you today?

/* This is a
multi-line comment */

<<declare $gold = 0>>
<<declare $has_sword = false>>

<<if $gold >= 10>>
    NPC: I see you have some gold with you. Interested in making a purchase?
    -> Yes, show me what you have
        <<jump Shop>>
    -> No, just browsing
        NPC: Alright, let me know if you need anything.
<<else>>
    NPC: You seem a bit short on gold. Perhaps you'd be interested in some work?
    -> Sure, what do you have?
        <<jump Quest>>
    -> No thanks, I'm good
        NPC: Very well. Safe travels!
<<endif>>

Player: Before I go, can you tell me about this place?
NPC: Of course! Our town is known for its...
-> Rich history
    NPC: Indeed! Our town dates back to the ancient times when...
-> Skilled craftsmen
    NPC: You're right! Our artisans are renowned throughout the land for...
-> Delicious cuisine
    NPC: Ah, a person of taste! You must try our famous...

NPC: Is there anything else you'd like to know?
-> Ask about nearby dungeons
    <<if $has_sword>>
        NPC: With that sword of yours, you might be ready for the Cave of Shadows...
    <<else>>
        NPC: Without a weapon, I wouldn't recommend any dungeons. Perhaps visit our blacksmith first?
    <<endif>>
-> Inquire about local legends
    NPC: Well, there's an old tale about a dragon that lives in the mountains...
-> No, that's all
    NPC: Very well. Enjoy your stay in our town!

<<jump Farewell>>

===
title: Shop
---
Shopkeeper: Welcome to my humble shop! What would you like to buy?
-> Sword (10 gold)
    <<if $gold >= 10>>
        <<set $gold to $gold - 10>>
        <<set $has_sword to true>>
        Shopkeeper: An excellent choice! This sword will serve you well.
    <<else>>
        Shopkeeper: I'm sorry, but you don't have enough gold for that.
    <<endif>>
-> Potion (5 gold)
    <<if $gold >= 5>>
        <<set $gold to $gold - 5>>
        Shopkeeper: Here's your potion. Use it wisely!
    <<else>>
        Shopkeeper: I'm afraid you can't afford that right now.
    <<endif>>
-> Nothing, thanks
    Shopkeeper: Feel free to browse. Let me know if you need anything.

<<jump Farewell>>

===
title: Quest
---
Questgiver: We've been having trouble with wolves attacking our livestock.
Questgiver: If you can clear out their den, we'll reward you handsomely.
-> I'll do it!
    Questgiver: Excellent! The den is located to the north of town.
    <<set $gold to $gold + 20>>
    Questgiver: Here's an advance of 20 gold. Good luck!
-> Sounds too dangerous
    Questgiver: I understand. It's not a task for the faint of heart.

<<jump Farewell>>

===
title: Farewell
---
NPC: Farewell, traveler! May your journeys be safe and prosperous.
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
