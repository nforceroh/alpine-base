# Local build and test only — CI is the sole publisher.
# Shared pipelines: https://github.com/nforceroh/.github
SHELL := /bin/bash
IMAGE ?= ghcr.io/nforceroh/alpine-base
TAG   ?= dev

.PHONY: build test

build:
	docker build \
		--build-arg BUILD_DATE="$(shell date -u +'%Y-%m-%dT%H:%M:%SZ')" \
		--build-arg VERSION="$(TAG)" \
		--tag $(IMAGE):$(TAG) .

test: build
	./tests/run_tests.sh "$(IMAGE):$(TAG)"
