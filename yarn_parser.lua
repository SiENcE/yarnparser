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

-- Remove /* ... */ multi-line comments while preserving the newline structure
-- (so that indentation and line layout of the surrounding code is unaffected).
local function strip_multiline_comments(str)
    return (str:gsub("/%*.-%*/", function(block)
        return (block:gsub("[^\n]", ""))
    end))
end

-- Split a string into lines, preserving blank lines and normalising line
-- endings. Keeping blank lines means indentation-based parsing stays in sync
-- with the original layout.
local function split_lines(str)
    str = str:gsub("\r\n", "\n"):gsub("\r", "\n")
    local lines = {}
    for line in (str .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end
    return lines
end

-- Get indentation level (number of leading whitespace characters)
local function get_indent_level(line)
    return #(line:match("^(%s*)"))
end

local function is_blank(line)
    return line:match("^%s*$") ~= nil
end

-- Trim leading/trailing whitespace
local function trim(s)
    return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

-- Parse a single, non-structural line (everything except block conditionals,
-- which are handled by the recursive block parser). Returns a content item.
local function parse_line(line)
    local indent_level = get_indent_level(line)
    local trimmed = trim(line)

    if trimmed:match("^%-%>") then
        -- Choice. May carry a trailing inline condition: "-> Text <<if $cond>>"
        local body = trimmed:match("^%-%>%s*(.*)") or ""
        local item = {type = "choice", indent = indent_level, response = {}}
        local text, cond = body:match("^(.-)%s*<<%s*if%s+(.-)%s*>>%s*$")
        if text and cond then
            item.text = text
            item.condition = cond
        else
            item.text = body
        end
        return item
    elseif trimmed:match("^<<") then
        -- Some command: set / declare / jump / generic
        local inner = trimmed:match("^<<%s*(.-)%s*>>") or trimmed:match("^<<%s*(.+)$") or ""
        local keyword = inner:match("^(%S+)")
        if keyword == "set" then
            local var, value = inner:match("^set%s+%$([%w_]+)%s+to%s+(.+)$")
            return {type = "set", variable = var, value = value and trim(value), indent = indent_level}
        elseif keyword == "declare" then
            local var, value = inner:match("^declare%s+%$([%w_]+)%s*=%s*(.+)$")
            return {type = "declare", variable = var, value = value and trim(value), indent = indent_level}
        elseif keyword == "jump" then
            local target = inner:match("^jump%s+(%S+)")
            return {type = "jump", target = target, indent = indent_level}
        else
            -- Generic command, e.g. <<fade_up 1.0>>
            local args = inner:match("^%S+%s+(.+)$")
            return {type = "command", name = keyword, args = args, raw = trimmed, indent = indent_level}
        end
    elseif trimmed:match("^//") then
        return {type = "comment", text = trimmed:match("^//(.*)$"), indent = indent_level}
    else
        return {type = "dialogue", text = trimmed, indent = indent_level}
    end
end

-- Forward declaration
local parse_block

-- Parse a conditional (if / elseif* / else? / endif) starting at lines[i],
-- where lines[i] is the "<<if ...>>" line. "elseif" branches are represented
-- as a nested conditional inside the parent's else_block, which lets the
-- interpreter evaluate the chain by simple recursion.
-- Returns the conditional node and the index just past the matching "<<endif>>".
local function parse_conditional(lines, i)
    local indent = get_indent_level(lines[i])
    local root = {
        type = "conditional",
        condition = lines[i]:match("<<%s*if%s+(.-)%s*>>"),
        indent = indent,
        if_block = {},
        else_block = {}
    }

    -- Conditional bodies are delimited by markers rather than by indentation,
    -- so we allow content at the same indent as the "<<if>>" itself.
    local body, ni = parse_block(lines, i + 1, indent)
    root.if_block = body
    i = ni

    local current = root
    while lines[i] and lines[i]:match("^%s*<<%s*elseif%s") do
        local branch_indent = get_indent_level(lines[i])
        local branch = {
            type = "conditional",
            condition = lines[i]:match("<<%s*elseif%s+(.-)%s*>>"),
            indent = branch_indent,
            if_block = {},
            else_block = {}
        }
        local body, n = parse_block(lines, i + 1, branch_indent)
        branch.if_block = body
        i = n
        current.else_block = {branch}
        current = branch
    end

    if lines[i] and lines[i]:match("^%s*<<%s*else%s*>>") then
        local body, n = parse_block(lines, i + 1, indent)
        current.else_block = body
        i = n
    end

    if lines[i] and lines[i]:match("^%s*<<%s*endif%s*>>") then
        i = i + 1
    end

    return root, i
end

-- Recursively parse a block of content. `min_indent` is the smallest
-- indentation that still belongs to this block; a line indented less than that
-- (or a structural marker) terminates the block and is left for the caller.
-- Returns the content array and the index of the first unconsumed line.
parse_block = function(lines, i, min_indent)
    local content = {}

    while i <= #lines do
        local line = lines[i]

        if is_blank(line) then
            i = i + 1
        elseif line:match("^title:") or line:match("^%s*===")
            or line:match("^%s*<<%s*endif%s*>>")
            or line:match("^%s*<<%s*else%s*>>")
            or line:match("^%s*<<%s*elseif%s") then
            -- Belongs to the caller (node boundary or conditional marker)
            break
        elseif line:match("^%s*%-%-%-%s*$") then
            -- Stray content separator inside a body; ignore.
            i = i + 1
        elseif get_indent_level(line) < min_indent then
            break
        elseif line:match("^%s*<<%s*if%s") then
            local node, ni = parse_conditional(lines, i)
            content[#content + 1] = node
            i = ni
        elseif line:match("^%s*%-%>") then
            local choice = parse_line(line)
            -- A choice's response is everything indented deeper than the choice.
            local resp, ni = parse_block(lines, i + 1, choice.indent + 1)
            choice.response = resp
            content[#content + 1] = choice
            i = ni
        else
            content[#content + 1] = parse_line(line)
            i = i + 1
        end
    end

    return content, i
end

-- Main parse function. Robust to malformed input: non-string input yields an
-- empty result, and missing "---"/"===" delimiters are tolerated.
function YarnParser:parse(script)
    if type(script) ~= "string" then
        return {}
    end

    local lines = split_lines(strip_multiline_comments(script))
    local nodes = {}
    local i = 1

    while i <= #lines do
        local title = lines[i]:match("^title:%s*(.+)")
        if title then
            local node = {title = trim(title), content = {}}
            i = i + 1

            -- Skip any header lines (tags, position, ...) until the "---"
            -- content separator (or until the node/file ends).
            while i <= #lines
                and not lines[i]:match("^%s*%-%-%-%s*$")
                and not lines[i]:match("^%s*===")
                and not lines[i]:match("^title:") do
                i = i + 1
            end
            if i <= #lines and lines[i]:match("^%s*%-%-%-%s*$") then
                i = i + 1
            end

            local content, ni = parse_block(lines, i, 0)
            node.content = content
            i = ni

            if i <= #lines and lines[i]:match("^%s*===") then
                i = i + 1
            end

            nodes[#nodes + 1] = node
        else
            i = i + 1
        end
    end

    return nodes
end

return YarnParser
