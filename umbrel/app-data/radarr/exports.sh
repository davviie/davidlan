# Check if qBittorrent and SABnzbd are installed
installed_apps=$(/opt/umbreld/source/modules/apps/legacy-compat/app-script ls-installed)

if echo "$installed_apps" | grep --quiet 'qbittorrent'; then
  export APP_RADARR_QBITTORRENT_INSTALLED="true"
fi

if echo "$installed_apps" | grep --quiet 'sabnzbd'; then
  export APP_RADARR_SABNZBD_INSTALLED="true"
  # export SABNZBD_API_KEY, which has the format:
  # api_key = 98e3444f7fab45e592958673bf656g3
  export APP_RADARR_SABNZBD_API_KEY=$(grep -Po 'api_key = \K.*' "${UMBREL_ROOT}/app-data/sabnzbd/data/config/sabnzbd.ini")
fi
