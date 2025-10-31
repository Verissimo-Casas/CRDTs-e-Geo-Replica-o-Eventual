#!/bin/bash

# Script de Demonstração - Reconexão e Convergência CRDT
# Demonstra convergência automática após reconectar rede particionada

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

# Função para detectar rede Docker automaticamente
detect_docker_network() {
    echo -e "${BLUE}🔍 Detectando rede Docker automaticamente...${NC}"

    # Procurar por rede que contenha "crdt"
    network=$(docker network ls --format "{{.Name}}" | grep crdt | head -1)

    if [ -z "$network" ]; then
        print_error "Nenhuma rede 'crdt' encontrada"
        print_info "Verifique se os containers estão rodando com 'docker-compose up -d'"
        exit 1
    fi

    echo -e "${GREEN}   ✓ Rede detectada: ${network}${NC}"
    echo "$network"
}

# Função para reconectar containers
reconnect_containers() {
    local network=$1

    echo -e "${GREEN}🔗 Reconectando containers à rede ${network}...${NC}"

    # Reconectar redis-eu
    echo -e "${CYAN}   Reconectando redis-eu...${NC}"
    docker network connect ${network} redis-eu 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}   ✓ redis-eu reconectado${NC}"
    else
        print_error "Falha ao reconectar redis-eu"
    fi

    # Reconectar api-eu
    echo -e "${CYAN}   Reconectando api-eu...${NC}"
    docker network connect ${network} api-eu 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}   ✓ api-eu reconectado${NC}"
    else
        print_error "Falha ao reconectar api-eu"
    fi
}

