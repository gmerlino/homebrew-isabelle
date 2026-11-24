class Isabelle < Formula
  desc "Proof assistant with Isabelle/HOL and the Isabelle/jEdit IDE"
  homepage "https://isabelle.in.tum.de/"
  url "https://isabelle.in.tum.de/website-Isabelle2026/dist/Isabelle2026_macos_arm.tar.gz"
  version "2026"
  sha256 "7244e596d44ee9fbb8b988ef2990474b3385fa4a7ec1343867b224a13b6ddc28"
  license "BSD-3-Clause"

  depends_on arch: :arm64
  depends_on macos: :ventura

  preserve_rpath

  def install
    # Compile outside the application bundle, then seal the completed bundle.
    sources = buildpath.parent/"isabelle-sources"
    mv "Contents/Resources", sources
    ENV["USER_HOME"] = buildpath.parent/"build-home"
    Pathname(ENV["USER_HOME"]).mkpath
    cd sources do
      system "/bin/bash", "bin/isabelle", "scala_build", "-f"
      system "/bin/bash", "bin/isabelle", "build", "-f", "-b", "-o", "system_heaps=true",
             "-o", "threads=4", "-o", "parallel_proofs=1", "Pure", "HOL"
    end
    mv sources, buildpath/"Contents/Resources"
    app = prefix/"Isabelle2026.app"
    app.mkpath
    app.install "Contents"
    # Keep Electron's short relative IDs relocatable without overflowing Mach-O headers.
    app.find do |path|
      next if path.symlink? || !path.file?

      path = MachOPathname.wrap(path)
      next unless path.dylib?

      id = path.dylib_id
      next if id.nil? || id.start_with?("@rpath/", "/usr/lib/swift/")

      Utils::Path.ensure_writable(path.to_path) do
        path.change_dylib_id("@rpath/#{File.basename(id)}", strict: false)
      end
    end
    Dir[app/"Contents/Resources/contrib/polyml-*/**/polyimport"].each do |path|
      libs = Utils.safe_popen_read("/usr/bin/otool", "-L", path)
      libs.scan(%r{(/private/tmp/\S+/libgmp\.10\.dylib)}).flatten.each do |old|
        system "/usr/bin/install_name_tool", "-change", old, "@loader_path/libgmp.10.dylib", path
      end
    end
    (libexec/"sign_bundle.py").write <<~'PYTHON'
      import os
      from pathlib import Path
      import subprocess
      import sys

      app = Path(sys.argv[1]).resolve()
      magic = {b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe', b'\xca\xfe\xba\xbe', b'\xbe\xba\xfe\xca'}
      def sign(path):
          subprocess.run(['/usr/bin/codesign', '--force', '--sign', '-', '--preserve-metadata=entitlements', str(path)], check=True)
      count = 0
      for parent, dirs, files in os.walk(app):
          for name in files:
              p = Path(parent)/name
              if p.is_symlink():
                  continue
              with p.open('rb') as stream:
                  header = stream.read(4)
              if header in magic:
                  sign(p)
                  count += 1
      for parent, dirs, files in os.walk(app, topdown=False):
          p = Path(parent)
          if p.is_symlink():
              continue
          if p.suffix == '.framework' or (p/'Contents/Info.plist').is_file():
              sign(p)
      print('Signed native files:', count)
    PYTHON
    (bin/"isabelle").write <<~SH
      #!/bin/sh
      exec "#{opt_prefix}/Isabelle2026.app/Contents/Resources/bin/isabelle" "$@"
    SH
  end

  post_install_steps do
    run "/usr/bin/python3", args:           ["{{prefix}}/libexec/sign_bundle.py", "{{prefix}}/Isabelle2026.app"],
                            writable_paths: ["{{prefix}}/Isabelle2026.app"]
  end

  def caveats
    <<~EOS
      GUI: #{opt_prefix}/Isabelle2026.app
      CLI: isabelle
      Isabelle/Scala and Pure/HOL are rebuilt from bundled source.
      Upstream Java, Poly/ML and external prover components are retained.
      User settings and projects are not removed or rewritten by this formula.
    EOS
  end

  test do
    ENV["USER_HOME"] = testpath
    assert_match "Isabelle2026", shell_output("#{bin}/isabelle version")
    (testpath/"ROOT").write <<~ROOT
      session Homebrew_Check = HOL +
        options [document = false, threads = 2, timeout = 180]
        theories Homebrew_Check
    ROOT
    (testpath/"Homebrew_Check.thy").write <<~'THY'
      theory Homebrew_Check imports Main begin
      lemma hol_check: "rev (rev xs) = (xs :: nat list)" by simp
      lemma hammer_check:
        assumes "\<forall>x. P x \<longrightarrow> Q x" "\<forall>x. Q x \<longrightarrow> R x" "P a"
        shows "R a"
        sledgehammer [provers = e, timeout = 30, expect = some]
        using assms by blast
      lemma smt_verit_check:
        fixes x y z :: int
        assumes "x < y" "y \<le> z"
        shows "x + 1 \<le> z"
        using assms by (smt (verit))
      lemma smt_cvc5_check:
        fixes x y z :: int
        assumes "x < y" "y \<le> z"
        shows "x + 1 \<le> z"
        using assms by (smt (cvc5))
      end
    THY
    system bin/"isabelle", "build", "-v", "-D", testpath
  end
end
