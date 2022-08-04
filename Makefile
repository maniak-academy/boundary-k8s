boundary-deploy:
	kubectl create secret generic psql-creds \
	--from-literal=username=postgres \
	--from-literal=password=postgres \
	--from-literal=database=boundary

	kubectl apply \
	-f manifests/boundary-serviceaccount.yaml

	kubectl apply \
	-f manifests/postgresql-statefulset.yaml \
	-f manifests/postgresql-service.yaml

	echo "Waiting 15s for PostgreSQL to come up..."
	sleep 15

	kubectl apply \
	-f manifests/controller-config-configmap.yaml \
	-f manifests/worker-config-configmap.yaml

	kubectl apply \
  	-f manifests/database-init-job.yaml

	echo "Waiting 15s for database to initalize..."
	sleep 15

	kubectl apply \
	-f manifests/controller-daemonset.yaml \
	-f manifests/controller-api-service.yaml \
	-f manifests/controller-cluster-service.yaml

	echo "Waiting 15s for Boundary controller to come up..."
	sleep 15

	kubectl apply \
	-f manifests/worker-daemonset.yaml \
  	-f manifests/worker-proxy-service.yaml