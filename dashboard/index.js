const express = require('express');
const redis = require('redis');
const path = require('path');
const promClient = require('prom-client');

const app = express();

// Configuração dos clientes Redis para cada região
const regions = {
  br: { host: 'redis-br', name: 'Brasil' },
  eu: { host: 'redis-eu', name: 'Europa' },
  usa: { host: 'redis-usa', name: 'EUA' }
};

// Criar clientes Redis
const clients = {};

async function initializeClients() {
  for (const [key, region] of Object.entries(regions)) {
    clients[key] = redis.createClient({
      socket: {
        host: region.host,
        port: 6379,
        connectTimeout: 2000,
        reconnectStrategy: (retries) => {
          if (retries > 10) return new Error('Max retries reached');
          return Math.min(retries * 100, 3000);
        }
      }
    });
    
    clients[key].on('error', (err) => {
      console.error(`❌ Redis Client Error (${key}):`, err.message);
    });

    clients[key].on('connect', () => {
      console.log(`✅ Conectado ao Redis ${key} (${region.name})`);
    });

    clients[key].on('reconnecting', () => {
      console.log(`🔄 Reconectando ao Redis ${key}...`);
    });

    // Tentar conectar (não bloquear se falhar)
    try {
      await clients[key].connect();
    } catch (err) {
      console.error(`⚠️  Falha inicial ao conectar no Redis ${key}:`, err.message);
    }
  }
}

// Inicializar clientes
initializeClients();

// Prometheus metrics
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

// Histogram para latência das estatísticas
const statsLatencyHistogram = new promClient.Histogram({
  name: 'stats_latency_ms',
  help: 'Latency of stats operations in milliseconds',
  labelNames: ['operation'],
  buckets: [10, 50, 100, 250, 500, 1000],
  registers: [register]
});

// Gauge para divergência CRDT
const crdtDivergenceGauge = new promClient.Gauge({
  name: 'crdt_divergence',
  help: 'CRDT divergence measure across regions',
  registers: [register]
});

console.log('🚀 Dashboard iniciado - conectando aos Redis regionais...');

// Servir página HTML estática
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// Endpoint de estatísticas (JSON)
app.get('/stats', async (req, res) => {
  const startTime = Date.now();
  const stats = {};

  // Consultar cada região independentemente
  const promises = Object.keys(regions).map(async (key) => {
    try {
      // Verificar se cliente está pronto
      if (!clients[key] || !clients[key].isReady) {
        return { key, data: { likes: 'Offline', uniques: 'Offline' } };
      }

      // Timeout de 2 segundos para cada operação
      const likesPromise = Promise.race([
        clients[key].get('post:1:likes'),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Timeout')), 2000)
        )
      ]);

      const uniquesPromise = Promise.race([
        clients[key].pfCount('post:1:uniques'),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Timeout')), 2000)
        )
      ]);

      const [likes, uniques] = await Promise.all([
        likesPromise.catch(() => null),
        uniquesPromise.catch(() => 0)
      ]);

      // Se likes for null, significa que falhou
      if (likes === null) {
        return { key, data: { likes: 'Offline', uniques: 'Offline' } };
      }

      return {
        key,
        data: {
          likes: parseInt(likes) || 0,
          uniques: uniques || 0
        }
      };
    } catch (error) {
      console.error(`⚠️  Erro ao obter stats de ${key}:`, error.message);
      return { key, data: { likes: 'Offline', uniques: 'Offline' } };
    }
  });

  // Aguardar todas as consultas
  const results = await Promise.all(promises);

  // Montar objeto de resposta
  results.forEach(({ key, data }) => {
    stats[key] = data;
  });

  // Log do estado atual
  const onlineCount = Object.values(stats).filter(s => s.likes !== 'Offline').length;
  const offlineCount = 3 - onlineCount;
  
  if (offlineCount > 0) {
    console.log(`📊 Stats: ${onlineCount} online, ${offlineCount} offline`);
  }

  // Medir latência da operação stats
  const latency = Date.now() - startTime;
  console.log(`⏱️  Stats operation took ${latency}ms`);
  
  // Registrar latência na métrica Prometheus
  statsLatencyHistogram.observe({ operation: 'stats' }, latency);

  // Calcular divergência CRDT (diferença máxima entre regiões online)
  const onlineStats = Object.values(stats).filter(s => s.likes !== 'Offline' && typeof s.likes === 'number');
  if (onlineStats.length > 1) {
    const likesValues = onlineStats.map(s => s.likes);
    const maxLikes = Math.max(...likesValues);
    const minLikes = Math.min(...likesValues);
    const divergence = maxLikes - minLikes;
    crdtDivergenceGauge.set(divergence);
    console.log(`📊 CRDT Divergence: ${divergence} (max: ${maxLikes}, min: ${minLikes})`);
  }

  res.json(stats);
});

// Endpoint de IPs ativos em todas as APIs
app.get('/active-ips', async (req, res) => {
  const apiPorts = {
    br: 3001,
    eu: 3002,
    usa: 3003
  };

  const ipStatsPromises = Object.keys(regions).map(async (key) => {
    try {
      const response = await fetch(`http://api-${key}:3000/ip-stats`, {
        signal: AbortSignal.timeout(2000)
      });
      
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      
      const data = await response.json();
      return { key, data };
    } catch (error) {
      console.error(`⚠️  Erro ao obter IP stats de ${key}:`, error.message);
      return { 
        key, 
        data: { 
          region: regions[key].name, 
          totalActiveIps: 0, 
          ips: [],
          offline: true 
        } 
      };
    }
  });

  const results = await Promise.all(ipStatsPromises);
  
  const response = {};
  results.forEach(({ key, data }) => {
    response[key] = data;
  });

  res.json(response);
});

// Health check detalhado
app.get('/health', async (req, res) => {
  const healthStatus = {
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: Math.floor(process.uptime()),
    regions: {}
  };

  let allOnline = true;
  const latencyTests = [];

  // Testar latência de cada região
  for (const [key, region] of Object.entries(regions)) {
    const regionHealth = {
      name: region.name,
      host: region.host,
      connected: false,
      latency: null
    };

    if (clients[key] && clients[key].isReady) {
      try {
        const start = Date.now();
        await clients[key].ping();
        const latency = Date.now() - start;
        
        regionHealth.connected = true;
        regionHealth.latency = `${latency}ms`;
        latencyTests.push(latency);
      } catch (error) {
        regionHealth.connected = false;
        regionHealth.error = error.message;
        allOnline = false;
      }
    } else {
      regionHealth.connected = false;
      allOnline = false;
    }

    healthStatus.regions[key] = regionHealth;
  }

  // Calcular latência média
  if (latencyTests.length > 0) {
    const avgLatency = Math.round(latencyTests.reduce((a, b) => a + b, 0) / latencyTests.length);
    healthStatus.averageLatency = `${avgLatency}ms`;
  }

  // Determinar status global
  if (!allOnline) {
    healthStatus.status = 'degraded';
    return res.status(503).json(healthStatus);
  }

  res.json(healthStatus);
});

// Endpoint Prometheus metrics
app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    const metrics = await register.metrics();
    res.end(metrics);
  } catch (error) {
    console.error('❌ Erro ao gerar métricas Prometheus:', error);
    res.status(500).end();
  }
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`📊 Dashboard rodando na porta ${PORT}`);
  console.log(`🌐 Acesse: http://localhost:${PORT}`);
});
