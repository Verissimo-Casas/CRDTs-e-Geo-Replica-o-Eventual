const express = require('express');
const redis = require('redis');
const cookieParser = require('cookie-parser');
const { v4: uuidv4 } = require('uuid');
const rateLimit = require('express-rate-limit');
const promClient = require('prom-client');

const app = express();
app.use(cookieParser());
app.use(express.urlencoded({ extended: true })); // Para processar dados de formulário

// Configuração a partir de variáveis de ambiente
const REDIS_HOST = process.env.REDIS_HOST || 'localhost';
const REGION_NAME = process.env.REGION_NAME || 'Região';
const REGION_IMG = process.env.REGION_IMG || '';
const ENABLE_HLL = process.env.ENABLE_HLL === 'true';

// Prometheus metrics
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

// Counter para likes por região
const likesCounter = new promClient.Counter({
  name: 'likes_total',
  help: 'Total number of likes by region',
  labelNames: ['region'],
  registers: [register]
});

// Histogram para latência das estatísticas
const statsLatencyHistogram = new promClient.Histogram({
  name: 'stats_latency_ms',
  help: 'Latency of stats operations in milliseconds',
  labelNames: ['operation', 'region'],
  buckets: [10, 50, 100, 250, 500, 1000],
  registers: [register]
});

// Gauge para divergência CRDT
const crdtDivergenceGauge = new promClient.Gauge({
  name: 'crdt_divergence',
  help: 'CRDT divergence measure across regions',
  labelNames: ['region'],
  registers: [register]
});

// Registrar a métrica com a região atual
likesCounter.labels(REGION_NAME.toLowerCase()).inc(0);

// Cliente Redis
const client = redis.createClient({
  socket: {
    host: REDIS_HOST,
    port: 6379
  }
});

client.on('error', (err) => console.error('Redis Client Error', err));

// Conectar ao Redis
(async () => {
  await client.connect();
  console.log(`✅ API ${REGION_NAME} conectada ao Redis em ${REDIS_HOST}`);
})();

// Rastreamento de IPs ativos e seus likes
const ipStats = new Map(); // { ip: { likes: count, lastSeen: timestamp, userAgent: string } }

// Rate limiter: 20 likes por minuto por IP
const likeLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minuto
  max: 20, // máximo de requisições
  message: {
    error: '⏱️ Muitos likes! Aguarde um momento antes de tentar novamente.',
    retryAfter: '60 segundos'
  },
  standardHeaders: true, // Retorna rate limit info nos headers `RateLimit-*`
  legacyHeaders: false, // Desabilita headers `X-RateLimit-*`
  skip: (req) => {
    // Não aplicar rate limit em desenvolvimento
    return process.env.NODE_ENV === 'development';
  },
  handler: (req, res) => {
    const remaining = req.rateLimit?.remaining || 0;
    const resetTime = new Date(Date.now() + 60000).toLocaleTimeString('pt-BR');
    
    console.log(`⚠️  Rate limit atingido para IP ${req.ip}`);
    
    res.status(429).send(`
      <!DOCTYPE html>
      <html lang="pt-BR">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Limite Atingido - ${REGION_NAME}</title>
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; }
          body {
            font-family: Arial, sans-serif;
            text-align: center;
            padding: 50px;
            background: linear-gradient(135deg, #f59e0b 0%, #ef4444 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          .container {
            background: rgba(255, 255, 255, 0.15);
            padding: 40px;
            border-radius: 20px;
            backdrop-filter: blur(10px);
            max-width: 500px;
          }
          h1 { font-size: 2.5em; margin-bottom: 20px; }
          p { font-size: 1.2em; line-height: 1.6; margin: 15px 0; }
          .retry-time { 
            font-size: 1.5em; 
            font-weight: bold; 
            color: #ffd700;
            margin: 20px 0;
          }
          a {
            display: inline-block;
            margin-top: 20px;
            padding: 15px 30px;
            background: white;
            color: #f59e0b;
            text-decoration: none;
            border-radius: 50px;
            font-weight: bold;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>⏱️ Calma lá!</h1>
          <p>Você atingiu o limite de likes por minuto.</p>
          <p class="retry-time">Tente novamente às ${resetTime}</p>
          <p>Limite: 20 likes por minuto</p>
          <a href="/">← Voltar</a>
        </div>
      </body>
      </html>
    `);
  }
});

