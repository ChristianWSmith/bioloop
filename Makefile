.PHONY: apk

IMAGE := bioloop-builder

apk:
	docker build -t $(IMAGE) . && docker run --rm --user $$(id -u):$$(id -g) -v $(PWD):/app $(IMAGE)
