import { LightningElement, api } from "lwc";
import { remote } from 'c/fetch';

import STATIC_RESOURCE_URL from "@salesforce/resourceUrl/MFA";

export default class WebauthnRegister extends LightningElement {
  @api authenticator;
  @api startUrl;
  @api userId;
  error;
  loading = true;
  ready = false;

  get canShowButton() {
    return this.ready && !this.error;
  }

  get webAuthnPath() {
    let prefix =
      STATIC_RESOURCE_URL.split("/resource/")[0][0] === "/"
        ? window.location.protocol +
          "//" +
          window.location.host +
          STATIC_RESOURCE_URL.split("/resource/")[0]
        : STATIC_RESOURCE_URL.split("/resource/")[0];
    return (
      prefix +
      "/webauthn?authenticator=" +
      encodeURIComponent(this.authenticator) +
      "&requestor=" +
      this.requestor
    );
  }

  requestor = Math.floor(Math.random() * 100_000) + "";

  rename;

  webauthnController = function ({ data: { action, response, requestor } }) {
    if (requestor !== this.requestor) return;
    this.loading = false;
    if (action === "ready") {
      const { error, error_description } = response;
      this.ready = true;
      this.error = error;
      return this.dispatchEvent(
        new CustomEvent("ready", {
          detail: error ? { error, error_description } : {},
        })
      );
    }
    if (action === "initRegisterWebAuthn") {
      const { credential, url, error, error_description } = response;
      console.log(
        JSON.parse(
          JSON.stringify({ credential, url, error, error_description })
        )
      );
      if (error)
        return this.dispatchEvent(
          new CustomEvent("error", {
            detail: { error, error_description },
          })
        );
      if (!credential)
        return this.dispatchEvent(
          new CustomEvent("error", {
            detail: {
              error: "invalid_credential",
              error_description: "Could not create a credential",
            },
          })
        );
      if (url)
        // Ask the user to rename
        this.rename = {
          id: credential.id,
          name: this.authenticator === 'webauthn_platform' ? "Built-In Authenticator Name" : "Security Key Name",
          handleChange: ((e) => {
            this.rename.name = e.target.value;
          }).bind(this),
          continue: ((e) => {
            e.preventDefault();
            e.stopPropagation();
            this.loading = true;
            remote('WebAuthnController.RenameCredential', {
                id: this.rename.id,
                name: this.rename.name,
                userId : this.userId
              })
              .then((resp) => {
                const { error } = resp;
                this.rename = undefined;
                if (error) {
                  return this.dispatchEvent(
                    new CustomEvent("error", { detail : resp})
                  );
                }
                this.dispatchEvent(
                  new CustomEvent("done", { detail: { redirect: url } })
                );
              })
              .catch(console.error.bind(undefined))
              .then(_ => this.loading = false);
          }).bind(this),
        };
        return;
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

  handleInitRegisterWebAuthn() {
    this.loading = true;
    let u = new URL(this.webAuthnPath);
    this.template.querySelector("iframe").contentWindow.postMessage(
      {
        action: "initRegisterWebAuthn",
        authenticator: this.authenticator,
        userId: this.userId,
        startUrl: this.startUrl,
      },
      `${u.protocol}//${u.host}`
    );
  }
}
