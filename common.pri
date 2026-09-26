# Copyright 2010-2020 wkhtmltopdf authors
#
# This file is part of wkhtmltopdf.
#
# wkhtmltopdf is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# wkhtmltopdf is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with wkhtmltopdf.  If not, see <http:#www.gnu.org/licenses/>.

# ---------------------------------------------------------------------------
# Engine selection
#
# wkhtmltopdf is built on QtWebKit (WebKit 1 / the in-process WebKit API). That
# module was deprecated in Qt 5.6 and *removed* in Qt 6, so Qt 6 and later can
# never work here without replacing the whole rendering engine. Fail early and
# loudly instead of emitting a wall of qmake "unknown module" errors.
# ---------------------------------------------------------------------------
greaterThan(QT_MAJOR_VERSION, 5) {
    # Keep this message on a single line: a stray tokeniser surprise here would
    # break every build rather than just the Qt 6 one.
    error("wkhtmltopdf requires QtWebKit, which does not exist in Qt $$QT_MAJOR_VERSION -- use Qt 5 (5.12/5.15 LTS recommended) with the QtWebKit module, e.g. libqt5webkit5-dev or qt5-qtwebkit-devel; see docs/building.md")
}

# QtWebKit is not part of a stock Qt 5 install either; without it qmake only
# complains much later with a confusing "Unknown module(s) in QT: webkit".
!exists($$[QT_INSTALL_PREFIX]/include/QtWebKit) {
    warning("QtWebKit headers not found under $$[QT_INSTALL_PREFIX]/include/QtWebKit -- install the QtWebKit module (libqt5webkit5-dev, qt5-webkit, qt5-qtwebkit) or point qmake at a Qt prefix that has it")
}

CONFIG(static, shared|static):lessThan(QT_MAJOR_VERSION, 5) {
    DEFINES  += QT4_STATICPLUGIN_TEXTCODECS
    QTPLUGIN += qcncodecs qjpcodecs qkrcodecs qtwcodecs
}

INCLUDEPATH += ../../src/lib
RESOURCES    = $$PWD/wkhtmltopdf.qrc

win32: CONFIG += console

# Historically every MinGW build was forced fully static. That no longer works
# with the UCRT-based MinGW-w64 toolchains shipped by current distros, and it
# silently produces binaries that fail to link. Static linking is now opt-in so
# that a plain `qmake && make` works on modern MinGW.
win32-g++* {
    contains(CONFIG, static_wkhtmltox) {
        QMAKE_LFLAGS += -static -static-libgcc -static-libstdc++
    }
}

QT += webkit network xmlpatterns svg
greaterThan(QT_MAJOR_VERSION, 4) {
    QT += webkitwidgets
    # QPrinter lives in QtPrintSupport, which only became a separate module in
    # Qt 5.0; on Qt 4 it is part of QtGui. Test the major version only -- the
    # previous "greaterThan(QT_MINOR_VERSION, 2)" test was wrong for every
    # Qt 5.0/5.1/5.2 build.
    QT += printsupport
}

# version related information
VERSION_TEXT=$$(WKHTMLTOX_VERSION)
isEmpty(VERSION_TEXT): VERSION_TEXT=$$cat($$PWD/VERSION)
VERSION_LIST=$$split(VERSION_TEXT, "-")

count(VERSION_LIST, 1): VERSION=$$VERSION_TEXT
else:                   VERSION=$$member(VERSION_LIST, 0)

DEFINES += VERSION=$$VERSION FULL_VERSION=$$VERSION_TEXT BUILDING_WKHTMLTOX
