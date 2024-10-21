# Yarn Script Syntax Description

Yarn Script is a language for writing conversations in games. Here's an updated syntax description based on the provided examples and documentation:

### 1. **Node Structure**

A **node** is the fundamental building block of Yarn Script. Each node is defined by a `title`, followed by a sequence of dialogue, choices, or commands.

#### Node Declaration:
- **Keyword**: `title:`
- **Format**: `title: <NodeName>`
- **Example**:
  ```yarn
  title: Start
  ---
  Hello there!
  ===
  ```

#### Node Termination:
- **Start Delimiter**: `---` (signals the start of node content)
- **End Delimiter**: `===` (signals the end of a node)

### 2. **Dialogue**

Dialogue is the primary content of nodes. Each line of dialogue is written as plain text.

#### Format:
- **Text**: `<PlainText>`
- **Example**:
  ```yarn
  Yarn Spinner is a language for writing conversations in games!
  ```

### 3. **Choices**

Choices present the player with options that branch the narrative. They are written using arrow symbols and can include nested choices.

#### Format:
- **Choice**: `-> <ChoiceText>`
- **Response**: Indented text following the choice
- **Example**:
  ```yarn
  -> Wow, some options!
      You got it, pal!
  -> Can I put text inside options?
      You sure can!
      For example, here's some lines inside an option.
      You can even put options inside OTHER options!
      -> Like this!
          Wow!
      -> Or this!
          Incredible!
  ```

### 4. **Variables**

Variables store data that affects dialogue flow or choices. Variables start with `$` and can be declared, assigned values, or used in expressions.

#### Variable Declaration and Assignment:
- **Command**: `<<set $<VariableName> to <Value>>>`
- **Example**:
  ```yarn
  <<set $name to "Yarn">>
  <<set $gold to 5>>
  ```

#### Variable Usage (Interpolation):
- **Format**: `{$<VariableName>}`
- **Example**:
  ```yarn
  My name's {$name}!
  ```

### 5. **Conditionals**

Conditionals enable branching based on the value of variables. They are enclosed in `<<if>>`, `<<else>>`, and `<<endif>>`.

#### Format:
- **Conditionals**: `<<if <Condition>>> ... <<else>> ... <<endif>>`
- **Example**:
  ```yarn
  <<if $gold > 5>>
      The '$gold' variable is bigger than 5!
  <<else>>
      The '$gold' variable is 5 or less!
  <<endif>>
  ```

### 6. **Commands**

Commands allow interaction with the game or the script engine. They are written between double angle brackets.

#### Format:
- **Command**: `<<command>>`
- **Example**:
  ```yarn
  <<fade_up 1.0>>
  ```

#### Common Commands:
- `<<jump <NodeName>>>`: Jump to another node.
- `<<set $<VariableName> to <Value>>>`: Assign a value to a variable.

### 7. **Comments**

Comments are used for annotating the script and are ignored by the interpreter. Yarn supports single-line comments.

#### Single-line Comment:
- **Syntax**: `//`
- **Example**:
  ```yarn
  // Comments start with two slashes, and won't show up in your conversation.
  ```

### 8. **Node Jumping**

The `<<jump>>` command can be used to jump to a different node.

#### Format:
- **Command**: `<<jump <NodeName>>>`
- **Example**:
  ```yarn
  <<jump OtherNode>>
  ```

### 9. **String Interpolation**

Variables can be inserted directly into dialogue using curly braces `{}`.

#### Format:
- **Interpolation**: `{$<VariableName>}`
- **Example**:
  ```yarn
  My name's {$name}!
  ```

### 10. **Overall Grammar**

The overall grammar for Yarn Script can be formalized as follows:

```ebnf
Script    ::= Node+ ;
Node      ::= "title:" NodeName "---" (Dialogue | Choice | Command | Conditional | Comment)* "===" ;
NodeName  ::= [A-Za-z_][A-Za-z0-9_]* ;
Dialogue  ::= PlainText ;
Choice    ::= "->" ChoiceText (Dialogue | Choice)* ;
Command   ::= "<<" CommandText ">>" ;
Conditional ::= "<<if" Condition ">>" Content ("<<else>>" Content)? "<<endif>>" ;
Comment   ::= "//" CommentText ;
PlainText ::= .+ ;  // Any printable character or whitespace
ChoiceText ::= .+ ;  // Text following the choice arrow
CommandText ::= [A-Za-z_][A-Za-z0-9_]* (" " .+)? ;  // Command name followed by optional parameters
Condition ::= Expression ;
Content   ::= (Dialogue | Choice | Command | Conditional | Comment)* ;
Expression ::= ... ; // Expressions for conditions and variable assignments
```

This updated syntax description reflects the structure and features demonstrated in the provided Yarn Script examples.


## Author

Florian Fischer ( https://github.com/SiENcE )