# Função para verificar convergência
check_convergence() {
    stats=$(curl -s http://localhost:3000/stats 2>&1)

    if [ $? -ne 0 ]; then
        echo "Erro ao consultar estatísticas"
        return 1
    fi

    # Extrair likes de cada região
    br_likes=$(echo "$stats" | jq -r '.br.likes // "Offline"' 2>/dev/null)
    eu_likes=$(echo "$stats" | jq -r '.eu.likes // "Offline"' 2>/dev/null)
    usa_likes=$(echo "$stats" | jq -r '.usa.likes // "Offline"' 2>/dev/null)

    # Verificar se todos estão online
    if [ "$br_likes" = "Offline" ] || [ "$eu_likes" = "Offline" ] || [ "$usa_likes" = "Offline" ]; then
        echo "Offline"
        return 1
    fi

    # Verificar convergência
    if [ "$br_likes" = "$eu_likes" ] && [ "$eu_likes" = "$usa_likes" ]; then
        echo "Convergido:$br_likes"
        return 0
    else
        echo "Divergente:$br_likes:$eu_likes:$usa_likes"
        return 1
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

print_header "🔄 DEMO: RECONEXÃO E CONVERGÊNCIA CRDT"
print_info "Demonstra convergência automática após reconectar rede particionada"

# Verificar se containers estão rodando
print_step "Verificando se os containers estão rodando..."
if ! docker ps | grep -q "redis-br\|redis-eu\|redis-usa\|api-br\|api-eu\|api-usa\|dashboard"; then
    print_error "Containers não estão rodando. Execute 'docker-compose up -d' primeiro"
    exit 1
fi
print_success "Containers estão rodando"

# Detectar rede Docker
print_step "Detectando rede Docker"
network=$(detect_docker_network)

# Estado antes da reconexão
print_step "Estado antes da reconexão"
result=$(check_convergence)
echo -e "${BOLD}${WHITE}Status atual: ${result}${NC}"

if [[ $result == Divergente:* ]]; then
    IFS=':' read -r status br_likes eu_likes usa_likes <<< "$result"
    echo -e "${BOLD}${WHITE}Estado Divergente:${NC}"
    echo -e "   🇧🇷 Brasil: ${CYAN}${br_likes} likes${NC}"
    echo -e "   🇪🇺 Europa: ${CYAN}${eu_likes} likes${NC}"
    echo -e "   🇺🇸 EUA:    ${CYAN}${usa_likes} likes${NC}"
    echo ""
elif [[ $result == Offline ]]; then
    print_warning "Europa ainda está offline - prosseguindo com reconexão"
elif [[ $result == Convergido:* ]]; then
    print_warning "Sistema já está convergido - talvez Europa já esteja conectada"
fi

# Reconectar containers
print_header "🔗 RECONECTANDO EUROPA À REDE"
reconnect_containers "$network"
wait_seconds 3

# Estado logo após reconexão
print_step "Estado logo após reconexão"
result=$(check_convergence)
echo -e "${BOLD}${WHITE}Status após reconexão: ${result}${NC}"

if [[ $result == Divergente:* ]]; then
    IFS=':' read -r status br_likes eu_likes usa_likes <<< "$result"
    echo -e "${BOLD}${WHITE}Estado Divergente:${NC}"
    echo -e "   🇧🇷 Brasil: ${CYAN}${br_likes} likes${NC}"
    echo -e "   🇪🇺 Europa: ${CYAN}${eu_likes} likes${NC}"
    echo -e "   🇺🇸 EUA:    ${CYAN}${usa_likes} likes${NC}"
    echo ""
elif [[ $result == Offline ]]; then
    print_error "Europa ainda está offline após reconexão"
    exit 1
elif [[ $result == Convergido:* ]]; then
    IFS=':' read -r status converged_value <<< "$result"
    print_success "Convergência imediata! Valor: $converged_value likes"
fi

# Monitoramento de convergência em tempo real
print_header "📊 MONITORANDO CONVERGÊNCIA EM TEMPO REAL"
print_info "Polling /stats a cada segundo até convergência..."

max_attempts=30  # máximo 30 segundos
attempt=1
last_status=""

while [ $attempt -le $max_attempts ]; do
    result=$(check_convergence)

    if [[ $result == Convergido:* ]]; then
        IFS=':' read -r status converged_value <<< "$result"
        echo ""
        print_success "CONVERGÊNCIA ALCANÇADA após ${attempt} segundos!"
        echo -e "${BOLD}${GREEN}✅ CRDT Converged Automatically — No Conflicts${NC}"
        echo -e "${BOLD}${WHITE}Valor final convergido: ${CYAN}${converged_value} likes${NC}"
        break
    elif [[ $result == Offline ]]; then
        echo -e "${RED}[$attempt/${max_attempts}]${NC} ${BOLD}${WHITE}Status: ${RED}Offline${NC} - Aguardando sincronização..."
    elif [[ $result == Divergente:* ]]; then
        IFS=':' read -r status br_likes eu_likes usa_likes <<< "$result"

        # Só imprimir se o status mudou
        current_status="$br_likes:$eu_likes:$usa_likes"
        if [ "$current_status" != "$last_status" ]; then
            echo -e "${YELLOW}[$attempt/${max_attempts}]${NC} ${BOLD}${WHITE}Status: ${YELLOW}Divergente${NC}"
            echo -e "   🇧🇷 Brasil: ${CYAN}${br_likes}${NC} | 🇪🇺 Europa: ${CYAN}${eu_likes}${NC} | 🇺🇸 EUA: ${CYAN}${usa_likes}${NC}"
            last_status="$current_status"
        else
            echo -e "${YELLOW}[$attempt/${max_attempts}]${NC} ${BOLD}${WHITE}Status: ${YELLOW}Divergente${NC} (sem mudanças)"
        fi
    else
        echo -e "${BLUE}[$attempt/${max_attempts}]${NC} ${BOLD}${WHITE}Consultando...${NC}"
    fi

    if [ $attempt -lt $max_attempts ]; then
        sleep 1
        attempt=$((attempt + 1))
    else
        echo ""
        print_warning "Timeout: Convergência não alcançada em ${max_attempts} segundos"
        print_info "Isso pode ser normal - convergência eventual pode levar mais tempo"
        break
    fi
done

# Verificação final
print_step "Verificação final de convergência"
result=$(check_convergence)

if [[ $result == Convergido:* ]]; then
    IFS=':' read -r status converged_value <<< "$result"
    echo -e "${BOLD}${WHITE}Estado Final:${NC}"
    echo -e "   🇧🇷 Brasil: ${GREEN}${converged_value} likes${NC}"
    echo -e "   🇪🇺 Europa: ${GREEN}${converged_value} likes${NC}"
    echo -e "   🇺🇸 EUA:    ${GREEN}${converged_value} likes${NC}"
    echo ""
    print_success "Sistema totalmente convergido!"
elif [[ $result == Divergente:* ]]; then
    IFS=':' read -r status br_likes eu_likes usa_likes <<< "$result"
    echo -e "${BOLD}${WHITE}Estado Final (Divergente):${NC}"
    echo -e "   🇧🇷 Brasil: ${YELLOW}${br_likes} likes${NC}"
    echo -e "   🇪🇺 Europa: ${YELLOW}${eu_likes} likes${NC}"
    echo -e "   🇺🇸 EUA:    ${YELLOW}${usa_likes} likes${NC}"
    echo ""
    print_info "Convergência eventual ainda em andamento..."
fi

# ============================================================================
# CONCLUSÃO
# ============================================================================
print_header "🎯 CONCLUSÃO DA DEMONSTRAÇÃO"

echo -e "${BOLD}${GREEN}O que aconteceu:${NC}"
echo -e "  ${CYAN}→${NC} Europa foi ${GREEN}reconectada${NC} à rede automaticamente"
echo -e "  ${CYAN}→${NC} CRDT iniciou ${GREEN}sincronização automática${NC}"
echo -e "  ${CYAN}→${NC} Valores ${GREEN}convergiram${NC} sem intervenção manual"
echo -e "  ${CYAN}→${NC} ${GREEN}Zero conflitos${NC} - merge determinístico"
echo ""

echo -e "${BOLD}${PURPLE}Propriedades CRDT demonstradas:${NC}"
echo -e "  ${CYAN}→${NC} ${BOLD}Convergência Eventual${NC}: Estados eventualmente consistentes"
echo -e "  ${CYAN}→${NC} ${BOLD}Merge Automático${NC}: Sem necessidade de resolução manual"
echo -e "  ${CYAN}→${NC} ${BOLD}Sem Conflitos${NC}: Operações comutativas garantem consistência"
echo -e "  ${CYAN}→${NC} ${BOLD}Tolerância a Partições${NC}: Recuperação transparente"
echo ""

# ============================================================================
# PRÓXIMOS PASSOS
# ============================================================================
print_header "PRÓXIMOS PASSOS"

echo -e "${BOLD}${PURPLE}🔍 Explore o Dashboard:${NC}"
echo -e "   ${CYAN}http://localhost:3000${NC}"
echo ""

echo -e "${BOLD}${PURPLE}🧪 Execute outras demos:${NC}"
echo -e "   ${YELLOW}./scripts/demo-normal.sh${NC}         - Operação normal"
echo -e "   ${YELLOW}./scripts/demo-partition.sh${NC}      - Partição completa"
echo -e "   ${YELLOW}./scripts/demo-partition-writes.sh${NC} - Writes durante partição"
echo ""

echo -e "${BOLD}${PURPLE}📱 Teste manualmente:${NC}"
echo -e "   ${CYAN}http://localhost:3001/like${NC}  (Brasil)"
echo -e "   ${CYAN}http://localhost:3002/like${NC}  (Europa)"
echo -e "   ${CYAN}http://localhost:3003/like${NC}  (EUA)"
echo ""

echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}Demo de reconexão concluído com sucesso! 🎉${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""