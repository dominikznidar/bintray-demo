VERSION ?= $(shell git rev-parse --short HEAD)
BUILD_TARGET_SCRIPT := build/usr/local/bin/script.sh
BUILD_TARGET_CONF := build/etc/demo/example.conf
JFROG_API_KEY ?= THE_KEY
JFROG_USERNAME ?= USERNAME
JFROG_URL ?= https://bintray.com/api/v1
FILES := usr/local/bin/script.sh etc/demo/example.conf

# :subject/:repo/:package/:version/publish
JFROG_SUBJECT ?= SUBJECT
JFROG_REPO_RPM ?= bintray-rpm
JFROG_REPO_DEB ?= bintray-deb
JFROG_PACKAGE ?= demo

# add BUILD_TARGET_SCRIPT to list of phony targets to for make to always do the build
# even when files already exist
.PHONY: clean build $(BUILD_TARGET_SCRIPT)

all: clean build publish

clean:
	rm -fr build/
	rm -fr pkg/

build: clean $(BUILD_TARGET_SCRIPT) $(BUILD_TARGET_CONF)

pkg: pkg/deb pkg/rpm

pkg/deb: REPO = $(JFROG_REPO_DEB)
pkg/rpm: REPO = $(JFROG_REPO_RPM)

pkg/%: PKG_PATH = "pkg/$(JFROG_SUBJECT)/$(REPO)/$(JFROG_PACKAGE)/$(VERSION)"
pkg/%: build
	mkdir -p $(PKG_PATH)
	cp -r build/* $(PKG_PATH)

$(BUILD_TARGET_SCRIPT):
	mkdir -p $(@D)
	sed -e 's/@@VERSION@@/$(VERSION)/' script.sh > $@
	chmod +x $@

$(BUILD_TARGET_CONF):
	mkdir -p $(@D)
	touch $@

publish: pkg
	@echo "Creating a new version ($(VERSION))"
	curl --user "$(JFROG_USERNAME):$(JFROG_API_KEY)" \
		-d '{"name": "$(VERSION)", "description": "Release $(VERSION)"}' \
		$(JFROG_URL)/packages/$(JFROG_SUBJECT)/$(JFROG_REPO_DEB)/$(JFROG_PACKAGE)/versions
	curl --user "$(JFROG_USERNAME):$(JFROG_API_KEY)" \
		-d '{"name": "$(VERSION)", "description": "Release $(VERSION)"}' \
		$(JFROG_URL)/packages/$(JFROG_SUBJECT)/$(JFROG_REPO_RPM)/$(JFROG_PACKAGE)/versions

	@echo "Uploading files"
	$(MAKE) $(addprefix upload/$(JFROG_SUBJECT)/$(JFROG_REPO_DEB)/$(JFROG_PACKAGE)/$(VERSION)/,$(FILES))
	$(MAKE) $(addprefix upload/$(JFROG_SUBJECT)/$(JFROG_REPO_RPM)/$(JFROG_PACKAGE)/$(VERSION)/,$(FILES))

	@echo "Publishing packages"
	curl --user "$(JFROG_USERNAME):$(JFROG_API_KEY)" -X POST \
		$(JFROG_URL)/content/$(JFROG_SUBJECT)/$(JFROG_REPO_DEB)/$(JFROG_PACKAGE)/$(VERSION)/publish
	curl --user "$(JFROG_USERNAME):$(JFROG_API_KEY)" -X POST \
		$(JFROG_URL)/content/$(JFROG_SUBJECT)/$(JFROG_REPO_RPM)/$(JFROG_PACKAGE)/$(VERSION)/publish

upload/%:
	@echo "Uploading $*"
	curl --user "$(JFROG_USERNAME):$(JFROG_API_KEY)" -X PUT \
		--data @pkg/$* $(JFROG_URL)/content/$*
