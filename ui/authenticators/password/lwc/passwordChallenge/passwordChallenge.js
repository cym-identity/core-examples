import { LightningElement, api } from "lwc";
import { remote } from "c/fetch";

export default class PasswordChallenge extends LightningElement {
  @api user;
  @api context;

  startUrl =
    new URLSearchParams(document.location.search).get("startURL") || "";
  loading = false;
  error;

  weak_password = false;
  newPassword;

  handlePasswordChange(e) {
    this.password = e.target.value;
  }
  handleNewPasswordChange(e) {
    this.newPassword = e.target.value;
  }

  async handleLogin(e) {
    e.preventDefault();
    this.loading = true;
    this.error = null;

    return (
      this.weak_password
        ? remote("DiscoveryController.ResetWeakPassword", {
            email: this.user.email,
            password: this.password,
            newPassword: this.newPassword,
            startURL: this.startUrl,
          })
        : remote("DiscoveryController.Authenticate", {
            email: this.user.email,
            password: this.password,
            startURL: this.startUrl,
          })
    )
      .then(({ redirect }) => {
        if (redirect)
          this.dispatchEvent(new CustomEvent("done", { detail: { redirect } }));
      })
      .catch((ex) => {
        this.error = ex;
        if (this.error.error === "weak_password") this.weak_password = true;
      })
      .then((_) => (this.loading = false));
  }
}
