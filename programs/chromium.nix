{ pkgs, ... }:
{
  chromium = {
    enable = true;

    dictionaries = [
      pkgs.hunspellDictsChromium.en_US
    ];

    extensions = [
      { id = "nngceckbapebfimnlniiiahkandclblb"; } # Bitwarden
      { id = "fhcgjolkccmbidfldomjliifgaodjagh"; } # Cookie AutoDelete
      { id = "lfhmikememgdcahcdlaciloancbhjino"; } # CORS Unblock
      { id = "eimadpbcbfnmbkopoojfekhnkhdbieeh"; } # Dark Reader 
      { id = "ldpochfccmkkmhdbclfhpagapcfdljkj"; } # Decentraleyes 
      { id = "fdpohaocaechififmbbbbbknoalclacl"; } # GoFullPage
      { id = "bmnlcjabgnpnenekpadlanbbkooimhnj"; } # Honey 
      { id = "amknoiejhlmhancpahfcfcfhllgkpbld"; } # Hoppscotch Browser Extension
      { id = "blipmdconlkpinefehnmjammfjpmpbjk"; } # Lighthouse
      { id = "hniebljpgcogalllopnjokppmgbhaden"; } # Scre.io
      { id = "mooikfkahbdckldjjndioackbalphokd"; } # Selenium IDE
      { id = "fmkadmapgofadopljbjfkapdkoienihi"; } # React Developer Tools 
      { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin 
      { id = "ogfcmafjalglgifnmanfmnieipoejdcf"; } # uMatrix 
      { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # Vimium 
      { id = "nhdogjmejiglipccpnnnanhbledajbpd"; } # Vue.js devtools 
      { id = "iaajmlceplecbljialhhkmedjlpdblhp"; } # Vue.js devtools (legacy) 
      { id = "ahfhijdlegdabablpippeagghigmibma"; } # Web Vitals
    ];
  };
}
