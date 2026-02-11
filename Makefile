CLUSTER_NAME := grafana-stack

.PHONY: cluster install test clean

cluster:
	kind create cluster --name $(CLUSTER_NAME)
	# Label the control plane node for opencost
	kubectl label nodes $(CLUSTER_NAME)-control-plane topology.kubernetes.io/region=local
	sleep 10

install:
	helm dependency update
	helm upgrade --install grafana-stack . -n monitoring --timeout 15m --create-namespace
	
update:
	helm upgrade --install grafana-stack . -n monitoring --timeout 15m --create-namespace

test:
	./test.sh

clean:
	kind delete cluster --name $(CLUSTER_NAME)
