.PHONY: apk

IMAGE := bioloop-builder

apk:
	docker build -t $(IMAGE) . && docker run --rm -v $(PWD):/app $(IMAGE)
