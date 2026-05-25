FORGEJO_TEST_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

.PHONY: deploy destroy apply delete restart logs status check check-db check-forgejo test

deploy: apply

apply:
	@echo "==> Applying k8s manifests for forgejo-test..."
	kubectl apply -f $(FORGEJO_TEST_DIR)namespace.yaml
	kubectl apply -f $(FORGEJO_TEST_DIR)pvc.yaml
	kubectl apply -f $(FORGEJO_TEST_DIR)postgres.yaml
	kubectl wait --for=condition=available deployment/postgres -n forgejo-test --timeout=120s
	kubectl apply -f $(FORGEJO_TEST_DIR)forgejo.yaml
	kubectl wait --for=condition=available deployment/forgejo -n forgejo-test --timeout=180s
	@echo "==> Deployment complete!"

delete:
	@echo "==> Deleting forgejo-test namespace..."
	kubectl delete namespace forgejo-test --ignore-not-found=true

destroy: delete

restart: delete apply

logs:
	kubectl logs -n forgejo-test -l app=forgejo -f --tail=100

status:
	@echo "==> Namespace:"
	@kubectl get pods -n forgejo-test
	@echo ""
	@echo "==> Services:"
	@kubectl get svc -n forgejo-test

check-db:
	@echo "==> Checking PostgreSQL connection..."
	@kubectl exec -n forgejo-test deployment/postgres -- pg_isready -U forgejo || echo "PostgreSQL not ready yet"

check-forgejo:
	@echo "==> Checking Forgejo HTTP response..."
	@kubectl exec -n forgejo-test deployment/forgejo -- wget -qO- http://localhost:3000 || echo "Forgejo not ready yet"

check: check-db check-forgejo

test:
	FORGEJO_URL=http://localhost:30080 FORGEJO_TOKEN=test-token \
		perl -Ilib t/90-live-admin.t

test-verbose:
	FORGEJO_URL=http://localhost:30080 FORGEJO_TOKEN=test-token \
		prove -vl t/90-live-admin.t