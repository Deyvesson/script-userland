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
# 1. Atualizar pacotes
# --------------------------------------------------------------
log "Atualizando lista de pacotes..."
sudo apt update -qq && ok "Lista atualizada"

# --------------------------------------------------------------
# 2. Instalar dependências essenciais
# --------------------------------------------------------------
log "Instalando pacotes essenciais..."
sudo apt install -y -qq \
    curl \
    wget \
    nano \
    openssh-server \
    net-tools \
    && ok "Pacotes instalados"

# --------------------------------------------------------------
# 3. Configurar o sshd via drop-in (sem sed — robusto)
#    Ubuntu moderno tem "Include /etc/ssh/sshd_config.d/*.conf"
#    no topo do sshd_config, então um arquivo aqui sobrescreve.
# --------------------------------------------------------------
log "Configurando sshd..."

SSHD_MAIN="/etc/ssh/sshd_config"

sudo tee -a "$SSHD_MAIN" >/dev/null <<'EOF'
Port 2223
ListenAddress 0.0.0.0
PasswordAuthentication yes
EOF

ok "sshd configurado"

sudo ssh-keygen -A && ok "Chave gerada"

sudo service ssh stop && ok "Serviço ssh parado"
/usr/sbin/sshd && ok "Serviço ssh iniciado"