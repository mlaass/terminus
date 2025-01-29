// Types for the WASM interface
interface WasmExports {
  memory: WebAssembly.Memory;
  tokenize: (ptr: number, len: number) => number;
  shuntingYard: (ptr: number, len: number) => number;
  parseToTree: (ptr: number, len: number) => number;
  evaluate: (ptr: number, len: number) => number;
  getStringLen: (ptr: number) => number;
}

// Types for the parser
export interface Token {
  type: string;
  value: string;
}

export interface Node {
  type: string;
  value?: number | string;
  name?: string;
  argCount?: number;
  elementCount?: number;
  args?: Node[];
}

export interface EvaluationResult {
  type: string;
  value: number | string | boolean | any[] | null;
}

class Termynus {
  private wasmInstance?: WebAssembly.Instance;
  private wasmExports?: WasmExports;
  private encoder: TextEncoder;
  private decoder: TextDecoder;
  private wasmPath: string;
  private wasmBytes?: Buffer | ArrayBuffer;
  private memoryOffset: number;

  constructor(wasmPath?: string, wasmBytes?: Buffer | ArrayBuffer) {
    this.encoder = new TextEncoder();
    this.decoder = new TextDecoder();
    this.wasmPath = wasmPath ?? './termynus.wasm';
    this.wasmBytes = wasmBytes;
    this.memoryOffset = 0;
  }

  async initialize(): Promise<void> {
    let wasmModule: WebAssembly.WebAssemblyInstantiatedSource;
    const importObject = {
      env: {
        memory: new WebAssembly.Memory({ initial: 16, maximum: 16 }) // 1MB initial/max
      }
    };

    if (this.wasmBytes) {
      // If bytes are provided directly
      wasmModule = await WebAssembly.instantiate(this.wasmBytes, importObject);
    } else if (typeof window !== 'undefined') {
      // Browser environment
      wasmModule = await WebAssembly.instantiateStreaming(
        fetch(this.wasmPath),
        importObject
      );
    } else {
      // Node.js environment
      const fs = require('fs');
      const path = require('path');
      const wasmBuffer = fs.readFileSync(path.resolve(process.cwd(), this.wasmPath));
      wasmModule = await WebAssembly.instantiate(wasmBuffer, importObject);
    }

    this.wasmInstance = wasmModule.instance;
    this.wasmExports = this.wasmInstance.exports as unknown as WasmExports;
    this.memoryOffset = 0;
  }

  private writeString(str: string): { ptr: number; len: number } {
    if (!this.wasmExports) throw new Error('WASM not initialized');

    const bytes = this.encoder.encode(str);
    const memory = new Uint8Array(this.wasmExports.memory.buffer);

    // Reset memory offset if we're near the end
    if (this.memoryOffset + bytes.length + 1 >= memory.length) {
      this.memoryOffset = 0;
    }

    // Copy bytes to memory
    memory.set(bytes, this.memoryOffset);
    const ptr = this.memoryOffset;
    const len = bytes.length;
    this.memoryOffset += bytes.length + 1; // +1 for null terminator
    memory[this.memoryOffset - 1] = 0; // Add null terminator

    return { ptr, len };
  }

  private readString(ptr: number): string {
    if (!this.wasmExports) throw new Error('WASM not initialized');
    if (ptr === -1) throw new Error('WASM operation failed');

    const len = this.wasmExports.getStringLen(ptr);
    if (len <= 0 || len >= 1024 * 1024) throw new Error('Invalid string length');

    const memory = new Uint8Array(this.wasmExports.memory.buffer);
    const bytes = memory.slice(ptr, ptr + len);
    return this.decoder.decode(bytes);
  }

  tokenize(input: string): Token[] {
    if (!this.wasmExports) throw new Error('WASM not initialized');

    const { ptr, len } = this.writeString(input);
    const resultPtr = this.wasmExports.tokenize(ptr, len);
    const result = this.readString(resultPtr);
    return JSON.parse(result);
  }

  shuntingYard(input: string): Node[] {
    if (!this.wasmExports) throw new Error('WASM not initialized');

    const { ptr, len } = this.writeString(input);
    const resultPtr = this.wasmExports.shuntingYard(ptr, len);
    const result = this.readString(resultPtr);
    return JSON.parse(result);
  }

  parseToTree(input: string): Node {
    if (!this.wasmExports) throw new Error('WASM not initialized');

    const { ptr, len } = this.writeString(input);
    const resultPtr = this.wasmExports.parseToTree(ptr, len);
    const result = this.readString(resultPtr);
    return JSON.parse(result);
  }

  evaluate(input: string): EvaluationResult {
    if (!this.wasmExports) throw new Error('WASM not initialized');

    const { ptr, len } = this.writeString(input);
    const resultPtr = this.wasmExports.evaluate(ptr, len);
    const result = this.readString(resultPtr);
    return JSON.parse(result);
  }
}

export default Termynus;
