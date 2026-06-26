#!/bin/bash
# =============================================================
#  userland_setup.sh — Setup inicial do Ubuntu no Userland
#  Execute UMA VEZ após instalar o Ubuntu do zero:
#    chmod +x userland_setup.sh && bash userland_setup.sh
# =============================================================

set -e  # Para execução se qualquer comando falhar

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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
# 1. Atualizar pacotes
# --------------------------------------------------------------
log "Atualizando lista de pacotes..."
apt-get update -qq && ok "Lista atualizada"

# --------------------------------------------------------------
# 2. Instalar dependências essenciais
# --------------------------------------------------------------
log "Instalando pacotes essenciais..."
apt-get install -y -qq \
    openssh-server \
    curl \
    wget \
    nano \
    net-tools \
    procps \
    && ok "Pacotes instalados"

# --------------------------------------------------------------
# 3. Configurar o sshd_config
# --------------------------------------------------------------
log "Configurando sshd..."

SSHD_CONFIG="/etc/ssh/sshd_config"

# Porta 2223
sed -i 's/^#*Port .*/Port 2223/' "$SSHD_CONFIG"
grep -q "^Port " "$SSHD_CONFIG" || echo "Port 2223" >> "$SSHD_CONFIG"

# Permitir autenticação por senha
sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication yes/' "$SSHD_CONFIG"
grep -q "^PasswordAuthentication " "$SSHD_CONFIG" || echo "PasswordAuthentication yes" >> "$SSHD_CONFIG"

# Escutar em todos os endereços
sed -i 's/^#*ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/' "$SSHD_CONFIG"
grep -q "^ListenAddress " "$SSHD_CONFIG" || echo "ListenAddress 0.0.0.0" >> "$SSHD_CONFIG"

# Permitir login como usuário normal
sed -i 's/^#*PermitRootLogin .*/PermitRootLogin no/' "$SSHD_CONFIG"

ok "sshd_config configurado (porta 2223)"

# --------------------------------------------------------------
# 4. Gerar chaves do host
# --------------------------------------------------------------
log "Gerando chaves do host SSH..."
ssh-keygen -A && ok "Chaves do host geradas"

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
        /usr/sbin/sshd > /dev/null 2>&1
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
    /usr/sbin/sshd && ok "sshd iniciado"
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
