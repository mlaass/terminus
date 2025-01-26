import re
from datetime import datetime

# Define the regex pattern for tokens
token_regex = re.compile(
    r'\s*(=>|//|\*\*|==|!=|<=|>=|<<|>>|\|{1,2}|&|\^|d"(?:\\.|[^"\\])*"|d\'(?:\\.|[^\'\\])*\'|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|-\d*\.\d+|-\.\d+|-\d+\b|\$[\w\.]+|\b[\w\.]+\b|\d+\.\d+|\.\d+|\d+\b|[+\-*/%(),<>!=])\s*'
)


iso_date_regex = re.compile(r"^\d{4}-\d{2}-\d{2}(T\d{2}:\d{2}:\d{2}(.\d+)?(Z|(\+|-)\d{2}:\d{2})?)?$")


# Define unary and binary operators, precedence, and associativity in Python dictionaries
unary_operators = {"not", "neg", "floor", "ceil", "abs", "int", "float", "bool"}
binary_operators = {
    "+",
    "-",
    "*",
    "/",
    "//",
    "**",
    "mod",
    "%",
    "<",
    "<=",
    ">",
    ">=",
    "==",
    "!=",
    "and",
    "or",
    "|",
    "&",
    "xor",
    "<<",
    ">>",
}

precedence = {
    "or": 1,
    "and": 2,
    "|": 3,
    "xor": 3,
    "&": 3,
    "==": 4,
    "!=": 4,
    "<": 5,
    ">": 5,
    "<=": 5,
    ">=": 5,
    "+": 6,
    "-": 6,
    "*": 7,
    "/": 7,
    "//": 7,
    "mod": 7,
    "%": 7,
    "<<": 8,
    ">>": 8,
    "**": 9,
    "not": 10,
    "neg": 6,
    "floor": 10,
    "ceil": 10,
    "abs": 10,
    "int": 10,
    "float": 10,
    "bool": 10,
    "function": 20,
}

associativity = {
    "or": "L",
    "and": "L",
    "|": "L",
    "xor": "L",
    "&": "L",
    "==": "L",
    "!=": "L",
    "<": "L",
    ">": "L",
    "<=": "L",
    ">=": "L",
    "+": "L",
    "-": "L",
    "*": "L",
    "/": "L",
    "//": "L",
    "mod": "L",
    "%": "L",
    "<<": "L",
    ">>": "L",
    "**": "R",  # exponentiation is right-associative
    "not": "R",
    "floor": "R",
    "ceil": "R",
    "abs": "R",
    "int": "R",
    "float": "R",
    "bool": "R",
}


def get_stack_precedence(stack):
    top = stack[-1]
    if top["type"] == "fun":
        return precedence["function"]
    return precedence[top["name"]]


def get_precedence(token):
    # print("get_precedence",token)
    return precedence[token]


# Tokenizing function
def tokenize(expression):
    tokens = token_regex.split(expression)
    return [token for token in tokens if token.strip()]


def unescape_string_literal(s):
    # Replace escape sequences with their corresponding characters
    # Common escape sequences: \n, \t, \", \', \\
    return s.encode().decode("unicode_escape")


def is_iso_date_string(value):
    return iso_date_regex.match(value) is not None


def parse_iso_date_string(value):
    try:
        return datetime.fromisoformat(value)
    except ValueError:
        raise ValueError(f"Invalid ISO date string: {value}")


# Functions for checking token types
def is_number(token):
    return re.match(r"^-?\d+(\.\d+)?$", token) is not None


def is_identifier(token):
    # Identifiers can include dots but cannot start with a dollar sign
    return re.match(r"^[a-zA-Z_][\w\.]*$", token) is not None and not token.startswith("$")


def is_function(token):
    # Functions start with a dollar sign and can include dots
    return re.match(r"^\$[a-zA-Z_][\w\.]*$", token) is not None


def is_operator(token):
    if isinstance(token, str):
        return token in binary_operators or token in unary_operators
    elif isinstance(token, dict):
        return is_operator(token.get("name", None))
    return False


def is_binary_operator(token):
    return token in binary_operators


def is_unary_operator(token):
    return token in unary_operators


