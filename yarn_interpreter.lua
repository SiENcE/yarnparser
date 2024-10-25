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

local YarnInterpreter = {}
YarnInterpreter.__index = YarnInterpreter

-- Constructor
function YarnInterpreter.new(nodes)
    local self = setmetatable({}, YarnInterpreter)
    self.nodes = nodes
    self.variables = {}
    self.current_node = nodes[1]
    self.on_dialogue = nil      -- Callback for dialogue events
    self.on_choice = nil        -- Callback for choice events
    self.on_variable = nil      -- Callback for variable changes
    self.on_node_enter = nil    -- Callback for node entry
    self.on_node_exit = nil     -- Callback for node exit
    return self
end

-- Set callbacks for various events
function YarnInterpreter:set_callbacks(callbacks)
    self.on_dialogue = callbacks.on_dialogue
    self.on_choice = callbacks.on_choice
    self.on_variable = callbacks.on_variable
    self.on_node_enter = callbacks.on_node_enter
    self.on_node_exit = callbacks.on_node_exit
end

-- Variable management methods
function YarnInterpreter:get_variable(name)
    return self.variables[name]
end

function YarnInterpreter:set_variable(name, value)
    self.variables[name] = value
    if self.on_variable then
        self.on_variable(name, value)
    end
end

-- Helper function to interpolate variables in text
function YarnInterpreter:interpolate_variables(text)
    return text:gsub("{%$(%w+)}", function(var)
        return tostring(self.variables[var] or "undefined")
    end)
end

-- Helper function to evaluate conditional expressions
function YarnInterpreter:evaluate_condition(condition)
    local var, op, value = condition:match("$(%w+)%s*([<>=]+)%s*(%d+)")
    if var and op and value then
        local num_value = tonumber(value)
        if self.variables[var] == nil then
            self:emit_warning("Variable " .. var .. " not initialized")
            return false
        end
        
        if op == "==" then
            return self.variables[var] == num_value
        elseif op == ">=" then
            return self.variables[var] >= num_value
        elseif op == "<=" then
            return self.variables[var] <= num_value
        elseif op == ">" then
            return self.variables[var] > num_value
        elseif op == "<" then
            return self.variables[var] < num_value
        elseif op == "!=" then
            return self.variables[var] ~= num_value
        end
    end
    
    self:emit_warning("Unable to parse condition: " .. condition)
    return false
end

-- Warning emission
function YarnInterpreter:emit_warning(message)
    print("Warning: " .. message)
end

-- Process a nested choice and its responses
function YarnInterpreter:process_nested_choice(choice, choice_path)
    if not choice.response then return false end
    
    for _, response_item in ipairs(choice.response) do
        if response_item.type == "choice" then
            -- Find a nested choices
            local jumped = self:handle_nested_choices({response_item}, choice_path .. " > " .. response_item.text)
            if jumped then return true end
        else
            local jumped = self:process_item(response_item)
            if jumped then return true end
        end
    end
    return false
end

-- Handle nested choices with path tracking
function YarnInterpreter:handle_nested_choices(choices, parent_path)
    local choice_texts = {}
    for idx, choice in ipairs(choices) do
        choice_texts[idx] = self:interpolate_variables(choice.text)
    end

    local selected_index
    if self.on_choice then
        selected_index = self.on_choice(choice_texts, parent_path)
    else
        print("\nChoices" .. (parent_path and " (" .. parent_path .. ")" or "") .. ":")
        for idx, text in ipairs(choice_texts) do
            print(idx .. ". " .. text)
        end
        io.write("Enter your choice (1-" .. #choices .. "): ")
        print("")
        selected_index = tonumber(io.read())
    end
    
    if selected_index and selected_index > 0 and selected_index <= #choices then
        local chosen = choices[selected_index]
        if chosen.response and #chosen.response > 0 then
            local has_nested_choices = false
            
            -- First handle all non-choice responses
            for _, response_item in ipairs(chosen.response) do
                if response_item.type ~= "choice" then
                    local jumped = self:process_item(response_item)
                    if jumped then return true end
                else
                    has_nested_choices = true
                end
            end
            
            -- Then handle any nested choices
            if has_nested_choices then
                local nested_choices = {}
                for _, response_item in ipairs(chosen.response) do
                    if response_item.type == "choice" then
                        table.insert(nested_choices, response_item)
                    end
                end
                
                if #nested_choices > 0 then
                    return self:handle_nested_choices(
                        nested_choices, 
                        (parent_path and (parent_path .. " > ") or "") .. chosen.text
                    )
                end
            end
        end
    else
        self:emit_warning("Invalid choice selection")
    end
    return false
end

-- Jump to a specific node
function YarnInterpreter:jump_to_node(target)
    for _, node in ipairs(self.nodes) do
        if node.title == target then
            if self.on_node_exit then
                self.on_node_exit(self.current_node.title)
            end
            self.current_node = node
            --if self.on_node_enter then
            --    self.on_node_enter(node.title)
            --end
            return true
        end
    end
    self:emit_warning("Jump target not found: " .. target)
    return false
end

-- Process a single content item
function YarnInterpreter:process_item(item)
    if item.type == "dialogue" then
        local interpolated_text = self:interpolate_variables(item.text)
        if self.on_dialogue then
            self.on_dialogue(interpolated_text)
        else
            print(interpolated_text)
        end
        return false
    elseif item.type == "choice" then
        -- Individual choices are handled by process_content
        -- This should never be called directly
        self:emit_warning("Choice processed individually - this should not happen")
        return false
    elseif item.type == "set" then
        self:set_variable(item.variable, tonumber(item.value) or item.value)
        return false
    elseif item.type == "declare" then
        self:set_variable(item.variable, tonumber(item.value) or item.value)
        return false
    elseif item.type == "conditional" then
        if self:evaluate_condition(item.condition) then
            return self:process_content(item.if_block)
        elseif item.else_block then
            return self:process_content(item.else_block)
        end
        return false
    elseif item.type == "jump" then
        return self:jump_to_node(item.target)
    end
    return false
end

-- Collect consecutive choices
function YarnInterpreter:collect_choices(content, start_index)
    local choices = {content[start_index]}
    local i = start_index + 1
    while i <= #content do
        if content[i].type == "choice" then
            table.insert(choices, content[i])
        else
            break
        end
        i = i + 1
    end
    return choices, i - start_index
end

-- Process content array
function YarnInterpreter:process_content(content)
    local i = 1
    while i <= #content do
        local item = content[i]
        
        if item.type == "choice" then
            local choices, choice_count = self:collect_choices(content, i)
            local jumped = self:handle_nested_choices(choices)
            if jumped then
                return true
            end
            i = i + choice_count
        else
            local jumped = self:process_item(item)
            if jumped then
                return true
            end
            i = i + 1
        end
    end
    return false
end

-- Main interpretation method
function YarnInterpreter:run()
    while self.current_node do
        if self.on_node_enter then
            self.on_node_enter(self.current_node.title)
        end
        
        local jumped = self:process_content(self.current_node.content)
        
        if not jumped then
            if self.on_node_exit then
                self.on_node_exit(self.current_node.title)
            end
            self.current_node = nil
        end
    end
end

return YarnInterpreter