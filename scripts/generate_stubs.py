#!/usr/bin/env python3
"""Generate .pyi stub file for the termynus module."""
import inspect
import termynus

STUB_TEMPLATE = '''"""Type stubs for termynus module."""
from typing import Tuple

def get_terminal_size() -> Tuple[int, int]: ...
def is_terminal() -> bool: ...
def get_cwd() -> str: ...

__version__: str
'''

def main():
    # Create the stub file
    with open('termynus.pyi', 'w') as f:
        f.write(STUB_TEMPLATE)

    # Verify the stubs match the actual module
    expected_functions = {'get_terminal_size', 'is_terminal', 'get_cwd'}
    actual_functions = {name for name, obj in inspect.getmembers(termynus)
                       if inspect.isroutine(obj) and not name.startswith('_')}
    
    missing = expected_functions - actual_functions
    extra = actual_functions - expected_functions
    
    if missing or extra:
        print("Warning: Stub file may be out of sync with module!")
        if missing:
            print(f"Missing functions in module: {missing}")
        if extra:
            print(f"Extra functions in module: {extra}")
        exit(1)
    
    print("Successfully generated stubs for termynus")

if __name__ == '__main__':
    main()