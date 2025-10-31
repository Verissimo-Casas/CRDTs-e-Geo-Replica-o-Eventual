# Gerando QR Codes para Acesso Público

Este guia explica como expor as APIs regionais publicamente e gerar QR codes para que a plateia possa interagir com a demo.

## Opção 1: ngrok (Recomendado para Demos)

### 1. Instalar ngrok

```bash
# Linux/macOS
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install ngrok

# Ou baixe direto de: https://ngrok.com/download
```

### 2. Criar conta e configurar token

```bash
# Obtenha seu token em: https://dashboard.ngrok.com/get-started/your-authtoken
ngrok config add-authtoken <seu-token>
```

### 3. Expor as APIs (em terminais separados)

```bash
# Terminal 1 - Brasil
ngrok http 3001

# Terminal 2 - Europa
ngrok http 3002

# Terminal 3 - EUA
ngrok http 3003
```

### 4. Anotar as URLs geradas

O ngrok fornecerá URLs como:
- `https://xxxx-yyyy.ngrok-free.app` (Brasil)
- `https://aaaa-bbbb.ngrok-free.app` (Europa)
- `https://cccc-dddd.ngrok-free.app` (EUA)

Adicione `/like` ao final de cada URL para o endpoint completo.

## Opção 2: Acesso Local (Rede WiFi)

Se todos estiverem na mesma rede local:

### 1. Descobrir IP da máquina

```bash
# Linux/macOS
ip addr show | grep "inet " | grep -v 127.0.0.1

# Ou
ifconfig | grep "inet " | grep -v 127.0.0.1
```

### 2. URLs de acesso

- Brasil: `http://<seu-ip>:3001/like`
- Europa: `http://<seu-ip>:3002/like`
- EUA: `http://<seu-ip>:3003/like`

**Nota**: Certifique-se de que o firewall permite conexões nas portas 3001-3003.

## Gerando QR Codes

### Online (Rápido)

1. Acesse: https://www.qr-code-generator.com/
2. Cole a URL completa (ex: `https://xxxx.ngrok-free.app/like`)
3. Personalize (opcional):
   - Adicione logo da bandeira da região
   - Altere cores
4. Baixe a imagem
5. Repita para cada região

### CLI (Automático)

```bash
# Instalar qrencode
sudo apt-get install qrencode  # Linux
brew install qrencode          # macOS

# Gerar QR codes
qrencode -o qr_brasil.png "https://xxxx.ngrok-free.app/like"
qrencode -o qr_europa.png "https://yyyy.ngrok-free.app/like"
qrencode -o qr_eua.png "https://zzzz.ngrok-free.app/like"
```

### Python Script

```python
# instalar: pip install qrcode[pil]
import qrcode

urls = {
    'brasil': 'https://xxxx.ngrok-free.app/like',
    'europa': 'https://yyyy.ngrok-free.app/like',
    'eua': 'https://zzzz.ngrok-free.app/like'
}

for region, url in urls.items():
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(url)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    img.save(f'qr_{region}.png')
    print(f'✅ QR code gerado: qr_{region}.png')
```

## Dicas para a Apresentação

1. **Teste antes**: Escaneie os QR codes você mesmo antes da apresentação
2. **Imprima grande**: QR codes devem ser facilmente escaneáveis a distância
3. **Identifique visualmente**: Use cores/bandeiras para distinguir regiões
4. **Projete na tela**: Se não imprimir, projete os QR codes em slides
5. **URLs curtas**: Use encurtadores (bit.ly, tinyurl) para QR codes menores

## Exemplo de Slide para Projeção

```
┌─────────────────────────────────────────┐
│         Participe da Demo! 🚀           │
├─────────────────────────────────────────┤
│                                         │
│  🇧🇷 BRASIL     🇪🇺 EUROPA    🇺🇸 EUA   │
│  [QR Code]    [QR Code]   [QR Code]    │
│                                         │
│  Escaneie e clique em LIKE!            │
│                                         │
└─────────────────────────────────────────┘
```

## Troubleshooting

- **QR code não funciona**: Verifique se a URL está correta e acessível
- **ngrok timeout**: Versão gratuita tem sessões temporárias - regenere se necessário
- **Firewall bloqueando**: Configure exceções para as portas 3001-3003
- **Muitos acessos simultâneos**: ngrok gratuito tem limite - considere upgrade ou acesso local

## Alternativas Profissionais

Para apresentações críticas:
- **Cloudflare Tunnel** (gratuito, mais estável que ngrok)
- **Deploy temporário** em cloud (AWS/Azure/GCP)
- **Tailscale** (VPN, compartilhamento de rede)
