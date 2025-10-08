#!/usr/bin/env python3
import json
import os
import sys
import subprocess
import textwrap
from pathlib import Path
import requests

REPO = os.environ.get("GITHUB_REPOSITORY", "")
TOKEN = os.environ.get("GITHUB_TOKEN", "")
API = f"https://api.github.com/repos/{REPO}"
TASKS_FILE_CANDIDATES = [
    Path(".taskmaster/tasks/tasks.json"),
    Path("tasks/tasks.json"),
]

LABEL = "taskmaster"
HEAD_SHA = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip()

if not REPO or not TOKEN:
    print("Missing GITHUB_REPOSITORY or GITHUB_TOKEN", file=sys.stderr)
    sys.exit(1)

def gh_request(method: str, path: str, **kwargs):
    headers = kwargs.pop("headers", {})
    headers["Authorization"] = f"Bearer {TOKEN}"
    headers["Accept"] = "application/vnd.github+json"
    url = f"{API}{path}"
    r = requests.request(method, url, headers=headers, **kwargs)
    if r.status_code // 100 != 2:
        print(f"GitHub API error {r.status_code}: {r.text}", file=sys.stderr)
    return r

def ensure_label():
    # Create label if missing
    r = gh_request("GET", "/labels")
    names = [x["name"] for x in r.json()]
    if LABEL not in names:
        gh_request("POST", "/labels", json={"name": LABEL, "color": "0ea5e9", "description": "Task Master task"})

def load_tasks():
    for p in TASKS_FILE_CANDIDATES:
        if p.exists():
            with open(p) as f:
                data = json.load(f)
            return data.get("tasks", [])
    return []


def list_all_issues():
    issues = []
    page = 1
    while True:
        r = gh_request("GET", f"/issues?state=all&labels={LABEL}&per_page=100&page={page}")
        batch = r.json()
        if not batch:
            break
        issues.extend(batch)
        page += 1
    return issues


def changed_files():
    out = subprocess.check_output(["git", "show", "--name-only", "--pretty=", "HEAD"], text=True)
    return [p for p in out.splitlines() if p.strip()]


def read_snippet(path: str, max_lines: int = 60):
    try:
        with open(path, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
        return "".join(lines[:max_lines])
    except Exception:
        return ""


def main():
    ensure_label()
    tasks = load_tasks()
    if not tasks:
        print("No tasks loaded; skipping")
        return

    issues = list_all_issues()
    by_title = {i["title"]: i for i in issues}

    files = changed_files()
    snippet_file = None
    if files:
        # Prefer a source file for example code
        for cand in files:
            if any(cand.endswith(ext) for ext in [".swift", ".metal", ".py", ".md"]):
                snippet_file = cand
                break
        if not snippet_file:
            snippet_file = files[0]

    for t in tasks:
        tid = t.get("id") or t.get("title")
        title = f"[TM] {tid}: {t.get('title','')}".strip()
        body = textwrap.dedent(f"""
        Task Master Sync
        
        - ID: `{tid}`
        - Status: `{t.get('status','todo')}`
        - Labels: {t.get('labels', [])}
        - Owner: {t.get('owner','')}
        - Acceptance: {t.get('acceptance', [])}
        - Links: {t.get('links', [])}
        
        Latest commit: `{HEAD_SHA}`
        Changed files (last commit): {files}
        """)

        # Ensure issue exists
        if title not in by_title:
            r = gh_request("POST", "/issues", json={"title": title, "body": body, "labels": [LABEL]})
            if r.status_code // 100 == 2:
                by_title[title] = r.json()
        else:
            # Update body a bit so it remains fresh
            num = by_title[title]["number"]
            gh_request("PATCH", f"/issues/{num}", json={"body": body})

        # Close if done
        if t.get("status") in ("done", "complete", "closed"):
            iss = by_title[title]
            num = iss["number"]
            comment = textwrap.dedent("""
            Closing via Task Master status.

            Summary:
            - Task marked complete in .taskmaster/tasks/tasks.json
            - This action adds proof-of-work: commit hash, changed files, and a short code excerpt.
            
            Code excerpt:
            """)
            if snippet_file:
                snippet = read_snippet(snippet_file)
                if snippet:
                    comment += f"\n```\n{snippet}\n```\n"
            gh_request("POST", f"/issues/{num}/comments", json={"body": comment})
            gh_request("PATCH", f"/issues/{num}", json={"state": "closed"})

if __name__ == "__main__":
    main()
