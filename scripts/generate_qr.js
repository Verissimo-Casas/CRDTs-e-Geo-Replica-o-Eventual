#!/usr/bin/env node

/**
 * Gerador de QR Codes para Demo CRDT
 * 
 * Uso:
 *   node generate_qr.js              # URLs com IP local (rede)
 *   node generate_qr.js --localhost  # URLs localhost
 *   node generate_qr.js --ngrok      # Aguarda URLs do ngrok
 */

const qrcode = require('qrcode-terminal');
const readline = require('readline');
const os = require('os');

const regions = {
  br: { 
    port: 3001, 
    name: 'Brasil 🇧🇷',
    color: '\x1b[32m' // Verde
  },
  eu: { 
    port: 3002, 
    name: 'Europa 🇪🇺',
    color: '\x1b[34m' // Azul
  },
  usa: { 
    port: 3003, 
    name: 'EUA 🇺🇸',
    color: '\x1b[31m' // Vermelho
  }
};

const reset = '\x1b[0m';
const useNgrok = process.argv.includes('--ngrok');
const useLocalhost = process.argv.includes('--localhost');

/**
 * Detecta o IP local da máquina
 */
function getLocalIp() {
  const interfaces = os.networkInterfaces();
  
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]) {
      // Ignorar loopback e endereços IPv6
      if (iface.family === 'IPv4' && !iface.internal) {
        return iface.address;
      }
    }
  }
  
  return 'localhost'; // Fallback
}

console.log('\n' + '='.repeat(60));
console.log('🎯  Gerador de QR Codes - Demo CRDT');
console.log('='.repeat(60) + '\n');

if (!useNgrok) {
  // Modo local (rede ou localhost)
  const host = useLocalhost ? 'localhost' : getLocalIp();
  const modoDesc = useLocalhost ? 'Localhost (apenas esta máquina)' : 'IP Local (rede WiFi)';
  
  console.log(`📍 Modo: ${modoDesc}`);
  console.log(`🌐 Host: ${host}\n`);
  
  if (!useLocalhost) {
    console.log('📱 Dispositivos na mesma rede WiFi podem escanear!\n');
    console.log('💡 Dicas:');
    console.log('   - Certifique-se que o firewall permite conexões nas portas 3001-3003');
    console.log('   - Conecte os dispositivos na mesma rede WiFi');
    console.log('   - Para apenas localhost, use: node generate_qr.js --localhost\n');
  } else {
    console.log('💡 Dica: Para acesso em rede, use sem parâmetros: node generate_qr.js\n');
  }
  
  console.log('━'.repeat(60) + '\n');
  
  for (const [key, region] of Object.entries(regions)) {
    const url = `http://${host}:${region.port}/like`;
    
    console.log(`${region.color}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}`);
    console.log(`${region.color}📍 ${region.name}${reset}`);
    console.log(`🔗 ${url}\n`);
    qrcode.generate(url, { small: true });
    console.log('');
  }
  
  console.log('='.repeat(60));
  console.log('✅ QR Codes gerados com sucesso!');
  console.log('📱 Escaneie com seu smartphone para dar likes!\n');
  
} else {
  // Modo ngrok - solicitar URLs
  console.log('🌐 Modo: URLs Públicas (ngrok)\n');
  console.log('⚠️  Antes de continuar, execute ngrok em terminais separados:\n');
  console.log('   Terminal 1: ngrok http 3001  # Brasil');
  console.log('   Terminal 2: ngrok http 3002  # Europa');
  console.log('   Terminal 3: ngrok http 3003  # EUA\n');
  
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
  });
  
  const ngrokUrls = {};
  const regionKeys = Object.keys(regions);
  let currentIndex = 0;
  
  function askForUrl() {
    if (currentIndex >= regionKeys.length) {
      rl.close();
      generateQRCodes();
      return;
    }
    
    const key = regionKeys[currentIndex];
    const region = regions[key];
    
    rl.question(`🔗 Digite a URL do ngrok para ${region.name}: `, (url) => {
      url = url.trim();
      
      // Validar URL
      if (!url.startsWith('http')) {
        console.log('❌ URL inválida! Deve começar com http:// ou https://');
        askForUrl();
        return;
      }
      
      // Remover barra final se existir
      url = url.replace(/\/$/, '');
      ngrokUrls[key] = `${url}/like`;
      
      currentIndex++;
      askForUrl();
    });
  }
  
  function generateQRCodes() {
    console.log('\n' + '='.repeat(60));
    console.log('🎯  Gerando QR Codes com URLs públicas...\n');
    
    for (const [key, region] of Object.entries(regions)) {
      const url = ngrokUrls[key];
      
      console.log(`${region.color}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${reset}`);
      console.log(`${region.color}📍 ${region.name}${reset}`);
      console.log(`🔗 ${url}\n`);
      qrcode.generate(url, { small: true });
      console.log('');
    }
    
    console.log('='.repeat(60));
    console.log('✅ QR Codes gerados com sucesso!');
    console.log('📱 Compartilhe com o público para iniciar a demo!\n');
    console.log('💡 Dica: Imprima ou projete os QR codes em slides\n');
  }
  
  askForUrl();
}
