#!/usr/bin/env bash
# Static validation: does not connect to managed nodes.
set -euo pipefail
cd -- "$(dirname -- "$0")"

ansible-inventory -i inventory/hosts.yml --graph
for course_playbook in 01-ubuntu.yml 02-templates.yml 03-role.yml 04-facts-when.yml site.yml verify.yml cleanup.yml local-demo.yml cleanup-local.yml; do
    ansible-playbook -i inventory/hosts.yml "$course_playbook" --syntax-check
done

