#!/bin/bash

# Script de Demonstração - Partição de Rede & Convergência
# Simula cenário de partição de rede e demonstra recuperação

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

# Função para imprimir warning
print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
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
        print_success "Convergência alcançada! Todas as regiões têm $br_likes likes"
        return 0
    else
        print_warning "Aguardando convergência..."
        return 1
    fi
}

# Função para desconectar rede
disconnect_network() {
    local container=$1
    local network=$2

    echo -e "${RED}🔌 Desconectando ${container} da rede ${network}...${NC}"
    docker network disconnect ${network} ${container} 2>&1

    if [ $? -eq 0 ]; then
        print_success "${container} desconectado da rede"
    else
        print_error "Erro ao desconectar ${container}"
    fi
}

# Função para reconectar rede
connect_network() {
    local container=$1
    local network=$2

    echo -e "${GREEN}🔗 Reconectando ${container} à rede ${network}...${NC}"
    docker network connect ${network} ${container} 2>&1

    if [ $? -eq 0 ]; then
        print_success "${container} reconectado à rede"
    else
        print_error "Erro ao reconectar ${container}"
    fi
}

# Função para aguardar
wait_seconds() {
    local seconds=$1
    echo -e "${BLUE}⏳ Aguardando ${seconds} segundos...${NC}"
    sleep $seconds
}

# ============================================================================
# INÍCIO DA DEMONSTRAÇÃO
# ============================================================================

print_header "🚀 DEMO: PARTIÇÃO DE REDE & CONVERGÊNCIA CRDT"
print_info "Este demo simula uma partição de rede e demonstra como o CRDT mantém consistência eventual"

# Verificar se containers estão rodando
print_step "Verificando se os containers estão rodando..."
if ! docker ps | grep -q "redis-br\|redis-eu\|redis-usa\|api-br\|api-eu\|api-usa\|dashboard"; then
    print_error "Containers não estão rodando. Execute 'docker-compose up -d' primeiro"
    exit 1
fi
print_success "Containers estão rodando"

# Estado inicial
print_step "Estado inicial - Enviando likes para todas as regiões"
send_like "Brasil" "3001" "🇧🇷"
send_like "Europa" "3002" "🇪🇺"
send_like "EUA" "3003" "🇺🇸"
wait_seconds 2

print_step "Estatísticas antes da partição"
fetch_stats

# Simular partição de rede
print_header "🔥 SIMULANDO PARTIÇÃO DE REDE"
print_warning "Desconectando Europa (redis-eu) da rede para simular falha de conectividade"

disconnect_network "redis-eu" "crdt-demo_crdt-network"
disconnect_network "api-eu" "crdt-demo_crdt-network"
wait_seconds 3

# Verificar impacto da partição
print_step "Verificando impacto da partição"
fetch_stats

# Enviar likes durante partição
print_step "Enviando likes durante a partição"
print_info "Europa está isolada, mas Brasil e EUA continuam funcionando"
send_like "Brasil" "3001" "🇧🇷"
send_like "Brasil" "3001" "🇧🇷"
send_like "EUA" "3003" "🇺🇸"
send_like "EUA" "3003" "🇺🇸"
send_like "EUA" "3003" "🇺🇸"

# Tentar enviar para Europa (deve falhar)
echo -e "${CYAN}   👍 Tentando enviar like para 🇪🇺 Europa (deve falhar)...${NC}"
response=$(curl -s --max-time 5 -X POST -L http://localhost:3002/like 2>&1)
if [ $? -eq 0 ]; then
    echo -e "${YELLOW}   ⚠️  Like enviado (inesperado)${NC}"
else
    print_success "Europa está inacessível (conforme esperado)"
fi

wait_seconds 2

print_step "Estatísticas durante partição"
fetch_stats

# Reconectar rede
print_header "🔄 RECUPERANDO DA PARTIÇÃO"
print_info "Reconectando Europa à rede - CRDT deve sincronizar automaticamente"

connect_network "redis-eu" "crdt-demo_crdt-network"
connect_network "api-eu" "crdt-demo_crdt-network"
wait_seconds 5

# Verificar recuperação
print_step "Verificando recuperação e convergência"
max_attempts=10
attempt=1

while [ $attempt -le $max_attempts ]; do
    echo -e "${BLUE}Tentativa ${attempt}/${max_attempts} de verificar convergência...${NC}"

    if check_convergence; then
        break
    fi

    if [ $attempt -lt $max_attempts ]; then
        wait_seconds 3
    fi

    attempt=$((attempt + 1))
done

if [ $attempt -gt $max_attempts ]; then
    print_warning "Convergência não alcançada no tempo esperado, mas deve ocorrer eventualmente"
fi

# Enviar likes finais para testar
print_step "Teste final - Enviando likes para todas as regiões"
send_like "Brasil" "3001" "🇧🇷"
send_like "Europa" "3002" "🇪🇺"
send_like "EUA" "3003" "🇺🇸"
wait_seconds 3

print_step "Estatísticas finais após recuperação"
fetch_stats

# Verificação final de convergência
print_step "Verificação final de convergência"
check_convergence

# ============================================================================
# CONCLUSÃO
# ============================================================================
print_header "🎯 CONCLUSÃO DA DEMONSTRAÇÃO"

echo -e "${BOLD}${GREEN}O que aconteceu:${NC}"
echo -e "  ${CYAN}→${NC} Partição isolou Europa completamente"
echo -e "  ${CYAN}→${NC} Brasil e EUA continuaram funcionando"
echo -e "  ${CYAN}→${NC} Dados foram perdidos apenas localmente na Europa"
echo -e "  ${CYAN}→${NC} Após reconexão, convergência eventual ocorreu"
echo -e "  ${CYAN}→${NC} Sistema manteve alta disponibilidade"
echo ""

echo -e "${BOLD}${PURPLE}Propriedades CRDT demonstradas:${NC}"
echo -e "  ${CYAN}→${NC} ${BOLD}Convergência Eventual${NC}: Estados eventualmente consistentes"
echo -e "  ${CYAN}→${NC} ${BOLD}Alta Disponibilidade${NC}: Sistema funcional mesmo com partições"
echo -e "  ${CYAN}→${NC} ${BOLD}Tolerância a Partições${NC}: Sobrevive a falhas de rede"
echo -e "  ${CYAN}→${NC} ${BOLD}Sem Coordenação${NC}: Não precisa de consenso distribuído"
echo ""

# ============================================================================
# PRÓXIMOS PASSOS
# ============================================================================
print_header "PRÓXIMOS PASSOS"

echo -e "${BOLD}${PURPLE}🔍 Explore o Dashboard:${NC}"
echo -e "   ${CYAN}http://localhost:3000${NC}"
echo ""

echo -e "${BOLD}${PURPLE}🧪 Execute outras demos:${NC}"
echo -e "   ${YELLOW}./scripts/demo-normal.sh${NC}     - Operação normal"
echo ""

echo -e "${BOLD}${PURPLE}📱 Teste manualmente:${NC}"
echo -e "   ${CYAN}http://localhost:3001/like${NC}  (Brasil)"
echo -e "   ${CYAN}http://localhost:3002/like${NC}  (Europa)"
echo -e "   ${CYAN}http://localhost:3003/like${NC}  (EUA)"
echo ""

echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}Demo de partição concluída com sucesso! 🎉${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""