import unittest

from service.term_interpreter import *
from service.term_parser import parse_to_tree


class TestASTEvaluation(unittest.TestCase):
    def test_evaluation_with_identifiers(self):
        ast_example_with_identifiers = {
            "type": "bin_op",
            "name": "+",
            "args": [
                {"type": "id", "value": "x"},
                {
                    "type": "bin_op",
                    "name": "*",
                    "args": [
                        {"type": "id", "value": "y"},
                        {"type": "lit", "value": "2"},
                    ],
                },
            ],
        }
        environment = {"x": 3, "y": 4}
        result = evaluate(ast_example_with_identifiers, environment)
        self.assertEqual(result, 11)

    def test_evaluation_without_identifiers(self):
        ast_example = {
            "type": "bin_op",
            "name": "+",
            "args": [
                {"type": "lit", "value": "3"},
                {
                    "type": "bin_op",
                    "name": "*",
                    "args": [
                        {"type": "lit", "value": "4"},
                        {"type": "lit", "value": "2"},
                    ],
                },
            ],
        }
        result = evaluate(ast_example, {})
        self.assertEqual(result, 11)

    # Unary ops
    def test_evaluation_unary_not(self):
        ast_not = {
            "type": "unary_op",
            "name": "not",
            "args": [
                {"type": "lit", "value": "1"},
            ],
        }
        result = evaluate(ast_not, {})
        self.assertEqual(result, False)

    def test_evaluation_unary_not2(self):
        ast_not = {
            "type": "unary_op",
            "name": "not",
            "args": [
                {"type": "lit", "value": "0"},
            ],
        }
        result = evaluate(ast_not, {})
        self.assertEqual(result, True)

    def test_evaluation_unary_floor(self):
        ast_floor = {
            "type": "unary_op",
            "name": "floor",
            "args": [
                {"type": "lit", "value": "3.5"},
            ],
        }
        result = evaluate(ast_floor, {})
        self.assertEqual(result, 3)

    def test_evaluation_unary_ceil(self):
        ast_ceil = {
            "type": "unary_op",
            "name": "ceil",
            "args": [
                {"type": "lit", "value": "3.2"},
            ],
        }
        result = evaluate(ast_ceil, {})
        self.assertEqual(result, 4)

    # Binary ops
    def test_evaluation_binary_add(self):
        ast_add = {
            "type": "bin_op",
            "name": "+",
            "args": [
                {"type": "lit", "value": "5"},
                {"type": "lit", "value": "3"},
            ],
        }
        result = evaluate(ast_add, {})
        self.assertEqual(result, 8)

    def test_evaluation_binary_subtract(self):
        ast_subtract = {
            "type": "bin_op",
            "name": "-",
            "args": [
                {"type": "lit", "value": "5"},
                {"type": "lit", "value": "3"},
            ],
        }
        result = evaluate(ast_subtract, {})
        self.assertEqual(result, 2)

    def test_evaluation_binary_multiply(self):
        ast_multiply = {
            "type": "bin_op",
            "name": "*",
            "args": [
                {"type": "lit", "value": "5"},
                {"type": "lit", "value": "3"},
            ],
        }
        result = evaluate(ast_multiply, {})
        self.assertEqual(result, 15)

    def test_evaluation_binary_divide(self):
        ast_divide = {
            "type": "bin_op",
            "name": "/",
            "args": [
                {"type": "lit", "value": "10"},
                {"type": "lit", "value": "2"},
            ],
        }
        result = evaluate(ast_divide, {})
        self.assertEqual(result, 5)

    def test_evaluation_binary_modulo(self):
        ast_modulo = {
            "type": "bin_op",
            "name": "mod",
            "args": [
                {"type": "lit", "value": "10"},
                {"type": "lit", "value": "3"},
            ],
        }
        result = evaluate(ast_modulo, {})
        self.assertEqual(result, 1)

    def test_evaluation_binary_less_than(self):
        ast_less_than = {
            "type": "bin_op",
            "name": "<",
            "args": [
                {"type": "lit", "value": "2"},
                {"type": "lit", "value": "3"},
            ],
        }
        result = evaluate(ast_less_than, {})
        self.assertTrue(result)

    def test_evaluation_binary_less_than_or_equal(self):
        ast_less_than_equal = {
            "type": "bin_op",
            "name": "<=",
            "args": [
                {"type": "lit", "value": "3"},
                {"type": "lit", "value": "3"},
            ],
        }
        result = evaluate(ast_less_than_equal, {})
        self.assertTrue(result)

    def test_evaluation_binary_greater_than(self):
        ast_greater_than = {
            "type": "bin_op",
            "name": ">",
            "args": [
                {"type": "lit", "value": "4"},
                {"type": "lit", "value": "3"},
            ],
        }
        result = evaluate(ast_greater_than, {})
        self.assertTrue(result)

    def test_evaluation_binary_greater_than_or_equal(self):
        ast_greater_than_equal = {
            "type": "bin_op",
            "name": ">=",
            "args": [
                {"type": "lit", "value": "3"},
                {"type": "lit", "value": "2"},
            ],
        }
        result = evaluate(ast_greater_than_equal, {})
        self.assertTrue(result)

    def test_evaluation_binary_equal(self):
        ast_equal = {
            "type": "bin_op",
            "name": "==",
            "args": [
                {"type": "lit", "value": "3"},
                {"type": "lit", "value": "3"},
            ],
        }
        result = evaluate(ast_equal, {})
        self.assertTrue(result)

    def test_evaluation_binary_not_equal(self):
        ast_not_equal = {
            "type": "bin_op",
            "name": "!=",
            "args": [
                {"type": "lit", "value": "3"},
                {"type": "lit", "value": "4"},
            ],
        }
        result = evaluate(ast_not_equal, {})
        self.assertTrue(result)

    def test_evaluation_binary_and(self):
        ast_and = {
            "type": "bin_op",
            "name": "and",
            "args": [
                {"type": "lit", "value": "true"},
                {"type": "lit", "value": "False"},
            ],
        }
        result = evaluate(ast_and, {})
        self.assertFalse(result)

    def test_evaluation_binary_and2(self):
        ast_and = {
            "type": "bin_op",
            "name": "and",
            "args": [
                {"type": "lit", "value": "true"},
                {"type": "lit", "value": "True"},
            ],
        }
        result = evaluate(ast_and, {})
        self.assertTrue(result)

    def test_evaluation_binary_or(self):
        ast_or = {
            "type": "bin_op",
            "name": "or",
            "args": [
                {"type": "lit", "value": "False"},
                {"type": "lit", "value": "True"},
            ],
        }
        result = evaluate(ast_or, {})
        self.assertTrue(result)

    def test_evaluation_binary_or2(self):
        ast_or = {
            "type": "bin_op",
            "name": "or",
            "args": [
                {"type": "lit", "value": "False"},
                {"type": "lit", "value": "0"},
            ],
        }
        result = evaluate(ast_or, {})
        self.assertFalse(result)

    # Bonus: Testing op precedence
    def test_evaluation_op_precedence(self):
        ast_precedence = {
            "type": "bin_op",
            "name": "+",
            "args": [
                {"type": "lit", "value": "3"},
                {
                    "type": "bin_op",
                    "name": "*",
                    "args": [
                        {"type": "lit", "value": "4"},
                        {"type": "lit", "value": "2"},
                    ],
                },
            ],
        }
        result = evaluate(ast_precedence, {})
        self.assertEqual(result, 11)  # Confirms 4 * 2 is evaluated before adding 3

    # Edge Cases Tests
    def test_division_by_zero(self):
        ast_div_zero = {
            "type": "bin_op",
            "name": "/",
            "args": [
                {"type": "lit", "value": "10"},
                {"type": "lit", "value": "0"},
            ],
        }
        with self.assertRaises(ZeroDivisionError):
            evaluate(ast_div_zero, {})

    def test_large_numbers(self):
        large_value = float(10**32)
        ast_large_numbers = {
            "type": "bin_op",
            "name": "+",
            "args": [
                {"type": "lit", "value": str(large_value)},
                {"type": "lit", "value": "1"},
            ],
        }
        result = evaluate(ast_large_numbers, {})
        self.assertEqual(result, large_value + 1)

    def test_negative_numbers(self):
        ast_negative_numbers = {
            "type": "bin_op",
            "name": "-",
            "args": [
                {"type": "lit", "value": "-5"},
                {"type": "lit", "value": "3"},
            ],
        }
        result = evaluate(ast_negative_numbers, {})
        self.assertEqual(result, -8)

    # Type Checking Tests
    def test_invalid_type_division(self):
        ast_invalid_type = {
            "type": "bin_op",
            "name": "/",
            "args": [
                {"type": "lit", "value": "'string'"},
                {"type": "lit", "value": "2"},
            ],
        }
        with self.assertRaises(TypeError):
            evaluate(ast_invalid_type, {})

    # Complex Expressions Tests
    def test_nested_expressions(self):
        ast_nested = {
            "type": "bin_op",
            "name": "*",
            "args": [
                {
                    "type": "bin_op",
                    "name": "+",
                    "args": [
                        {"type": "lit", "value": "3"},
                        {"type": "lit", "value": "2"},
                    ],
                },
                {
                    "type": "bin_op",
                    "name": "-",
                    "args": [
                        {"type": "lit", "value": "5"},
                        {"type": "lit", "value": "1"},
                    ],
                },
            ],
        }
        result = evaluate(ast_nested, {})
        self.assertEqual(result, (3 + 2) * (5 - 1))

    def test_multiple_ops(self):
        ast_multiple_ops = {
            "type": "bin_op",
            "name": "+",
            "args": [
                {
                    "type": "bin_op",
                    "name": "*",
                    "args": [
                        {"type": "lit", "value": "2"},
                        {"type": "lit", "value": "3"},
                    ],
                },
                {
                    "type": "bin_op",
                    "name": "/",
                    "args": [
                        {"type": "lit", "value": "10"},
                        {"type": "lit", "value": "2"},
                    ],
                },
            ],
        }
        result = evaluate(ast_multiple_ops, {})
        self.assertEqual(result, (2 * 3) + (10 / 2))

    def test_simple_date_lit_expression(self):
        expression = "d'2023-01-01' == d\"2023-01-01\""
        ast = parse_to_tree(expression)
        result = evaluate(ast, {})
        self.assertEqual(result, True)

    def test_simple_date_lit_expression2(self):
        expression = "d'2023-01-01' == d\"2023-03-01\""
        ast = parse_to_tree(expression)
        result = evaluate(ast, {})
        self.assertEqual(result, False)

    def test_simple_str_lit_expression2(self):
        expression = "'xxx' == \"xxx\""
        ast = parse_to_tree(expression)
        result = evaluate(ast, {})
        self.assertEqual(result, True)

    def test_simple_str_lit_expression2(self):
        expression = "'x' == \"y\""
        ast = parse_to_tree(expression)
        result = evaluate(ast, {})
        self.assertEqual(result, False)

    def test_simple_str_lit_expression2(self):
        expression = "str.concat('x', 'yz')== \"xyz\""
        ast = parse_to_tree(expression)
        result = evaluate(ast, {})
        self.assertEqual(result, True)
        self.assertEqual(evaluate(parse_to_tree("str.replace('banana', 'a', 'x') == 'bxnxnx'"), {}), True)

    def test_simple_date_fun(self):
        self.assertEqual(evaluate(parse_to_tree("date.addDays(d'2024-01-01',2) == d'2024-01-03'"), {}), True)
