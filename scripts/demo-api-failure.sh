#!/bin/bash

# Script de Demonstração - Falha de Nó API
# Demonstra comportamento quando um nó da API falha

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
        echo -e "${RED}   ✗ Erro ao enviar like para ${region} (esperado se falhou)${NC}"
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

# Função para testar conectividade da API
test_api_connectivity() {
    local region=$1
    local port=$2
    local flag=$3

    echo -e "${BLUE}   Testando conectividade da API ${flag} ${region}...${NC}"
    response=$(curl -s --max-time 3 http://localhost:${port}/ 2>&1)

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}   ✓ API ${region} está respondendo${NC}"
        return 0
    else
        echo -e "${RED}   ✗ API ${region} não está respondendo${NC}"
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

print_header "🔥 DEMO: FALHA DE NÓ API"
print_info "Demonstra comportamento quando um nó da API falha completamente"

# Verificar se containers estão rodando
print_step "Verificando se os containers estão rodando..."
if ! docker ps | grep -q "redis-br\|redis-eu\|redis-usa\|api-eu\|api-usa\|dashboard"; then
    print_error "Containers necessários não estão rodando. Execute 'docker-compose up -d' primeiro"
    exit 1
fi

# Verificar se api-br está rodando (vamos pará-lo)
if docker ps | grep -q "api-br"; then
    print_success "Containers estão rodando (api-br será parado)"
else
    print_warning "api-br já está parado - prosseguindo com a demonstração"
fi

# Estado inicial
print_step "Estado inicial - Todos os serviços funcionando"
fetch_stats

# Enviar alguns likes iniciais para ter dados
print_step "Enviando likes iniciais para todas as regiões"
send_like "Brasil" "3001" "🇧🇷"
send_like "Europa" "3002" "🇪🇺"
send_like "EUA" "3003" "🇺🇸"
wait_seconds 2

print_step "Estatísticas após likes iniciais"
fetch_stats

# SIMULAR FALHA DA API DO BRASIL
print_header "💥 SIMULANDO FALHA COMPLETA DA API DO BRASIL"

print_warning "Parando o container api-br para simular falha completa..."
docker stop api-br 2>&1

if [ $? -eq 0 ]; then
    print_success "Container api-br parado com sucesso"
else
    print_error "Erro ao parar api-br"
fi

wait_seconds 3

# Verificar impacto da falha
print_step "Verificando impacto da falha da API do Brasil"
test_api_connectivity "Brasil" "3001" "🇧🇷"
echo ""

# Tentar enviar like para Brasil (deve falhar)
print_step "Tentando enviar like para Brasil (deve falhar)"
send_like "Brasil" "3001" "🇧🇷"
echo ""

# Enviar likes para regiões ainda funcionais
print_step "Enviando likes para regiões ainda funcionais (EU e USA)"
send_like "Europa" "3002" "🇪🇺"
send_like "Europa" "3002" "🇪🇺"
send_like "EUA" "3003" "🇺🇸"
send_like "EUA" "3003" "🇺🇸"
send_like "EUA" "3003" "🇺🇸"
wait_seconds 2

# Verificar estatísticas após falha
print_step "Estatísticas após falha da API do Brasil"
fetch_stats

# Verificar conectividade das outras APIs
print_step "Verificando conectividade das outras APIs"
test_api_connectivity "Europa" "3002" "🇪🇺"
test_api_connectivity "EUA" "3003" "🇺🇸"
echo ""

# Mais testes de likes nas regiões funcionais
print_step "Continuando a enviar likes para regiões funcionais"
send_like "Europa" "3002" "🇪🇺"
send_like "EUA" "3003" "🇺🇸"
wait_seconds 2

print_step "Estatísticas finais durante falha da API"
fetch_stats

# ============================================================================
# ANÁLISE DA FALHA
# ============================================================================
print_header "🔍 ANÁLISE DO IMPACTO DA FALHA"

echo -e "${BOLD}${GREEN}O que foi observado:${NC}"
echo -e "  ${CYAN}→${NC} API do Brasil: ${RED}Completamente indisponível${NC}"
echo -e "  ${CYAN}→${NC} APIs da Europa e EUA: ${GREEN}Continuam funcionando${NC}"
echo -e "  ${CYAN}→${NC} Dashboard: ${GREEN}Continua exibindo estatísticas${NC}"
echo -e "  ${CYAN}→${NC} Redis nodes: ${GREEN}Continuam replicando entre si${NC}"
echo ""

echo -e "${BOLD}${PURPLE}Impacto na disponibilidade:${NC}"
echo -e "  ${CYAN}→${NC} ${RED}Brasil${NC}: Indisponível para novos likes"
echo -e "  ${CYAN}→${NC} ${GREEN}Europa/EUA${NC}: Completamente funcionais"
echo -e "  ${CYAN}→${NC} ${GREEN}Sistema geral${NC}: ${BOLD}Alta disponibilidade mantida${NC}"
echo ""

echo -e "${BOLD}${GREEN}🔥 API BR failed — system still available${NC}"
echo ""
echo -e "${BOLD}${GREEN}✅ Redis continues replication for state integrity${NC}"
echo ""

# ============================================================================
# RECUPERAÇÃO (OPCIONAL)
# ============================================================================
print_header "🔄 RECUPERAÇÃO (OPCIONAL)"

echo -e "${BOLD}${PURPLE}Para recuperar a API do Brasil:${NC}"
echo -e "  ${CYAN}docker start api-br${NC}"
echo ""

echo -e "${BOLD}${PURPLE}Ou recriar completamente:${NC}"
echo -e "  ${CYAN}docker-compose up -d api-br${NC}"
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
echo -e "   ${YELLOW}./scripts/demo-reconnect.sh${NC}       - Reconexão e convergência"
echo -e "   ${YELLOW}./scripts/demo-hll.sh${NC}             - HyperLogLog"
echo ""

echo -e "${BOLD}${PURPLE}📱 Teste manualmente:${NC}"
echo -e "   ${CYAN}http://localhost:3002/like${NC}  (Europa - deve funcionar)"
echo -e "   ${CYAN}http://localhost:3003/like${NC}  (EUA - deve funcionar)"
echo -e "   ${CYAN}http://localhost:3001/like${NC}  (Brasil - deve falhar)"
echo ""

echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}Demo de falha de API concluído com sucesso! 🎉${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""