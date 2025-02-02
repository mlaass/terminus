# Termynus

A powerful term evaluator written in Zig that provides parsing, evaluation, and analysis of mathematical and logical expressions. Available as both a Python library and an NPM package (via WebAssembly).

## Overview

Termynus is a versatile expression evaluator that supports:
- Mathematical expressions with operator precedence
- Logical operations and comparisons
- String manipulation
- (Date comparisons)
- List operations
- Built-in functions for math, strings, and lists
- Custom function definitions

## Expression Syntax

### Basic Types
- Integers: `42`, `-17`
- Floats: `3.14`, `-0.001`
- Strings: `'hello'`, `'world'`
- Dates: `d'2023-12-31'`
- Booleans: `true`, `false`
- Lists: `[1, 2, 3]`, `['a', 'b', 'c']`

### Operators

#### Arithmetic
- Addition: `+`
- Subtraction: `-`
- Multiplication: `*`
- Division: `/`
- Floor Division: `//`
- Power: `**`
- Modulo: `%` or `mod`

#### Comparison
- Equal: `==`
- Not Equal: `!=`
- Greater Than: `>`
- Less Than: `<`
- Greater Than or Equal: `>=`
- Less Than or Equal: `<=`

#### Logical
- AND: `and`
- OR: `or`
- NOT: `not`

#### Bitwise
- AND: `&`
- OR: `|`
- XOR: `xor`
- Left Shift: `<<`
- Right Shift: `>>`

### Function Calls
```
function_name(arg1, arg2, ...)
```

### Examples
```
# Basic arithmetic
5 + 3 * 2             # 11
(5 + 3) * 2          # 16

# Mixed types
1 + 2.5              # 3.5

# Comparisons
5 > 3 and 2 <= 4     # true

# Lists
[1, 2 + 3, 4 * 2]    # [1, 5, 8]

# Strings
'hello' + ' world'    # 'hello world'

# Dates
d'2023-01-01' < d'2023-12-31'  # true
```

## Installation

### Python Package
```bash
pip install termynus
```

### NPM Package
```bash
npm install termynus
```

## Building from Source

### Prerequisites
- Zig (version 0.11.0)
- Node.js and npm (for JavaScript/TypeScript package)
- Python 3.8+ and Poetry (for Python package)

### CLI Tool

1. Clone the repository:

2. Build the CLI:

   ```bash
   zig build
   ```

3. Run the CLI:

   ```bash
   ./zig-out/bin/termynus "5 + 3 * 2"
   ```
4. (Optional) Generate documentation:

   ```bash
   zig build docs
   ```



### JavaScript/TypeScript Package

1. Clone the repository (if not already done)
2. Install dependencies:
   ```bash
   npm install
   ```
3. Build the WASM module and TypeScript bindings:
   ```bash
   npm run build:wasm    # Builds the WASM module
   npm run build:ts      # Builds TypeScript files
   npm run build        # Builds everything
   ```
4. Run tests:
   ```bash
   npm test
   ```

### Python Package

1. Clone the repository (if not already done)
2. Install Poetry if not installed:
```bash
   curl -sSL https://install.python-poetry.org | python3 -
   ```
3. Install dependencies and build:
```bash
   poetry install
   poetry build
   ```
4. Run tests:
```bash
   poetry run pytest
   ```

### Development Setup

For development, you might want to set up all components:
```bash
# Clone and enter directory
git clone https://github.com/mlaass/termynus.git
cd termynus

# Build Zig components
zig build

# Install and build npm package
npm install
npm run build

# Install and build Python package
poetry install

# Run all tests
zig build test
npm test
poetry run pytest
```

## Usage

### Command Line Interface
```bash
# Basic evaluation
termynus "5 + 3 * 2"

# Show parse tree
termynus --tree "5 + 3 * 2"

# Show tokenization
termynus --parse "5 + 3 * 2"

# Show reverse polish notation output
termynus --rpn "5 + 3 * 2"
```

### Python

```python
import termynus

# Evaluate expressions
result = termynus.evaluate("5 + 3 * 2")
print(result)  # 11

# Complex expressions
expr = "(2 + 3 * 4 > 10) and (5 + 5 == 10)"
result = termynus.evaluate(expr)
print(result)  # True

# Lists and mixed types
result = termynus.evaluate("[1, 2 + 3, 'hello']")
print(result)  # [1, 5, 'hello']
```

### JavaScript/TypeScript

```typescript
import Termynus from 'termynus';

async function example() {
  const termynus = new Termynus();
  await termynus.initialize();

  // Evaluate expressions
  const result = termynus.evaluate('1 + 2 * 3');
  console.log(result);  // 7

  // Parse expression to AST
  const ast = termynus.parseToTree('1 + 2 * 3');
  console.log(ast);

  // Get tokens
  const tokens = termynus.tokenize('1 + 2 * 3');
  console.log(tokens);
}
```

## Built-in Functions

Termynus provides a rich set of built-in functions for various operations. Here's a brief overview:

### Math Functions

- `min(x, y, ...)`: Minimum value
- `max(x, y, ...)`: Maximum value
- `abs(x)`: Absolute value
- `sqrt(x)`: Square root
- `pow(x, y)`: Power
- `log(x)`, `log2(x)`, `log10(x)`: Logarithms
- `exp(x)`: Exponential
- `floor(x)`, `ceil(x)`: Rounding
- `mean(x, y, ...)`: Arithmetic mean

### String Functions

- `str.concat(s1, s2, ...)`: Concatenate strings
- `str.length(s)`: String length
- `str.substring(s, start, end)`: Extract substring
- `str.replace(s, old, new)`: Replace substring
- `str.toUpper(s)`, `str.toLower(s)`: Case conversion
- `str.trim(s)`: Remove whitespace

### List Functions

- `list.length(l)`: List length
- `list.get(l, index)`: Get element
- `list.append(l, item)`: Append item
- `list.concat(l1, l2)`: Concatenate lists
- `list.slice(l, start, end)`: Extract sublist
- `list.map(l, f)`: Apply function to elements
- `list.filter(l, f)`: Filter elements

### Function Features

- `def(name, args, body)`: Define a function

## Roadmap / To Do

### Incomplete Features

- **Documentation**
  - Missing documentation for all built-in functions
  - Example usage for built-in functions and language features
  - Missing documentation for CLI

- **Date Support**
  - Date arithmetic operations not implemented
  - Missing date manipulation functions (addDays, addHours, etc.)
  - Date comparison operators not implemented
  - Need proper date parsing and validation

- **String Functions**
  - Missing string splitting functionality
  - No regex support
  - Missing string search functions (indexOf, contains, etc.)
  - No format string support

- **List Operations**
  - Missing list sorting functionality
  - No list reversal operation
  - Missing list insertion at index
  - No list removal operations
  - Missing list search operations
  - No list uniqueness operations

- **Function Features**
  - Missing function composition
  - No currying support
  - Missing function memoization
  - No support for async functions

### Planned Features

- **Language Features**
- Variable declarations
- Variable assignment
- Control flow statements (if/else, loops)
- Pattern matching
- Modules/imports
- (Optional) anonymous functions
- (Optional) type annotations

- **Error Handling**
  - Better error messages
  - Error recovery
  - Stack traces for errors

- **Performance Optimizations**
  - Expression compilation
  - Constant folding
  - Expression caching
  - Memory usage optimizations

- **Type System**
  - Type checking and inference
  - Custom type definitions
  - Type coercion rules
  - (Optional) type annotations

- **Tooling**
  - REPL environment
  - Debugging support

## License

MIT
