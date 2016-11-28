VERSION ?= $(shell git rev-parse --short HEAD)
BUILD_TARGET_SCRIPT := build/usr/local/bin/script.sh
BUILD_TARGET_CONF := build/etc/demo/example.conf
JFROG_API_KEY ?= THE_KEY
JFROG_USERNAME ?= USERNAME
JFROG_URL ?= https://bintray.com/api/v1
FILES := usr/local/bin/script.sh etc/demo/example.conf
PACKAGES ?= pkg/$(JFROG_PACKAGE).deb pkg/$(JFROG_PACKAGE).rpm

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

pkg: $(PACKAGES)

pkg/$(JFROG_PACKAGE).rpm: TARGET_ARTIFACT = rpm
pkg/%: TARGET_ARTIFACT = deb
pkg/%: build
	mkdir -p pkg
	fpm -s dir -t $(TARGET_ARTIFACT) \
		--name demo \
		--package pkg/$(JFROG_PACKAGE).$(TARGET_ARTIFACT) \
		--force \
		--category admin \
		--epoch $(shell /bin/date +%s) \
		--iteration $(VERSION) \
		--deb-compression bzip2 \
		--url https://example.com \
		--description "demo package" \
		--maintainer "demo <demo@example.com>" \
		--license "Some Licence" \
		--vendor "example.com" \
		--architecture amd64 \
		build/=/

# pkg/$(JFROG_PACKAGE).rpm:

# pkg/%: PKG_PATH = "pkg/$(JFROG_SUBJECT)/$(REPO)/$(JFROG_PACKAGE)/$(VERSION)"
# pkg/%: build
# 	mkdir -p $(PKG_PATH)
# 	cp -r build/* $(PKG_PATH)

$(BUILD_TARGET_SCRIPT):
	mkdir -p $(@D)
	sed -e 's/@@VERSION@@/$(VERSION)/' script.sh > $@
	chmod +x $@

$(BUILD_TARGET_CONF):
	mkdir -p $(@D)
	touch $@

publish: pkg
	@echo "Creating a new version ($(VERSION))"
	curl -v --user "$(JFROG_USERNAME):$(JFROG_API_KEY)" \
		-d '{"name": "$(VERSION)", "description": "Release $(VERSION)"}' \
		$(JFROG_URL)/packages/$(JFROG_SUBJECT)/$(JFROG_REPO_DEB)/$(JFROG_PACKAGE)/versions
	@echo ""
	@echo ""
	curl -v --user "$(JFROG_USERNAME):$(JFROG_API_KEY)" \
		-d '{"name": "$(VERSION)", "description": "Release $(VERSION)"}' \
		$(JFROG_URL)/packages/$(JFROG_SUBJECT)/$(JFROG_REPO_RPM)/$(JFROG_PACKAGE)/versions
	@echo ""
	@echo ""


	@echo "Uploading files"
	$(MAKE) $(addprefix upload/,$(PACKAGES))

	# @echo "Publishing packages"
	curl --user "$(JFROG_USERNAME):$(JFROG_API_KEY)" -X POST -d '{"publish_wait_for_secs": -1}' \
		$(JFROG_URL)/content/$(JFROG_SUBJECT)/$(JFROG_REPO_DEB)/$(JFROG_PACKAGE)/$(VERSION)/publish
	curl --user "$(JFROG_USERNAME):$(JFROG_API_KEY)" -X POST -d '{"publish_wait_for_secs": -1}' \
		$(JFROG_URL)/content/$(JFROG_SUBJECT)/$(JFROG_REPO_RPM)/$(JFROG_PACKAGE)/$(VERSION)/publish

upload/pkg/$(JFROG_PACKAGE).deb: HEADERS = -H "X-Bintray-Debian-Distribution: talam" -H "X-Bintray-Debian-Component: main" -H 'X-Bintray-Debian-Architecture: amd64'
upload/pkg/$(JFROG_PACKAGE).deb: CONTENT_PATH = $(JFROG_SUBJECT)/$(JFROG_REPO_DEB)/$(JFROG_PACKAGE)/$(VERSION)
upload/pkg/$(JFROG_PACKAGE).deb: FILE_PATH = $(JFROG_PACKAGE)_$(VERSION)_amd64.deb

upload/%: HEADERS =
upload/%: CONTENT_PATH = $(JFROG_SUBJECT)/$(JFROG_REPO_RPM)/$(JFROG_PACKAGE)/$(VERSION)
upload/%: FILE_PATH = $(JFROG_PACKAGE)-$(VERSION)-x86_64.rpm
upload/%:
	@echo "Uploading $*"
	curl -v --user "$(JFROG_USERNAME):$(JFROG_API_KEY)" -X PUT $(HEADERS) \
		-T $* "$(JFROG_URL)/content/$(CONTENT_PATH)/$(FILE_PATH)?override=1&publish=1"
	@echo ""
	@echo ""
