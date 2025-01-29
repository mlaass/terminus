/// <reference types="jest" />
import { describe, expect, it, beforeAll } from '@jest/globals';
import * as path from 'path';
import Termynus from '../index';

describe('Termynus', () => {
  let termynus: Termynus;

  beforeAll(async () => {
    const wasmPath = path.resolve(__dirname, '../../../zig-out/lib/termynus.wasm');
    termynus = new Termynus(wasmPath);
    await termynus.initialize();
  });

  describe('tokenize', () => {
    it('should tokenize a simple expression', () => {
      const tokens = termynus.tokenize('1 + 2');
      expect(tokens).toEqual([
        { type: 'number', value: '1' },
        { type: 'operator', value: '+' },
        { type: 'number', value: '2' },
      ]);
    });
  });

  describe('shuntingYard', () => {
    it('should convert expression to RPN', () => {
      const rpn = termynus.shuntingYard('1 + 2 * 3');
      expect(rpn).toEqual([
        { type: 'literal_integer', value: 1 },
        { type: 'literal_integer', value: 2 },
        { type: 'literal_integer', value: 3 },
        { type: 'binary_operator', value: '*' },
        { type: 'binary_operator', value: '+' },
      ]);
    });
  });

  describe('parseToTree', () => {
    it('should parse expression to AST', () => {
      const ast = termynus.parseToTree('1 + 2');
      expect(ast).toEqual({
        type: 'binary_operator',
        value: '+',
        args: [
          { type: 'literal_integer', value: 1 },
          { type: 'literal_integer', value: 2 },
        ],
      });
    });
  });

  describe('evaluate', () => {
    describe('arithmetic operations', () => {
      it('evaluates basic arithmetic', () => {
        expect(termynus.evaluate('1 + 2 * 3')).toEqual({
          type: 'integer',
          value: 7,
        });
      });

      it('respects operator precedence', () => {
        expect(termynus.evaluate('(1 + 2) * 3')).toEqual({
          type: 'integer',
          value: 9,
        });
      });

      it('handles floating point arithmetic', () => {
        expect(termynus.evaluate('3.14 * 2')).toEqual({
          type: 'float',
          value: 6.28,
        });
      });

      it('handles division', () => {
        expect(termynus.evaluate('10 / 2')).toEqual({
          type: 'integer',
          value: 5,
        });
      });

      it('handles floor division', () => {
        expect(termynus.evaluate('7 // 2')).toEqual({
          type: 'integer',
          value: 3,
        });
      });

      it('handles modulo', () => {
        expect(termynus.evaluate('7 % 3')).toEqual({
          type: 'integer',
          value: 1,
        });
      });

      it('handles power operation', () => {
        expect(termynus.evaluate('2 ** 3')).toEqual({
          type: 'integer',
          value: 8,
        });
      });
    });

    describe('boolean operations', () => {
      it('evaluates comparisons', () => {
        expect(termynus.evaluate('1 < 2')).toEqual({
          type: 'boolean',
          value: true,
        });
        expect(termynus.evaluate('2 > 1')).toEqual({
          type: 'boolean',
          value: true,
        });
        expect(termynus.evaluate('2 >= 2')).toEqual({
          type: 'boolean',
          value: true,
        });
        expect(termynus.evaluate('1 <= 2')).toEqual({
          type: 'boolean',
          value: true,
        });
      });

      it('evaluates equality', () => {
        expect(termynus.evaluate('1 == 1')).toEqual({
          type: 'boolean',
          value: true,
        });
        expect(termynus.evaluate('1 != 2')).toEqual({
          type: 'boolean',
          value: true,
        });
      });

      it('handles logical operations', () => {
        expect(termynus.evaluate('true and true')).toEqual({
          type: 'boolean',
          value: true,
        });
        expect(termynus.evaluate('true or false')).toEqual({
          type: 'boolean',
          value: true,
        });
        expect(termynus.evaluate('not false')).toEqual({
          type: 'boolean',
          value: true,
        });
      });
    });

    describe('string operations', () => {
      it('handles string literals', () => {
        expect(termynus.evaluate('"Hello"')).toEqual({
          type: 'string',
          value: 'Hello',
        });
        expect(termynus.evaluate('\'World\'')).toEqual({
          type: 'string',
          value: 'World',
        });
      });

      it('handles escaped strings', () => {
        expect(termynus.evaluate('"Hello\\nWorld"')).toEqual({
          type: 'string',
          value: 'Hello\nWorld',
        });
        expect(termynus.evaluate('"Quote: \\"Hello\\""')).toEqual({
          type: 'string',
          value: 'Quote: "Hello"',
        });
      });
    });

    describe('date operations', () => {
      it('handles date literals', () => {
        expect(termynus.evaluate('d"2024-01-01"')).toEqual({
          type: 'date',
          value: '2024-01-01',
        });
        expect(termynus.evaluate('d\'2024-12-31\'')).toEqual({
          type: 'date',
          value: '2024-12-31',
        });
      });
    });

    describe('list operations', () => {
      it('handles empty lists', () => {
        expect(termynus.evaluate('[]')).toEqual({
          type: 'list',
          value: [],
        });
      });

      it('handles lists with single type', () => {
        expect(termynus.evaluate('[1, 2, 3]')).toEqual({
          type: 'list',
          value: [1, 2, 3],
        });
        expect(termynus.evaluate('["a", "b", "c"]')).toEqual({
          type: 'list',
          value: ['a', 'b', 'c'],
        });
      });

      it('handles mixed type lists', () => {
        expect(termynus.evaluate('[1, "two", true]')).toEqual({
          type: 'list',
          value: [1, 'two', true],
        });
      });

      it('handles nested lists', () => {
        expect(termynus.evaluate('[[1, 2], [3, 4]]')).toEqual({
          type: 'list',
          value: [[1, 2], [3, 4]],
        });
      });
    });

    describe('error handling', () => {
      it('handles division by zero', () => {
        expect(() => termynus.evaluate('1 / 0')).toThrow();
      });

      it('handles invalid syntax', () => {
        expect(() => termynus.evaluate('1 +')).toThrow();
      });

      it('handles undefined variables', () => {
        expect(() => termynus.evaluate('x + 1')).toThrow();
      });

      it('handles type errors', () => {
        expect(() => termynus.evaluate('"hello" + 1')).toThrow();
      });
    });
  });
});
