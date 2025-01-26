from datetime import datetime
import unittest
import termynus


class TestParserMethods(unittest.TestCase):
    def test_tokenize_simple_case(self):
        input_expression = "tm1 and tm2"
        expected_tokens = ["tm1", "and", "tm2"]
        self.assertEqual(termynus.tokenize(input_expression), expected_tokens)

    def test_tokenize_simple_case_string_lit(self):
        input_expression = "'tm1' and tm2"
        expected_tokens = ["'tm1'", "and", "tm2"]
        self.assertEqual(termynus.tokenize(input_expression), expected_tokens)

    def test_tokenize_simple_case_date_lit(self):
        input_expression = "d'2023-01-01' and tm2"
        expected_tokens = ["d'2023-01-01'", "and", "tm2"]
        self.assertEqual(termynus.tokenize(input_expression), expected_tokens)

    def test_tokenize_simple_case_list_lit(self):
        input_expression = "[tm1,and,tm2]"
        expected_tokens = ["[", "tm1", ",", "and", ",", "tm2", "]"]
        self.assertEqual(termynus.tokenize(input_expression), expected_tokens)

    def test_tokenize_simple_env_call(self):
        input_expression = "fun(tm1,'x',tm2)"
        expected_tokens = ["fun", "(", "tm1", ",", "'x'", ",", "tm2", ")"]
        self.assertEqual(termynus.tokenize(input_expression), expected_tokens)

    def test_tokenize_simple_env_call_b(self):
        input_expression = "fun(tm1,'x',tm2)"
        expected_tokens = ["fun", "(", "tm1", ",", "'x'", ",", "tm2", ")"]
        self.assertEqual(termynus.tokenize(input_expression), expected_tokens)

    def test_tokenize_simple_env_call_dot_interp(self):
        input_expression = "str.concat(tm1.x,'x',tm2.y)"
        expected_tokens = ["str.concat", "(", "tm1.x", ",", "'x'", ",", "tm2.y", ")"]
        self.assertEqual(termynus.tokenize(input_expression), expected_tokens)


