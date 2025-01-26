import math
import operator
import re
import statistics
import datetime


unary_operators = {
    "not": operator.not_,
    "inv": operator.inv,
    "~": operator.inv,
    "neg": operator.neg,
    "floor": math.floor,
    "trunc": math.trunc,
    "ceil": math.ceil,
    "isinf": math.isinf,
    "isnan": math.isnan,
    "isfinite": math.isfinite,
    "abs": operator.abs,
    "int": int,
    "str": str,
    "float": float,
    "bool": bool,
}

binary_operators = {
    "+": operator.add,
    "-": operator.sub,
    "*": operator.mul,
    "/": operator.truediv,
    "//": operator.floordiv,
    "**": operator.pow,
    "pow": operator.pow,
    "mod": operator.mod,
    "%": operator.mod,
    "<": operator.lt,
    "<=": operator.le,
    ">": operator.gt,
    ">=": operator.ge,
    "==": operator.eq,
    "!=": operator.ne,
    "and": lambda a, b: a and b,
    "or": lambda a, b: a or b,
    "|": operator.or_,
    "&": operator.and_,
    "xor": operator.xor,
    "<<": operator.lshift,
    ">>": operator.rshift,
}


def builtin_mean(*args):
    return statistics.mean(list(args))


def builtin_fmean(*args):
    return statistics.fmean(list(args))


def builtin_geometric_mean(*args):
    return statistics.geometric_mean(list(args))


def builtin_median(*args):
    return statistics.median(list(args))


def builtin_stdev(*args):
    return statistics.stdev(list(args))


def builtin_variance(*args):
    return statistics.variance(list(args))


# string builtins:
def builtin_concat(*args):
    return "".join(map(str, args))


def builtin_length(s):
    return len(s)


def builtin_substring(s, start, length=None):
    return s[start : start + length] if length is not None else s[start:]


def builtin_replace(s, old, new):
    return s.replace(old, new)


def builtin_to_upper(s):
    return s.upper()


def builtin_to_lower(s):
    return s.lower()


def builtin_trim(s):
    return s.strip()


def builtin_split(s, delimiter):
    return s.split(delimiter)


def builtin_index_of(s, substring):
    return s.find(substring)


def builtin_contains(s, substring):
    return substring in s


def builtin_starts_with(s, substring):
    return s.startswith(substring)


def builtin_ends_with(s, substring):
    return s.endswith(substring)


def builtin_regex_match(s, pattern):
    return re.search(pattern, s) is not None


def builtin_format(template, *args):
    return template.format(*args)


# date builtins
def parse_iso_date(date_str):
    return datetime.datetime.fromisoformat(date_str)


def format_date(date_obj, format_str="%Y-%m-%d"):
    return date_obj.strftime(format_str)


def add_days(date_obj, days):
    return date_obj + datetime.timedelta(days=days)


def add_hours(date_obj, hours):
    return date_obj + datetime.timedelta(hours=hours)


def add_minutes(date_obj, minutes):
    return date_obj + datetime.timedelta(minutes=minutes)


def add_seconds(date_obj, seconds):
    return date_obj + datetime.timedelta(seconds=seconds)


def day_of_week(date_obj):
    return date_obj.strftime("%A")


def day_of_month(date_obj):
    return date_obj.day


def day_of_year(date_obj):
    return date_obj.timetuple().tm_yday


def month_of_year(date_obj):
    return date_obj.month


def year_of_date(date_obj):
    return date_obj.year


def week_of_year(date_obj):
    return date_obj.isocalendar()[1]


# list builtins
def append_to_list(lst, item):
    lst.append(item)
    return lst


def concat_lists(lst1, lst2):
    return lst1 + lst2


def list_get(lst, index):
    return lst[index]


def list_put(lst, index, item):
    lst[index] = item
    return lst


def slice_list(lst, start, end=None):
    return lst[start:end]


def list_map(function, lst):
    return list(map(function, lst))


def list_filter(function, lst):
    return list(filter(function, lst))


def apply_function(function, args):
    return function(*args)


