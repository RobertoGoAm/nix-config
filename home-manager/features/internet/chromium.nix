{
  programs.chromium = {
    enable = true;

    extensions = [
      { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
      { id = "lfhmikememgdcahcdlaciloancbhjino"; } # CORS Unblock
      { id = "fdpohaocaechififmbbbbbknoalclacl"; } # GoFullPage
      { id = "amknoiejhlmhancpahfcfcfhllgkpbld"; } # Hoppscotch Browser Extension
      { id = "blipmdconlkpinefehnmjammfjpmpbjk"; } # Lighthouse
      { id = "hniebljpgcogalllopnjokppmgbhaden"; } # Scre.io
      { id = "mooikfkahbdckldjjndioackbalphokd"; } # Selenium IDE
      { id = "fmkadmapgofadopljbjfkapdkoienihi"; } # React Developer Tools
      { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # Vimium
      { id = "nhdogjmejiglipccpnnnanhbledajbpd"; } # Vue.js devtools
      { id = "iaajmlceplecbljialhhkmedjlpdblhp"; } # Vue.js devtools (legacy)
      { id = "ahfhijdlegdabablpippeagghigmibma"; } # Web Vitals
    ];
  };
}
