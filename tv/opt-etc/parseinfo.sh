#!/usr/bin/awk -f
BEGIN {
  log_file = "/opt/etc/overlay.log"
  "date" | getline now; close("date")
  print now ": Clean overlay v4 starting" > log_file

  # v3: Samsung AI picture services (aifw-*, aisctrlmgr_server, screen-analysis, contents-cognition,
  # aitech) are no longer blocked. contents-recognition-service (ACR) stays blocked.
  targets = "data-service sp-kpi devicetracker stability-monitor SCSAgent TIFADaemon_L TIFSDaemon abnormal_user_behavior ambient-ua-agent pushd register-device SWUAutoUpgrade bt-monitor wifi-monitor SWUService SWUCoreTV SWUVerifierTV fw-update-service fw-update-init-download nagsam-daemon p2p-asm-UI contents-recognition-service p2p-asm emergencyLogTransmitter gamebar-service"
  n = split(targets, svcs, " ")
  count = 0
  for (i = 1; i <= n; i++) {
    path = "/usr/bin/" svcs[i]
    cmd = "test -f " path " && mount --bind /bin/true " path " 2>/dev/null; echo $?"
    cmd | getline rc; close(cmd)
    if (rc == 0) {
      count++
      ov[path] = 1
      print "  overlaid: " path >> log_file
    }
  }

  sbin_targets = "user-presence wifi_state_manager"
  n2 = split(sbin_targets, sbin_svcs, " ")
  for (i = 1; i <= n2; i++) {
    path = "/usr/sbin/" sbin_svcs[i]
    cmd = "test -f " path " && mount --bind /bin/true " path " 2>/dev/null; echo $?"
    cmd | getline rc; close(cmd)
    if (rc == 0) {
      count++
      ov[path] = 1
      print "  overlaid: " path >> log_file
    }
  }

  app_targets = "/usr/apps/org.tizen.registerav/bin/registerav /usr/apps/org.tizen.registertv/bin/registertv /usr/apps/org.tizen.welcome-mode/bin/welcome-mode /usr/apps/org.tizen.bleapp/bin/bleapp /usr/apps/com.samsung.tv.cis-api-service-app/bin/cis-api-service-app /usr/apps/screen_sharing/bin/screen_sharing"
  n3 = split(app_targets, app_svcs, " ")
  for (i = 1; i <= n3; i++) {
    path = app_svcs[i]
    cmd = "test -f " path " && mount --bind /bin/true " path " 2>/dev/null; echo $?"
    cmd | getline rc; close(cmd)
    if (rc == 0) {
      count++
      ov[path] = 1
      print "  overlaid: " path >> log_file
    }
  }

  "date" | getline now2; close("date")
  print now2 ": Overlay done (" count " binaries)" >> log_file

  # v4: kill processes started before the overlay by matching their program path
  # (v3 used pidof and reused the previous PID when nothing matched). SIGKILL because
  # some (stability-monitor) ignore SIGTERM; a systemd restart then runs the /bin/true overlay.
  system("sleep 3")
  kill_count = 0
  cmd = "ps -eo pid,args"
  while ((cmd | getline psline) > 0) {
    np = split(psline, pf, " ")
    if (np >= 2 && (pf[2] in ov)) {
      system("kill -9 " pf[1] " 2>/dev/null")
      kill_count++
      print "  killed pre-overlay: " pf[2] " (" pf[1] ")" >> log_file
    }
  }
  close(cmd)
  if (kill_count > 0) {
    print "  killed " kill_count " pre-overlay processes" >> log_file
  }

  # v4: systemd units that restart-loop forever (Restart=always, every 2-5 s) because their
  # binary is overlaid with /bin/true, their app is disabled (pkgcmd -D), or they crash without
  # disabled Samsung components. Stop them and mask for this boot only (/run, /etc is read-only).
  # org.tizen.ssoservice: its sso-service binary was renamed away; Restart=on-failure every 3 s
  # never hits StartLimitBurst, so it relaunched ~18 times per 30 s.
  loop_units = "stability-monitor devicetracker emergency-log-transmitter gamebar-service p2p-asm scs-agent mcf-agent-service org.tizen.easysetup-daemon adagent-service pisa-service com.samsung.tv.ai-interpreter-service com.samsung.tv.context-aware-agent com.samsung.tv.multiscreen slive-provider-daemon org.tizen.ssoservice"
  nu = split(loop_units, lu, " ")
  for (i = 1; i <= nu; i++) {
    system("systemctl mask --runtime " lu[i] ".service >/dev/null 2>&1; systemctl stop " lu[i] ".service >/dev/null 2>&1")
  }
  print "  stopped+masked " nu " restart-looping units" >> log_file

  # --- Control Center boot setup ---
  cc_rules = "/opt/etc/smack-cc.rules"
  cmd = "test -f " cc_rules "; echo $?"
  cmd | getline rc; close(cmd)
  if (rc == 0) {
    while ((getline rule < cc_rules) > 0) {
      if (rule != "") {
        system("echo \"" rule "\" > /sys/fs/smackfs/load2 2>/dev/null")
      }
    }
    close(cc_rules)
    print "  Control Center SMACK rules loaded" >> log_file
  }
  # Security-manager registration (idempotent)
  cmd = "sqlite3 /opt/dbspace/.security-manager.db \"SELECT COUNT(*) FROM app WHERE name=\'ClaudeTVCC0.ControlCenter\'\" 2>/dev/null"
  cmd | getline sec_count; close(cmd)
  if (sec_count+0 == 0) {
    system("security-manager-cmd --manage-apps a --app ClaudeTVCC0.ControlCenter --pkg ClaudeTVCC0 --uid 5001 --tizen 6.0 --install-type global --privilege http://tizen.org/privilege/application.launch --privilege http://tizen.org/privilege/application.info --privilege http://tizen.org/privilege/filesystem.read --privilege http://tizen.org/privilege/filesystem.write --privilege http://tizen.org/privilege/internet --privilege http://tizen.org/privilege/tv.inputdevice --privilege http://tizen.org/privilege/volume.set --privilege http://tizen.org/privilege/notification --path=/opt/usr/apps/ClaudeTVCC0 rw 2>/dev/null")
    print "  Control Center security-manager registered" >> log_file
  }
  # Native notifications over other apps (idempotent; CC was registered before it needed this)
  system("cyad -s -k MANIFESTS_GLOBAL -c User::Pkg::ClaudeTVCC0 -u '*' -p http://tizen.org/privilege/notification -t 65535 2>/dev/null")
  system("vconftool set -t string db/appfw/home_appid ClaudeTVCC0.ControlCenter -f 2>/dev/null")
  print "  Control Center home_appid set" >> log_file
  # --- end Control Center ---
  # CC launcher daemon (also resets the AVOC new_home flag so Picture Clarity stays available)
  system("systemctl is-active cc-launcher.service >/dev/null 2>/dev/null || systemd-run --unit=cc-launcher /usr/bin/awk -f /opt/etc/cc-launcher.awk 2>/dev/null")
  # Key monitor: Sweet TV -> HBO, Back hold / Home -> CC, Power -> screen toggle
  # (v4: replaces the dmesg-polling cc-homekey daemon)
  system("systemctl is-active cc-keymon.service >/dev/null 2>/dev/null || systemd-run --unit=cc-keymon /usr/bin/awk -f /opt/etc/cc-keymon.awk 2>/dev/null")
  # Back monitor: return to CC after user app exit, TV Plus -> HBO
  system("systemctl is-active cc-backmon.service >/dev/null 2>/dev/null || systemd-run --unit=cc-backmon /usr/bin/awk -f /opt/etc/cc-backmon.awk 2>/dev/null")
  # Notification wake: posts CC notifications as native Samsung banners while another app is on
  # screen (LC_ALL=C: the daemon builds byte-length-prefixed bundles)
  system("systemctl is-active cc-notifywake.service >/dev/null 2>/dev/null || systemd-run --unit=cc-notifywake /usr/bin/env LC_ALL=C /usr/bin/awk -f /opt/etc/cc-notifywake.awk 2>/dev/null")
  print "  CC daemons started (launcher, keymon, backmon, notifywake)" >> log_file
  close(log_file)

  while ((getline line < "/etc/prd_info.ini") > 0) {
    if (line ~ /Build=/) {
      sub(/.*Build=/, "", line); sub(/;.*/, "", line); repo = line
    }
    if (line ~ /Model=/) {
      sub(/.*Model=/, "", line); sub(/;.*/, "", line); model = line
    }
  }
  close("/etc/prd_info.ini")

  printf "__%s__%s\n", repo, model > "/proc/target_version"
  close("/proc/target_version")
}
