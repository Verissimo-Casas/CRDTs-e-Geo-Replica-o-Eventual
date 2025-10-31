# 🌍 CRDT Demo - Geo-Replicação com Redis

Demonstração **interativa** e **ao vivo** de conceitos fundamentais de sistemas distribuídos: **Alta Disponibilidade (AP)**, **Consistência Eventual** e **Resolução Automática de Conflitos via CRDT**.

```
┌─────────────────────────────────────────────────────────────┐
│                    Teorema CAP na Prática                   │
│  Availability + Partition Tolerance → Eventual Consistency  │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Objetivo

Provar conceitos do **Teorema CAP** através de uma aplicação geo-replicada com 3 regiões (Brasil, Europa, EUA) que:

✅ **Aceita likes localmente** (baixa latência)  
✅ **Mantém disponibilidade** durante partições de rede (AP)  
✅ **Converge automaticamente** após reconexão (CRDT)  
✅ **Demonstra visualmente** o comportamento do sistema em tempo real

---

## 🏗️ Arquitetura

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   API Brasil │     │  API Europa  │     │    API EUA   │
│  Port: 3001  │     │  Port: 3002  │     │  Port: 3003  │
└──────┬───────┘     └──────┬───────┘     └──────┬───────┘
       │                    │                    │
       ▼                    ▼                    ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  Redis BR    │────▶│  Redis EU    │◀────│  Redis USA   │
│ (CRDT Sync)  │     │ (CRDT Sync)  │     │ (CRDT Sync)  │
└──────────────┘     └──────────────┘     └──────────────┘
       │                    │                    │
       └────────────────────┼────────────────────┘
                            ▼
                    ┌───────────────┐
                    │   Dashboard   │
                    │  Port: 3000   │
                    │  (Polling 1s) │
                    └───────────────┘
                            │
                            ▼
              ┌─────────────────────────────┐
              │        MONITORING           │
              │  ┌─────────────┐ ┌─────────┐ │
              │  │ Prometheus  │ │ Grafana │ │
              │  │ Port: 9090  │ │3004:3000│ │
              │  └─────────────┘ └─────────┘ │
              └─────────────────────────────┘
```

### Componentes:

- **3 APIs Regionais** (Node.js + Express)
  - Endpoint `/like` com cookies anônimos
  - Incrementa contador CRDT local (`post:1:likes`)
  - HyperLogLog para usuários únicos (`post:1:uniques`)

- **3 Nós Redis** (com suporte CRDT)
  - PN-Counter para likes (convergência automática)
  - Replicação eventual entre regiões

- **1 Dashboard** (Node.js + HTML/JS)
  - Polling de `/stats` a cada 1 segundo
  - Visualização de convergência/divergência/offline

- **Prometheus** (Métricas)
  - Coleta métricas de todos os serviços
  - Exposição de métricas em `/metrics` (se implementado)

- **Grafana** (Visualização)
  - Dashboards customizáveis
  - Integração com Prometheus como fonte de dados

---

## 🚀 Como Rodar

### Pré-requisitos
- Docker 20+
- Docker Compose 2+

### 1. Subir o ambiente completo

```bash
cd crdt-demo
docker-compose up --build
```

Aguarde os 9 serviços subirem:
```
✅ redis-br (port 7001)
✅ redis-eu (port 7002)
✅ redis-usa (port 7003)
✅ api-br (port 3001)
✅ api-eu (port 3002)
✅ api-usa (port 3003)
✅ dashboard (port 3000)
✅ prometheus (port 9090)
✅ grafana (port 3004)
```

### 3. Configurar Grafana (Opcional)

Após subir os serviços:

1. **Acesse Grafana:** http://localhost:3004
2. **Login:** admin / admin
3. **Adicionar Data Source:**
   - Type: Prometheus
   - URL: http://prometheus:9090
   - Access: Server (default)
4. **Criar Dashboard** para visualizar métricas dos serviços

---

## 🎭 Roteiro de Demonstração ao Vivo

### **Fase 1: Estado Inicial (Convergido)** ✅

```bash
# Abrir dashboard
open http://localhost:3000
```

**Expectativa:**
- 3 regiões online
- Status: **✅ Convergido (0 likes)**
- Indicadores verdes

---

### **Fase 2: Gerar Likes** 👍

```bash
# Simular likes em diferentes regiões (ou use QR codes)
curl http://localhost:3001/like  # Brasil
curl http://localhost:3002/like  # Europa
curl http://localhost:3003/like  # EUA
```

**Expectativa:**
- Valores sobem em todas as regiões
- Status: **✅ Convergido (N likes)**
- Sincronização automática entre nós

