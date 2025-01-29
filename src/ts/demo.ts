import Termynus from './index';
import * as path from 'path';

async function runDemo() {
  // Initialize Termynus with the correct path to the WASM file
  const termynus = new Termynus(path.resolve(__dirname, '../../zig-out/lib/termynus.wasm'));
  await termynus.initialize();

  // Example expressions to test
  const expressions = [
    "1 + 2 * 3",                    // Basic arithmetic
    "true && false || true",        // Boolean operations
    "'Hello' + ' ' + 'World'",      // String concatenation
    "d'2024-01-01'",               // Date literal
    "[1, 2, 3]",                   // List
    "10 / 2",                      // Division
    "2 ^ 3",                       // Power
    "15 % 4",                      // Modulo
  ];

  // Test each expression
  for (const expr of expressions) {
    console.log("\nTesting expression:", expr);

    try {
      // Show tokens
      console.log("Tokens:", JSON.stringify(termynus.tokenize(expr), null, 2));

      // Show RPN (Reverse Polish Notation)
      console.log("RPN:", JSON.stringify(termynus.shuntingYard(expr), null, 2));

      // Show AST (Abstract Syntax Tree)
      console.log("AST:", JSON.stringify(termynus.parseToTree(expr), null, 2));

      // Show evaluation result
      console.log("Result:", JSON.stringify(termynus.evaluate(expr), null, 2));
    } catch (error) {
      console.error("Error processing expression:", error);
    }

    console.log("-".repeat(50));
  }
}

// Run the demo
runDemo().catch(console.error);