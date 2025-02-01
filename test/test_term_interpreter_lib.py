import unittest
import termynus


class TestInterpreterMethods(unittest.TestCase):
    def test_evaluate_simple_arithmetic(self):
        self.assertEqual(termynus.evaluate("5 + 3"), 8)
        self.assertEqual(termynus.evaluate("10 - 4"), 6)
        self.assertEqual(termynus.evaluate("3 * 4"), 12)
        self.assertEqual(termynus.evaluate("10 / 2"), 5)

    def test_evaluate_complex_arithmetic(self):
        self.assertEqual(termynus.evaluate("2 * (3 + 4) - 5"), 9)
        self.assertEqual(termynus.evaluate("10 / 2 + 3 * 4"), 17)
        self.assertEqual(termynus.evaluate("(5 + 3) * (2 + 2)"), 32)

    def test_evaluate_comparison_operators(self):
        self.assertTrue(termynus.evaluate("5 > 3"))
        self.assertFalse(termynus.evaluate("5 < 3"))
        self.assertTrue(termynus.evaluate("5 >= 5"))
        self.assertTrue(termynus.evaluate("3 <= 5"))
        self.assertTrue(termynus.evaluate("5 == 5"))
        self.assertTrue(termynus.evaluate("5 != 3"))

    def test_evaluate_boolean_operators(self):
        self.assertTrue(termynus.evaluate("true and true"))
        self.assertFalse(termynus.evaluate("true and false"))
        self.assertTrue(termynus.evaluate("true or false"))
        self.assertFalse(termynus.evaluate("false or false"))
        self.assertFalse(termynus.evaluate("not true"))
        self.assertTrue(termynus.evaluate("not false"))

    def test_evaluate_string_operations(self):
        self.assertTrue(termynus.evaluate("'hello' == 'hello'"))
        self.assertFalse(termynus.evaluate("'hello' == 'world'"))
        self.assertTrue(termynus.evaluate("'abc' < 'def'"))
        self.assertFalse(termynus.evaluate("'xyz' < 'abc'"))

    def test_evaluate_date_operations(self):
        self.assertTrue(termynus.evaluate("d'2023-01-01' < d'2023-12-31'"))
        self.assertFalse(termynus.evaluate("d'2023-12-31' < d'2023-01-01'"))
        self.assertTrue(termynus.evaluate("d'2023-01-01' == d'2023-01-01'"))
        self.assertFalse(termynus.evaluate("d'2023-01-01' == d'2023-01-02'"))

    def test_evaluate_list_operations(self):
        self.assertEqual(termynus.evaluate("[1, 2, 3]"), [1, 2, 3])
        self.assertEqual(termynus.evaluate("[1, 2 + 3, 4 * 2]"), [1, 5, 8])
        self.assertEqual(termynus.evaluate("['a', 'b', 'c']"), ["a", "b", "c"])
        self.assertEqual(termynus.evaluate("[1, 'a', d'2023-01-01']"), [1, "a", "2023-01-01"])

    def test_evaluate_mixed_types(self):
        self.assertEqual(termynus.evaluate("1 + 2.5"), 3.5)
        self.assertEqual(termynus.evaluate("10.5 - 3"), 7.5)
        self.assertEqual(termynus.evaluate("2 * 3.5"), 7.0)
        self.assertEqual(termynus.evaluate("10 / 2.5"), 4.0)

    def test_evaluate_precedence(self):
        self.assertEqual(termynus.evaluate("1 + 2 * 3"), 7)
        self.assertEqual(termynus.evaluate("(1 + 2) * 3"), 9)
        self.assertEqual(termynus.evaluate("2 * 3 + 4 * 5"), 26)
        self.assertEqual(termynus.evaluate("2 + 3 * 4 + 5"), 19)

    def test_evaluate_errors(self):
        with self.assertRaises(ZeroDivisionError):
            termynus.evaluate("1 / 0")
        with self.assertRaises(TypeError):
            termynus.evaluate("'hello' + 1")
        with self.assertRaises(ValueError):
            termynus.evaluate("(1 + 2")  # Unmatched parentheses

    def test_evaluate_complex_expressions(self):
        expr = "(2 + 3 * 4 > 10) and (5 + 5 == 10)"
        self.assertTrue(termynus.evaluate(expr))

        expr = "[1, 2 + 3, 'hello'] == [1, 5, 'hello']"
        self.assertTrue(termynus.evaluate(expr))

        expr = "d'2023-01-01' < d'2023-12-31' and 'abc' < 'def'"
        self.assertTrue(termynus.evaluate(expr))


if __name__ == "__main__":
    unittest.main()
