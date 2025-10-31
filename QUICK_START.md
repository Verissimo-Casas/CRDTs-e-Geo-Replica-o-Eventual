## 🚀 Guia Rápido - Teste com Dispositivos na Rede

### Passo 1: Iniciar a Aplicação
```bash
cd /home/verissimo/banco2_projeto/crdt-demo
docker-compose up
```

### Passo 2: Gerar QR Codes
```bash
# Em outro terminal
cd /home/verissimo/banco2_projeto/crdt-demo/scripts
npm run qr
```

### Passo 3: URLs de Acesso

**Seu IP:** `192.168.1.17`

| Serviço | URL | Função |
|---------|-----|--------|
| 📊 Dashboard | http://192.168.1.17:3000 | Monitorar em tempo real |
| 🇧🇷 Brasil | http://192.168.1.17:3001/like | Dar likes BR |
| 🇪🇺 Europa | http://192.168.1.17:3002/like | Dar likes EU |
| 🇺🇸 EUA | http://192.168.1.17:3003/like | Dar likes USA |

### Passo 4: Testar do Celular

1. **Conectar na mesma rede WiFi**
2. **Escanear o QR code** gerado
3. **OU digitar a URL** no navegador do celular
4. **Clicar em "Curtir de novo!"** várias vezes
5. **Ver o Dashboard** atualizando em tempo real!

### Comandos Úteis

```bash
# Verificar se está rodando
docker-compose ps

# Ver IP local
hostname -I | awk '{print $1}'

# Testar conectividade
curl http://192.168.1.17:3000/health

# Liberar firewall (se necessário)
sudo ufw allow 3000:3003/tcp

# Ver logs
docker logs dashboard
docker logs api-br
```

### Demo Completa

```bash
# 1. Dashboard no navegador do computador
open http://192.168.1.17:3000

# 2. Gerar QR codes
cd scripts && npm run qr

# 3. Plateia dá likes pelo celular

# 4. Simular partição
cd .. && ./scripts/partition.sh

# 5. Continuar dando likes (Europa offline)

# 6. Reconectar
./scripts/reconnect.sh

# 7. Ver convergência automática! 🎉
```

### Troubleshooting

**Celular não acessa?**
- Verifique se está na mesma rede WiFi
- Teste: `ping 192.168.1.17` (de outro dispositivo)
- Libere o firewall: `sudo ufw allow 3000:3003/tcp`

**QR code não funciona?**
- Use a URL manual: `http://192.168.1.17:3001/like`
- Gere novos QR codes online: https://qr.io/

**Dashboard mostra offline?**
- Aguarde 5 segundos para conexão
- Reinicie: `docker-compose restart`

---

📱 **Pronto para testar!** Qualquer dúvida, consulte `TESTE_REDE_LOCAL.md`
