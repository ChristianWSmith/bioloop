.PHONY: apk

IMAGE := bioloop-builder

apk:
	docker build --network host -t $(IMAGE) . && docker run --rm --network host -v $(PWD):/app $(IMAGE)
