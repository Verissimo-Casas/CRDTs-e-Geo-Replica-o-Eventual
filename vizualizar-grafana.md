I'll quickly scan the docker-compose and docs in your repo to give precise, project-specific steps for bringing up Grafana, wiring the Prometheus datasource, and importing the dashboard.

Read [](file:///home/verissimo/banco2_projeto/crdt-demo/docker-compose.yml)

Read [](file:///home/verissimo/banco2_projeto/crdt-demo/README.md#1-1), lines 1 to 400

Read [](file:///home/verissimo/banco2_projeto/crdt-demo/QUICK_START.md)

Read [](file:///home/verissimo/banco2_projeto/crdt-demo/dashboard/Dockerfile)

Read [](file:///home/verissimo/banco2_projeto/crdt-demo/monitoring/prometheus.yml)

Read [](file:///home/verissimo/banco2_projeto/crdt-demo/api/index.js#1-1), lines 1 to 400

Read [](file:///home/verissimo/banco2_projeto/crdt-demo/api/index.js#401-401), lines 401 to 630

Read [](file:///home/verissimo/banco2_projeto/crdt-demo/dashboard/index.js)

Ran terminal command: docker-compose ps

Ran terminal command: docker-compose -f /home/verissimo/banco2_projeto/crdt-demo/docker-compose.yml ps

Created 7 todos

Completed (3/7) *Instruir acesso ao Grafana*

Pelos arquivos do seu projeto, vou te guiar para abrir o Grafana, apontar para o Prometheus e importar o dashboard JSON que já existe no repo.

## Acessar o Grafana

- O compose já está rodando e o Grafana está acessível em: http://localhost:3004
- Login: admin / admin (definido no docker-compose.yml via GF_SECURITY_ADMIN_PASSWORD=admin)

Se precisar conferir os serviços:
- Prometheus: http://localhost:9090
- Dashboard web: http://localhost:3000
- APIs: http://localhost:3001, :3002, :3003

## Configurar o Data Source (Prometheus)

No Grafana:
1. Menu lateral > Connections > Data sources > Add data source
2. Escolha “Prometheus”
3. Em URL, use: http://prometheus:9090
   - Observação: “prometheus” é o hostname do serviço na rede Docker (correto quando o Grafana está em container, como aqui).
4. Clique “Save & test” (deve aparecer “Data source is working”).

## Importar o dashboard pronto

Você já tem um dashboard JSON no repo:
- Arquivo: grafana-dashboard.json

No Grafana:
1. Menu lateral > Dashboards > New > Import
2. Clique em “Upload JSON file” e selecione o arquivo acima
3. Na etapa de importação, selecione o data source Prometheus que você acabou de criar
4. Import

Pronto! O dashboard “CRDT Distributed System Dashboard” será criado com estes painéis:
- Likes Total by Region: rate(likes_total[5m]) por região
- Stats Latency: histogram_quantile 95% e 50% sobre `stats_latency_ms_bucket`
- CRDT Divergence: gauge com `crdt_divergence`
- Service Availability: `up{job=~"api-.*"}`

## Gerar dados para os gráficos

Se o painel estiver vazio, gere eventos:
- Dê likes nas APIs:
  - http://localhost:3001/like (Brasil)
  - http://localhost:3002/like (Europa)
  - http://localhost:3003/like (EUA)
- Abra o dashboard web em http://localhost:3000 para acompanhar

As métricas são expostas em:
- APIs: `GET /metrics` (já implementado)
- Dashboard: `GET /metrics` (já implementado)
- Prometheus está configurado para coletar de todos eles em prometheus.yml

## Conferir se o Prometheus está coletando

- Abra http://localhost:9090/targets e verifique se os jobs estão “UP”:
  - api-br, api-eu, api-usa, dashboard, prometheus
- Você também pode testar consultas no Prometheus (ex.: `likes_total`, `stats_latency_ms_bucket`, `crdt_divergence`)

## Troubleshooting rápido

- Datasource com erro:
  - Verifique se a URL está como http://prometheus:9090 (não use localhost dentro do Grafana container)
- Painéis sem dados:
  - Gere likes (acima)
  - Cheque Prometheus Targets (devem estar “UP”)
- Portas ocupadas:
  - Grafana usa 3004, Prometheus 9090, Dashboard 3000, APIs 3001–3003; certifique-se que nada no host está usando essas portas

Se preferir, posso automatizar a provisão do Grafana (datasource e dashboard) via volumes e arquivos de provisioning no docker-compose — diga se quer que eu adicione isso.