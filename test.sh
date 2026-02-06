#!/bin/bash
set -e

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=grafana-stack -n monitoring --timeout=600s --all

echo "Port-forwarding Grafana..."
kubectl port-forward -n monitoring services/grafana-stack 3000:3000 &
PF_PID=$!

# Cleanup port-forward on exit
trap "kill $PF_PID 2>/dev/null || true" EXIT

sleep 5

echo "Checking Grafana Health..."
curl -f http://admin:admin@localhost:3000/api/health

echo ""
echo "Verifying Datasources..."
curl -f -u admin:admin http://localhost:3000/api/datasources

echo ""
echo "Basic tests passed!"

#######################
# Manual tests for Mimir and Loki - expected to fail without port-forwards
#######################

echo ""
echo "Setting up port-forwards for Mimir and Loki..."
kubectl port-forward -n monitoring services/grafana-stack-mimir-gateway 8080:80 &
PF_MIMIR_PID=$!
kubectl port-forward -n monitoring services/grafana-stack-loki-gateway 8089:80 &
PF_LOKI_PID=$!

trap "kill $PF_PID $PF_MIMIR_PID $PF_LOKI_PID 2>/dev/null || true" EXIT

sleep 5

echo "Testing Mimir - pushing a test metric via OTLP..."
curl -X POST -H "Content-Type: application/json" \
  http://localhost:8080/otlp/v1/metrics \
  -d '{
    "resourceMetrics": [{
      "scopeMetrics": [{
        "metrics": [{
          "name": "test_gauge_value",
          "gauge": {
            "dataPoints": [{
              "asInt": "42",
              "attributes": [
                {"key": "test_label", "value": {"stringValue": "hello_mimir"}}
              ]
            }]
          }
        }]
      }]
    }]
  }'

echo ""
echo "Querying Mimir for the test metric..."
curl -G "http://localhost:8080/prometheus/api/v1/query" \
  --data-urlencode 'query=test_gauge_value{test_label="hello_mimir"}'

echo ""
echo "Testing Loki - pushing a test log entry..."
curl -X POST -H "Content-Type: application/json" \
  http://localhost:8089/loki/api/v1/push \
  -d "{
    \"streams\": [
      {
        \"stream\": { \"job\": \"test-curl\", \"env\": \"dev\" },
        \"values\": [
          [ \"$(date +%s%N)\", \"Manual log entry: The eagle has landed.\" ]
        ]
      }
    ]
  }"

echo ""
echo "Querying Loki for the test log..."
curl -G "http://localhost:8089/loki/api/v1/query_range" \
  --data-urlencode 'query={job="test-curl"}'

echo ""
echo "All tests completed!"
