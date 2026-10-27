# Linux lab — setup and execution

Run commands on the Ubuntu controller from `lab`, unless explicitly marked as target commands. Provide one controller and Ubuntu managed node per learner or pair. Use isolated VMs and preserve state between sessions. Setup happens **before** the two 1h50 sessions.

## 1. Baseline and controller setup

| Component | Fixed course reference |
|---|---|
| Controller and target | Ubuntu 24.04 LTS, Python 3.12, systemd. |
| Engine | ansible-core 2.21.5. |
| Templates/YAML | Jinja2 3.1.6, PyYAML 6.0.3. |
| Connection | SSH keys, sudo-capable account, host key checking enabled. |
| Application | Nginx from the approved Ubuntu repository; state present. |
| Additional collections | None; modules come from ansible.builtin. |

Core 2.21 supports Python 3.12–3.14 on the controller and 3.9–3.14 on the target, according to the [official matrix](https://docs.ansible.com/projects/ansible/latest/reference_appendices/release_and_maintenance.html#ansible-core-support-matrix). The playbooks target Ubuntu; adapt APT, paths and service management for other distributions.

On the controller:

```bash
python3 --version
sudo apt update
sudo apt install -y python3-venv openssh-client ca-certificates
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
ansible --version
python -m pip freeze
```

Save pip freeze and the Nginx version during rehearsal. Direct requirements are pinned; transitive dependencies are not a full lock. Keep the same environment/snapshots across cohorts and rehearse again before upgrading.

## 2. Prepare the Ubuntu target

On the managed VM before class:

```bash
sudo apt update
sudo apt install -y openssh-server python3 python3-apt curl
sudo systemctl enable --now ssh
python3 --version
```

Prepare a dedicated account, SSH key access and required sudo permissions using the organisation's procedure. Replace fictional `lab_automation` and `ubuntu01.lab.example` in `inventory/group_vars/linux.yml` and `inventory/hosts.yml`.

Verify the fingerprint through a trusted channel before accepting the host key. Test using the same account:

```bash
ssh lab_automation@ubuntu01.lab.example
sudo -v
exit
```

The VM should use Ubuntu's default Nginx configuration. Reserve ports 80, 8080 and 8081 without conflicting applications. Prepare any firewall access required by the training network in advance. The supplied health check uses loopback HTTP on the target; learner-browser access is an additional check.

## 3. Confirm before class

On the controller:

```bash
source .venv/bin/activate
ansible-inventory --graph
ansible-playbook 01-ubuntu.yml --list-hosts
ansible linux -m ansible.builtin.ping
bash ci-validate.sh
```

Rehearse the complete remote sequence below, including identical repeat runs, port change and cleanup. Restore the starting snapshot afterwards. Exclude real credentials from the package and logs.

## 4. Session 1

```bash
ansible-doc ansible.builtin.service
ansible linux -m ansible.builtin.command -a 'uptime'
ansible-playbook 01-ubuntu.yml --syntax-check
ansible-playbook 01-ubuntu.yml --ask-become-pass
ansible-playbook 01-ubuntu.yml --ask-become-pass
```

In the target's SSH terminal:

```bash
systemctl is-active nginx
curl -fsS http://127.0.0.1/ansible-lab.txt
dpkg-query -W nginx
```

Add the team file in exercise 4. Change environment/message in vars/lab.yml for exercise 5, apply and verify. Preserve the VM for session 2. APT metadata refresh can report a change after cache_valid_time expires; compare individual tasks.

## 5. Session 2

Slide 13 recap: gather facts and observe two opposite conditions. On Ubuntu, the Ubuntu task runs and the other one is `skipped`. It requires no sudo and changes no configuration.

```bash
ansible-playbook 04-facts-when.yml --limit ubuntu01
```

Apply templates at the initial port 8080:

```bash
ansible-playbook 02-templates.yml --ask-become-pass
ansible-playbook verify.yml --limit ubuntu01
```

Change lab_web_port to 8081 in vars/lab.yml and run:

```bash
ansible-playbook 02-templates.yml --ask-become-pass
ansible-playbook verify.yml --limit ubuntu01
ansible-playbook 02-templates.yml --ask-become-pass
ansible-playbook 03-role.yml --ask-become-pass
ansible-playbook verify.yml --limit ubuntu01
```

Handlers validate Nginx before reload. If validation fails, the invalid file is already on disk: correct the template and reapply. This example does not provide automatic rollback.

Set the final values from exercise 8:

```bash
bash ci-validate.sh
ansible-playbook site.yml --list-hosts
ansible-playbook site.yml --limit ubuntu01 --ask-become-pass
ansible-playbook verify.yml --limit ubuntu01
ansible-playbook site.yml --limit ubuntu01 --ask-become-pass
```

The health check verifies HTTP 200, environment and message in the HTML. Register stores the response and assert checks HTML-escaped values. The first session's file remains on port 80; the template website uses 8080/8081.

## 6. Local fallback demonstration

This creates demonstration files on the controller only. It covers variables, templates, idempotency and handler notifications while access is repaired. It does not install Nginx or replace the remote project.

```bash
ansible-playbook -i localhost, local-demo.yml
ansible-playbook -i localhost, local-demo.yml
ansible-playbook -i localhost, local-demo.yml --extra-vars 'lab_environment=test'
cat .ansible/local-demo/index.html
ansible-playbook -i localhost, cleanup-local.yml
python3 validate-local.py
```

The automated test writes `evidence/local-validation.json`, checking HTML, repeat runs, changed values, handler execution and cleanup. It is a trainer tool, not a required learner exercise.

## 7. SDLC and validation levels

```bash
bash ci-validate.sh
# After an actual lab deployment:
ansible-playbook site.yml --limit ubuntu01 --ask-become-pass --check --diff
```

The script checks inventory/syntax without contacting VMs. Check mode can connect, collect facts and request sudo, and depends on module support/initial state. Real execution and HTTP checks remain necessary. An external pipeline, lint and integration tests are follow-up work, not implemented by this script.

## 8. Cleanup and next cohort

Save evidence first:

```bash
ansible-playbook cleanup.yml --limit ubuntu01 --ask-become-pass
ansible-playbook -i localhost, cleanup-local.yml
```

Remote cleanup removes course files/directories and reloads Nginx if its lab configuration was removed. Nginx remains installed and the service state remains as configured. Restore the snapshot after class to recover the complete starting state.

## 9. Rehearsal record to complete

| Field | Value / evidence |
|---|---|
| Date, cohort and language | To complete. |
| Controller/target Ubuntu and Python | To complete. |
| Ansible version and pip freeze | To complete. |
| Nginx, repository and snapshot | To complete. |
| Alias, address and account, no passwords | To complete. |
| SSH, fingerprint and sudo | To complete. |
| Two first-playbook runs | To complete. |
| Templates, 8080 → 8081 and handlers | To complete. |
| Role, final site and HTTP/content | To complete. |
| Cleanup and snapshot restoration | To complete. |

See [VALIDATION.md](../VALIDATION.md) for checks already performed during revision.