---

### **Fase 3: Simular Partição de Rede** ⚠️

```bash
# Usar script automatizado
./scripts/partition.sh

# OU manualmente:
docker network disconnect crdt-demo_crdt-network redis-eu
```

**Expectativa:**
```
┌──────────┐     ┌──────────┐     ┌──────────┐
│ Brasil ✅│◀───▶│Europa ❌ │     │  EUA  ✅ │
│ online   │     │ OFFLINE  │     │ online   │
└──────────┘     └──────────┘     └──────────┘
```

- Dashboard mostra: **⚠️ 1 região(s) offline**
- Brasil e EUA continuam convergindo entre si
- Europa **continua aceitando likes** localmente (AP!)

```bash
# Teste: Europa ainda responde!
curl http://localhost:3002/like
# ✅ Funciona! (Alta Disponibilidade)
```

---

### **Fase 4: Reconexão e Convergência** 🔄

```bash
# Usar script automatizado
./scripts/reconnect.sh

# OU manualmente:
docker network connect crdt-demo_crdt-network redis-eu
```

**Expectativa:**
```
┌──────────┐     ┌──────────┐     ┌──────────┐
│ Brasil ✅│◀───▶│Europa ✅ │◀───▶│  EUA  ✅ │
│   42     │     │   42     │     │   42     │
└──────────┘     └──────────┘     └──────────┘
```

- Status muda para: **🔄 Divergente** (temporariamente)
- Após 5-10 segundos: **✅ Convergido**
- **CRDT faz merge automático** dos valores!

---

## 🧪 Conceitos Demonstrados

### 1. **Teorema CAP**
Durante partição, priorizamos **AP** (Availability + Partition Tolerance):
- Sistema continua disponível mesmo com nó offline
- Consistência forte é sacrificada temporariamente
- Convergência eventual após reconexão

### 2. **CRDT (PN-Counter)**
```
Counter_global = Σ increments_per_node - Σ decrements_per_node
```
- Operações comutativas (ordem não importa)
- Merge determinístico (sem conflitos)
- Não requer líder ou lock distribuído

### 3. **HyperLogLog (Opcional)**
- Estimativa de cardinalidade (usuários únicos)
- Memória constante (~12KB para bilhões de elementos)
- Erro: ~0.81%

### 4. **Geo-Replicação**
- Latência baixa (leitura/escrita local)
- Replicação assíncrona (eventual consistency)
- Failover automático

---

## 📊 Endpoints

### APIs Regionais (BR/EU/USA)

#### `GET /like`
Incrementa contador local e retorna HTML de confirmação.

**Response:**
```html
<!DOCTYPE html>
<html>
<body>
  <h1>❤️ Obrigado por curtir!</h1>
  <h2>Região: Brasil 🇧🇷</h2>
  <p><strong>Likes nesta região:</strong> 42</p>
  <p><strong>Usuários únicos:</strong> ~15</p>
  <a href="/like">Curtir de novo! 🚀</a>
</body>
</html>
```

**Cookies:**
- `user_id` (UUID v4) - criado automaticamente se não existir

---

### Dashboard

#### `GET /stats`
Retorna JSON com status de todas as regiões.

**Response:**
```json
{
  "br": { "likes": 42, "uniques": 15 },
  "eu": { "likes": "Offline", "uniques": "Offline" },
  "usa": { "likes": 42, "uniques": 15 }
}
```

#### `GET /metrics` (Opcional)
Endpoint Prometheus para métricas customizadas.

---

### Dashboard

#### `GET /`
Interface visual com polling automático (1s).

---

### Prometheus

#### `GET /`
Interface web do Prometheus (porta 9090).

**Targets configurados:**
- api-br:3000/metrics
- api-eu:3000/metrics
- api-usa:3000/metrics
- dashboard:3000/metrics
- redis-br:6379
- redis-eu:6379
- redis-usa:6379

---

### Grafana

#### `GET /`
Interface web do Grafana (porta 3004).

**Configuração inicial:**
- Usuário: admin
- Senha: admin

---

## 🔧 Scripts Auxiliares

### Partição de Rede
```bash
./scripts/partition.sh
```
- Detecta rede Docker automaticamente
- Desconecta `redis-eu` da rede
- Mostra status esperado

### Reconexão
```bash
./scripts/reconnect.sh
```
- Reconecta `redis-eu` à rede
- Aguarda convergência CRDT

---

## 📁 Estrutura do Projeto

