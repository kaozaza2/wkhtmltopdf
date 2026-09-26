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
Ubuntu, Debian, Fedora, openSUSE and Alpine (musl) on amd64 and arm64.

QtWebKit is not published for macOS on Apple Silicon or for Windows on ARM64,
so this project cannot build for those targets as things stand. See
[docs/status.md](docs/status.md) for the details and the options.

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
