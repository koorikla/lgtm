#!/bin/bash
set -e

echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=grafana-stack --timeout=600s --all

echo "Port-forwarding Grafana..."
kubectl port-forward -n monitoring services/grafana-stack 3000:3000  &
PF_PID=$!

# Cleanup port-forward on exit
trap "kill $PF_PID" EXIT

sleep 5

echo "Checking Grafana Health..."
curl -f http://admin:admin@localhost:3000/api/health

echo "Verifying Datasources..."
# List datasources
curl -f -u admin:admin http://localhost:3000/api/datasources

echo "Test Passed!"

#######################
echo !!!! IS a MESS, port forward mimir and loki for further tests - expleted to fail for now

curl -X POST -H "Content-Type: application/json" \
  http://localhost:8080/otlp/v1/metrics \
  -d '{
    "resourceMetrics": [{
      "scopeMetrics": [{
        "metrics": [{
          "name": "test_gauge_valuez",
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


curl -G "http://localhost:8080/prometheus/api/v1/query" \
  --data-urlencode 'query=test_gauge_value{test_label="hello_mimir"}'




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

curl -G "http://localhost:8089/loki/api/v1/query_range" \
  --data-urlencode 'query={job="test-curl"}'