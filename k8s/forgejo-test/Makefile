FORGEJO_TEST_DIR := $(dir $(lastword $(MAKEFILE_LIST)))

.PHONY: deploy destroy apply delete restart logs status check check-db check-forgejo setup test test-verbose

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
	@kubectl exec -n forgejo-test deployment/forgejo -- wget -qO- http://localhost:3000/api/v1/version || echo "Forgejo not ready yet"

check: check-db check-forgejo

# Admin user and token for the live tests; prints the export lines:
#   eval "$(make -s -f k8s/forgejo-test/Makefile setup)"
ADMIN_USER ?= forgejo_admin
ADMIN_PASS ?= Admin123!
ADMIN_EMAIL ?= admin@localhost

setup:
	@kubectl exec -n forgejo-test deployment/forgejo -- su git -c "forgejo admin user list" \
		| awk '{print $$2}' | grep -qx '$(ADMIN_USER)' \
		|| kubectl exec -n forgejo-test deployment/forgejo -- su git -c \
			"forgejo admin user create --username '$(ADMIN_USER)' --password '$(ADMIN_PASS)' --email '$(ADMIN_EMAIL)' --must-change-password=false --admin" >&2
	@echo "export TEST_FORGEJO_URL='$(TEST_FORGEJO_URL)'"
	@echo "export TEST_FORGEJO_TOKEN='$$(kubectl exec -n forgejo-test deployment/forgejo -- su git -c \
		"forgejo admin user generate-access-token --username '$(ADMIN_USER)' --token-name live-tests-$$(date +%s) --scopes all --raw")'"

export TEST_FORGEJO_URL ?= http://localhost:30080

test:
	@test -n "$$TEST_FORGEJO_TOKEN" || { echo 'TEST_FORGEJO_TOKEN not set; run: eval "$$(make -s -f k8s/forgejo-test/Makefile setup)"' >&2; exit 1; }
	prove -l t/9*-live-*.t

test-verbose:
	@test -n "$$TEST_FORGEJO_TOKEN" || { echo 'TEST_FORGEJO_TOKEN not set; run: eval "$$(make -s -f k8s/forgejo-test/Makefile setup)"' >&2; exit 1; }
	prove -vl t/9*-live-*.t