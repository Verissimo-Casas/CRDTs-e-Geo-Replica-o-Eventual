#!/bin/bash

# Script de Demonstração - Operação Normal & Convergência
# Simula cenário normal com likes distribuídos entre regiões

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Função para imprimir cabeçalho
print_header() {
    echo ""
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${WHITE}$1${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Função para imprimir passo
print_step() {
    echo -e "${BOLD}${YELLOW}➤ $1${NC}"
}

# Função para imprimir sucesso
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Função para imprimir info
print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Função para imprimir erro
print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Função para enviar like
send_like() {
    local region=$1
    local port=$2
    local flag=$3
    
    echo -e "${CYAN}   👍 Enviando like para ${flag} ${region}...${NC}"
    response=$(curl -s -X POST -L http://localhost:${port}/like 2>&1)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}   ✓ Like registrado em ${region}${NC}"
    else
        echo -e "${RED}   ✗ Erro ao enviar like para ${region}${NC}"
    fi
}

# Função para buscar estatísticas
fetch_stats() {
    echo -e "${PURPLE}📊 Consultando estatísticas...${NC}"
    stats=$(curl -s http://localhost:3000/stats 2>&1)
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${BOLD}${WHITE}Estatísticas Atuais:${NC}"
        echo "$stats" | jq '.' 2>/dev/null || echo "$stats"
        echo ""
    else
        print_error "Erro ao consultar estatísticas"
    fi
}

# Função para verificar convergência
check_convergence() {
    stats=$(curl -s http://localhost:3000/stats 2>&1)
    
    if [ $? -ne 0 ]; then
        print_error "Não foi possível verificar convergência"
        return 1
    fi
    
    # Extrair likes de cada região
    br_likes=$(echo "$stats" | jq -r '.br.likes // "Offline"' 2>/dev/null)
    eu_likes=$(echo "$stats" | jq -r '.eu.likes // "Offline"' 2>/dev/null)
    usa_likes=$(echo "$stats" | jq -r '.usa.likes // "Offline"' 2>/dev/null)
    
    echo -e "${BOLD}${WHITE}Status de Convergência:${NC}"
    echo -e "   🇧🇷 Brasil: ${CYAN}${br_likes} likes${NC}"
    echo -e "   🇪🇺 Europa: ${CYAN}${eu_likes} likes${NC}"
    echo -e "   🇺🇸 EUA:    ${CYAN}${usa_likes} likes${NC}"
    echo ""
    
    # Verificar se todos estão online
    if [ "$br_likes" = "Offline" ] || [ "$eu_likes" = "Offline" ] || [ "$usa_likes" = "Offline" ]; then
        print_error "Uma ou mais regiões estão offline"
        return 1
    fi
    
    # Verificar convergência
    if [ "$br_likes" = "$eu_likes" ] && [ "$eu_likes" = "$usa_likes" ]; then
        print_success "Sistema CONVERGIDO! Todas as regiões têm ${br_likes} likes"
        return 0
    else
        print_info "Sistema DIVERGENTE (esperado durante sincronização)"
        return 2
    fi
}

# Função para exibir dashboard URL
show_dashboard() {
    echo ""
    echo -e "${BOLD}${PURPLE}┌─────────────────────────────────────────────────────┐${NC}"
    echo -e "${BOLD}${PURPLE}│${NC} ${BOLD}${WHITE}📊 Dashboard em tempo real:${NC}                     ${BOLD}${PURPLE}│${NC}"
    echo -e "${BOLD}${PURPLE}│${NC} ${CYAN}http://localhost:3000${NC}                           ${BOLD}${PURPLE}│${NC}"
    echo -e "${BOLD}${PURPLE}└─────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# Banner inicial
clear
echo ""
echo -e "${BOLD}${CYAN}"
cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     🌍 CRDT DEMO - Operação Normal & Convergência 🌍        ║
║                                                              ║
║          Demonstração de Consistência Eventual              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Verificar se containers estão rodando
print_step "Verificando se containers estão ativos..."
if ! docker ps | grep -q "api-br"; then
    print_error "Containers não estão rodando!"
    echo -e "${YELLOW}Execute: docker-compose up -d${NC}"
    exit 1
fi
print_success "Containers ativos"

# Verificar conectividade
print_step "Verificando conectividade das APIs..."
sleep 1

errors=0
for region in "BR:3001" "EU:3002" "USA:3003"; do
    IFS=':' read -r name port <<< "$region"
    if curl -s http://localhost:${port}/health > /dev/null 2>&1; then
        echo -e "${GREEN}   ✓ API ${name} respondendo${NC}"
    else
        echo -e "${RED}   ✗ API ${name} não responde${NC}"
        ((errors++))
    fi
done

if [ $errors -gt 0 ]; then
    print_error "Algumas APIs não estão respondendo"
    exit 1
fi

print_success "Todas as APIs respondendo"
sleep 1

# Mostrar URL do dashboard
show_dashboard
sleep 2

# ============================================================================
# FASE 1: Estado Inicial
# ============================================================================
print_header "FASE 1: Estado Inicial"
print_step "Consultando estado inicial do sistema..."
sleep 1
fetch_stats
sleep 2

# ============================================================================
# FASE 2: Likes Distribuídos
# ============================================================================
print_header "FASE 2: Simulando Usuários - Likes Distribuídos"
print_info "Enviando likes de diferentes regiões..."
echo ""
sleep 1

# Brasil - 3 likes
print_step "Usuários no Brasil 🇧🇷"
for i in {1..3}; do
    send_like "Brasil" "3001" "🇧🇷"
    sleep 0.5
done
echo ""
sleep 1

# Europa - 2 likes
print_step "Usuários na Europa 🇪🇺"
for i in {1..2}; do
    send_like "Europa" "3002" "🇪🇺"
    sleep 0.5
done
echo ""
sleep 1

# EUA - 4 likes
print_step "Usuários nos EUA 🇺🇸"
for i in {1..4}; do
    send_like "EUA" "3003" "🇺🇸"
    sleep 0.5
done
echo ""
sleep 2

# ============================================================================
# FASE 3: Verificação Intermediária
# ============================================================================
print_header "FASE 3: Verificação Durante Sincronização"
print_info "Aguardando sincronização CRDT entre regiões..."
sleep 2
fetch_stats
check_convergence
conv_status=$?
sleep 2

# ============================================================================
# FASE 4: Segunda Rodada de Likes
# ============================================================================
print_header "FASE 4: Segunda Rodada - Mais Usuários"
print_info "Mais likes chegando de todas as regiões..."
echo ""
sleep 1

# Mix de regiões
send_like "Brasil" "3001" "🇧🇷"
sleep 0.5
send_like "EUA" "3003" "🇺🇸"
sleep 0.5
send_like "Europa" "3002" "🇪🇺"
sleep 0.5
send_like "Brasil" "3001" "🇧🇷"
sleep 0.5
send_like "EUA" "3003" "🇺🇸"
echo ""
sleep 2

# ============================================================================
# FASE 5: Convergência Final
# ============================================================================
print_header "FASE 5: Convergência Final"
print_info "Aguardando sincronização completa entre todas as regiões..."
echo ""
sleep 3

# Tentar até 5 vezes com intervalo de 2s
max_attempts=5
converged=false

for attempt in $(seq 1 $max_attempts); do
    if [ $attempt -gt 1 ]; then
        echo -e "${YELLOW}Tentativa ${attempt}/${max_attempts}...${NC}"
        sleep 2
    fi
    
    fetch_stats
    check_convergence
    conv_status=$?
    
    if [ $conv_status -eq 0 ]; then
        converged=true
        break
    fi
done

echo ""
sleep 1

# ============================================================================
# RESULTADO FINAL
# ============================================================================
print_header "RESULTADO FINAL"

if [ "$converged" = true ]; then
    echo ""
    echo -e "${BOLD}${GREEN}"
    cat << "EOF"
    ✅  ✅  ✅  ✅  ✅  ✅  ✅  ✅  ✅  ✅
    
    Operação Normal & Convergência VERIFICADA!
    
    ✅  ✅  ✅  ✅  ✅  ✅  ✅  ✅  ✅  ✅
EOF
    echo -e "${NC}"
    echo ""
    
    print_success "Todas as regiões convergiram para o mesmo valor"
    print_success "CRDT funcionando corretamente!"
    print_success "Sistema demonstrou Consistência Eventual"
    echo ""
    
    # Estatísticas finais
    stats=$(curl -s http://localhost:3000/stats 2>&1)
    total_likes=$(echo "$stats" | jq -r '.br.likes // 0' 2>/dev/null)
    total_uniques=$(echo "$stats" | jq -r '.br.uniques // 0' 2>/dev/null)
    
    echo -e "${BOLD}${CYAN}📊 Estatísticas Finais:${NC}"
    echo -e "   Total de Likes: ${BOLD}${WHITE}${total_likes}${NC}"
    echo -e "   Usuários Únicos: ${BOLD}${WHITE}~${total_uniques}${NC}"
    echo ""
else
    echo ""
    echo -e "${BOLD}${YELLOW}"
    cat << "EOF"
    ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️
    
    Sistema ainda não convergiu completamente
    
    ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️  ⚠️
EOF
    echo -e "${NC}"
    echo ""
    
    print_info "Isso pode acontecer em sistemas reais durante sincronização"
    print_info "Aguarde alguns segundos e verifique o dashboard"
    echo ""
fi

# ============================================================================
# CONCEITOS DEMONSTRADOS
# ============================================================================
print_header "CONCEITOS DEMONSTRADOS"

echo -e "${BOLD}${WHITE}✓ CAP Theorem:${NC}"
echo -e "  ${CYAN}→${NC} Sistema priorizou ${BOLD}A${NC}vailability (disponibilidade)"
echo -e "  ${CYAN}→${NC} Tolerante a ${BOLD}P${NC}artições (veremos no próximo script)"
echo -e "  ${CYAN}→${NC} ${BOLD}C${NC}onsistência Eventual demonstrada"
echo ""

echo -e "${BOLD}${WHITE}✓ CRDT (PN-Counter):${NC}"
echo -e "  ${CYAN}→${NC} Incrementos locais (baixa latência)"
echo -e "  ${CYAN}→${NC} Merge automático entre regiões"
echo -e "  ${CYAN}→${NC} Convergência determinística"
echo ""

echo -e "${BOLD}${WHITE}✓ Geo-Replicação:${NC}"
echo -e "  ${CYAN}→${NC} 3 regiões independentes (BR/EU/USA)"
echo -e "  ${CYAN}→${NC} Sincronização em background"
echo -e "  ${CYAN}→${NC} Sem ponto único de falha"
echo ""

# ============================================================================
# PRÓXIMOS PASSOS
# ============================================================================
print_header "PRÓXIMOS PASSOS"

echo -e "${BOLD}${PURPLE}🔍 Explore o Dashboard:${NC}"
echo -e "   ${CYAN}http://localhost:3000${NC}"
echo ""

echo -e "${BOLD}${PURPLE}🧪 Execute outras demos:${NC}"
echo -e "   ${YELLOW}./scripts/demo-partition.sh${NC}  - Simula partição de rede"
echo ""

echo -e "${BOLD}${PURPLE}📱 Teste manualmente:${NC}"
echo -e "   ${CYAN}http://localhost:3001/like${NC}  (Brasil)"
echo -e "   ${CYAN}http://localhost:3002/like${NC}  (Europa)"
echo -e "   ${CYAN}http://localhost:3003/like${NC}  (EUA)"
echo ""

echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}Demo concluída com sucesso! 🎉${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
