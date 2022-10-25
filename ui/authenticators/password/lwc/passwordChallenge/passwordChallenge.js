import { LightningElement, api } from "lwc";
import { remote } from "c/fetch";

export default class PasswordChallenge extends LightningElement {
  @api user;
  @api requestId;

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
            userId: this.user.id,
            password: this.password,
            newPassword: this.newPassword,
            requestId: this.requestId,
          })
        : remote("DiscoveryController.Authenticate", {
            userId: this.user.id,
            password: this.password,
            requestId: this.requestId,
          })
    )
      .then(({ isValid }) => {
        if (isValid)
          this.dispatchEvent(new CustomEvent("done", { detail: {} }));
      })
      .catch((ex) => {
        this.error = ex;
        if (this.error.error === "weak_password") this.weak_password = true;
      })
      .then((_) => (this.loading = false));
  }

  handleForgotPassword() {
    console.log('handleForgotPassword');
  }
}
