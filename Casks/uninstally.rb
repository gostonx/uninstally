cask "uninstally" do
  version "1.7.3"
  sha256 :no_check

  url "https://github.com/gostonx/uninstally/releases/download/v#{version}/Uninstally-#{version}.dmg"
  name "Uninstally"
  desc "Complete macOS application uninstaller with leftover detection"
  homepage "https://github.com/gostonx/uninstally"

  depends_on macos: ">= :ventura"

  app "Uninstally.app"

  zap trash: [
    "~/Library/Application Scripts/com.codenta.uninstally",
    "~/Library/Preferences/com.codenta.uninstally.plist",
    "~/Library/Application Support/com.codenta.uninstally",
  ]
end
