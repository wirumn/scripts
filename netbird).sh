netbird)
    name="NetBird"
    type="pkg"
    downloadURL="https://pkgs.netbird.io/macos/universal"
    appNewVersion=$(curl -LsI $downloadURL -o /dev/null -w '%{url_effective}' | grep -oE "\d+\.\d+\.\d+")
    expectedTeamID="TA739QLA7A"
    ;;