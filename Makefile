.PHONY: check package publish-public publish-private

check:
	./tests/static.sh

package:
	./scripts/package-release.sh

publish-public:
	./publish-to-github.sh public

publish-private:
	./publish-to-github.sh private
