import { LightningElement, api } from "lwc";
import { remote } from "c/fetch";
import { base64url, preformatMakeCredReq } from "c/webAuthnUtils";

export default class WebauthnChallenge extends LightningElement {
  @api authenticator;
  @api startUrl;
  @api userId;
  @api requestId;
  @api mode = 'auto';
  error;
  loading = true;

  connectedCallback() {
    if (this.mode === 'auto') this.handleInitVerifyWebAuthn();
  }

  handleInitVerifyWebAuthn() {
    this.loading = true;
    return remote('WebAuthnController.initVerifyWebAuthn', {'authenticator' : this.authenticator, userId: this.userId || null })
      .then(({ publicKey }) => {
        return navigator.credentials.get({ publicKey: preformatMakeCredReq(publicKey) })
      })
      .then(response => {
        return remote('WebAuthnController.VerifyVerifyWebAuthn', {
          startURL: this.startUrl,
          id: response.id,
          rawId: base64url.encode(response.rawId),
          authenticatorData: base64url.encode(response.response.authenticatorData),
          clientDataJSON: base64url.encode(response.response.clientDataJSON),
          signature: base64url.encode(response.response.signature),
          authenticator: this.authenticator,
          requestId: this.requestId,
          userId: this.userId || null
        });
      })
      .then(({ isValid, error, error_description }) => {
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
        return this.dispatchEvent(
          new CustomEvent("done", { detail: { isValid } })
        );
      }).catch(error => {
        this.error = error;
        console.log(error);
      })
      .then(_ => this.loading = false);
  }
}
