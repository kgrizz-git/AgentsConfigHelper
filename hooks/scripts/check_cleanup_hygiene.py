#!/usr/bin/env python3
"""
Cleanup hygiene check for completed work artifacts.

Warns when:
- to_do.md/TODO.md has completed items that should be removed/logged
- Plans are marked complete but not archived to plans/archive/
- .context/ has old scratch files (>14 days by default)
- Recent user-visible commits lack changelog entries

Environment variables:
POLICY_CONTEXT_MAX_AGE_DAYS - Max age for .context/ files (default: 14)
POLICY_WARN_CHANGELOG_DAYS - Days to check back for missing changelog entries (default: 7)
POLICY_WARN_AS_ERROR - Set to 1 to treat warnings as errors (default: 0)
"""

import os
import sys
import re
from pathlib import Path
from datetime import datetime, timedelta
import subprocess

def get_env_int(name, default):
    """Get integer from environment with default."""
    try:
        return int(os.environ.get(name, default))
    except ValueError:
        return default

def check_todo_cleanup():
    """Check for completed items in TODO files."""
    issues = []
    todo_files = ['to_do.md', 'TODO.md']
    
    for todo_file in todo_files:
        if not Path(todo_file).exists():
            continue
            
        with open(todo_file, 'r') as f:
            content = f.read()
            
        # Check for completed checklist items
        completed_items = re.findall(r'^-\s+\[x\]', content, re.MULTILINE)
        if completed_items:
            issues.append(f"{todo_file}: Found {len(completed_items)} completed items that should be removed/logged")
    
    return issues

def check_plan_archival():
    """Check for completed plans not archived."""
    issues = []
    plans_dir = Path('plans')
    
    if not plans_dir.exists():
        return issues
    
    # Skip archived plans
    archive_dir = plans_dir / 'archive'
    
    for plan_file in plans_dir.glob('*.md'):
        # Skip archive directory
        if archive_dir in plan_file.parents:
            continue
            
        with open(plan_file, 'r') as f:
            content = f.read()
            
        # Check for complete or abandoned status
        if re.search(r'Status:\s*(complete|abandoned)', content, re.IGNORECASE):
            issues.append(f"{plan_file}: Plan marked complete/abandoned but not in plans/archive/")
    
    return issues

def check_context_files(max_age_days):
    """Check for old .context/ files."""
    issues = []
    context_dir = Path('.context')
    
    if not context_dir.exists():
        return issues
    
    cutoff = datetime.now() - timedelta(days=max_age_days)
    
    for context_file in context_dir.iterdir():
        if context_file.is_file():
            mtime = datetime.fromtimestamp(context_file.stat().st_mtime)
            if mtime < cutoff:
                age_days = (datetime.now() - mtime).days
                issues.append(f"{context_file}: Scratch file {age_days} days old (consider cleanup)")
    
    return issues

def check_changelog_entries(days_back):
    """Check for recent commits that might need changelog entries."""
    issues = []
    
    try:
        # Get recent commits
        result = subprocess.run(
            ['git', 'log', f'--since={days_back}days ago', '--pretty=format:%h %s'],
            capture_output=True, text=True, check=True
        )
        
        if not result.stdout.strip():
            return issues
            
        recent_commits = result.stdout.strip().split('\n')
        
        # Check if changelog exists
        changelog_files = ['CHANGELOG.md', 'CHANGELOG.dev.md', 'MAINTENANCE.md']
        has_changelog = any(Path(f).exists() for f in changelog_files)
        
        if not has_changelog:
            # No changelog files exist, can't check
            return issues
            
        # This is a rough heuristic - warn if there are significant commits
        # but the changelog hasn't been updated recently
        significant_commits = [
            c for c in recent_commits 
            if not any(skip in c.lower() for skip in ['merge', 'wip', 'draft', 'cleanup', 'typo'])
        ]
        
        if len(significant_commits) > 3:  # More than 3 significant commits
            # Check if any changelog was modified in the period
            changelog_modified = False
            for cf in changelog_files:
                if Path(cf).exists():
                    try:
                        result = subprocess.run(
                            ['git', 'log', f'--since={days_back}days ago', '--pretty=format:%h', cf],
                            capture_output=True, text=True, check=True
                        )
                        if result.stdout.strip():
                            changelog_modified = True
                            break
                    except subprocess.CalledProcessError:
                        pass
            
            if not changelog_modified:
                issues.append(f"Found {len(significant_commits)} significant commits in last {days_back} days but no changelog updates")
    
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Not a git repo or git not available
        pass
    
    return issues

def main():
    warn_as_error = get_env_int('POLICY_WARN_AS_ERROR', 0)
    context_max_age = get_env_int('POLICY_CONTEXT_MAX_AGE_DAYS', 14)
    changelog_days = get_env_int('POLICY_WARN_CHANGELOG_DAYS', 7)
    
    all_issues = []
    
    # Run all checks
    all_issues.extend(check_todo_cleanup())
    all_issues.extend(check_plan_archival())
    all_issues.extend(check_context_files(context_max_age))
    all_issues.extend(check_changelog_entries(changelog_days))
    
    if not all_issues:
        print("✓ Cleanup hygiene check passed")
        return 0
    
    # Report issues
    print("Cleanup hygiene warnings:")
    for issue in all_issues:
        print(f"  ⚠ {issue}")
    
    print("\nRun 'prompts/cleanup-completed-work.md' to address these issues")
    
    if warn_as_error:
        print("\nPOLICY_WARN_AS_ERROR=1: treating warnings as errors")
        return 1
    
    return 0

if __name__ == '__main__':
    sys.exit(main())
