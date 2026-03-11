#!/bin/bash
# Deploy Prometheus + Grafana monitoring stack to EKS
# Usage: ./deploy-monitoring.sh

set -e

echo "=========================================="
echo " Deploying Monitoring Stack"
echo " Prometheus + Grafana on EKS"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo ""
echo "[1/7] Creating monitoring namespace..."
kubectl apply -f "$SCRIPT_DIR/00-namespace.yaml"

echo "[2/7] Setting up Prometheus RBAC..."
kubectl apply -f "$SCRIPT_DIR/01-prometheus-rbac.yaml"

echo "[3/7] Deploying Prometheus..."
kubectl apply -f "$SCRIPT_DIR/02-prometheus-config.yaml"
kubectl apply -f "$SCRIPT_DIR/03-prometheus-deployment.yaml"

echo "[4/7] Deploying Node Exporter (DaemonSet)..."
kubectl apply -f "$SCRIPT_DIR/04-node-exporter.yaml"

echo "[5/7] Deploying kube-state-metrics..."
kubectl apply -f "$SCRIPT_DIR/05-kube-state-metrics.yaml"

echo "[6/7] Deploying Grafana..."
kubectl apply -f "$SCRIPT_DIR/06-grafana-datasource.yaml"
kubectl apply -f "$SCRIPT_DIR/07-grafana-dashboards-config.yaml"
kubectl apply -f "$SCRIPT_DIR/09-grafana-secret.yaml"
kubectl apply -f "$SCRIPT_DIR/08-grafana-deployment.yaml"

echo "[7/7] Setting up Grafana Ingress (HTTPS)..."
kubectl apply -f "$SCRIPT_DIR/10-grafana-ingress.yaml"

echo ""
echo "=========================================="
echo " Monitoring Stack Deployed!"
echo "=========================================="
echo ""
echo "  Prometheus:  kubectl port-forward -n monitoring svc/prometheus 9090:9090"
echo "  Grafana:     https://ai-fairy-grafana.duckdns.org"
echo "  Grafana:     kubectl port-forward -n monitoring svc/grafana 3000:80"
echo ""
echo "  Default Grafana credentials:"
echo "    User:     admin"
echo "    Password: (see 09-grafana-secret.yaml)"
echo ""
echo "  Pre-configured dashboards:"
echo "    - Cloud Wars — Voting App Overview"
echo "    - EKS Node Metrics"
echo ""
echo "  Verify pods:"
echo "    kubectl get pods -n monitoring"
echo ""
