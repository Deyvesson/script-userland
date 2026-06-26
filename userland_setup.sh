#!/bin/bash
# =============================================================
#  userland_setup.sh — Setup inicial do Ubuntu no Userland
#  Execute UMA VEZ após instalar o Ubuntu do zero:
#    bash userland_setup.sh
#  ou direto do GitHub:
#    wget -qO- https://raw.githubusercontent.com/Deyvesson/script-userland/main/userland_setup.sh | bash
# =============================================================

set -e  # Para execução se qualquer comando falhar

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()   { echo -e "${GREEN}[ OK ]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
fail() { echo -e "${RED}[ERRO]${NC} $1"; }

echo ""
echo "======================================"
echo "  Userland Ubuntu — Setup Inicial"
echo "======================================"
echo ""

# --------------------------------------------------------------
# 0. Detectar necessidade de sudo
# --------------------------------------------------------------
if [ "$(id -u)" -eq 0 ]; then
    SUDO=""
    log "Rodando como root — sudo não necessário"
else
    if command -v sudo > /dev/null 2>&1; then
        SUDO="sudo"
        log "Usuário comum detectado — usando sudo"
    else
        fail "Você não é root e o 'sudo' não está instalado."
        fail "Entre como root primeiro com 'su' e rode o script novamente."
        exit 1
    fi
fi

# --------------------------------------------------------------
# 1. Atualizar pacotes
# --------------------------------------------------------------
log "Atualizando lista de pacotes..."
$SUDO apt-get update -qq && ok "Lista atualizada"

# --------------------------------------------------------------
# 2. Instalar dependências essenciais
# --------------------------------------------------------------
log "Instalando pacotes essenciais..."
$SUDO apt-get install -y -qq \
    openssh-server \
    curl \
    wget \
    nano \
    net-tools \
    procps \
    && ok "Pacotes instalados"

# --------------------------------------------------------------
# 3. Configurar o sshd via drop-in (sem sed — robusto)
#    Ubuntu moderno tem "Include /etc/ssh/sshd_config.d/*.conf"
#    no topo do sshd_config, então um arquivo aqui sobrescreve.
# --------------------------------------------------------------
log "Configurando sshd..."

SSHD_MAIN="/etc/ssh/sshd_config"
SSHD_DROPIN_DIR="/etc/ssh/sshd_config.d"

# Garante que o diretório de drop-in existe e é incluído
$SUDO mkdir -p "$SSHD_DROPIN_DIR"

if ! $SUDO grep -q "^Include .*sshd_config.d" "$SSHD_MAIN" 2>/dev/null; then
    warn "Diretiva Include ausente — adicionando ao sshd_config"
    echo "Include $SSHD_DROPIN_DIR/*.conf" | $SUDO tee -a "$SSHD_MAIN" > /dev/null
fi

# Escreve nossas configurações num arquivo dedicado
$SUDO tee "$SSHD_DROPIN_DIR/00-userland.conf" > /dev/null << 'CONF'
Port 2223
ListenAddress 0.0.0.0
PasswordAuthentication yes
PermitRootLogin no
CONF

ok "sshd configurado via $SSHD_DROPIN_DIR/00-userland.conf (porta 2223)"

# --------------------------------------------------------------
# 4. Gerar chaves do host
# --------------------------------------------------------------
log "Gerando chaves do host SSH..."
$SUDO ssh-keygen -A && ok "Chaves do host geradas"

# Valida a configuração antes de prosseguir
if $SUDO sshd -t 2>/dev/null; then
    ok "Configuração do sshd válida"
else
    warn "sshd -t reportou avisos (veja acima), mas seguindo..."
fi

# --------------------------------------------------------------
# 5. Instalar o script de startup
# --------------------------------------------------------------
log "Instalando script de startup (~/.userland_startup.sh)..."

STARTUP_SCRIPT="$HOME/.userland_startup.sh"

cat > "$STARTUP_SCRIPT" << 'STARTUP'
#!/bin/bash
# -------------------------------------------------------
#  .userland_startup.sh — Executado em cada sessão nova
# -------------------------------------------------------

_ul_start_sshd() {
    if ! pgrep -x sshd > /dev/null 2>&1; then
        if [ "$(id -u)" -eq 0 ]; then
            /usr/sbin/sshd > /dev/null 2>&1
        else
            sudo /usr/sbin/sshd > /dev/null 2>&1
        fi
        echo "[startup] sshd iniciado na porta 2223"
    fi
}

_ul_start_sshd
STARTUP

chmod +x "$STARTUP_SCRIPT"
ok "Script de startup criado"

# --------------------------------------------------------------
# 6. Adicionar startup ao .bashrc (idempotente)
# --------------------------------------------------------------
BASHRC="$HOME/.bashrc"
MARKER="# >>> userland startup <<<"

if ! grep -q "$MARKER" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << BASHRC_ENTRY

$MARKER
if [ -f "\$HOME/.userland_startup.sh" ]; then
    source "\$HOME/.userland_startup.sh"
fi
# >>> end userland startup <<<
BASHRC_ENTRY
    ok ".bashrc atualizado com hook de startup"
else
    warn ".bashrc já possui o hook (pulando)"
fi

# --------------------------------------------------------------
# 7. Iniciar sshd agora para esta sessão
# --------------------------------------------------------------
log "Iniciando sshd agora..."
if pgrep -x sshd > /dev/null 2>&1; then
    warn "sshd já está rodando"
else
    $SUDO /usr/sbin/sshd && ok "sshd iniciado"
fi

# --------------------------------------------------------------
# 8. Resumo final
# --------------------------------------------------------------
echo ""
echo "======================================"
echo -e "${GREEN}  Setup concluído com sucesso!${NC}"
echo "======================================"
echo ""
echo "  SSH disponível em:"
echo "    Porta  : 2223"
echo "    Usuário: $(whoami)"
echo ""
echo "  Conecte pelo PC:"
echo "    ssh $(whoami)@<IP-DO-CELULAR> -p 2223"
echo ""
echo "  Para saber o IP do celular:"
echo "    ip addr show | grep 'inet ' | grep -v 127"
echo ""
