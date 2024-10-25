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

-- Split a string into lines
local function split_lines(str)
    local lines = {}
    for line in str:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    return lines
end

-- Get indentation level
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

-- Recursive function to process content blocks that can contain nested choices and conditionals
local function process_content_block(lines, start_index, base_indent)
    local content = {}
    local current_choice = nil
    local i = start_index
    
    while i <= #lines do
        local line = lines[i]
        local indent_level = get_indent_level(line)
        
        -- End conditions for recursive processing
        if indent_level <= base_indent then
            if line:match("^%s*<<%s*endif%s*>>") or 
               line:match("^%s*<<%s*else%s*>>") or
               line:match("^%s*===") then
                break
            end
        end
        
        -- Parse the current line
        if line:match("^%s*<<%s*if%s") then
            local condition = line:match("<<if%s*(.-)%s*>>")
            local conditional = {
                type = "conditional",
                condition = condition,
                indent = indent_level,
                if_block = {},
                else_block = {}
            }
            
            -- Process if block
            local if_content, new_i = process_content_block(lines, i + 1, indent_level)
            conditional.if_block = if_content
            i = new_i
            
            -- Check for else block
            if lines[i] and lines[i]:match("^%s*<<%s*else%s*>>") then
                local else_content, new_i = process_content_block(lines, i + 1, indent_level)
                conditional.else_block = else_content
                i = new_i
            end
            
            -- Add conditional to current context
            if current_choice and indent_level > base_indent then
                table.insert(current_choice.response, conditional)
            else
                if current_choice then
                    table.insert(content, current_choice)
                    current_choice = nil
                end
                table.insert(content, conditional)
            end
        elseif line:match("^%s*%-%>") then
            -- Handle nested choices
            if current_choice and indent_level > current_choice.indent then
                -- This is a nested choice
                local nested_choice = {
                    type = "choice",
                    text = line:match("^%s*%-%>%s*(.+)"),
                    indent = indent_level,
                    response = {}
                }
                
                -- Process the nested choice's content
                local j = i + 1
                while j <= #lines do
                    local next_line = lines[j]
                    local next_indent = get_indent_level(next_line)
                    
                    if next_indent <= indent_level then
                        break
                    end
                    
                    if next_line:match("^%s*%-%>") then
                        -- Found another choice at the same level
                        break
                    end
                    
                    local parsed = parse_line(next_line)
                    table.insert(nested_choice.response, parsed)
                    j = j + 1
                end
                
                table.insert(current_choice.response, nested_choice)
                i = j - 1
            else
                -- Start new top-level choice
                if current_choice then
                    table.insert(content, current_choice)
                end
                current_choice = {
                    type = "choice",
                    text = line:match("^%s*%-%>%s*(.+)"),
                    indent = indent_level,
                    response = {}
                }
            end
        else
            local parsed = parse_line(line)
            if current_choice and indent_level > current_choice.indent then
                table.insert(current_choice.response, parsed)
            else
                if current_choice then
                    table.insert(content, current_choice)
                    current_choice = nil
                end
                table.insert(content, parsed)
            end
        end
        
        i = i + 1
    end
    
    -- Add final choice if exists
    if current_choice then
        table.insert(content, current_choice)
    end
    
    return content, i
end

-- Modified main parse function
function YarnParser:parse(script)
    local nodes = {}
    local current_node = nil
    local lines = split_lines(script)
    
    local skiplines=0
    for i, line in ipairs(lines) do
        if i < skiplines then goto continue end

        if line:match("^title:") then
            if current_node then
                table.insert(nodes, current_node)
            end
            current_node = {
                title = line:match("^title:%s*(.+)"),
                content = {}
            }
        elseif line == "===" then
            if current_node then
                table.insert(nodes, current_node)
                current_node = nil
            end
        elseif current_node and line ~= "---" then
            if not current_node.content then
                current_node.content = {}
            end
			-- possibly wrong?
--            current_node.content = process_content_block(lines, i, 0)
            -- Skip to next node
--            while skiplines <= #lines and lines[skiplines] ~= "===" do
--                skiplines = skiplines + 1
--            end

			-- alternative
            local block_content, new_i = process_content_block(lines, i, 0)
            current_node.content = block_content
            skiplines = new_i
        end

        ::continue::
    end
    
    if current_node then
        table.insert(nodes, current_node)
    end
    
    return nodes
end

return YarnParser