def shunting_yard(tokens):
    output_queue = []
    operator_stack = []
    argument_count = []  # for function args
    element_count = []  # for list elements

    for token in tokens:
        # print(token, operator_stack, output_queue)
        if is_number(token):
            # It's a number
            try:
                output_queue.append({"type": "lit", "value": float(token)})
            except ValueError:
                output_queue.append({"type": "lit", "value": token})
        elif (token.startswith('"') and token.endswith('"')) or (token.startswith("'") and token.endswith("'")):
            # It's a string literal with potential escaped characters
            string_value = unescape_string_literal(token[1:-1])  # Remove quotes and unescape
            output_queue.append({"type": "lit_str", "value": string_value})
        elif (token.startswith('d"') and token.endswith('"')) or (token.startswith("d'") and token.endswith("'")):
            # It's a date string literal with potential escaped characters
            string_value = unescape_string_literal(token[2:-1])  # Remove quotes and unescape
            if is_iso_date_string(string_value):
                output_queue.append({"type": "lit_date", "value": parse_iso_date_string(string_value)})

        elif is_identifier(token) and not (is_function(token) or is_operator(token)):
            # It's an identifier
            output_queue.append({"type": "id", "value": token})
        elif is_function(token):
            # It's a function
            operator_stack.append({"type": "fun", "name": token})
        elif token == ",":
            # Argument separator
            while operator_stack and operator_stack[-1] not in ["(", "["]:
                output_queue.append(operator_stack.pop())
            if not operator_stack:
                raise ValueError("Misplaced function argument separator or mismatched parentheses/brackets.")
            if operator_stack[-1] == "(":
                if argument_count[-1] == 0:
                    argument_count[-1] += 1  # +1 for first element
                argument_count[-1] += 1  # Increment function argument count
            elif operator_stack[-1] == "[":
                if element_count[-1] == 0:
                    element_count[-1] += 1  # +1 for first element
                element_count[-1] += 1
        elif token == "(":
            argument_count.append(0)
            found_fun = False
            if (
                operator_stack
                and isinstance(operator_stack[-1], dict)
                and operator_stack[-1].get("type", None) == "fun"
            ):
                found_fun = True

            if not found_fun and output_queue and output_queue[-1]["type"] == "id":
                ident = output_queue.pop()
                operator_stack.append({"type": "fun", "name": ident["value"]})
            operator_stack.append(token)
        elif token == "[":
            operator_stack.append(token)
            element_count.append(0)
        elif token == ")":
            # print(")", operator_stack, output_queue)
            while operator_stack and operator_stack[-1] != "(":
                output_queue.append(operator_stack.pop())
            if not operator_stack:
                raise ValueError("Mismatched parentheses when unrolling.")
            operator_stack.pop()
            if operator_stack and operator_stack[-1]["type"] == "fun":
                func = operator_stack.pop()
                args = argument_count.pop()
                func["args"] = args
                output_queue.append(func)

        elif token == "]":
            while operator_stack and operator_stack[-1] != "[":
                output_queue.append(operator_stack.pop())
            if not operator_stack:
                raise ValueError("Mismatched brackets when unrolling.")
            operator_stack.pop()
            output_queue.append({"type": "list", "elements": element_count.pop()})

        elif is_operator(token):
            while (
                operator_stack
                and is_operator(operator_stack[-1])
                and (
                    (associativity[token] == "L" and get_precedence(token) <= get_stack_precedence(operator_stack))
                    or (
                        associativity[token] == "R" and get_precedence(token) < get_stack_precedence(operator_stack)
                    )
                )
            ):
                output_queue.append(operator_stack.pop())
            if is_binary_operator(token):
                operator_stack.append({"type": "bin_op", "name": token})
            else:
                operator_stack.append({"type": "unary_op", "name": token})
        else:
            raise ValueError("Unknown token: " + token)

    while operator_stack:
        if operator_stack[-1] == "(":
            raise ValueError("Mismatched parentheses.")
        if operator_stack[-1] == "[":
            raise ValueError("Mismatched brackets.")
        output_queue.append(operator_stack.pop())

    return output_queue


def check_parentheses_balance(tokens):
    balance = 0
    for token in tokens:
        if token == "(":
            balance += 1
        elif token == ")":
            balance -= 1
        if balance < 0:
            raise ValueError("Unbalanced parentheses: too many closing parentheses")
    if balance > 0:
        raise ValueError("Unbalanced parentheses: missing closing parenthesis - " + str(balance))


def parse_to_tree(expression):
    tokens = tokenize(expression)
    check_parentheses_balance(tokens)
    rpn = shunting_yard(tokens)
    # print(rpn)

    def build_tree(rpn_queue):
        stack = []

        for token in rpn_queue:
            if token["type"] in ["lit", "lit_str", "lit_date", "id"]:
                stack.append(token)
            elif token["type"] == "unary_op":
                args = [stack.pop()]
                stack.append({**token, "args": args})
            elif token["type"] == "bin_op":
                right = stack.pop()
                left = stack.pop()
                if not left or not right:
                    raise ValueError(f"Syntax Error: Insufficient operands for {token}")
                stack.append({**token, "args": [left, right]})
            elif token["type"] == "fun":
                args = [stack.pop() for _ in range(token["args"])]
                args.reverse()
                stack.append({**token, "args": args})
            elif token["type"] == "list":
                elements = [stack.pop() for _ in range(token["elements"])]
                elements.reverse()
                stack.append({**token, "elements": elements})
            # print(token, stack)

        if len(stack) != 1:
            # print("ERROR")
            print(stack)
            raise ValueError(
                "Syntax Error: The user might have not closed a parenthesis or the expression is malformed."
            )

        return stack[0]

    return build_tree(rpn)


# exp = "addDays(startDate, 10) < addDays(endDate, -5) and not userActive()"
# exp = "addDays(d'2023-01-01', 2) == d'2023-01-03'"

# res = tokenize(exp)
# print(res)
# res2 = shunting_yard(res)
# print(f"----------")
# print(res2)
# print(f"----------")
# print(parse_to_tree(exp))
