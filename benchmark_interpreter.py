import timeit
import random
from typing import List
import statistics
import sys
from pathlib import Path
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
        # "1e5 + -.123e-2",
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
        # "d'2023-01-01' < d'2023-12-31'",
        # # Boolean operations
        "(5 < 3)",
        "(5 > 3) and (2 < 4)",
        "(5 < 3) or (2 < 4)",
        # "not(5 < 3)",
        # "!(5 < 3)",
        # "(5 > 3 and 2 < 4) or not(1 == 1)",
        # # Complex expressions
        # "2 * (3 + 4) - 5",
        # "[1, 2, 3] == [1, 2, 3]",
        # "'hello' + ' world'",
        # "42 + 3.14 * 2",
        # "(5 > 3) and ('abc' < 'def')",
        # "[1, 'two', d'2023-01-01']",
    ]


def benchmark_implementation(name: str, evaluate_func, expressions: List[str], iterations: int = 10000):
    """Benchmark a specific implementation."""
    times = []

    def run_evaluate():
        for expr in expressions:
            try:
                evaluate_func(expr)
            except Exception as e:
                print(f"Error evaluating {expr}: {e}")

    # Warm-up run
    run_evaluate()

    # Actual timing
    for _ in range(iterations):
        time = timeit.timeit(run_evaluate, number=1)
        times.append(time)

    avg_time = statistics.mean(times)
    median_time = statistics.median(times)
    std_dev = statistics.stdev(times)

    print(f"\n{name} Results:")
    print(f"total time: {sum(times):.6f} seconds")
    print(f"Average time: {avg_time:.6f} seconds")
    print(f"Median time: {median_time:.6f} seconds")
    print(f"Std Dev: {std_dev:.6f} seconds")
    print(f"Min time: {min(times):.6f} seconds")
    print(f"Max time: {max(times):.6f} seconds")

    return {"avg": avg_time, "median": median_time, "std_dev": std_dev, "min": min(times), "max": max(times)}


def main():
    # Get test expressions
    print("Loading test expressions...")
    expressions = get_test_expressions()

    print("\nSample of test expressions:")
    for expr in expressions[:5]:
        print(f"  {expr}")
    print(f"Total number of expressions: {len(expressions)}")

    print("\nRunning benchmarks...")

    # Benchmark both implementations
    py_results = benchmark_implementation("Python Implementation", py_evaluate, expressions)
    zig_results = benchmark_implementation("Zig Implementation", zig_evaluate, expressions)

    # Compare results
    speedup = py_results["avg"] / zig_results["avg"]
    print(f"\nSpeedup (Python/Zig): {speedup:.2f}x")


if __name__ == "__main__":
    main()
