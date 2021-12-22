import { LightningElement, api } from "lwc";

import STATIC_RESOURCE_URL from "@salesforce/resourceUrl/MFA";

export default class WebauthnChallenge extends LightningElement {
  @api authenticator;
  @api startUrl;
  @api userId;
  error;
  loading = true;
  ready = false;

  get canShowButton() { return this.ready && !this.error; }

  get webAuthnPath() {
    let prefix = STATIC_RESOURCE_URL.split("/resource/")[0][0] === '/' ? window.location.protocol + '//' + window.location.host + STATIC_RESOURCE_URL.split("/resource/")[0] : STATIC_RESOURCE_URL.split("/resource/")[0]
    return prefix + "/webauthn?authenticator=" + encodeURIComponent(this.authenticator) + '&requestor=' + this.requestor;
  }

  requestor = Math.floor(Math.random() * 100_000) + "";

  webauthnController = function ({ data: { action, response, requestor } }) {
    if (requestor !== this.requestor) return;
    this.loading = false;
    if (action === "ready") {
      const {
        error,
        error_description,
      } = response;
      this.ready = true;
      this.error = error;
      return this.dispatchEvent(
        new CustomEvent("ready", {
          detail: error? { error, error_description } : {},
        })
      );
    }
    if (action === "initVerifyWebAuthn") {
      const { isValid, url, error, error_description } = response;
      if (error)
        return this.dispatchEvent(
          new CustomEvent("error", {
            detail: { error, error_description },
          })
        );
      if (!isValid)
        return this.dispatchEvent(
          new CustomEvent("error", {
            detail: {
              error: "invalid_credential",
              error_description:
                "The credential presented is unknown, malformed or invalid",
            },
          })
        );
      if (url)
        return this.dispatchEvent(
          new CustomEvent("done", { detail: { redirect: url } })
        );
    }
    return this.dispatchEvent(
      new CustomEvent("error", {
        detail: {
          error: "invalid_action",
          error_description:
            "The response received from the handler is unknown : " + action,
        },
      })
    );
  }.bind(this);

  connectedCallback() {
    window.addEventListener("message", this.webauthnController);
  }

  disconnectedCallback() {
    window.removeEventListener("message", this.webauthnController);
  }

  handleInitVerifyWebAuthn() {
    try {
      let u = new URL(this.webAuthnPath);
      this.loading = true;
      const input = {
        action: "initVerifyWebAuthn",
        requestor: this.requestor,
        startUrl: this.startUrl,
      };
      if (this.userId != undefined) input.userId = this.userId;
      this.template.querySelector("iframe").contentWindow.postMessage(
        input,
        `${u.protocol}//${u.host}`
      );
    } catch(e) {
      console.error(e);
    }
  }
}
