# Zen, and the language packs

# Zen is a Firefox fork, so the home-manager module takes the same shape as the
# Firefox one and the preferences below are ordinary Firefox prefs.

# darwinDefaultsId is required on macOS by this module: it is the plist domain
# the module writes preferences to. The darwin package is the beta channel --
# Zen ships no stable macOS build for the flake to wrap -- so the bundle id is
# the beta one.

# The profile path is left at the module's own default: Zen keeps its profiles
# in its own directory, not Firefox's, so there is no legacy path to pin.

{
  inputs,
  lib,
  pkgs,
  user,
  ...
}:

# The identities are named outside this repo

# This repo is public, and the names of an employer and a client are exactly what
# must not be in it -- nor are the hostnames that would route to them, since an
# Atlassian site or a self-hosted forge is named after the organisation that owns
# it. Both live in the gitignored =work-extras.nix= alongside the corporate casks
# and packages, read at eval under ~--impure~, and what stays here is the shape.

# Absent that file the three identities still exist; they are called Work and
# Client and route nothing, which is a working browser and an honest public
# config at the same time.

# The private file adds one attribute to the set it already returns:

#   zen.spaces.work   = { name = "..."; routes = [ "host" ]; suspendUrls = [ "host" ]; };
#   zen.spaces.client = { name = "..."; routes = [ "host" ]; suspendUrls = [ "host" ]; };

# ~suspendUrls~ extends the list of sites the suspender puts to sleep after hours.
# The common ones are named in the open below -- Google, Atlassian, the forges --
# because a vendor hostname on its own says nothing about who uses it. Anything
# that would (an internal tool, a self-hosted forge, an HR system) goes here
# instead, on the same reasoning that keeps the VDI client and the rest of the
# corporate stack in this file.

# Route ids are prefixed with the identity key because Zen keeps every route in
# one file, and two spaces both declaring a first route would otherwise collide
# on the same id.

let
  privatePath = "/Users/${user}/.config/nix-secrets/work-extras.nix";
  private = if builtins.pathExists privatePath then import privatePath { inherit pkgs; } else { };

  identities = private.zen.spaces or { };

  identityName = key: fallback: (identities.${key} or { }).name or fallback;

  identityRoutes =
    key:
    lib.listToAttrs (
      lib.imap0 (
        i: reference:
        lib.nameValuePair "${key}-${toString i}" {
          inherit reference;
          matchType = "contains";
        }
      ) ((identities.${key} or { }).routes or [ ])
    );

  identitySuspendUrls = key: (identities.${key} or { }).suspendUrls or [ ];

  # The working day. A rule names these hours to treat them differently from
  # the rest of the week -- and naming the working day is the whole trick: the
  # hours that are *not* it take three windows to enumerate and leave a corner
  # on Monday morning, where a window opening on Friday evening does not reach.

  workdayHours = {
    days = [
      1
      2
      3
      4
      5
    ];
    from = "09:00";
    to = "18:00";
  };

  # The sites that are only ever work, whoever "work" is. Scoped by container
  # in the rules below, so the same hostname means a different account in each.

  officeUrls = [
    "mail.google.com"
    "calendar.google.com"
    "meet.google.com"
    "atlassian.net"
  ];