```
crdt-demo/
├── docker-compose.yml       # Orquestração dos 9 serviços
├── README.md                # Este arquivo
│
├── api/                     # API Regional (Node.js)
│   ├── Dockerfile
│   ├── package.json
│   └── index.js             # Express + Redis client
│
├── dashboard/               # Dashboard (Node.js)
│   ├── Dockerfile
│   ├── package.json
│   ├── index.js             # Backend /stats
│   └── index.html           # Frontend com polling
│
├── monitoring/              # Configurações de monitoramento
│   └── prometheus.yml       # Configuração Prometheus
│
└── scripts/                 # Scripts de demonstração
    ├── partition.sh         # Simula partição
    ├── reconnect.sh         # Reconecta rede
    └── generate_qr_codes.md # Guia para QR codes
```

---

## 🧪 Testes Mínimos

### T-1: Funcional
```bash
for i in {1..10}; do curl -s http://localhost:3001/like > /dev/null; done
# Verificar dashboard: Brasil deve ter >= 10 likes
```

### T-2: Convergência
```bash
curl http://localhost:3001/like  # BR
curl http://localhost:3002/like  # EU
curl http://localhost:3003/like  # USA
sleep 5
# Verificar dashboard: todos devem ter mesmo valor
```

### T-3: Partição
```bash
./scripts/partition.sh
curl http://localhost:3002/like  # Europa ainda responde!
# Dashboard deve mostrar Europa como Offline
```

### T-4: Reconexão
```bash
./scripts/reconnect.sh
sleep 10
# Dashboard deve mostrar status Convergido
```

### T-5: Monitoramento
```bash
# Verificar Prometheus
curl http://localhost:9090/-/healthy
# Deve retornar: Prometheus is Healthy!

# Verificar Grafana
curl http://localhost:3004/api/health
# Deve retornar status OK
```

### T-1: Funcional
```bash
for i in {1..10}; do curl -s http://localhost:3001/like > /dev/null; done
# Verificar dashboard: Brasil deve ter >= 10 likes
```

### T-2: Convergência
```bash
curl http://localhost:3001/like  # BR
curl http://localhost:3002/like  # EU
curl http://localhost:3003/like  # USA
sleep 5
# Verificar dashboard: todos devem ter mesmo valor
```

### T-3: Partição
```bash
./scripts/partition.sh
curl http://localhost:3002/like  # Europa ainda responde!
# Dashboard deve mostrar Europa como Offline
```

### T-4: Reconexão
```bash
./scripts/reconnect.sh
sleep 10
# Dashboard deve mostrar status Convergido
```

---

## 🎨 Personalização

### Mudar portas
Edite `docker-compose.yml`:
```yaml
services:
  dashboard:
    ports:
      - "8080:3000"  # Nova porta externa
```

### Desabilitar HyperLogLog
```yaml
environment:
  - ENABLE_HLL=false
```

### Desabilitar monitoramento
```yaml
# Comente ou remova estes serviços do docker-compose.yml
# prometheus:
# grafana:
```

### Configurar alertas no Prometheus
Edite `monitoring/prometheus.yml`:
```yaml
rule_files:
  - "alert_rules.yml"
```

---

## � Troubleshooting

### Porta já em uso
```bash
# Verificar processos
lsof -i :3000

# Mudar porta no docker-compose.yml
```

### Container não conecta ao Redis
```bash
# Verificar logs
docker logs api-br

# Verificar rede
docker network inspect crdt-demo_crdt-network
```

### Dashboard mostra "Offline" mesmo com containers rodando
```bash
# Verificar se Redis está pronto
docker exec redis-br redis-cli PING
# Deve retornar: PONG
```

---

## 📚 Referências

- **CAP Theorem**: Brewer, 2000
- **CRDT**: Shapiro et al., 2011
- **Redis CRDT**: [Redis Enterprise Active-Active](https://redis.io/docs/stack/active-active/)
- **HyperLogLog**: Flajolet et al., 2007

---

## 📝 Notas

- ⚠️ **MVP educacional** - não use em produção sem ajustes de segurança
- 🍪 Cookies anônimos apenas (UUID v4)
- 🔒 Sem autenticação ou rate limiting
- 📊 Redis padrão não tem CRDT nativo (use Redis Stack ou Enterprise para produção)
- 🎯 Foco em demonstração de conceitos, não em performance

---

## 🤝 Contribuindo

Este é um projeto educacional. Sugestões e melhorias são bem-vindas!

---

## 📄 Licença

MIT License - Livre para uso educacional e demonstrações.

---

**Desenvolvido para demonstração de conceitos de Banco de Dados II** 🎓
