# REPO_PROJECT_ID=terranetes-resources
REGISTRY=us-docker.pkg.dev
REPO=examples

.PHONY:

all: hello-digest.txt

%-digest.txt: %.image_on_gcr project
	gcloud container images list-tags \
		--format='get(digest)' \
		--filter=tags:latest ${REGISTRY}/${PROJECT}/${REPO}/$* \
		> $@

%.image_on_gcr: .PHONY Dockerfile.% reporoot project gomodtidy
	gcloud builds submit ${REPOROOT} \
		--project ${PROJECT} \
		--config ${REPOROOT}/examples/build/cloudbuild.yaml \
		--substitutions=_DOCKERFILE=examples/build/Dockerfile.$*,_DESTINATION=${REGISTRY}/${PROJECT}/${REPO}/$* \

gomodtidy: .PHONY
	go mod tidy

reporoot: .PHONY
	$(eval REPOROOT=$(shell git rev-parse --show-toplevel))

project: .PHONY
	$(eval PROJECT=$(shell gcloud config get-value project))
	@echo Using project ${PROJECT}
