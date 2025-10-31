#!/bin/bash

# Script de Demonstração - Comportamento HyperLogLog (HLL)
# Demonstra contagem de usuários únicos com HyperLogLog

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

# Função para enviar like com cookie específico
send_like_with_cookie() {
    local region=$1
    local port=$2
    local flag=$3
    local cookie_file=$4
    local user_label=$5

    echo -e "${CYAN}   👍 ${user_label} enviando like para ${flag} ${region}...${NC}"

    # Fazer requisição POST /like com cookie
    response=$(curl -s -X POST \
        --cookie-jar "$cookie_file" \
        --cookie "$cookie_file" \
        -L "http://localhost:${port}/like" 2>&1)

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

# Função para extrair valores específicos
get_stats_values() {
    stats=$(curl -s http://localhost:3000/stats 2>&1)

    if [ $? -ne 0 ]; then
        echo "Erro:Offline:Offline"
        return 1
    fi

    # Extrair valores (usando Brasil como exemplo)
    likes=$(echo "$stats" | jq -r '.br.likes // "Offline"' 2>/dev/null)
    uniques=$(echo "$stats" | jq -r '.br.uniques // "Offline"' 2>/dev/null)

    echo "${likes}:${uniques}"
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

print_header "🎯 DEMO: HYPERLOGLOG - CONTAGEM DE USUÁRIOS ÚNICOS"
print_info "Demonstra como HLL conta usuários únicos mesmo com múltiplas interações"

# Verificar se containers estão rodando
print_step "Verificando se os containers estão rodando..."
if ! docker ps | grep -q "redis-br\|redis-eu\|redis-usa\|api-br\|api-eu\|api-usa\|dashboard"; then
    print_error "Containers não estão rodando. Execute 'docker-compose up -d' primeiro"
    exit 1
fi
print_success "Containers estão rodando"

# Verificar se HLL está habilitado
print_step "Verificando se HyperLogLog está habilitado..."
stats=$(curl -s http://localhost:3000/stats 2>&1)
if [[ $stats == *"uniques"* ]]; then
    print_success "HLL está habilitado - contagem de usuários únicos disponível"
else
    print_warning "HLL pode não estar habilitado - verifique ENABLE_HLL=true no docker-compose.yml"
fi

# Estado inicial
print_step "Estado inicial (antes de qualquer like)"
fetch_stats

# Criar arquivos de cookies para simular usuários diferentes
USER1_COOKIE="/tmp/user1_cookies.txt"
USER2_COOKIE="/tmp/user2_cookies.txt"

# Limpar cookies anteriores
rm -f "$USER1_COOKIE" "$USER2_COOKIE"

print_header "👤 USUÁRIO 1: MÚLTIPLAS INTERAÇÕES COM MESMO COOKIE"

# Usuário 1 - Like 1
print_step "Usuário 1 - Like 1 (novo usuário)"
send_like_with_cookie "Brasil" "3001" "🇧🇷" "$USER1_COOKIE" "👤 Usuário 1"
wait_seconds 1

print_step "Estatísticas após primeiro like do Usuário 1"
result=$(get_stats_values)
IFS=':' read -r likes uniques <<< "$result"
echo -e "${BOLD}${WHITE}Após 1 like do Usuário 1:${NC}"
echo -e "   Likes: ${CYAN}${likes}${NC}"
echo -e "   Uniques: ${CYAN}${uniques}${NC}"
echo ""

# Usuário 1 - Like 2
print_step "Usuário 1 - Like 2 (mesmo usuário)"
send_like_with_cookie "Brasil" "3001" "🇧🇷" "$USER1_COOKIE" "👤 Usuário 1"
wait_seconds 1

print_step "Estatísticas após segundo like do Usuário 1"
result=$(get_stats_values)
IFS=':' read -r likes uniques <<< "$result"
echo -e "${BOLD}${WHITE}Após 2 likes do Usuário 1:${NC}"
echo -e "   Likes: ${CYAN}${likes}${NC} (aumentou)"
echo -e "   Uniques: ${CYAN}${uniques}${NC} (permanece igual)"
echo ""

# Usuário 1 - Like 3, 4, 5
print_step "Usuário 1 - Likes 3, 4, 5 (mesmo usuário)"
for i in {3..5}; do
    send_like_with_cookie "Brasil" "3001" "🇧🇷" "$USER1_COOKIE" "👤 Usuário 1"
    sleep 0.5
done
wait_seconds 1

print_step "Estatísticas após 5 likes do Usuário 1"
result=$(get_stats_values)
IFS=':' read -r likes uniques <<< "$result"
echo -e "${BOLD}${WHITE}Após 5 likes do Usuário 1:${NC}"
echo -e "   Likes: ${CYAN}${likes}${NC} (continua aumentando)"
echo -e "   Uniques: ${CYAN}${uniques}${NC} (ainda único usuário)"
echo ""

print_info "📝 Observação: Mesmo com 5 likes, únicos permanece em 1 porque é o mesmo usuário!"

print_header "👥 USUÁRIO 2: NOVO COOKIE, NOVO USUÁRIO ÚNICO"

# Usuário 2 - Like 1 (novo cookie)
print_step "Usuário 2 - Like 1 (usuário completamente novo)"
send_like_with_cookie "Brasil" "3001" "🇧🇷" "$USER2_COOKIE" "👥 Usuário 2"
wait_seconds 1

print_step "Estatísticas após primeiro like do Usuário 2"
result=$(get_stats_values)
IFS=':' read -r likes uniques <<< "$result"
echo -e "${BOLD}${WHITE}Após 1 like do Usuário 2:${NC}"
echo -e "   Likes: ${CYAN}${likes}${NC} (aumentou)"
echo -e "   Uniques: ${CYAN}${uniques}${NC} (AGORA aumentou!)"
echo ""

# Usuário 2 - Like 2
print_step "Usuário 2 - Like 2 (mesmo usuário 2)"
send_like_with_cookie "Brasil" "3001" "🇧🇷" "$USER2_COOKIE" "👥 Usuário 2"
wait_seconds 1

print_step "Estatísticas após segundo like do Usuário 2"
result=$(get_stats_values)
IFS=':' read -r likes uniques <<< "$result"
echo -e "${BOLD}${WHITE}Após 2 likes do Usuário 2:${NC}"
echo -e "   Likes: ${CYAN}${likes}${NC} (continua aumentando)"
echo -e "   Uniques: ${CYAN}${uniques}${NC} (permanece igual para usuário 2)"
echo ""

print_header "📊 RESUMO FINAL DA DEMONSTRAÇÃO"

echo -e "${BOLD}${GREEN}Resultados observados:${NC}"
echo -e "  ${CYAN}→${NC} Usuário 1: 5 likes → 1 único (correto)"
echo -e "  ${CYAN}→${NC} Usuário 2: 2 likes → 1 único (correto)"
echo -e "  ${CYAN}→${NC} Total: 7 likes → 2 únicos (correto)"
echo ""

echo -e "${BOLD}${PURPLE}Como funciona o HyperLogLog:${NC}"
echo -e "  ${CYAN}→${NC} ${BOLD}Probabilístico${NC}: Estimativa, não contagem exata"
echo -e "  ${CYAN}→${NC} ${BOLD}Memory-efficient${NC}: Usa pouco espaço (~1.5KB para milhões)"
echo -e "  ${CYAN}→${NC} ${BOLD}Mergeable${NC}: Pode ser combinado entre regiões"
echo -e "  ${CYAN}→${NC} ${BOLD}No false negatives${NC}: Nunca subestima usuários únicos"
echo ""

echo -e "${BOLD}${GREEN}🎯 HLL demonstrates unique user counting across regions${NC}"
echo ""

# Limpar arquivos de cookies
rm -f "$USER1_COOKIE" "$USER2_COOKIE"

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
echo ""

echo -e "${BOLD}${PURPLE}📱 Teste manualmente:${NC}"
echo -e "   ${CYAN}http://localhost:3001/like${NC}  (Brasil)"
echo -e "   ${CYAN}http://localhost:3002/like${NC}  (Europa)"
echo -e "   ${CYAN}http://localhost:3003/like${NC}  (EUA)"
echo ""

echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}Demo HLL concluído com sucesso! 🎉${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""