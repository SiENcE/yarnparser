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

local YarnParser = {}

-- Helper function to split a string into lines
local function split_lines(str)
    local lines = {}
    for line in str:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

-- Helper function to get indentation level
local function get_indent_level(line)
    local indent = line:match("^(%s*)")
    return #indent
end

-- Parse a line of content
local function parse_line(line)
    local indent_level = get_indent_level(line)
    
    if line:match("^%s*%-%>") then
        -- Choice
        local choice_text = line:match("^%s*%-%>%s*(.+)")
        return {
            type = "choice",
            text = choice_text,
            indent = indent_level,
            response = {}
        }
    elseif line:match("^%s*<<%s*set%s") then
        -- Variable assignment
        local var, value = line:match("<<set%s*$(.-)%s*to%s*(.-)%s*>>")
        return {type = "set", variable = var, value = value, indent = indent_level}
    elseif line:match("^%s*<<%s*if%s") then
        -- Start of conditional block
        local condition = line:match("<<if%s*(.-)%s*>>")
        return {type = "conditional", condition = condition, if_block = {}, else_block = {}, indent = indent_level}
    elseif line:match("^%s*<<%s*jump%s") then
        -- Jump to another node
        local jump_to = line:match("<<jump%s*(.-)%s*>>")
        return {type = "jump", target = jump_to, indent = indent_level}
    elseif line:match("^%s*<<%s*declare%s") then
        -- Variable declaration
        local var, value = line:match("<<declare%s*$(.-)%s*=%s*(.-)%s*>>")
        return {type = "declare", variable = var, value = value, indent = indent_level}
    elseif line:match("^%s*//") then
        -- Single-line comment
        return {type = "comment", text = line:match("^%s*//(.*)$"), indent = indent_level}
    else
        -- Regular dialogue
        return {type = "dialogue", text = line:gsub("^%s+", ""), indent = indent_level}
    end
end

-- Group choices with their indented content
local function group_choices(content)
    local grouped_content = {}
    local current_choice = nil
    local base_indent = 0

    for i, item in ipairs(content) do
        if item.type == "choice" then
            if current_choice then
                table.insert(grouped_content, current_choice)
            end
            current_choice = item
            base_indent = item.indent
        else
            -- If we have a current choice and this line is indented more than the choice
            if current_choice and item.indent > base_indent then
                table.insert(current_choice.response, item)
            else
                -- If we have a current choice, add it before adding the non-indented line
                if current_choice then
                    table.insert(grouped_content, current_choice)
                    current_choice = nil
                end
                table.insert(grouped_content, item)
            end
        end
    end

    -- Add the last choice if there is one
    if current_choice then
        table.insert(grouped_content, current_choice)
    end

    return grouped_content
end

-- Parse a Yarn script into nodes
function YarnParser:parse(script)
    local nodes = {}
    local current_node = nil
    local lines = split_lines(script)
    local in_multiline_comment = false
    local conditional_stack = {}

    for _, line in ipairs(lines) do
        if line:match("^title:") then
            if current_node then
                current_node.content = group_choices(current_node.content)
                table.insert(nodes, current_node)
            end
            current_node = {
                title = line:match("^title:%s*(.+)"),
                content = {}
            }
        elseif line == "===" then
            if current_node then
                current_node.content = group_choices(current_node.content)
                table.insert(nodes, current_node)
                current_node = nil
            end
        elseif current_node and line ~= "---" then
            if line:match("^%s*/%*") then
                in_multiline_comment = true
                table.insert(current_node.content, {type = "comment", text = line:match("^%s*/%*(.*)$")})
            elseif line:match("%*/%s*$") then
                in_multiline_comment = false
                table.insert(current_node.content, {type = "comment", text = line:match("^(.*)%*/%s*$")})
            elseif in_multiline_comment then
                table.insert(current_node.content, {type = "comment", text = line})
            else
                local parsed = parse_line(line)
                
                if parsed.type == "conditional" then
                    table.insert(conditional_stack, parsed)
                    table.insert(current_node.content, parsed)
                elseif line:match("^%s*<<%s*else%s*>>") then
                    if #conditional_stack > 0 then
                        conditional_stack[#conditional_stack].current_target = conditional_stack[#conditional_stack].else_block
                    end
                elseif line:match("^%s*<<%s*endif%s*>>") then
                    if #conditional_stack > 0 then
                        table.remove(conditional_stack).current_target = nil
                    end
                else
                    if #conditional_stack > 0 then
                        local current_conditional = conditional_stack[#conditional_stack]
                        local target_block = current_conditional.current_target or current_conditional.if_block
                        table.insert(target_block, parsed)
                    else
                        table.insert(current_node.content, parsed)
                    end
                end
            end
        end
    end

    if current_node then
        current_node.content = group_choices(current_node.content)
        table.insert(nodes, current_node)
    end

    return nodes
end

-- Function to find the dialogue immediately preceding a choice group
function YarnParser:find_preceding_dialogue(node, choice_group_index)
    for i = choice_group_index - 1, 1, -1 do
        if node.content and node.content[i].type == "dialogue" then
            return node.content[i]
        end
    end
    return nil
end

return YarnParser
