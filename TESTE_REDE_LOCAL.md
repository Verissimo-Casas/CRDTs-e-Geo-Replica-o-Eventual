# 📱 Teste com Dispositivos na Mesma Rede

## 🌐 Acesso Descoberto

**IP da sua máquina:** `192.168.1.17`

Todos os dispositivos conectados à mesma rede WiFi/LAN podem acessar as APIs!

---

## ✅ URLs de Acesso

### Dashboard (Monitoramento)
```
http://192.168.1.17:3000
```

### APIs Regionais (Para dar likes)

#### 🇧🇷 Brasil
```
http://192.168.1.17:3001/like
```

#### 🇪🇺 Europa
```
http://192.168.1.17:3002/like
```

#### 🇺🇸 EUA
```
http://192.168.1.17:3003/like
```

---

## 🚀 Como Testar

### 1. Iniciar a aplicação
```bash
cd /home/verissimo/banco2_projeto/crdt-demo
docker-compose up --build
```

### 2. Verificar se está funcionando
No computador host:
```bash
curl http://localhost:3000/stats
```

### 3. Testar do celular/tablet

**Opção A - Digitar a URL:**
1. Abra o navegador do dispositivo móvel
2. Digite: `http://192.168.1.17:3001/like`
3. Clique em "Curtir de novo!"

**Opção B - Gerar QR Code:**
```bash
cd scripts
npm run qr:local
```

---

## 📱 Gerar QR Codes Personalizados

### Opção 1: Online (Mais Rápido)

Acesse: https://qr.io/ ou https://www.qr-code-generator.com/

Cole as URLs:
- Brasil: `http://192.168.1.17:3001/like`
- Europa: `http://192.168.1.17:3002/like`
- EUA: `http://192.168.1.17:3003/like`

### Opção 2: Terminal (Automático)

```bash
cd /home/verissimo/banco2_projeto/crdt-demo/scripts

# Instalar dependência (se ainda não fez)
npm install

# Gerar QR codes com seu IP local
node generate_qr.js
```

O script vai perguntar se você quer usar ngrok. Digite **N** (não) e ele usará automaticamente o IP local `192.168.1.17`.

---

## 🔥 Firewall (Importante!)

Se os dispositivos não conseguirem acessar, libere as portas:

```bash
# Ubuntu/Debian
sudo ufw allow 3000:3003/tcp

# Fedora/RHEL
sudo firewall-cmd --add-port=3000-3003/tcp --permanent
sudo firewall-cmd --reload

# Verificar se as portas estão abertas
sudo netstat -tulpn | grep -E '3000|3001|3002|3003'
```

---

## 🧪 Teste Rápido

### Do seu celular:

1. **Conecte na mesma rede WiFi** que o computador
2. **Abra o navegador** (Chrome, Safari, Firefox)
3. **Acesse:** `http://192.168.1.17:3000`
4. **Você deve ver** o Dashboard com as 3 regiões
5. **Em outra aba, acesse:** `http://192.168.1.17:3001/like`
6. **Clique em "Curtir de novo!"** várias vezes
7. **Volte ao Dashboard** e veja os valores subindo!

---

## 📊 Demo Completa

### Roteiro:

1. **Projetar o Dashboard** no telão: `http://192.168.1.17:3000`
2. **Distribuir QR codes** impressos ou projetados
3. **Pedir para a plateia** escanear e dar likes
4. **Mostrar convergência** no Dashboard em tempo real
5. **Simular partição:**
   ```bash
   cd /home/verissimo/banco2_projeto/crdt-demo
   ./scripts/partition.sh
   ```
6. **Continuar recebendo likes** (Europa fica offline no Dashboard)
7. **Reconectar:**
   ```bash
   ./scripts/reconnect.sh
   ```
8. **Mostrar convergência automática!** 🎉

---

## ❓ Troubleshooting

### "Não consigo acessar do celular"

**Verificar se estão na mesma rede:**
```bash
# No computador
ip addr show | grep inet

# No celular, verificar IP (Configurações > WiFi > Detalhes)
# Deve estar na mesma sub-rede (ex: 192.168.1.x)
```

**Verificar firewall:**
```bash
sudo ufw status
# Se estiver ativo, adicione as regras acima
```

**Testar conectividade:**
```bash
# Do celular, use um app de ping ou o navegador:
http://192.168.1.17:3000/health
```

### "QR Code não abre"

- Verifique se digitou o IP correto
- Confirme que está usando `http://` e não `https://`
- Teste a URL manualmente primeiro

### "Dashboard mostra regiões offline"

```bash
# Verificar logs dos containers
docker logs dashboard
docker logs api-br
docker logs redis-br

# Reiniciar se necessário
docker-compose restart
```

---

## 🎯 Resumo Rápido

| Serviço | URL Local | Finalidade |
|---------|-----------|------------|
| Dashboard | http://192.168.1.17:3000 | Monitorar convergência |
| API Brasil | http://192.168.1.17:3001/like | Dar likes - BR |
| API Europa | http://192.168.1.17:3002/like | Dar likes - EU |
| API EUA | http://192.168.1.17:3003/like | Dar likes - USA |

---

## 💡 Dicas

- 📱 **Imprima os QR codes** em tamanho grande (A4)
- 🎨 **Use cores** para diferenciar regiões (verde=BR, azul=EU, vermelho=USA)
- 📺 **Projete o Dashboard** para todos verem
- 🔄 **Atualize em tempo real** - o polling é de 1 segundo
- 🎤 **Explique enquanto acontece** - mostre o conceito CAP

---

**Tudo pronto para testar! 🚀**

Qualquer problema, verifique:
1. Aplicação rodando: `docker-compose ps`
2. Rede ativa: `ping 192.168.1.17`
3. Firewall liberado: `sudo ufw status`
