# Maintainer: Ozan Özdil <ozan@pm.me>
pkgname=omarchy-git-radar
pkgver=1.1.0
pkgrel=1
pkgdesc="Developer pulse, live commit activity and multi-repo tracker for Omarchy Linux"
arch=('x86_64')
url="https://github.com/ozdil/omarchy-git-radar"
license=('MIT')
depends=('glibc' 'gcc-libs' 'git')
makedepends=('cargo' 'rust')

build() {
    cd "${startdir}"
    cargo build --release --locked
}

package() {
    cd "${startdir}"
    install -Dm755 "target/release/gitradar-engine" "${pkgdir}/usr/bin/gitradar-engine"
    install -Dm755 "target/release/gitradar-engine" "${pkgdir}/usr/share/omarchy/plugins/ozdil.git-radar/gitradar-engine"
    install -Dm755 "git-status" "${pkgdir}/usr/share/omarchy/plugins/ozdil.git-radar/git-status"
    install -Dm755 "git-scanner" "${pkgdir}/usr/share/omarchy/plugins/ozdil.git-radar/git-scanner"
    install -Dm755 "git-dashboard" "${pkgdir}/usr/share/omarchy/plugins/ozdil.git-radar/git-dashboard"
    install -Dm644 "manifest.json" "${pkgdir}/usr/share/omarchy/plugins/ozdil.git-radar/manifest.json"
    install -Dm644 "Panel.qml" "${pkgdir}/usr/share/omarchy/plugins/ozdil.git-radar/Panel.qml"
    install -Dm644 "README.md" "${pkgdir}/usr/share/doc/${pkgname}/README.md"
    install -Dm644 "LICENSE" "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE"
}
