#!/usr/bin/make -f

SHELL := /bin/bash
IMG_NAME := k8s-alpine-baseimage
IMG_REPO := nforceroh
DOCKERCMD := docker

.PHONY: all build push test gitcommit gitpush create
all: build push 
git: gitcommit gitpush 

build: 
	@echo "Building $(IMG_NAME)image"
	$(DOCKERCMD) build \
		--tag $(IMG_REPO)/$(IMG_NAME) .

test:
	@echo "=== [1/7] Basic startup ==="
	$(DOCKERCMD) run --rm $(IMG_REPO)/$(IMG_NAME) echo "OK"

	@echo "=== [2/7] s6 services listed ==="
	$(DOCKERCMD) run --rm $(IMG_REPO)/$(IMG_NAME) /command/s6-rc -a list

	@echo "=== [3/7] Default user (abc) created ==="
	$(DOCKERCMD) run --rm $(IMG_REPO)/$(IMG_NAME) id abc

	@echo "=== [4/7] Custom PUID/PGID ==="
	$(DOCKERCMD) run --rm -e PUID=1500 -e PGID=1500 $(IMG_REPO)/$(IMG_NAME) id abc

	@echo "=== [5/7] Timezone applied ==="
	$(DOCKERCMD) run --rm -e TZ=Europe/Paris $(IMG_REPO)/$(IMG_NAME) \
		sh -c "cat /etc/timezone && readlink /etc/localtime"

	@echo "=== [6/7] Required directories exist ==="
	$(DOCKERCMD) run --rm $(IMG_REPO)/$(IMG_NAME) ls -la /app /config /defaults

	@echo "=== [7/7] Key tools present ==="
	$(DOCKERCMD) run --rm $(IMG_REPO)/$(IMG_NAME) \
		sh -c "jq --version && curl --version | head -1 && openssl version && bash --version | head -1"

	@echo "All tests passed!"

push: 
	@echo "Tagging and Pushing $(IMG_NAME):$(VERSION) image"
	$(DOCKERCMD) tag $(IMG_REPO)/$(IMG_NAME) docker.io/$(IMG_REPO)/$(IMG_NAME):3.24
	$(DOCKERCMD) push docker.io/$(IMG_REPO)/$(IMG_NAME):3.24

end:
	@echo "Done!"