// GET /like - Apenas exibe a página (não incrementa)
app.get('/like', async (req, res) => {
  try {
    // Gerar ou recuperar user_id do cookie
    let userId = req.cookies.user_id;
    
    if (!userId) {
      userId = uuidv4();
      res.cookie('user_id', userId, { maxAge: 365 * 24 * 60 * 60 * 1000 }); // 1 ano
    }

    // Apenas buscar valores atuais, sem incrementar
    const likes = await client.get('post:1:likes') || 0;
    const uniques = ENABLE_HLL ? await client.pfCount('post:1:uniques') : 'N/A';

    // Retornar página HTML de confirmação
    const html = `
      <!DOCTYPE html>
      <html lang="pt-BR">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Obrigado - ${REGION_NAME}</title>
        <style>
          * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
          }
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            text-align: center;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          .container {
            background: rgba(255, 255, 255, 0.15);
            padding: 40px 30px;
            border-radius: 20px;
            max-width: 500px;
            width: 100%;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
          }
          h1 { 
            font-size: 2.5em; 
            margin-bottom: 10px;
            animation: pulse 1s ease-in-out;
          }
          @keyframes pulse {
            0%, 100% { transform: scale(1); }
            50% { transform: scale(1.05); }
          }
          .region-img { 
            width: 120px; 
            height: 80px;
            margin: 20px 0; 
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
            object-fit: cover;
          }
          h2 {
            font-size: 1.8em;
            margin-bottom: 25px;
            font-weight: 600;
          }
          .stats { 
            font-size: 1.1em; 
            margin: 25px 0;
            background: rgba(255, 255, 255, 0.1);
            padding: 20px;
            border-radius: 12px;
          }
          .stats p {
            margin: 10px 0;
            line-height: 1.6;
          }
          .stats strong {
            display: block;
            font-size: 0.9em;
            opacity: 0.9;
            margin-bottom: 5px;
          }
          .count {
            font-size: 2em;
            font-weight: bold;
            color: #ffd700;
          }
          .button {
            display: inline-block;
            padding: 18px 40px;
            margin-top: 25px;
            background: white;
            color: #667eea;
            border: none;
            border-radius: 50px;
            font-weight: bold;
            font-size: 1.1em;
            transition: all 0.3s;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
            cursor: pointer;
          }
          .button:hover { 
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(0, 0, 0, 0.3);
          }
          .button:active {
            transform: translateY(0);
          }
          form {
            margin: 0;
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>👍 Dar Like!</h1>
          ${REGION_IMG ? `<img src="${REGION_IMG}" alt="${REGION_NAME}" class="region-img">` : ''}
          <h2>Região: ${REGION_NAME}</h2>
          <div class="stats">
            <p>
              <strong>Likes nesta região:</strong>
              <span class="count">${likes}</span>
            </p>
            ${ENABLE_HLL ? `<p><strong>Usuários únicos:</strong> <span class="count">~${uniques}</span></p>` : ''}
          </div>
          <form method="POST" action="/like">
            <button type="submit" class="button">Curtir agora! 🚀</button>
          </form>
          <div style="margin-top: 20px; font-size: 0.85em; opacity: 0.8;">
            <small>🕐 Clique no botão para registrar seu like!</small>
          </div>
        </div>
      </body>
      </html>
    `;

    res.send(html);
  } catch (error) {
    console.error('❌ Erro ao exibir página /like:', error);
    res.status(500).send(`
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Erro</title>
      </head>
      <body style="font-family: Arial; text-align: center; padding: 50px;">
        <h1>⚠️ Erro interno do servidor</h1>
        <p>Não foi possível carregar a página. Tente novamente.</p>
        <a href="/like" style="color: #667eea;">Tentar novamente</a>
      </body>
      </html>
    `);
  }
});

