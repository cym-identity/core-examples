import { LightningElement } from "lwc";
import { remote } from "c/fetch";

export default class MeBrowserSession extends LightningElement {
  sessions = [];
  loading = true;

  get showEmpty() {
    return !this.loading && this.sessions.length === 0;
  }

  connectedCallback() {
    remote("ProfileController.GetAllBrowsers")
      .then(
        (sessions) =>
          (this.sessions = sessions.map((session) => {
            return {
              ...session,
              lastSeen: new Date(session.lastSeen).toLocaleString(),
              icon: this.getBrowserIcon(session.browser),
              logout() {
                this.loading = true;
                remote("ProfileController.RevokeSession", {
                  session: session.id,
                }).then(this.connectedCallback.bind(this));
              },
            };
          }))
      )
      .then((_) => (this.loading = false));
  }

  closeAllSessions() {
    remote("ProfileController.RevokeSessions");
  }

  getBrowserIcon(browser) {
    if (!browser)
      return "https://img.icons8.com/external-those-icons-fill-those-icons/2x/external-browser-bookmarks-tags-those-icons-fill-those-icons-2.png";
    if (browser.indexOf("Chrome") > -1)
      return "https://img.icons8.com/ios/2x/chrome.png";
    if (browser.indexOf("Safari") > -1)
      return "https://img.icons8.com/ios-glyphs/2x/safari.png";
    if (browser.indexOf("Firefox") > -1)
      return "https://img.icons8.com/external-tal-revivo-light-tal-revivo/2x/external-firefox-a-free-and-open-source-web-browser-developed-by-the-mozilla-foundation-logo-light-tal-revivo.png";
    if (browser.indexOf("Edge") > -1)
      return "https://img.icons8.com/ios-glyphs/2x/ms-edge.png";
    if (browser.indexOf("Brave") > -1)
      return "https://img.icons8.com/windows/2x/brave-web-browser.png";
    if (browser.indexOf("Vivaldi") > -1)
      return "https://img.icons8.com/ios/2x/vivaldi-web-browser.png";
    return "https://img.icons8.com/external-those-icons-fill-those-icons/2x/external-browser-bookmarks-tags-those-icons-fill-those-icons-2.png";
  }
}