in
{
  imports = [
    inputs.zen-browser.homeModules.default
    ./vimium.nix
  ];

  programs.zen-browser = {
    enable = true;

    darwinDefaultsId = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin "app.zen-browser.zen";

    languagePacks = [
      "en-US"
      "es-ES"
      "de"
    ];

    profiles.${user} = {
      id = 0;
      name = user;

      # Bookmarks

      # force = true because the module refuses to overwrite a bookmarks file it did
      # not write, and this one is declarative: whatever is here wins over whatever
      # the browser has accumulated.

      bookmarks = {
        force = true;
        settings = [
          {
            name = "Nix sites";
            toolbar = true;
            bookmarks = [
              {
                name = "Nix";
                url = "https://nixos.org/";
              }
              {
                name = "Nix Wiki";
                tags = [
                  "wiki"
                  "nix"
                ];
                url = "https://wiki.nixos.org/";
              }
              {
                name = "Nixpkgs";
                tags = [
                  "packages"
                  "nix"
                ];
                url = "https://search.nixos.org/packages";
              }
            ];
          }
        ];
      };

      # Extensions

      # From the firefox-addons flake, so each one is pinned and reproducible rather
      # than fetched by the browser at first run.

      extensions = {
        force = true;

        packages = with inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system}; [
          pkgs.tab-suspender
          bitwarden
          cookie-autodelete
          darkreader
          decentraleyes
          firenvim
          image-search-options
          lingq-importer2
          readeck
          sponsorblock
          ublock-origin
          umatrix
          vimium
        ];

        # uBlock Origin

        # The dynamic filtering rules neuter behind-the-scene requests -- the ones the
        # browser itself makes outside any tab -- and the filter list selection is the
        # default set plus the annoyance and cookie-notice lists.

        settings."uBlock0@raymondhill.net".settings = {
          dynamicFilteringString = "behind-the-scene * * noop\nbehind-the-scene * inline-script noop\nbehind-the-scene * 1p-script noop\nbehind-the-scene * 3p-script noop\nbehind-the-scene * 3p-frame noop\nbehind-the-scene * image noop\nbehind-the-scene * 3p noop";
          hostnameSwitchesString = "no-large-media: behind-the-scene false\nno-csp-reports: * true";

          selectedFilterlist = [
            "user-filters"
            "ublock-filters"
            "ublock-badware"
            "ublock-privacy"
            "ublock-quick-fixes"
            "ublock-unbreak"
            "easylist"
            "adguard-generic"
            "adguard-mobile"
            "easyprivacy"
            "urlhaus-1"
            "plowe-0"
            "fanboy-cookiemonster"
            "ublock-cookies-easylist"
            "adguard-cookies"
            "ublock-cookies-adguard"
            "easylist-chat"
            "easylist-newsletters"
            "easylist-notifications"
            "easylist-annoyances"
            "adguard-mobile-app-banners"
            "adguard-other-annoyances"
            "adguard-popup-overlays"
            "adguard-widgets"
            "ublock-annoyances"
            "spa-1"
            "spa-0"
          ];

          userSettings = {
            uiTheme = "dark";
          };
        };

        # Tab Suspender

        # Three signed-in organisations in one window is three organisations' worth of
        # tabs left open, and a loaded tab costs a content process whether or not anyone
        # has looked at it since lunch. Discarding one frees that process and leaves the
        # tab in the strip; clicking it loads the page again.

        # Gecko's own unloading does not cover this. =browser.tabs.unloadOnLowMemory=
        # fires under memory pressure, which on 16 GiB means it acts once the machine is
        # already struggling rather than keeping it from getting there, and it has no
        # notion of whose tab it is discarding.

        # A rule is a container and a set of sites and a schedule, and it needs all
        # three. Container alone is too blunt: a jar holds the things worth suspending
        # and the things worth keeping. Sites alone cannot tell two accounts apart, since
        # both organisations are on the same Google and the same Atlassian. Pair them and
        # each is exact -- which is also why the patterns below can be plain vendor
        # hostnames in a public file: the container has already decided whose Atlassian
        # it is.

        # A rule carries a standing idle time and, optionally, hours that override it. A
        # window can say ~suspend = false~ and make those hours untouchable however long
        # a tab sits, or give ~idleMinutes~ of its own and merely be more patient then;
        # the first window matching the moment decides, and where none matches the
        # standing time applies. A rule with no windows behaves the same way around the
        # clock, which is what most of them want.

        # The client's inbox is why the override exists. It must survive a working day
        # untouched, so it leaves the general list, takes a standing five minutes, and
        # marks the working day itself as off limits -- after six an inbox left open is
        # just resident memory, but at eleven in the morning it is the job. Naming the
        # working day is also what makes it simple: the hours that are *not* it need
        # three windows and still leave a corner on Monday morning, which a window
        # opening on Friday evening never reaches.

        # Everything else is on idle alone, at any hour. A page nobody has looked at for
        # half an hour is not doing anything at half past ten in the morning either, and
        # getting it back costs a reload. Any of them can grow a window later without
        # touching the extension.

        # Rules are a union rather than a chain: a tab goes as soon as any rule covering
        # it has had its time met, so the shortest applicable time acts and the order
        # they appear in does not matter.

        # Untouched means since the tab was last in front, not since it was last clicked,
        # so a suspended tab resumed at seven and worked in until quarter to eight has
        # its full half hour from quarter to eight. Each tab keeps its own clock.

        # Three protections are on unless a rule turns them off: pinned, audio, and
        # sharing. The last is the one that matters for a call -- a tab holding the
        # camera, the microphone or a screen share is in use precisely while nobody is
        # touching it, and audio would not catch it, since Meet keeps the microphone
        # captured through a mute and a call where nobody is speaking is silent.

        # The settings reach the extension as ~storage.local~, which is what home-manager
        # writes. The extension prefers ~storage.managed~ where a policy exists, but this
        # module only passes ~policies~ into the Linux package, so on darwin the local
        # copy is the one that arrives.

        settings."tab-suspender@nix-config".settings = {
          intervalMinutes = 5;

          rules = [
            {
              containerIds = [ 3 ];
              urls = [ "mail.google.com" ];
              idleMinutes = 5;
              windows = [ (workdayHours // { suspend = false; }) ];
            }
            {
              containerIds = [ 2 ];
              urls = officeUrls ++ [ "github.com" ] ++ identitySuspendUrls "work";
              idleMinutes = 30;
            }
            {
              containerIds = [ 3 ];
              urls = lib.remove "mail.google.com" officeUrls ++ [ "gitlab.com" ] ++ identitySuspendUrls "client";
              idleMinutes = 30;
            }
          ];
        };
      };

      # Containers: one browser, two cookie jars

      # Three accounts on the same site are the case this exists for. Google is the
      # sharp edge -- employer mail, client mail and personal mail are all
      # =mail.google.com=, so no amount of URL matching separates them; only the cookie
      # jar does. A container is that jar: tabs opened in one never see another's
      # cookies, storage or logins, and all three stay signed in at once. Atlassian is
      # the same story with two of them.

      # Forced, like the bookmarks and the extensions above: what is written here is
      # the whole set, and a container invented in the UI does not survive the next
      # activation. Ids are explicit because everything else refers to a container by
      # id, not by name -- renaming one must not silently repoint a space.

      containersForce = true;

      containers = {
        personal = {
          id = 1;
          color = "green";
          icon = "fingerprint";
        };
        work = {
          id = 2;
          name = identityName "work" "Work";
          color = "blue";
          icon = "briefcase";
        };
        client = {
          id = 3;
          name = identityName "client" "Client";
          color = "purple";
          icon = "circle";
        };
      };

      # Spaces: the container made visible, and URLs routed into it

      # Zen's spaces are the UI over the containers. Each one carries its own tab
      # strip and pins and is bound to a container, so switching space switches
      # identity rather than merely filtering tabs.

      # ~routes~ are the part worth having: a URL matching one opens in that space
      # whatever space is in front, which is what makes a link clicked from a chat or a
      # terminal land in the right jar instead of whichever one happened to be focused.

      # They have to be per-organisation hostnames, not vendor domains. Two of these
      # identities are on Atlassian, so a rule for =atlassian.net= would drag both into
      # one space and be wrong half the time; it is the site subdomain that
      # distinguishes them, and that is a name this repo cannot hold. Hence the list
      # coming from outside. Google cannot be routed by URL at all -- pin each account
      # in its own space instead.

      # ~spacesForce~ is deliberately left off. It deletes spaces that are not declared
      # here, and Zen spaces hold live tabs; turn it on once this list is the whole
      # truth, not before.

      # The session store is written only when Zen is not running -- the module takes
      # the profile lock and says so when it skips -- so these land on the first
      # activation after the browser is closed.

      spaces = {
        Personal = {
          id = "76b6baa5-dafa-4b86-8f2e-5240f05dddc7";
          position = 0;
          icon = "🏠";
          container = 1;
        };

        Work = {
          name = identityName "work" "Work";
          id = "ff0fd16a-4226-48b9-8911-3a0cc6235304";
          position = 1;
          icon = "💼";
          container = 2;
          routes = identityRoutes "work";
        };

        Client = {
          name = identityName "client" "Client";
          id = "3a3bb718-f2c3-41ae-a000-64a915c26514";
          position = 2;
          icon = "🤝";
          container = 3;
          routes = identityRoutes "client";
        };
      };

      # Preferences: first-run noise

      # autoDisableScopes = 0 stops Firefox disabling the addons installed above
      # before you ever see them. The rest is the welcome tour, the what's-new panel,
      # the default-browser nag and the rights notice.

      settings = {
        "extensions.autoDisableScopes" = 0;

        "browser.startup.homepage" = "about:home";

        "browser.disableResetPrompt" = true;
        "browser.download.panel.shown" = true;
        "browser.feeds.showFirstRunUI" = false;
        "browser.messaging-system.whatsNewPanel.enabled" = false;
        "browser.rights.3.shown" = true;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.shell.defaultBrowserCheckCount" = 1;
        "browser.startup.homepage_override.mstone" = "ignore";
        "browser.uitour.enabled" = false;
        "startup.homepage_override_url" = "";
        "trailhead.firstrun.didSeeAboutWelcome" = true;
        "browser.bookmarks.restore_default_bookmarks" = false;
        "browser.bookmarks.addedImportButton" = true;

        "browser.download.useDownloadDir" = false;

        # Preferences: the new tab page

        # The activity stream is off, and the six top sites Firefox ships are blocked
        # by their hashes -- that is the only handle the pref gives you, hence the
        # comment against each one.

        "browser.newtabpage.activity-stream.feeds.topsites" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts" = false;
        "browser.newtabpage.blocked" = lib.genAttrs [
          # Youtube
          "26UbzFJ7qT9/4DhodHKA1Q=="
          # Facebook
          "4gPpjkxgZzXPVtuEoAL9Ig=="
          # Wikipedia
          "eV8/WsSLxHadrTL1gAxhug=="
          # Reddit
          "gLv0ja2RYVgxKdp0I5qwvA=="
          # Amazon
          "K00ILysCaEq8+bEqV/3nuw=="
          # Twitter
          "T9nJot5PurhJSy8n038xGA=="
        ] (_: 1);

        # Preferences: telemetry

        # Every reporting channel Firefox has, off. Several of these are redundant with
        # each other; they are all set because which one actually governs a given ping
        # has changed between releases more than once.

        "app.shield.optoutstudies.enabled" = false;
        "browser.discovery.enabled" = false;
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        "browser.ping-centre.telemetry" = false;
        "datareporting.healthreport.service.enabled" = false;
        "datareporting.healthreport.uploadEnabled" = false;
        "datareporting.policy.dataSubmissionEnabled" = false;
        "datareporting.sessions.current.clean" = true;
        "devtools.onboarding.telemetry.logged" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "toolkit.telemetry.bhrPing.enabled" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.firstShutdownPing.enabled" = false;
        "toolkit.telemetry.hybridContent.enabled" = false;
        "toolkit.telemetry.newProfilePing.enabled" = false;
        "toolkit.telemetry.prompted" = 2;
        "toolkit.telemetry.rejected" = true;
        "toolkit.telemetry.reportingpolicy.firstRun" = false;
        "toolkit.telemetry.server" = "";
        "toolkit.telemetry.shutdownPingSender.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.unifiedIsOptIn" = false;
        "toolkit.telemetry.updatePing.enabled" = false;

        # Preferences: hardening

        # Passwords live in Bitwarden, so the browser's own password manager is off
        # rather than merely unused -- an empty prompt is still a prompt.

        "signon.rememberSignons" = false;

        "privacy.trackingprotection.enabled" = true;
        "dom.security.https_only_mode" = true;

        # Preferences: containers

        # home-manager writes =containers.json= but never touches this pref, and without
        # it the contextual identities exist on disk and nowhere in the browser.

        "privacy.userContext.enabled" = true;

        # Preferences: toolbar layout

        # Pinned as JSON because Firefox stores the whole toolbar arrangement in one
        # pref. Editing it by hand in the browser and copying the result back out is
        # the only practical way to change this.

        "browser.uiCustomization.state" = builtins.toJSON {
          currentVersion = 20;
          newElementCount = 5;
          dirtyAreaCache = [
            "nav-bar"
            "PersonalToolbar"
            "toolbar-menubar"
            "TabsToolbar"
            "widget-overflow-fixed-list"
          ];
          placements = {
            PersonalToolbar = [ "personal-bookmarks" ];
            TabsToolbar = [
              "tabbrowser-tabs"
              "new-tab-button"
              "alltabs-button"
            ];
            nav-bar = [
              "back-button"
              "forward-button"
              "stop-reload-button"
              "urlbar-container"
              "downloads-button"
              "ublock0_raymondhill_net-browser-action"
              "reset-pbm-toolbar-button"
              "unified-extensions-button"
            ];
            toolbar-menubar = [ "menubar-items" ];
            unified-extensions-area = [ ];
            widget-overflow-fixed-list = [ ];
          };
          seen = [
            "save-to-pocket-button"
            "developer-button"
            "ublock0_raymondhill_net-browser-action"
          ];
        };
      };
    };
  };
}