// POST /like - Processa o like (incrementa contador)
app.post('/like', likeLimiter, async (req, res) => {
  try {
    // Gerar ou recuperar user_id do cookie
    let userId = req.cookies.user_id;
    let isNewUser = false;
    
    if (!userId) {
      userId = uuidv4();
      isNewUser = true;
      res.cookie('user_id', userId, { maxAge: 365 * 24 * 60 * 60 * 1000 }); // 1 ano
      console.log(`🆕 Novo usuário: ${userId.slice(0, 8)}...`);
    }

    // Rastrear IP do cliente
    const clientIp = req.ip || req.connection.remoteAddress || 'unknown';
    const userAgent = req.get('user-agent') || 'Unknown';
    
    if (!ipStats.has(clientIp)) {
      ipStats.set(clientIp, { likes: 0, lastSeen: Date.now(), userAgent });
    }
    const ipData = ipStats.get(clientIp);
    ipData.likes++;
    ipData.lastSeen = Date.now();
    ipData.userAgent = userAgent;

    // Incrementar contador CRDT (PN-Counter)
    const likes = await client.incr('post:1:likes');
    console.log(`👍 Like registrado em ${REGION_NAME} do IP ${clientIp}. Total: ${likes}`);

    // Incrementar métrica Prometheus
    likesCounter.labels(REGION_NAME.toLowerCase()).inc();

    // Opcional: adicionar ao HyperLogLog para contagem de usuários únicos
    let uniques = 'N/A';
    if (ENABLE_HLL) {
      const wasAdded = await client.pfAdd('post:1:uniques', userId);
      uniques = await client.pfCount('post:1:uniques');
      
      // Log apenas se for usuário único novo
      if (wasAdded === 1 && isNewUser) {
        console.log(`👤 Novo usuário único detectado! Total de únicos: ${uniques}`);
      }
    }

    // Retornar página HTML de confirmação
    const html = `
      <!DOCTYPE html>
      <html lang="pt-BR">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Obrigado - ${REGION_NAME}</title>
        <style>
          * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
          }
          body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Arial, sans-serif;
            text-align: center;
            padding: 20px;
            background: linear-gradient(135deg, #10b981 0%, #059669 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
          }
          .container {
            background: rgba(255, 255, 255, 0.15);
            padding: 40px 30px;
            border-radius: 20px;
            max-width: 500px;
            width: 100%;
            backdrop-filter: blur(10px);
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
          }
          h1 { 
            font-size: 2.5em; 
            margin-bottom: 10px;
            animation: pulse 1s ease-in-out;
          }
          @keyframes pulse {
            0%, 100% { transform: scale(1); }
            50% { transform: scale(1.05); }
          }
          .region-img { 
            width: 120px; 
            height: 80px;
            margin: 20px 0; 
            border-radius: 8px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
            object-fit: cover;
          }
          h2 {
            font-size: 1.8em;
            margin-bottom: 25px;
            font-weight: 600;
          }
          .stats { 
            font-size: 1.1em; 
            margin: 25px 0;
            background: rgba(255, 255, 255, 0.1);
            padding: 20px;
            border-radius: 12px;
          }
          .stats p {
            margin: 10px 0;
            line-height: 1.6;
          }
          .stats strong {
            display: block;
            font-size: 0.9em;
            opacity: 0.9;
            margin-bottom: 5px;
          }
          .count {
            font-size: 2em;
            font-weight: bold;
            color: #ffd700;
          }
          .button {
            display: inline-block;
            padding: 18px 40px;
            margin-top: 25px;
            background: white;
            color: #10b981;
            text-decoration: none;
            border-radius: 50px;
            font-weight: bold;
            font-size: 1.1em;
            transition: all 0.3s;
            box-shadow: 0 4px 15px rgba(0, 0, 0, 0.2);
          }
          .button:hover { 
            transform: translateY(-2px);
            box-shadow: 0 6px 20px rgba(0, 0, 0, 0.3);
          }
          .button:active {
            transform: translateY(0);
          }
        </style>
      </head>
      <body>
        <div class="container">
          <h1>✅ Like registrado!</h1>
          ${REGION_IMG ? `<img src="${REGION_IMG}" alt="${REGION_NAME}" class="region-img">` : ''}
          <h2>Região: ${REGION_NAME}</h2>
          <div class="stats">
            <p>
              <strong>Likes nesta região:</strong>
              <span class="count">${likes}</span>
            </p>
            ${ENABLE_HLL ? `<p><strong>Usuários únicos:</strong> <span class="count">~${uniques}</span></p>` : ''}
          </div>
          <a href="/like" class="button">Curtir de novo! 🚀</a>
          <div style="margin-top: 20px; font-size: 0.85em; opacity: 0.8;">
            <small>🕐 Você pode dar mais ${req.rateLimit?.remaining || 0} likes neste minuto</small>
          </div>
        </div>
      </body>
      </html>
    `;

    res.send(html);
  } catch (error) {
    console.error('❌ Erro ao processar like:', error);
    res.status(500).send(`
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Erro</title>
      </head>
      <body style="font-family: Arial; text-align: center; padding: 50px;">
        <h1>⚠️ Erro interno do servidor</h1>
        <p>Não foi possível processar seu like. Tente novamente.</p>
        <a href="/like" style="color: #10b981;">Tentar novamente</a>
      </body>
      </html>
    `);
  }
});

