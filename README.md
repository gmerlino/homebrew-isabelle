# Homebrew Isabelle

Isabelle2026 for Apple Silicon, using the official macOS ARM distribution with its coordinated components. The formula rebuilds Isabelle/Scala/Java modules and Pure/HOL heap images from their bundled sources. Java, Poly/ML, jEdit, the native application launcher and external prover binaries are retained from upstream; this is not a source rebuild of every component.

```sh
brew install gmerlino/isabelle/isabelle
isabelle version
open /opt/homebrew/opt/isabelle/Isabelle2026.app
brew test gmerlino/isabelle/isabelle
```

The download is pinned by the SHA-256 published in the [official distribution index](https://isabelle.in.tum.de/website-Isabelle2026/dist/). The application includes upstream sources, documentation, components and licenses. Isabelle's main code uses a BSD-style license; bundled components have their own licenses.

## Preservation and validation

Builds and Homebrew tests use a separate USER_HOME. Existing versioned settings in `~/.isabelle`, user theories, ROOT files and AFP projects are not changed by installation or removal. Migration between Isabelle releases may require proof changes; use an AFP release matching Isabelle2026.

The `tests` session checks HOL, Sledgehammer with the bundled E and Vampire provers, and proof-reconstructing SMT calls to veriT, cvc5 and Z3. The Homebrew test covers E, veriT and cvc5; the extended `tests` session also covers Vampire and Z3. `expect = some` makes the Sledgehammer check fail if no proof is found. It can be run in a disposable user environment:

```sh
USER_HOME="$(mktemp -d)" isabelle build -v -D tests
```

The official distribution is retained in full to preserve tools and provers. Architecture and operational checks are recorded during migration; no claim of universal support for all external prover/component combinations is made.

Validated on Apple Silicon macOS 27.2.1: a complete Homebrew reinstall succeeded, including Scala/Java and Pure/HOL rebuilding, linkage handling and post-install signing. Homebrew tests and the extended session passed on the resulting installation. Isabelle/jEdit opened the migration theory and reached “Prover: ready” with HOL; navigation, tool panels and normal exit worked. Recursive signature verification, brew linkage --test and brew missing passed. The 91 pre-existing configuration files matched their original hashes.

## macOS packaging

Compilation happens outside the application bundle: executing components inside an incomplete bundle hung during macOS process startup on the validation host. Once compiled, the standard `Contents` layout is installed and the complete app is signed locally. The CLI wrapper points directly to `Contents/Resources/bin/isabelle`; obsolete top-level convenience symlinks are not needed.

Native library IDs are converted to short `@rpath` IDs using Homebrew's Mach-O writer and preserved during linkage processing. Read-only files are made writable only for the edit, then their permissions are restored; this also handles upstream SQLite signatures that Apple's install_name_tool cannot rewrite. Poly/ML `polyimport` tools use their bundled GMP through `@loader_path`, replacing upstream build-machine paths. Post-installation signing explicitly covers Mach-O files under Resources, then signs nested bundles from the inside out while preserving entitlements. This includes native FlatLaf and Poly/ML libraries that codesign --deep alone does not re-sign. The original component versions are retained.

The normal recursive `codesign --verify --deep` validation passes. The optional strict validation currently fails with `No such file or directory`; the complete upstream E source tree contains 12 dangling build-output symlinks. These are retained rather than replacing or deleting upstream source contents. This formula uses local ad-hoc signatures and does not provide Apple notarization.
