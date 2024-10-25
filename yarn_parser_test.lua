local YarnParser = require("yarn_parser")

local function spaces(num_spaces)
    return string.rep(" ", num_spaces)
end

-- Function to print the content of a node
local function print_content(content, indent)
    indent = indent or ""
    for _, item in ipairs(content) do
        if item.type == "dialogue" then
            print(spaces(item.indent) .. item.text)
        elseif item.type == "choice" then
            print(spaces(item.indent) .. "-> " .. item.text)
            print_content(item.response, indent .. "  ")
        elseif item.type == "set" then
            print(spaces(item.indent) .. "Set: " .. item.variable .. " to " .. item.value)
        elseif item.type == "conditional" then
            print(spaces(item.indent) .. "If: " .. item.condition)
            print(spaces(item.indent) .. "Then:")
            print_content(item.if_block, indent .. "  ")
            if #item.else_block > 0 then
                print(spaces(item.indent) .. "Else:")
                print_content(item.else_block, indent .. "  ")
            end
        elseif item.type == "jump" then
            print(spaces(item.indent) .. "Jump to: " .. item.target)
        elseif item.type == "declare" then
            print(spaces(item.indent) .. "Declare: " .. item.variable .. " = " .. item.value)
        elseif item.type == "comment" then
            print(spaces(item.indent) .. "Comment: " .. item.text)
        else
            print(spaces(item.indent) .. "Unknown type: " .. tostring(item.type))
        end
    end
end

-- Read the script from file
local file = io.open("tests/gold_or_health.yarn", "r")
if not file then
    error("Could not open xxx.yarn")
end
local script = file:read("*all")
file:close()

local parsed_nodes = YarnParser:parse(script)

-- Print the parsed structure
if parsed_nodes then
    for i, node in ipairs(parsed_nodes) do
        print("Node: " .. node.title)
        print_content(node.content, "  ")
        print("") -- Empty line between nodes for readability
    end
end
