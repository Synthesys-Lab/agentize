#!/usr/bin/env python3
"""
Test case for Python SDK
This test verifies that the project_name module can be imported properly
and that it prints "Hello, World!" when imported.
"""

import sys
import io

def test_import():
    """Test that importing the module prints Hello, World!"""
    # Capture stdout
    captured_output = io.StringIO()
    sys.stdout = captured_output

    try:
        # Import the module (this should print "Hello, World!")
        import project_name

        # Restore stdout
        sys.stdout = sys.__stdout__

        # Get the captured output
        output = captured_output.getvalue()

        # Check if output matches expected
        if output.strip() == "Hello, World!":
            print("Test passed: project_name module imported successfully and printed 'Hello, World!'")
            return 0
        else:
            print(f"Test failed: expected 'Hello, World!', got '{output.strip()}'")
            return 1
    except ImportError as e:
        # Restore stdout
        sys.stdout = sys.__stdout__
        print(f"Test failed: could not import project_name module: {e}")
        return 1
    except Exception as e:
        # Restore stdout
        sys.stdout = sys.__stdout__
        print(f"Test failed with exception: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(test_import())
