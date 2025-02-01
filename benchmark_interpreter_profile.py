import timeit
import random
from typing import List
import statistics
import sys
from pathlib import Path
import cProfile
import pstats
from pstats import SortKey
import time
from termynus import evaluate as zig_evaluate
from service.term_interpreter import evaluate_str as py_evaluate

# Add the project root to Python path
sys.path.append(str(Path(__file__).parent.parent))


def get_test_expressions() -> List[str]:
    """Get a list of test expressions from our test cases."""
    return [
        # Simple arithmetic
        "5 + 3",
        "10 - 4",
        "3 * 4",
        "10 / 2",
        # Complex arithmetic
        "42 + 5",
        "42 + 3.14",
        "10 / 3",
        "2 * (3 + 4) - 5",
        # Literals
        "42",
        "3.14",
        "'hello'",
        "d'2023-01-01'",
        "[1, 2, 3]",
        # Comparisons
        "5 > 3",
        "5 < 3",
        "5 == 5",
        "5 != 3",
        "'abc' == 'def'",
        # Boolean operations
        "(5 < 3)",
        "(5 > 3) and (2 < 4)",
        "(5 < 3) or (2 < 4)",
    ]


def profile_single_expression(evaluate_func, expr: str, iterations: int = 1000) -> dict:
    """Profile a single expression evaluation."""
    times = []
    for _ in range(iterations):
        start = time.perf_counter()
        try:
            evaluate_func(expr)
        except Exception as e:
            print(f"Error evaluating {expr}: {e}")
        end = time.perf_counter()
        times.append(end - start)

    return {
        "expr": expr,
        "avg": statistics.mean(times),
        "median": statistics.median(times),
        "min": min(times),
        "max": max(times),
        "std_dev": statistics.stdev(times),
    }


def benchmark_implementation(name: str, evaluate_func, expressions: List[str], iterations: int = 10000):
    """Benchmark a specific implementation."""
    print(f"\n{name} Detailed Results:")

    # Profile each expression individually
    expr_profiles = []
    for expr in expressions:
        profile = profile_single_expression(evaluate_func, expr, iterations=100)
        expr_profiles.append(profile)
        print(f"\nExpression: {profile['expr']}")
        print(f"  Average time: {profile['avg']:.9f} seconds")
        print(f"  Median time: {profile['median']:.9f} seconds")
        print(f"  Min time: {profile['min']:.9f} seconds")
        print(f"  Max time: {profile['max']:.9f} seconds")

    # Overall benchmark
    times = []

    def run_evaluate():
        for expr in expressions:
            try:
                evaluate_func(expr)
            except Exception as e:
                print(f"Error evaluating {expr}: {e}")

    # Profile the entire run
    profiler = cProfile.Profile()
    profiler.enable()

    # Warm-up run
    run_evaluate()

    # Actual timing
    for _ in range(iterations):
        time = timeit.timeit(run_evaluate, number=1)
        times.append(time)

    profiler.disable()

    # Print cProfile stats
    stats = pstats.Stats(profiler).sort_stats(SortKey.CUMULATIVE)
    print(f"\n{name} cProfile Results:")
    stats.print_stats(20)  # Print top 20 entries

    avg_time = statistics.mean(times)
    median_time = statistics.median(times)
    std_dev = statistics.stdev(times)

    print(f"\n{name} Overall Results:")
    print(f"Average time: {avg_time:.6f} seconds")
    print(f"Median time: {median_time:.6f} seconds")
    print(f"Std Dev: {std_dev:.6f} seconds")
    print(f"Min time: {min(times):.6f} seconds")
    print(f"Max time: {max(times):.6f} seconds")

    return {
        "avg": avg_time,
        "median": median_time,
        "std_dev": std_dev,
        "min": min(times),
        "max": max(times),
        "expr_profiles": expr_profiles,
    }


def main():
    # Get test expressions
    print("Loading test expressions...")
    expressions = get_test_expressions()
    print(f"Total number of expressions: {len(expressions)}")

    print("\nRunning benchmarks...")

    # Benchmark both implementations
    py_results = benchmark_implementation("Python Implementation", py_evaluate, expressions)
    zig_results = benchmark_implementation("Zig Implementation", zig_evaluate, expressions)

    # Compare results
    speedup = py_results["avg"] / zig_results["avg"]
    print(f"\nOverall Speedup (Python/Zig): {speedup:.2f}x")

    # Compare individual expressions
    print("\nExpression-by-expression comparison:")
    for py_prof, zig_prof in zip(py_results["expr_profiles"], zig_results["expr_profiles"]):
        expr = py_prof["expr"]
        speedup = py_prof["avg"] / zig_prof["avg"]
        print(f"\n{expr}:")
        print(f"  Python: {py_prof['avg']:.9f}s")
        print(f"  Zig:    {zig_prof['avg']:.9f}s")
        print(f"  Ratio:  {speedup:.2f}x")


if __name__ == "__main__":
    main()
