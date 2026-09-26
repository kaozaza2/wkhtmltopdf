# Building wkhtmltopdf

## Which Qt do I need?

wkhtmltopdf renders with **QtWebKit** (the original in-process WebKit 1 API).
QtWebKit was deprecated in Qt 5.6 and **removed entirely in Qt 6**, so:

| Qt | Works? | Notes |
|----|--------|-------|
| Qt 4.8 | yes | The historical target. Only the patched 4.8.7 in `qt/` gives full fidelity. |
| Qt 5.12 / 5.15 | yes | **Recommended.** Needs the QtWebKit module, which Qt no longer ships itself. |
| Qt 6+ | **no** | QtWebKit does not exist. `qmake` will stop with an explanatory error. |

On Linux, distributions package QtWebKit separately. Install it alongside
`qtbase` and the build needs no extra flags:

| Distribution | Packages |
|--------------|----------|
| Debian / Ubuntu | `qtbase5-dev qtbase5-dev-tools libqt5svg5-dev libqt5xmlpatterns5-dev libqt5webkit5-dev libqt5printsupport5` |
| Fedora | `qt5-qtbase-devel qt5-qtsvg-devel qt5-qtxmlpatterns-devel qt5-qtwebkit-devel qt5-qtprintsupport-devel` |
| openSUSE | `qt5-qtbase-devel qt5-qtsvg-devel qt5-qtxmlpatterns-devel qt5-qtwebkit-devel qt5-qtprintsupport-devel` |
| Arch | `qt5-base qt5-svg qt5-xmlpatterns qt5-webkit` |
| Alpine | `qt5-qtbase-dev qt5-qtsvg-dev qt5-qtxmlpatterns-dev qt5-qtwebkit-dev qt5-qtprintsupport-dev` |
| Void | `qt5-devel qt5-webkit-devel` |

## Build

```sh
# QtWebKit is not part of a stock Qt 5; make sure qtchooser picks Qt 5.
export QT_SELECT=qt5

qmake CONFIG+=release
make -j"$(nproc)"
```

Binaries land in `./bin`:

```
bin/wkhtmltopdf
bin/wkhtmltoimage
```

The `qt/` submodule (patched Qt 4.8.7) is **only** needed for the legacy static
build. A normal dynamic build does not check it out:

```sh
git clone --recurse-submodules ...   # only if you want the static Qt 4 build
git clone ...                        # otherwise, skip it entirely
```

## Why dynamic and not static?

The released 0.12.6 binaries link Qt statically, which sounds like it should
make them portable. It does not. Those binaries are built inside a container
matching one distribution, so they carry that distribution's glibc, its
`fontconfig`, and its `freetype`. On a newer distribution they fail; on Alpine
they never worked at all, because Alpine uses musl rather than glibc and the
generic build is glibc-only.

A dynamic build against the distribution's own Qt avoids the whole class of
problem: each distribution and each architecture builds against its own libc,
and anything that packages `qt5-webkit` can ship wkhtmltopdf. This is why the
supported targets in CI are distributions and architectures rather than
prebuilt artifacts.

The trade-off is that a dynamic build links the *unpatched* QtWebKit 5.212
rather than wkhtmltopdf's patched Qt 4.8.7. Rendering is therefore very close
to, but not byte-identical with, the 0.12.6 static binaries. The patched Qt
builds also carry a WebKit from 2011 with known unpatched vulnerabilities; the
5.212 engine is newer and better hardened, but still frozen at 2016 and **not
suitable for rendering untrusted HTML**. See `status.md`.

## Build options

Passed through to `qmake` as `CONFIG+=`:

| Option | Effect |
|--------|--------|
| `release` | Optimised build (default is debug). |
| `static_wkhtmltox` | Build a static `libwkhtmltox`. |
| `shared` | Build `libwkhtmltox` as a shared library (default). |
| `static` | Static build using the bundled/patched Qt 4. |
| `silent` | Reduce `qmake`/`make` noise. |

## Tests

`tests/run-smoke-tests.sh` renders a handful of documents and checks the
results, so it catches "compiles but produces empty PDFs" — which is the
failure mode you get when fonts are missing, and one that a build-only check
will happily pass.

Needs `poppler-utils` (`pdftotext`, `pdfinfo`).

```sh
./tests/run-smoke-tests.sh ./bin
```

## Platform support

QtWebKit binaries are published **for Linux only**. There is no QtWebKit build
for macOS on Apple Silicon, nor for Windows on ARM64, and since Qt 6 dropped
the module there is no upstream source to build one from. Those platforms
therefore cannot be covered by this project as it stands; see `status.md` for
what would be required.