// Health check detalhado
app.get('/health', async (req, res) => {
  const health = {
    status: 'ok',
    region: REGION_NAME,
    timestamp: new Date().toISOString(),
    uptime: Math.floor(process.uptime()),
    redis: {
      connected: false,
      latency: null,
      host: REDIS_HOST
    }
  };

  try {
    const start = Date.now();
    await client.ping();
    const latency = Date.now() - start;
    
    health.redis.connected = true;
    health.redis.latency = `${latency}ms`;
    
    res.status(200).json(health);
  } catch (error) {
    health.status = 'degraded';
    health.redis.connected = false;
    health.redis.error = error.message;
    res.status(503).json(health);
  }
});

// Readiness probe (para Kubernetes/orquestração)
app.get('/ready', async (req, res) => {
  try {
    await client.ping();
    res.status(200).send('Ready');
  } catch (error) {
    res.status(503).send('Not Ready');
  }
});

// Liveness probe
app.get('/live', (req, res) => {
  res.status(200).send('Alive');
});

// Endpoint de estatísticas de IPs ativos
app.get('/ip-stats', (req, res) => {
  const now = Date.now();
  const activeThreshold = 5 * 60 * 1000; // 5 minutos
  
  // Filtrar IPs ativos (vistos nos últimos 5 minutos)
  const activeIps = [];
  
  for (const [ip, data] of ipStats.entries()) {
    if (now - data.lastSeen < activeThreshold) {
      activeIps.push({
        ip: ip.replace('::ffff:', ''), // Limpar prefixo IPv6
        likes: data.likes,
        lastSeen: new Date(data.lastSeen).toISOString(),
        userAgent: data.userAgent
      });
    }
  }
  
  // Ordenar por quantidade de likes (decrescente)
  activeIps.sort((a, b) => b.likes - a.likes);
  
  res.json({
    region: REGION_NAME,
    totalActiveIps: activeIps.length,
    ips: activeIps
  });
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

// Rota raiz
app.get('/', (req, res) => {
  res.send(`
    <!DOCTYPE html>
    <html lang="pt-BR">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>API ${REGION_NAME}</title>
      <style>
        body {
          font-family: Arial, sans-serif;
          text-align: center;
          padding: 50px;
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
          color: white;
        }
        h1 { font-size: 3em; }
        a {
          display: inline-block;
          margin-top: 30px;
          padding: 15px 30px;
          background: white;
          color: #667eea;
          text-decoration: none;
          border-radius: 50px;
          font-weight: bold;
        }
      </style>
    </head>
    <body>
      <h1>🌍 API ${REGION_NAME}</h1>
      <p>Demo CRDT - Geo-Replicação</p>
      <a href="/like">👍 Dar um Like!</a>
    </body>
    </html>
  `);
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`🚀 API ${REGION_NAME} rodando na porta ${PORT}`);
});
