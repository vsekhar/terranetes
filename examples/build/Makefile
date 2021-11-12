PROJECT=terranetes-resources
REGISTRY=us-docker.pkg.dev
REPO=examples

.PHONY:

all: hello-digest.txt

%-digest.txt: %.image_on_gcr
	gcloud container images list-tags \
		--project ${PROJECT} \
		--format='get(digest)' \
		--filter=tags:latest ${REGISTRY}/${PROJECT}/${REPO}/$* \
		> $@

%.image_on_gcr: .PHONY Dockerfile.% reporoot gomodtidy
	gcloud builds submit ${REPOROOT} \
		--project ${PROJECT} \
		--config ${REPOROOT}/examples/build/cloudbuild.yaml \
		--substitutions=_DOCKERFILE=examples/build/Dockerfile.$*,_DESTINATION=${REGISTRY}/${PROJECT}/${REPO}/$* \

gomodtidy: .PHONY
	go mod tidy

reporoot: .PHONY
	$(eval REPOROOT=$(shell git rev-parse --show-toplevel))