"""
    def test_shunting_yard_simple_case(self):
        tokens = ["tm1", "and", "tm2"]
        expected_output = [
            {"type": "id", "value": "tm1"},
            {"type": "id", "value": "tm2"},
            {"name": "and", "type": "bin_op"},
        ]
        self.assertEqual(termynus.shunting_yard(tokens), expected_output)

    def test_parse_to_tree_simple_binary_expression(self):
        expression = "3 + 4"
        expected_tree = {
            "type": "bin_op",
            "name": "+",
            "args": [
                {"type": "lit", "value": 3},
                {"type": "lit", "value": 4},
            ],
        }
        self.assertEqual(termynus.parse_to_tree(expression), expected_tree)

    def test_parse_to_tree_simple_string_lit_expression(self):
        expression = "'x' == \"y\""
        expected_tree = {
            "type": "bin_op",
            "name": "==",
            "args": [
                {"type": "lit_str", "value": "x"},
                {"type": "lit_str", "value": "y"},
            ],
        }
        self.assertEqual(   termynus.parse_to_tree(expression), expected_tree)

    def test_parse_to_tree_simple_date_lit_expression(self):
        expression = "d'2023-01-01' == d\"2023-03-01\""
        expected_tree = {
            "type": "bin_op",
            "name": "==",
            "args": [
                {"type": "lit_date", "value": datetime.fromisoformat("2023-01-01")},
                {"type": "lit_date", "value": datetime.fromisoformat("2023-03-01")},
            ],
        }
        self.assertEqual(termynus.parse_to_tree(expression), expected_tree)

    def test_parse_to_tree_simple_list_expression(self):
        expression = "[3, 'x',  4]"
        expected_tree = {
            "type": "list",
            "elements": [
                {"type": "lit", "value": 3},
                {"type": "lit_str", "value": "x"},
                {"type": "lit", "value": 4},
            ],
        }
        self.assertEqual(termynus.parse_to_tree(expression), expected_tree)

    def test_parse_to_tree_simple_list_expression2(self):
        expression = "[3, 1+2]"
        expected_tree = {
            "type": "list",
            "elements": [
                {"type": "lit", "value": 3},
                {
                    "type": "bin_op",
                    "name": "+",
                    "args": [
                        {"type": "lit", "value": 1},
                        {"type": "lit", "value": 2},
                    ],
                },
            ],
        }
        res = termynus.parse_to_tree(expression)
        self.assertEqual(res, expected_tree)

    def test_parse_to_tree_logical_and_comparison_operators(self):
        expression = "A and B < C or D != E"
        expected_tree = {
            "type": "bin_op",
            "name": "or",
            "args": [
                {
                    "type": "bin_op",
                    "name": "and",
                    "args": [
                        {"type": "id", "value": "A"},
                        {
                            "type": "bin_op",
                            "name": "<",
                            "args": [
                                {"type": "id", "value": "B"},
                                {"type": "id", "value": "C"},
                            ],
                        },
                    ],
                },
                {
                    "type": "bin_op",
                    "name": "!=",
                    "args": [
                        {"type": "id", "value": "D"},
                        {"type": "id", "value": "E"},
                    ],
                },
            ],
        }
        self.assertEqual(termynus.parse_to_tree(expression), expected_tree)

    def test_parse_to_tree_unbalanced_parentheses_1(self):
        expression = "3 + (4 * 2"
        with self.assertRaises(ValueError) as context:
            termynus.parse_to_tree(expression)
        self.assertTrue("Unbalanced parentheses" in str(context.exception))

    def test_parse_to_tree_unbalanced_parentheses_2(self):
        expression = "3 + 4 * 2)"
        with self.assertRaises(ValueError) as context:
            termynus.parse_to_tree(expression)
        self.assertTrue("Unbalanced parentheses" in str(context.exception))

    def test_parse_to_tree_function_call_with_addition(self):
        expression = "addDays(date, 5) + 10"
        expected_tree = {
            "type": "bin_op",
            "name": "+",
            "args": [
                {
                    "type": "fun",
                    "name": "addDays",
                    "args": [{"type": "id", "value": "date"}, {"type": "lit", "value": 5}],
                },
                {"type": "lit", "value": 10},
            ],
        }
        self.assertEqual(termynus.parse_to_tree(expression), expected_tree)

    def test_parse_to_tree_function_call_with_addition2(self):
        expression = "addDays(date, 5) + 10"
        expected_tree = {
            "type": "bin_op",
            "name": "+",
            "args": [
                {
                    "type": "fun",
                    "name": "addDays",
                    "args": [{"type": "id", "value": "date"}, {"type": "lit", "value": 5}],
                },
                {"type": "lit", "value": 10},
            ],
        }
        self.assertEqual(   termynus.parse_to_tree(expression), expected_tree)

    def test_shunting_yard_complex_expression_with_function_calls(self):
        tokens = termynus.tokenize("(addDays(startDate, 10) < addDays(endDate, -5)) and not userActive")
        expected_rpn = [
            {"type": "id", "value": "startDate"},
            {"type": "lit", "value": 10},
            {"type": "fun", "name": "addDays", "args": 2},
            {"type": "id", "value": "endDate"},
            {"type": "lit", "value": -5},
            {"type": "fun", "name": "addDays", "args": 2},
            {"type": "bin_op", "name": "<"},
            {"type": "id", "value": "userActive"},
            {"type": "unary_op", "name": "not"},
            {"type": "bin_op", "name": "and"},
        ]
        self.assertEqual(termynus.shunting_yard(tokens), expected_rpn)

    def test_parse_to_tree_complex_expression_with_function_calls(self):
        expression = "(addDays(startDate, 10) < addDays(endDate, -5)) and userActive"
        expected_tree = {
            "type": "bin_op",
            "name": "and",
            "args": [
                {
                    "type": "bin_op",
                    "name": "<",
                    "args": [
                        {
                            "type": "fun",
                            "name": "addDays",
                            "args": [{"type": "id", "value": "startDate"}, {"type": "lit", "value": 10}],
                        },
                        {
                            "type": "fun",
                            "name": "addDays",
                            "args": [{"type": "id", "value": "endDate"}, {"type": "lit", "value": -5}],
                        },
                    ],
                },
                {"type": "id", "value": "userActive"},
            ],
        }
        self.assertEqual(termynus.parse_to_tree(expression), expected_tree)

    def test_parse_to_tree_nested_function_call_with_arithmetic_operation(self):
        expression = "multiply(addDays(date, 5), subtract(num, 2))"
        expected_tree = {
            "type": "fun",
            "name": "multiply",
            "args": [
                {
                    "type": "fun",
                    "name": "addDays",
                    "args": [{"type": "id", "value": "date"}, {"type": "lit", "value": 5}],
                },
                {
                    "type": "fun",
                    "name": "subtract",
                    "args": [{"type": "id", "value": "num"}, {"type": "lit", "value": 2}],
                },
            ],
        }
        self.assertEqual(termynus.parse_to_tree(expression), expected_tree)
"""

if __name__ == "__main__":
    unittest.main()
