# ssh-askpass-mac from source, HEAD only: a local checkout of this
# repository is its own tap.
#   brew tap martinpaljak/ssh-askpass-mac /path/to/checkout
#   brew install --HEAD martinpaljak/ssh-askpass-mac/ssh-askpass-mac
# A formula cannot write to /Applications; copy the app there after install.
class SshAskpassMac < Formula
  # The source is what the tap was cloned from (its origin), at the tap's
  # branch: a local checkout or GitHub. brew upgrade --fetch-HEAD then builds
  # the newest commit there without a brew update.
  TAP_GIT = File.expand_path("../.git", __dir__).freeze
  SOURCE = ((File.read("#{TAP_GIT}/config")[/^\[remote "origin"\][^\[]*?^\s*url = (.+)$/, 1] rescue nil) ||
            File.dirname(TAP_GIT)).freeze
  BRANCH = ((File.read("#{TAP_GIT}/HEAD")[%r{^ref: refs/heads/(.+)$}, 1] rescue nil) || "master").freeze

  desc "Passphrase and confirmation dialog for OpenSSH on macOS"
  homepage "https://github.com/martinpaljak/ssh-askpass-mac"
  license "BSD-2-Clause"
  head SOURCE, branch: BRANCH, using: :git

  depends_on xcode: :build
  depends_on :macos

  def install
    # xcodebuild needs full Xcode, also when xcode-select points to the CLT.
    ENV["DEVELOPER_DIR"] = MacOS::Xcode.prefix.to_s
    xcodebuild "-project", "ssh-askpass.xcodeproj",
               "-configuration", "Release",
               "SYMROOT=build"
    prefix.install "build/Release/ssh-askpass.app"
  end

  def caveats
    <<~EOS
      Copy the app to /Applications (again after each upgrade):
        rm -rf /Applications/ssh-askpass.app
        ditto #{opt_prefix}/ssh-askpass.app /Applications/ssh-askpass.app
      To set SSH_ASKPASS for the whole login session, load its Launch Agent:
        ln -s /Applications/ssh-askpass.app/Contents/Resources/com.hardssh.ssh-askpass-mac.plist ~/Library/LaunchAgents/
        launchctl load -w ~/Library/LaunchAgents/com.hardssh.ssh-askpass-mac.plist
    EOS
  end

  test do
    assert_predicate prefix/"ssh-askpass.app/Contents/MacOS/ssh-askpass", :executable?
  end
end
