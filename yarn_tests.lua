--[[
Assertion-based test suite for the Yarn parser and interpreter.

Run from the project root with:
    lua yarn_tests.lua

Exits with a non-zero status if any test fails, so it can be wired into CI.
]]--

-- Make sure the modules next to this file are found regardless of CWD.
local here = (arg and arg[0] and arg[0]:match("^(.*[/\\])")) or "./"
package.path = here .. "?.lua;" .. package.path

local YarnParser = require("yarn_parser")
local YarnInterpreter = require("yarn_interpreter")

------------------------------------------------------------------------
-- Tiny test framework
------------------------------------------------------------------------
local passed, failed = 0, 0
local failures = {}
local current = "?"

local function check(ok, msg)
    if ok then
        passed = passed + 1
    else
        failed = failed + 1
        local detail = "[" .. current .. "] " .. (msg or "assertion failed")
        failures[#failures + 1] = detail
        print("  FAIL: " .. detail)
    end
end

local function eq(a, b, msg)
    check(a == b, (msg or "") .. " (expected " .. tostring(b) .. ", got " .. tostring(a) .. ")")
end

local function truthy(v, msg) check(v and true or false, msg) end
local function is_nil(v, msg) check(v == nil, (msg or "") .. " (got " .. tostring(v) .. ")") end

local function test(name, fn)
    current = name
    local ok, err = pcall(fn)
    if not ok then
        failed = failed + 1
        failures[#failures + 1] = "[" .. name .. "] CRASHED: " .. tostring(err)
        print("  CRASH: [" .. name .. "] " .. tostring(err))
    end
end

local function read_file(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local s = f:read("*a")
    f:close()
    return s
end

-- Build an interpreter that auto-plays choices from `plan` (a list of indices
-- into the *available* choices) and records all observed events.
local function make_recorder(nodes, plan)
    local log = {dialogue = {}, choices = {}, commands = {}, variables = {}, enter = {}, exit = {}}
    local interp = YarnInterpreter.new(nodes)
    local ci = 0
    interp:set_callbacks({
        on_dialogue = function(t) log.dialogue[#log.dialogue + 1] = t end,
        on_choice = function(choices)
            ci = ci + 1
            log.choices[#log.choices + 1] = choices
            return (plan and plan[ci]) or 1
        end,
        on_command = function(n, a) log.commands[#log.commands + 1] = {name = n, args = a} end,
        on_variable = function(n, v) log.variables[n] = v end,
        on_node_enter = function(t) log.enter[#log.enter + 1] = t end,
        on_node_exit = function(t) log.exit[#log.exit + 1] = t end,
    })
    return interp, log
end

------------------------------------------------------------------------
-- Parser tests
------------------------------------------------------------------------

test("parse: basic node structure", function()
    local nodes = YarnParser:parse("title: Start\n---\nHello world\n===\n")
    eq(#nodes, 1, "one node")
    eq(nodes[1].title, "Start", "title")
    eq(#nodes[1].content, 1, "one content item")
    eq(nodes[1].content[1].type, "dialogue", "dialogue type")
    eq(nodes[1].content[1].text, "Hello world", "dialogue text")
    eq(nodes[1].content[1].indent, 0, "indent")
end)

test("parse: multiple nodes", function()
    local nodes = YarnParser:parse("title: A\n---\nHi\n===\ntitle: B\n---\nBye\n===\n")
    eq(#nodes, 2, "two nodes")
    eq(nodes[1].title, "A")
    eq(nodes[2].title, "B")
    eq(nodes[2].content[1].text, "Bye")
end)

test("parse: set / declare / jump / comment", function()
    local nodes = YarnParser:parse([[
title: A
---
<<declare $gold = 100>>
<<set $health to 50>>
// a comment
<<jump Next>>
===
]])
    local c = nodes[1].content
    eq(c[1].type, "declare"); eq(c[1].variable, "gold"); eq(c[1].value, "100")
    eq(c[2].type, "set"); eq(c[2].variable, "health"); eq(c[2].value, "50")
    eq(c[3].type, "comment"); eq(c[3].text, " a comment")
    eq(c[4].type, "jump"); eq(c[4].target, "Next")
end)

test("parse: set with expression value keeps raw expression", function()
    local nodes = YarnParser:parse("title: A\n---\n<<set $gold to $gold - 10>>\n===\n")
    eq(nodes[1].content[1].value, "$gold - 10")
end)

test("parse: generic command -> command type", function()
    local nodes = YarnParser:parse("title: A\n---\n<<fade_up 1.0>>\n<<wait>>\n===\n")
    local c = nodes[1].content
    eq(c[1].type, "command"); eq(c[1].name, "fade_up"); eq(c[1].args, "1.0")
    eq(c[2].type, "command"); eq(c[2].name, "wait"); is_nil(c[2].args, "no args")
end)

test("parse: multi-line comments are stripped", function()
    local nodes = YarnParser:parse("title: A\n---\nBefore\n/*\nhidden\nlines\n*/\nAfter\n===\n")
    local c = nodes[1].content
    eq(#c, 2, "only two dialogue lines remain")
    eq(c[1].text, "Before")
    eq(c[2].text, "After")
end)

test("parse: conditional choice condition is extracted", function()
    local nodes = YarnParser:parse("title: A\n---\n-> Pick me <<if $hasA>>\n    yep\n===\n")
    local choice = nodes[1].content[1]
    eq(choice.type, "choice")
    eq(choice.text, "Pick me", "text without condition")
    eq(choice.condition, "$hasA", "condition extracted")
    eq(choice.response[1].text, "yep")
end)

test("parse: arbitrary depth nested choices (4 levels)", function()
    local nodes = YarnParser:parse([[
title: A
---
-> L1
    -> L2
        -> L3
            -> L4
                Deep
===
]])
    local l1 = nodes[1].content[1]
    eq(l1.text, "L1")
    local l2 = l1.response[1]; eq(l2.type, "choice"); eq(l2.text, "L2")
    local l3 = l2.response[1]; eq(l3.type, "choice"); eq(l3.text, "L3")
    local l4 = l3.response[1]; eq(l4.type, "choice"); eq(l4.text, "L4")
    eq(l4.response[1].text, "Deep", "deepest dialogue nested correctly")
end)

test("parse: conditional within choice within conditional", function()
    local nodes = YarnParser:parse([[
title: A
---
<<if $x > 5>>
    -> Choice A
        <<if $y > 1>>
            Deep yes
        <<else>>
            Deep no
        <<endif>>
<<endif>>
===
]])
    local cond = nodes[1].content[1]
    eq(cond.type, "conditional"); eq(cond.condition, "$x > 5")
    local choice = cond.if_block[1]
    eq(choice.type, "choice"); eq(choice.text, "Choice A")
    local inner = choice.response[1]
    eq(inner.type, "conditional"); eq(inner.condition, "$y > 1")
    eq(inner.if_block[1].text, "Deep yes")
    eq(inner.else_block[1].text, "Deep no")
end)

test("parse: elseif becomes nested conditional in else_block", function()
    local nodes = YarnParser:parse([[
title: A
---
<<if $x > 5>>
    Big
<<elseif $x > 2>>
    Medium
<<else>>
    Small
<<endif>>
===
]])
    local c = nodes[1].content[1]
    eq(c.condition, "$x > 5")
    eq(c.if_block[1].text, "Big")
    local branch = c.else_block[1]
    eq(branch.type, "conditional", "elseif represented as nested conditional")
    eq(branch.condition, "$x > 2")
    eq(branch.if_block[1].text, "Medium")
    eq(branch.else_block[1].text, "Small")
end)

------------------------------------------------------------------------
-- Robustness / malformed input tests
------------------------------------------------------------------------

test("robust: nil input returns empty table (no crash)", function()
    local nodes = YarnParser:parse(nil)
    eq(type(nodes), "table"); eq(#nodes, 0)
end)

test("robust: non-string input returns empty table", function()
    eq(#YarnParser:parse(42), 0)
    eq(#YarnParser:parse({}), 0)
end)

test("robust: empty string returns empty table", function()
    eq(#YarnParser:parse(""), 0)
end)

test("robust: missing === terminator", function()
    local nodes = YarnParser:parse("title: A\n---\nHello\n")
    eq(#nodes, 1); eq(nodes[1].content[1].text, "Hello")
end)

test("robust: missing === between two nodes still splits them", function()
    local nodes = YarnParser:parse("title: A\n---\nHi\ntitle: B\n---\nBye\n")
    eq(#nodes, 2, "title boundary splits nodes even without ===")
    eq(nodes[1].content[1].text, "Hi")
    eq(nodes[2].content[1].text, "Bye")
end)

test("robust: CRLF line endings", function()
    local nodes = YarnParser:parse("title: A\r\n---\r\nHello\r\n===\r\n")
    eq(nodes[1].content[1].text, "Hello", "carriage returns stripped")
end)

test("robust: header tags between title and --- are skipped", function()
    local nodes = YarnParser:parse("title: A\ntags: foo bar\nposition: 0,0\n---\nHello\n===\n")
    eq(nodes[1].title, "A")
    eq(nodes[1].content[1].text, "Hello")
end)

test("robust: bundled real-world scripts parse without error", function()
    for _, name in ipairs({
        "example.yarn", "SpaceJourney_FinalVersion.yarn",
        "GhostyLads.yarn", "GhostyLads_Final.yarn",
        "yarn_spinner.yarn", "gold_or_health.yarn",
    }) do
        local txt = read_file(here .. "tests/" .. name)
        if txt then
            local ok, res = pcall(function() return YarnParser:parse(txt) end)
            truthy(ok, name .. " parsed without error")
            truthy(ok and #res > 0, name .. " produced nodes")
        end
    end
end)

------------------------------------------------------------------------
-- Interpreter tests
------------------------------------------------------------------------

test("interp: variable interpolation", function()
    local interp = YarnInterpreter.new({})
    interp:set_variable("name", "Yarn")
    eq(interp:interpolate_variables("Hi {$name}!"), "Hi Yarn!")
    eq(interp:interpolate_variables("{$missing}"), "undefined")
end)

test("interp: expression evaluation", function()
    local interp = YarnInterpreter.new({})
    interp:set_variable("gold", 12)
    interp:set_variable("has_sword", true)
    eq(interp:evaluate_expression("$gold + 3"), 15)
    eq(interp:evaluate_condition("$gold >= 10"), true)
    eq(interp:evaluate_condition("$gold < 5"), false)
    eq(interp:evaluate_condition("$gold != 10"), true)
    eq(interp:evaluate_condition("$has_sword"), true)
    eq(interp:evaluate_condition("not $has_sword"), false)
    eq(interp:evaluate_condition("$gold > 5 and $has_sword"), true)
    eq(interp:evaluate_condition("$gold > 100 or $has_sword"), true)
end)

test("interp: undefined variable in condition is false, not a crash", function()
    local interp = YarnInterpreter.new({})
    eq(interp:evaluate_condition("$nope > 5"), false)
end)

test("interp: set with expression is evaluated", function()
    local nodes = YarnParser:parse([[
title: A
---
<<set $gold to 30>>
<<set $gold to $gold - 10>>
===
]])
    local interp, log = make_recorder(nodes)
    interp:run()
    eq(log.variables.gold, 20, "expression evaluated")
end)

test("interp: declare type defaults and string literal", function()
    local nodes = YarnParser:parse([[
title: A
---
<<declare $h = Number>>
<<declare $n = String>>
<<declare $b = Boolean>>
<<set $name to "Yarn">>
===
]])
    local interp, log = make_recorder(nodes)
    interp:run()
    eq(log.variables.h, 0)
    eq(log.variables.n, "")
    eq(log.variables.b, false)
    eq(log.variables.name, "Yarn", "string literal stored without quotes")
end)

test("interp: if/elseif/else chooses correct branch", function()
    local function branch_for(x)
        local nodes = YarnParser:parse(string.format([[
title: A
---
<<set $x to %d>>
<<if $x > 5>>
    big
<<elseif $x > 2>>
    medium
<<else>>
    small
<<endif>>
===
]], x))
        local interp, log = make_recorder(nodes)
        interp:run()
        return log.dialogue[1]
    end
    eq(branch_for(10), "big")
    eq(branch_for(3), "medium")
    eq(branch_for(0), "small")
end)

test("interp: generic commands routed to on_command", function()
    local nodes = YarnParser:parse("title: A\n---\n<<camera Title>>\n<<wait 2>>\nHi\n===\n")
    local interp, log = make_recorder(nodes)
    interp:run()
    eq(#log.commands, 2)
    eq(log.commands[1].name, "camera"); eq(log.commands[1].args, "Title")
    eq(log.commands[2].name, "wait"); eq(log.commands[2].args, "2")
    eq(log.dialogue[1], "Hi")
end)

test("interp: conditional choices are filtered by condition", function()
    local nodes = YarnParser:parse([[
title: A
---
<<set $hasA to true>>
<<set $hasB to false>>
-> Always
    chose always
-> Needs A <<if $hasA>>
    chose A
-> Needs B <<if $hasB>>
    chose B
===
]])
    local interp, log = make_recorder(nodes, {1})  -- pick first available
    interp:run()
    -- Only "Always" and "Needs A" should be offered (B filtered out).
    eq(#log.choices[1], 2, "two choices available")
    eq(log.choices[1][1], "Always")
    eq(log.choices[1][2], "Needs A")
end)

test("interp: selecting an available conditional choice runs its response", function()
    local nodes = YarnParser:parse([[
title: A
---
<<set $hasA to true>>
-> Plain
    chose plain
-> Needs A <<if $hasA>>
    chose A
===
]])
    local interp, log = make_recorder(nodes, {2})  -- pick "Needs A"
    interp:run()
    eq(log.dialogue[1], "chose A")
end)

test("interp: jump moves between nodes and fires enter/exit", function()
    local nodes = YarnParser:parse([[
title: A
---
First
<<jump B>>
Never
===
title: B
---
Second
===
]])
    local interp, log = make_recorder(nodes)
    interp:run()
    eq(log.dialogue[1], "First")
    eq(log.dialogue[2], "Second")
    is_nil(log.dialogue[3], "text after jump is not executed")
    eq(#log.enter, 2, "each node entered exactly once")
    eq(log.enter[1], "A"); eq(log.enter[2], "B")
    eq(#log.exit, 2, "each node exited exactly once")
    eq(log.exit[1], "A"); eq(log.exit[2], "B")
end)

test("interp: full gold_or_health script runs end-to-end", function()
    local txt = read_file(here .. "tests/gold_or_health.yarn")
    if txt then
        local nodes = YarnParser:parse(txt)
        local interp, log = make_recorder(nodes, {2, 1, 1, 1, 1, 1})
        local ok = pcall(function() interp:run() end)
        truthy(ok, "ran without error")
        truthy(#log.dialogue > 0, "produced dialogue")
    end
end)

------------------------------------------------------------------------
-- Summary
------------------------------------------------------------------------
print(string.rep("-", 50))
print(string.format("Tests: %d passed, %d failed", passed, failed))
if failed > 0 then
    print("\nFailures:")
    for _, f in ipairs(failures) do print("  - " .. f) end
    os.exit(1)
end
print("All tests passed.")
