wkhtmltopdf and wkhtmltoimage
-----------------------------

wkhtmltopdf and wkhtmltoimage are command line tools to render HTML into PDF
and various image formats using the QT Webkit rendering engine. These run
entirely "headless" and do not require a display or display service.

See https://wkhtmltopdf.org for updated documentation.

## Building

wkhtmltopdf is built against **Qt 5 and the QtWebKit module** (Qt 6 removed
QtWebKit, so Qt 6 cannot be used). On Linux, install your distribution's
QtWebKit package and then:

```sh
export QT_SELECT=qt5   # only needed on Debian/Ubuntu
qmake CONFIG+=release
make -j"$(nproc)"
```

Binaries are written to `./bin`. The pinned Qt 4.8.7 submodule is only needed
for the legacy static build and is not required for the above.

Per-distribution package lists, build options, and the reasoning behind dynamic
rather than static linking are in [docs/building.md](docs/building.md).

Run the smoke tests with `./tests/run-smoke-tests.sh ./bin` (needs
`poppler-utils`).

## Platform support

The supported targets are Linux distributions and architectures, built
dynamically against each distribution's own Qt 5 + QtWebKit. CI covers
Ubuntu 24.04 and Debian 12 on amd64 and arm64, plus Fedora.

Two important limits, both documented in [docs/status.md](docs/status.md):

* **QtWebKit is being dropped by distributions.** Debian 13, openSUSE
  Tumbleweed and Alpine (which never had it) cannot build this. The list of
  distributions that still ship it is shrinking, so "newest distribution" is
  often not currently buildable.
* **macOS arm64 and Windows ARM64 are not reachable.** QtWebKit is published
  for Linux only, and Qt 6 removed the module, so there is no upstream source
  to build one from.

## Security

wkhtmltopdf depends on the original in-process WebKit API, which is no longer
maintained upstream. Do not use it with untrusted HTML or with pages that load
untrusted content. See the
[recommended AppArmor policy](docs/apparmor.md) and the warning in
[docs/status.md](docs/status.md).

## Legacy packaging

The historical "official" static binaries are built by a separate repository,
https://github.com/wkhtmltopdf/packaging. It requires the pinned Qt 4.8.7
submodule and is no longer the recommended path.
