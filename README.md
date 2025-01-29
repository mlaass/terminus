# Termynus

A term evaluator that provides parsing, evaluation, and analysis of mathematical and logical expressions written in zig and available as npm library with wasm and a python library.

Mostly written for educational purposes.

## Installation

```bash
npm install termynus
```

## Usage

```typescript
import Termynus from 'termynus';

async function example() {
  // Create a new instance with optional custom WASM path
  const termynus = new Termynus();

  // Initialize the WASM module
  await termynus.initialize();

  // Tokenize an expression
  const tokens = termynus.tokenize('1 + 2 * 3');
  console.log('Tokens:', tokens);

  // Convert to RPN using shunting yard algorithm
  const rpn = termynus.shuntingYard('1 + 2 * 3');
  console.log('RPN:', rpn);

  // Parse expression to AST
  const ast = termynus.parseToTree('1 + 2 * 3');
  console.log('AST:', ast);

  // Evaluate expression
  const result = termynus.evaluate('1 + 2 * 3');
  console.log('Result:', result);
}

example().catch(console.error);
```

## API Reference

### `new Termynus(wasmPath?: string)`

Creates a new instance of the Termynus evaluator. Optionally accepts a custom path to the WASM file.

### `async initialize(): Promise<void>`

Initializes the WASM module. Must be called before using any other methods.

### `tokenize(input: string): Token[]`

Tokenizes the input string into an array of tokens.

### `shuntingYard(input: string): Node[]`

Converts the input expression to Reverse Polish Notation (RPN) using the shunting yard algorithm.

### `parseToTree(input: string): Node`

Parses the input expression into an Abstract Syntax Tree (AST).

### `evaluate(input: string): EvaluationResult`

Evaluates the input expression and returns the result.

## Types

```typescript
interface Token {
  type: string;
  value: string;
}

interface Node {
  type: string;
  value?: number | string;
  name?: string;
  argCount?: number;
  elementCount?: number;
  args?: Node[];
}

interface EvaluationResult {
  type: string;
  value: number | string | boolean | any[] | null;
}
```

## Building from Source

1. Install Zig (version 0.11.0 or later)
2. Clone the repository
3. Run `npm install`
4. Run `npm run build`

## License

MIT
