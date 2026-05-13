#!/bin/bash
set -uo pipefail

# ==========================================
# 0. 初期準備
# ==========================================
mkdir -p /etc/grafana/provisioning/datasources
mkdir -p /etc/grafana/provisioning/dashboards
mkdir -p /var/lib/grafana/dashboards

if [ -f "/run/secrets/grafana_password" ]; then
    export GF_SECURITY_ADMIN_PASSWORD=$(cat /run/secrets/grafana_password)
fi

# ==========================================
# 1. Prometheusデータソースの自動設定
# ==========================================
cat << EOF > /etc/grafana/provisioning/datasources/prometheus.yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    uid: prometheus-ds
    access: proxy
    url: http://prometheus:9090/prometheus
    isDefault: true
EOF

# ==========================================
# 2. ダッシュボード・プロバイダーの設定
# ==========================================
cat << EOF > /etc/grafana/provisioning/dashboards/default.yaml
apiVersion: 1
providers:
  - name: 'Default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# ==========================================
# 3. 「Prometheus自己監視」ダッシュボードJSONの生成
# ==========================================
# 改善点: ラッパーを外し、ルートに属性を配置。かつデータソースをUIDで紐付け。
cat << EOF > /var/lib/grafana/dashboards/prometheus_self.json
{
  "uid": "prometheus-self-monitor",
  "title": "Prometheus Self Monitor",
  "tags": ["infrastructure"],
  "timezone": "browser",
  "schemaVersion": 21,
  "panels": [
    {
      "title": "Prometheus HTTP Request Rate",
      "type": "timeseries",
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus-ds"
      },
      "gridPos": { "h": 8, "w": 24, "x": 0, "y": 0 },
      "targets": [
        {
          "expr": "rate(prometheus_http_requests_total[1m])",
          "legendFormat": "{{handler}}"
        }
      ]
    }
  ]
}
EOF

# ==========================================
# 4. 権限の最終調整と起動 (PID 1)
# ==========================================
chown -R grafana:grafana /etc/grafana/provisioning /var/lib/grafana/dashboards /var/lib/grafana 2>/dev/null || true

exec grafana-server \
  --config=/etc/grafana/grafana.ini \
  --homepath=/usr/share/grafana