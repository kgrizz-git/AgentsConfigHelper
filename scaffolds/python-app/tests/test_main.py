"""Tests for the main module."""

from your_project_name import main


def test_main_runs() -> None:
    """Test that main function runs without error."""
    try:
        main()
    except Exception as e:
        raise AssertionError(f"main() raised an exception: {e}")