builtin_env = {
    # math
    "min": min,
    "max": max,
    "log": math.log,
    "log1p": math.log1p,
    "log2": math.log2,
    "log10": math.log10,
    "exp": math.exp,
    "fsum": math.fsum,
    "gcd": math.gcd,
    "sqrt": math.sqrt,
    "isqrt": math.isqrt,
    "cos": math.cos,
    "sin": math.sin,
    "tan": math.tan,
    "acos": math.acos,
    "asin": math.asin,
    "atan": math.atan,
    "degrees": math.degrees,
    "radians": math.radians,
    "mean": builtin_mean,
    "fmean": builtin_fmean,
    "geometric_mean": builtin_geometric_mean,
    "median": builtin_median,
    "stdev": builtin_stdev,
    "variance": builtin_variance,
    "pi": math.pi,
    "e": math.e,
    "inf": math.inf,
    "tau": math.tau,
    "nan": math.nan,
    # string functions:
    "str.concat": builtin_concat,
    "str.length": builtin_length,
    "str.substring": builtin_substring,
    "str.replace": builtin_replace,
    "str.toUpper": builtin_to_upper,
    "str.toLower": builtin_to_lower,
    "str.trim": builtin_trim,
    "str.split": builtin_split,
    "str.indexOf": builtin_index_of,
    "str.contains": builtin_contains,
    "str.startsWith": builtin_starts_with,
    "str.endsWith": builtin_ends_with,
    "str.regexMatch": builtin_regex_match,
    "str.format": builtin_format,
    # date stuff
    "date.parse": parse_iso_date,
    "date.format": format_date,
    "date.addDays": add_days,
    "date.addHours": add_hours,
    "date.addMinutes": add_minutes,
    "date.addSeconds": add_seconds,
    "date.dayOfWeek": day_of_week,
    "date.dayOfMonth": day_of_month,
    "date.dayOfYear": day_of_year,
    "date.month": month_of_year,
    "date.year": year_of_date,
    "date.week": week_of_year,
    # list stuff
    "list.length": len,
    "list.append": append_to_list,
    "list.concat": concat_lists,
    "list.get": list_get,
    "list.put": list_put,
    "list.slice": slice_list,
    "list.map": list_map,
    "list.filter": list_filter,
    "apply": apply_function,
}


def evaluate(ast, env=None, join_builtin=True):
    if env is None:
        env = {}
    # join with builtin env
    if join_builtin:
        env = {**builtin_env, **env}

    if ast["type"] == "bin_op":
        left_val = evaluate(ast["args"][0], env, join_builtin=False)
        right_val = evaluate(ast["args"][1], env, join_builtin=False)
        return binary_operators[ast["name"]](left_val, right_val)
    elif ast["type"] == "unary_op":
        val = evaluate(ast["args"][0], env, join_builtin=False)
        return unary_operators[ast["name"]](val)
    elif ast["type"] == "fun":
        args = [evaluate(arg, env, join_builtin=False) for arg in ast["args"]]
        return env[ast["name"]](*args)
    elif ast["type"] == "list":
        return [evaluate(element, env, join_builtin=False) for element in ast["elements"]]
    elif ast["type"] == "lit":
        if isinstance(ast["value"], str):
            if ast["value"].lower() == "true":
                return 1
            if ast["value"].lower() == "false":
                return 0
            if (ast["value"][0] == '"' or ast["value"][0] == "'") and (
                ast["value"][-1] == '"' or ast["value"][-1] == "'"
            ):
                return ast["value"][1:-1]  # for strings
            return float(ast["value"])  # assuming all lits are float otherwise
        else:
            return ast["value"]
    elif ast["type"] == "lit_str":
        if not isinstance(ast["value"], str):
            raise ValueError(f"Not a valid string literal: {ast['value']}")
        else:
            return ast["value"]
    elif ast["type"] == "lit_date":
        return ast["value"]

    elif ast["type"] == "id":
        identifier = ast["value"]
        if identifier in env:
            return env[identifier]
        else:
            raise NameError(f"Undefined identifier: {identifier}")
    else:
        raise ValueError(f"Unknown AST node type: {ast['type']}")
