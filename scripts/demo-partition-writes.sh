#!/bin/bash

# Script de Demonstração - Escrita Durante Partição
# Demonstra que writes são aceitos localmente mesmo com isolamento de rede

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

# Função para analisar diferenças
analyze_differences() {
    stats=$(curl -s http://localhost:3000/stats 2>&1)

    if [ $? -ne 0 ]; then
        print_error "Não foi possível analisar diferenças"
        return 1
    fi

    # Extrair likes de cada região
    br_likes=$(echo "$stats" | jq -r '.br.likes // "Offline"' 2>/dev/null)
    eu_likes=$(echo "$stats" | jq -r '.eu.likes // "Offline"' 2>/dev/null)
    usa_likes=$(echo "$stats" | jq -r '.usa.likes // "Offline"' 2>/dev/null)

    echo -e "${BOLD}${WHITE}Análise de Diferenças:${NC}"
    echo -e "   🇧🇷 Brasil: ${CYAN}${br_likes} likes${NC}"
    echo -e "   🇪🇺 Europa: ${CYAN}${eu_likes} likes${NC}"
    echo -e "   🇺🇸 EUA:    ${CYAN}${usa_likes} likes${NC}"
    echo ""

    # Calcular diferenças
    if [ "$br_likes" != "Offline" ] && [ "$eu_likes" != "Offline" ] && [ "$usa_likes" != "Offline" ]; then
        br_eu_diff=$((br_likes - eu_likes))
        usa_eu_diff=$((usa_likes - eu_likes))

        if [ $br_eu_diff -gt 0 ]; then
            echo -e "${YELLOW}   📈 Brasil tem ${br_eu_diff} likes a mais que Europa${NC}"
        elif [ $br_eu_diff -lt 0 ]; then
            br_eu_diff_abs=$((br_eu_diff * -1))
            echo -e "${YELLOW}   📈 Europa tem ${br_eu_diff_abs} likes a mais que Brasil${NC}"
        else
            echo -e "${GREEN}   ⚖️  Brasil e Europa têm o mesmo número de likes${NC}"
        fi

        if [ $usa_eu_diff -gt 0 ]; then
            echo -e "${YELLOW}   📈 EUA tem ${usa_eu_diff} likes a mais que Europa${NC}"
        elif [ $usa_eu_diff -lt 0 ]; then
            usa_eu_diff_abs=$((usa_eu_diff * -1))
            echo -e "${YELLOW}   📈 Europa tem ${usa_eu_diff_abs} likes a mais que EUA${NC}"
        else
            echo -e "${GREEN}   ⚖️  EUA e Europa têm o mesmo número de likes${NC}"
        fi
    else
        print_warning "Alguma região está offline - não é possível calcular diferenças"
    fi

    echo ""
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

print_header "🧠 DEMO: ESCRITAS DURANTE PARTIÇÃO DE REDE"
print_info "Demonstra que writes são aceitos localmente mesmo com isolamento de rede"

# Verificar se containers estão rodando
print_step "Verificando se os containers estão rodando..."
if ! docker ps | grep -q "redis-br\|redis-eu\|redis-usa\|api-br\|api-eu\|api-usa\|dashboard"; then
    print_error "Containers não estão rodando. Execute 'docker-compose up -d' primeiro"
    exit 1
fi
print_success "Containers estão rodando"

# Assumir que redis-eu já está particionado
print_warning "Assumindo que redis-eu já está particionado (desconectado da rede)"
print_info "Se não estiver, execute primeiro: docker network disconnect crdt-demo_crdt-network redis-eu"

wait_seconds 2

# Estado inicial durante partição
print_step "Estado inicial durante partição"
fetch_stats
analyze_differences

# Burst 1: Múltiplas escritas apenas na Europa
print_header "💥 BURST 1: Múltiplas escritas APENAS na Europa"
print_info "Europa está isolada, mas deve aceitar writes localmente"

echo -e "${BOLD}${CYAN}Enviando 5 likes para Europa isolada...${NC}"
for i in {1..5}; do
    send_like "Europa" "3002" "🇪🇺"
    sleep 0.5
done

wait_seconds 1
print_step "Estatísticas após Burst 1"
fetch_stats
analyze_differences

# Burst 2: Algumas escritas em BR e USA
print_header "💥 BURST 2: Escrita em Brasil e EUA"
print_info "BR e EUA continuam conectados entre si"

echo -e "${BOLD}${CYAN}Enviando 2 likes para Brasil...${NC}"
for i in {1..2}; do
    send_like "Brasil" "3001" "🇧🇷"
    sleep 0.5
done

echo -e "${BOLD}${CYAN}Enviando 3 likes para EUA...${NC}"
for i in {1..3}; do
    send_like "EUA" "3003" "🇺🇸"
    sleep 0.5
done

wait_seconds 1
print_step "Estatísticas após Burst 2"
fetch_stats
analyze_differences

# Burst 3: Mais escritas na Europa
print_header "💥 BURST 3: Mais escritas na Europa isolada"
print_info "Continuando a demonstrar que Europa aceita writes mesmo isolada"

echo -e "${BOLD}${CYAN}Enviando 3 likes para Europa isolada...${NC}"
for i in {1..3}; do
    send_like "Europa" "3002" "🇪🇺"
    sleep 0.5
done

wait_seconds 1
print_step "Estatísticas após Burst 3"
fetch_stats
analyze_differences

# Burst 4: Escrita simultânea em todas as regiões disponíveis
print_header "💥 BURST 4: Escrita simultânea em regiões disponíveis"
print_info "BR e EUA continuam funcionando normalmente"

echo -e "${BOLD}${CYAN}Enviando 1 like para Brasil e 1 para EUA...${NC}"
send_like "Brasil" "3001" "🇧🇷"
send_like "EUA" "3003" "🇺🇸"

# Tentar enviar para Europa (deve funcionar pois está isolada mas operacional)
echo -e "${BOLD}${CYAN}Tentando enviar 1 like para Europa isolada...${NC}"
send_like "Europa" "3002" "🇪🇺"

wait_seconds 1
print_step "Estatísticas finais durante partição"
fetch_stats
analyze_differences

# ============================================================================
# CONCLUSÃO
# ============================================================================
print_header "🧠 CONCLUSÃO: WRITES DURANTE ISOLAMENTO"

echo -e "${BOLD}${GREEN}🧠 Writes are accepted locally during network isolation${NC}"
echo ""

echo -e "${BOLD}${PURPLE}O que foi demonstrado:${NC}"
echo -e "  ${CYAN}→${NC} Europa isolada ${GREEN}continuou aceitando writes${NC}"
echo -e "  ${CYAN}→${NC} Brasil e EUA ${GREEN}permaneceram totalmente funcionais${NC}"
echo -e "  ${CYAN}→${NC} Dados foram ${GREEN}processados localmente${NC} em cada região"
echo -e "  ${CYAN}→${NC} ${YELLOW}Diferenças${NC} surgiram entre regiões isoladas"
echo ""

echo -e "${BOLD}${PURPLE}Propriedades CRDT demonstradas:${NC}"
echo -e "  ${CYAN}→${NC} ${BOLD}Alta Disponibilidade (AP)${NC}: Writes aceitos mesmo isolados"
echo -e "  ${CYAN}→${NC} ${BOLD}Processamento Local${NC}: Não depende de consenso global"
echo -e "  ${CYAN}→${NC} ${BOLD}Tolerância a Partições${NC}: Sistema sobrevive a falhas de rede"
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
echo ""

echo -e "${BOLD}${PURPLE}🔄 Próxima etapa:${NC}"
echo -e "   ${CYAN}docker network connect crdt-demo_crdt-network redis-eu${NC}"
echo -e "   ${CYAN}docker network connect crdt-demo_crdt-network api-eu${NC}"
echo -e "   ${YELLOW}Em seguida execute demo-partition.sh para ver convergência${NC}"
echo ""

echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}Demo de writes durante partição concluído! 🎉${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""