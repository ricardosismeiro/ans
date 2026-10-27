#!/usr/bin/env python3
"""Validate real local Ansible runs; no SSH, sudo or package installation.

Only the course's .ansible/local-demo directory is created and removed.
Run from the prepared virtual environment, or pass --ansible-playbook.
"""
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ansible-playbook', default=shutil.which('ansible-playbook'))
    parser.add_argument('--report', default='evidence/local-validation.json')
    options = parser.parse_args()
    if not options.ansible_playbook:
        parser.error('Activate the virtual environment or pass --ansible-playbook.')
    project = Path(__file__).resolve().parent
    steps = []

    def run(label, playbook, extra=None):
        command = [options.ansible_playbook, '-i', 'localhost,', playbook]
        if extra:
            command.extend(['--extra-vars', json.dumps(extra)])
        result = subprocess.run(command, cwd=project, capture_output=True, text=True)
        if result.returncode:
            raise RuntimeError(f'{label}: Ansible failed\n{result.stdout}\n{result.stderr}')
        recap = re.search(r'localhost\s*:\s*(.+)', result.stdout)
        if not recap:
            raise RuntimeError(f'{label}: play recap missing.')
        counts = {key: int(value) for key, value in re.findall(r'(\w+)=(\d+)', recap[1])}
        if counts.get('failed') or counts.get('unreachable'):
            raise RuntimeError(f'{label}: failed execution: {counts}')
        step = {'stage': label, 'recap': counts,
                'handler_ran': 'RUNNING HANDLER' in result.stdout}
        steps.append(step)
        print(json.dumps(step, ensure_ascii=False))
        return step

    run('Initial cleanup', 'cleanup-local.yml')
    try:
        first = run('First application', 'local-demo.yml')
        second = run('Repeat without changes', 'local-demo.yml')
        values = {'lab_environment': 'test', 'lab_message': 'A < B'}
        changed = run('Change variables', 'local-demo.yml', values)
        repeated = run('Repeat changed variables', 'local-demo.yml', values)
        assert first['recap']['changed'] > 0 and first['handler_ran']
        assert second['recap']['changed'] == 0 and not second['handler_ran']
        assert changed['recap']['changed'] > 0 and changed['handler_ran']
        assert repeated['recap']['changed'] == 0 and not repeated['handler_ran']
        page = (project / '.ansible/local-demo/index.html').read_text()
        assert 'Environment: test' in page
        assert 'A &lt; B' in page
        assert '<html lang="en">' in page
    finally:
        run('Final cleanup', 'cleanup-local.yml')
    clean = not (project / '.ansible/local-demo').exists()
    assert clean, 'Local demonstration directory remains after cleanup.'
    version = subprocess.run([options.ansible_playbook, '--version'],
                             capture_output=True, text=True, check=True).stdout
    report = {'scope': 'Local demonstration only; remote Linux not tested',
              'runtime': version.splitlines()[0], 'steps': steps,
              'content_and_html_escaping_verified': True, 'cleanup_verified': clean}
    target = project / options.report
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
    print(f'Report: {target}')


if __name__ == '__main__':
    main()
