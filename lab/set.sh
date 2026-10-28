#!/usr/bin/env bash
# Ubuntu/Debian with Python 3.12–3.14; Ansible lab requirements.

if [ -z "${BASH_VERSION:-}" ]; then
    printf 'ERROR: use Bash: bash set.sh\n' >&2
    return 1 2>/dev/null || exit 1
fi

_ansible_lab_setup() {
    local lab_dir lab_venv lab_requirements lab_backup lab_script_dir
    local -a lab_privilege=()

    if [[ "$(uname -s)" != Linux ]] || ! command -v apt-get >/dev/null 2>&1; then
        printf 'ERROR: run this script on the Ubuntu/Debian controller.\n' >&2
        return 1
    fi

    lab_script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" || return 1
    if [[ $# -gt 0 ]]; then
        lab_dir="$1"
    elif [[ -f "$PWD/requirements.txt" ]]; then
        lab_dir="$PWD"
    else
        lab_dir="$lab_script_dir"
    fi
    lab_dir="$(cd -- "$lab_dir" && pwd -P)" || return 1
    lab_requirements="$lab_dir/requirements.txt"
    lab_venv="$lab_dir/.venv"

    if [[ ! -r "$lab_requirements" ]]; then
        printf 'ERROR: requirements.txt not found in %s\n' "$lab_dir" >&2
        printf 'Usage: source ./setup-lab.sh /path/to/ans/lab\n' >&2
        return 1
    fi
    if [[ ! -w "$lab_dir" ]]; then
        printf 'ERROR: you need write permission for %s\n' "$lab_dir" >&2
        return 1
    fi

    if (( EUID != 0 )); then
        if ! command -v sudo >/dev/null 2>&1 || ! sudo -v; then
            printf 'ERROR: you need sudo access to install the Ubuntu packages.\n' >&2
            return 1
        fi
        lab_privilege=(sudo)
    fi

    printf '\n[1/5] Install Python, venv, and controller dependencies\n'
    if ! "${lab_privilege[@]}" apt-get -o Acquire::Retries=3 update; then
        printf 'ERROR: apt update failed. Check the network and APT repositories.\n' >&2
        return 1
    fi
    if ! "${lab_privilege[@]}" env DEBIAN_FRONTEND=noninteractive \
        apt-get -o Acquire::Retries=3 -o DPkg::Lock::Timeout=120 \
        install -y python3 python3-venv openssh-client ca-certificates; then
        printf 'ERROR: could not install the Ubuntu packages.\n' >&2
        return 1
    fi
    if ! /usr/bin/python3 -c 'import sys; sys.exit(not ((3, 12) <= sys.version_info[:2] <= (3, 14)))'; then
        printf 'ERROR: these requirements need Python 3.12 to 3.14 on the controller.\n' >&2
        printf 'Use the lab reference environment: Ubuntu 24.04 with Python 3.12.\n' >&2
        return 1
    fi

    printf '\n[2/5] Prepare the virtual environment\n'
    if [[ -e "$lab_venv" || -L "$lab_venv" ]]; then
        if [[ ! -f "$lab_venv/pyvenv.cfg" ]] || \
            ! "$lab_venv/bin/python" -c 'import sys; sys.exit(not (sys.prefix != sys.base_prefix and (3, 12) <= sys.version_info[:2] <= (3, 14)))' 2>/dev/null; then
            lab_backup="${lab_venv}.backup-$(date +%Y%m%d-%H%M%S)-$$"
            if ! mv -- "$lab_venv" "$lab_backup"; then
                printf 'ERROR: could not preserve the existing .venv.\n' >&2
                return 1
            fi
            printf 'Previous environment preserved at: %s\n' "$lab_backup"
        fi
    fi
    if [[ ! -x "$lab_venv/bin/python" ]]; then
        if ! /usr/bin/python3 -m venv "$lab_venv"; then
            printf 'ERROR: could not create .venv.\n' >&2
            return 1
        fi
    fi
    if ! "$lab_venv/bin/python" -m pip --version >/dev/null 2>&1; then
        if ! "$lab_venv/bin/python" -m ensurepip --upgrade; then
            printf 'ERROR: could not set up pip in .venv.\n' >&2
            return 1
        fi
    fi

    printf '\n[3/5] Install requirements.txt in .venv\n'
    if ! "$lab_venv/bin/python" -m pip --require-virtualenv \
        --disable-pip-version-check --retries 3 --timeout 60 \
        install -r "$lab_requirements"; then
        printf 'ERROR: requirements installation failed; see the pip message above.\n' >&2
        return 1
    fi

    printf '\n[4/5] Verify dependencies and Ansible commands\n'
    if ! "$lab_venv/bin/python" -m pip check; then
        printf 'ERROR: incompatible dependencies were detected.\n' >&2
        return 1
    fi
    if [[ ! -x "$lab_venv/bin/ansible" || ! -x "$lab_venv/bin/ansible-inventory" ]]; then
        printf 'ERROR: the requirements did not provide the Ansible commands.\n' >&2
        return 1
    fi
    if ! "$lab_venv/bin/ansible-inventory" --version; then
        printf 'ERROR: ansible-inventory was installed but did not start correctly.\n' >&2
        return 1
    fi

    printf '\n[5/5] Activate .venv\n'
    if ! source "$lab_venv/bin/activate"; then
        printf 'ERROR: could not activate .venv.\n' >&2
        return 1
    fi
    hash -r
    printf '\nInstallation complete. Python: %s\n' "$(command -v python)"
    printf 'Ansible inventory: %s\n' "$(command -v ansible-inventory)"
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        printf '\nTo activate it in your terminal, run:\nsource %q\n' "$lab_venv/bin/activate"
    else
        printf '\nThe .venv is active in this terminal.\n'
    fi
    printf 'To display the inventory:\nansible-inventory -i %q --graph\n' "$lab_dir/inventory/hosts.yml"
}

# Each failure is handled explicitly: does not change the terminal's set -e/-u options or traps.
if _ansible_lab_setup "$@"; then
    unset -f _ansible_lab_setup
    return 0 2>/dev/null || exit 0
else
    unset -f _ansible_lab_setup
    return 1 2>/dev/null || exit 1
fi
