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

-- Parse a line of content
local function parse_line(line)
    if line:match("^%s*%-%>") then
        -- Choice
        local indent = #(line:match("^(%s*)") or "")
        local choice_text = line:match("^%s*%-%>%s*(.+)")
        return {type = "choice", text = choice_text, indent = indent, response = {}}
    elseif line:match("^%s*<<%s*set%s") then
        -- Variable assignment
        local var, value = line:match("<<set%s*$(.-)%s*to%s*(.-)%s*>>")
        return {type = "set", variable = var, value = value}
    elseif line:match("^%s*<<%s*if%s") then
        -- Start of conditional block
        local condition = line:match("<<if%s*(.-)%s*>>")
        return {type = "conditional", condition = condition, if_block = {}, else_block = {}}
    elseif line:match("^%s*<<%s*jump%s") then
        -- Jump to another node
        local jump_to = line:match("<<jump%s*(.-)%s*>>")
        return {type = "jump", target = jump_to}
    elseif line:match("^%s*<<%s*declare%s") then
        -- Variable declaration
        local var, value = line:match("<<declare%s*$(.-)%s*=%s*(.-)%s*>>")
        return {type = "declare", variable = var, value = value}
    elseif line:match("^%s*//") then
        -- Single-line comment
        return {type = "comment", text = line:match("^%s*//(.*)$")}
    else
        -- Regular dialogue
        return {type = "dialogue", text = line}
    end
end

-- Group choices, including nested choices
local function group_choices(content)
    local grouped_content = {}
    local choice_stack = {}
    local current_indent = 0

    for _, item in ipairs(content) do
        if item.type == "choice" then
            while #choice_stack > 0 and item.indent <= choice_stack[#choice_stack].indent do
                table.remove(choice_stack)
            end

            if #choice_stack == 0 then
                table.insert(grouped_content, item)
                table.insert(choice_stack, item)
            else
                table.insert(choice_stack[#choice_stack].response, item)
                table.insert(choice_stack, item)
            end
        else
            if #choice_stack > 0 then
                table.insert(choice_stack[#choice_stack].response, item)
            else
                table.insert(grouped_content, item)
            end
        end
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
                        conditional_stack[#conditional_stack].current_block = conditional_stack[#conditional_stack].else_block
                    end
                elseif line:match("^%s*<<%s*endif%s*>>") then
                    if #conditional_stack > 0 then
                        local completed_conditional = table.remove(conditional_stack)
                        completed_conditional.if_block = group_choices(completed_conditional.if_block)
                        completed_conditional.else_block = group_choices(completed_conditional.else_block)
                    end
                else
                    if #conditional_stack > 0 then
                        table.insert(conditional_stack[#conditional_stack].current_block or conditional_stack[#conditional_stack].if_block, parsed)
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
