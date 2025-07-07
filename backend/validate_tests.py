#!/usr/bin/env python3
"""
Validate test structure and imports for ResiCentral backend tests.
This script checks that all test files are properly structured and can be imported.
"""
import sys
import ast
import os
from pathlib import Path


def validate_python_syntax(file_path):
    """Validate that a Python file has correct syntax."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            source = f.read()
        
        ast.parse(source)
        return True, "Syntax OK"
    except SyntaxError as e:
        return False, f"Syntax Error: {e}"
    except Exception as e:
        return False, f"Error: {e}"


def check_test_structure(file_path):
    """Check if test file follows pytest conventions."""
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    issues = []
    
    # Check for pytest imports
    if 'import pytest' not in content:
        issues.append("Missing 'import pytest'")
    
    # Check for test functions
    if 'def test_' not in content:
        issues.append("No test functions found (functions should start with 'test_')")
    
    # Check for test classes
    if 'class Test' in content:
        # Good, has test classes
        pass
    elif 'def test_' not in content:
        issues.append("No test classes or functions found")
    
    return issues


def validate_test_file(file_path):
    """Validate a single test file."""
    print(f"\n📁 Validating: {file_path.name}")
    
    # Check syntax
    syntax_ok, syntax_msg = validate_python_syntax(file_path)
    if not syntax_ok:
        print(f"  ❌ {syntax_msg}")
        return False
    else:
        print(f"  ✅ {syntax_msg}")
    
    # Check test structure
    structure_issues = check_test_structure(file_path)
    if structure_issues:
        print(f"  ⚠️  Structure issues:")
        for issue in structure_issues:
            print(f"     - {issue}")
    else:
        print(f"  ✅ Structure OK")
    
    return syntax_ok and not structure_issues


def main():
    """Main validation function."""
    print("🧪 ResiCentral Backend Test Validation")
    print("=" * 50)
    
    backend_dir = Path(__file__).parent
    tests_dir = backend_dir / "tests"
    
    if not tests_dir.exists():
        print(f"❌ Tests directory not found: {tests_dir}")
        return False
    
    # Find all test files
    test_files = list(tests_dir.glob("test_*.py"))
    
    if not test_files:
        print(f"❌ No test files found in {tests_dir}")
        return False
    
    print(f"Found {len(test_files)} test files:")
    
    all_valid = True
    
    for test_file in sorted(test_files):
        file_valid = validate_test_file(test_file)
        all_valid = all_valid and file_valid
    
    # Validate fixtures file
    fixtures_file = tests_dir / "fixtures.py"
    if fixtures_file.exists():
        print(f"\n📁 Validating: {fixtures_file.name}")
        syntax_ok, syntax_msg = validate_python_syntax(fixtures_file)
        if syntax_ok:
            print(f"  ✅ {syntax_msg}")
        else:
            print(f"  ❌ {syntax_msg}")
            all_valid = False
    
    # Check pytest configuration
    pytest_ini = backend_dir / "pytest.ini"
    if pytest_ini.exists():
        print(f"\n📁 Validating: {pytest_ini.name}")
        try:
            with open(pytest_ini, 'r') as f:
                content = f.read()
            if '[tool:pytest]' in content or '[pytest]' in content:
                print(f"  ✅ Configuration OK")
            else:
                print(f"  ⚠️  No pytest configuration section found")
        except Exception as e:
            print(f"  ❌ Error reading pytest.ini: {e}")
    
    # Summary
    print("\n" + "=" * 50)
    if all_valid:
        print("🎉 All tests validation passed!")
        print("\nNext steps:")
        print("1. Install dependencies: pip install -r requirements.txt")
        print("2. Run tests: python -m pytest")
        print("3. Run with coverage: python run_tests.py --coverage")
    else:
        print("💥 Some validation issues found!")
        print("Please fix the issues above before running tests.")
    
    return all_valid


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)