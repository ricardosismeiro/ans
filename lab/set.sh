#!/usr/bin/env bash
# Ubuntu/Debian com Python 3.12–3.14; requisitos do laboratorio Ansible.

if [ -z "${BASH_VERSION:-}" ]; then
    printf 'ERRO: usa Bash: bash set.sh\n' >&2
    return 1 2>/dev/null || exit 1
fi

_ansible_lab_setup() {
    local lab_dir lab_venv lab_requirements lab_backup lab_script_dir
    local -a lab_privilege=()

    if [[ "$(uname -s)" != Linux ]] || ! command -v apt-get >/dev/null 2>&1; then
        printf 'ERRO: executa este script no controlador Ubuntu/Debian.\n' >&2
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
        printf 'ERRO: requirements.txt nao encontrado em %s\n' "$lab_dir" >&2
        printf 'Usa: source ./setup-lab.sh /caminho/ans/lab\n' >&2
        return 1
    fi
    if [[ ! -w "$lab_dir" ]]; then
        printf 'ERRO: precisas de permissao de escrita em %s\n' "$lab_dir" >&2
        return 1
    fi

    if (( EUID != 0 )); then
        if ! command -v sudo >/dev/null 2>&1 || ! sudo -v; then
            printf 'ERRO: precisas de acesso sudo para instalar os pacotes Ubuntu.\n' >&2
            return 1
        fi
        lab_privilege=(sudo)
    fi

    printf '\n[1/5] Instalar Python, venv e dependencias do controlador\n'
    if ! "${lab_privilege[@]}" apt-get -o Acquire::Retries=3 update; then
        printf 'ERRO: apt update falhou. Verifica a rede e os repositorios APT.\n' >&2
        return 1
    fi
    if ! "${lab_privilege[@]}" env DEBIAN_FRONTEND=noninteractive \
        apt-get -o Acquire::Retries=3 -o DPkg::Lock::Timeout=120 \
        install -y python3 python3-venv openssh-client ca-certificates; then
        printf 'ERRO: nao foi possivel instalar os pacotes Ubuntu.\n' >&2
        return 1
    fi
    if ! /usr/bin/python3 -c 'import sys; sys.exit(not ((3, 12) <= sys.version_info[:2] <= (3, 14)))'; then
        printf 'ERRO: estes requisitos exigem Python 3.12 a 3.14 no controlador.\n' >&2
        printf 'Usa a referencia do laboratorio: Ubuntu 24.04 com Python 3.12.\n' >&2
        return 1
    fi

    printf '\n[2/5] Preparar o ambiente virtual\n'
    if [[ -e "$lab_venv" || -L "$lab_venv" ]]; then
        if [[ ! -f "$lab_venv/pyvenv.cfg" ]] || \
            ! "$lab_venv/bin/python" -c 'import sys; sys.exit(not (sys.prefix != sys.base_prefix and (3, 12) <= sys.version_info[:2] <= (3, 14)))' 2>/dev/null; then
            lab_backup="${lab_venv}.backup-$(date +%Y%m%d-%H%M%S)-$$"
            if ! mv -- "$lab_venv" "$lab_backup"; then
                printf 'ERRO: nao foi possivel preservar a .venv existente.\n' >&2
                return 1
            fi
            printf 'Ambiente anterior preservado em: %s\n' "$lab_backup"
        fi
    fi
    if [[ ! -x "$lab_venv/bin/python" ]]; then
        if ! /usr/bin/python3 -m venv "$lab_venv"; then
            printf 'ERRO: nao foi possivel criar a .venv.\n' >&2
            return 1
        fi
    fi
    if ! "$lab_venv/bin/python" -m pip --version >/dev/null 2>&1; then
        if ! "$lab_venv/bin/python" -m ensurepip --upgrade; then
            printf 'ERRO: nao foi possivel preparar o pip na .venv.\n' >&2
            return 1
        fi
    fi

    printf '\n[3/5] Instalar requirements.txt na .venv\n'
    if ! "$lab_venv/bin/python" -m pip --require-virtualenv \
        --disable-pip-version-check --retries 3 --timeout 60 \
        install -r "$lab_requirements"; then
        printf 'ERRO: instalacao dos requisitos falhou; consulta a mensagem do pip acima.\n' >&2
        return 1
    fi

    printf '\n[4/5] Verificar dependencias e comandos Ansible\n'
    if ! "$lab_venv/bin/python" -m pip check; then
        printf 'ERRO: foram detetadas dependencias incompatíveis.\n' >&2
        return 1
    fi
    if [[ ! -x "$lab_venv/bin/ansible" || ! -x "$lab_venv/bin/ansible-inventory" ]]; then
        printf 'ERRO: os requisitos nao disponibilizaram os comandos Ansible.\n' >&2
        return 1
    fi
    if ! "$lab_venv/bin/ansible-inventory" --version; then
        printf 'ERRO: ansible-inventory foi instalado, mas nao iniciou corretamente.\n' >&2
        return 1
    fi

    printf '\n[5/5] Ativar a .venv\n'
    if ! source "$lab_venv/bin/activate"; then
        printf 'ERRO: nao foi possivel ativar a .venv.\n' >&2
        return 1
    fi
    hash -r
    printf '\nInstalacao concluida. Python: %s\n' "$(command -v python)"
    printf 'Ansible inventory: %s\n' "$(command -v ansible-inventory)"
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        printf '\nPara ativar no teu terminal, executa:\nsource %q\n' "$lab_venv/bin/activate"
    else
        printf '\nA .venv esta ativa neste terminal.\n'
    fi
    printf 'Para mostrar o inventario:\nansible-inventory -i %q --graph\n' "$lab_dir/inventory/hosts.yml"
}

# Cada falha e tratada explicitamente: nao altera set -e/-u nem traps do terminal.
if _ansible_lab_setup "$@"; then
    unset -f _ansible_lab_setup
    return 0 2>/dev/null || exit 0
else
    unset -f _ansible_lab_setup
    return 1 2>/dev/null || exit 1
fi
