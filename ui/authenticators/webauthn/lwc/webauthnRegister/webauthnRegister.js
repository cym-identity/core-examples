import { LightningElement, api } from "lwc";
import { remote } from "c/fetch";
import { base64url, preformatMakeCredReq } from "c/webAuthnUtils";

export default class WebauthnRegister extends LightningElement {
  @api authenticator;
  @api startUrl;
  @api userId;
  @api requestId;
  error;

  loading = false;

  handleInitRegisterWebAuthn() {
    this.loading = true;
    return remote('WebAuthnController.initRegisterWebAuthn', {'authenticator' : this.authenticator, userId: this.userId || null })
      .then(({ publicKey }) => {
        return navigator.credentials.create({ publicKey: preformatMakeCredReq(publicKey) })
      })
      .then(response => {
        return remote('WebAuthnController.VerifyRegisterWebAuthn', {
          startURL: this.startUrl,
          id: response.id,
          rawId: base64url.encode(response.rawId),
          attestationObject: base64url.encode(response.response.attestationObject),
          clientDataJSON: base64url.encode(response.response.clientDataJSON),
          transports: response.response.getTransports
            ? JSON.stringify(response.response.getTransports())
            : "[]",
          authenticator: this.authenticator,
          requestId: this.requestId,
          userId: this.userId || null
        });
      })
      .then(({ credential, error, error_description }) => {
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
        return this.dispatchEvent(
          new CustomEvent("done", { detail: { isValid: true } })
        );
      }).catch(error => {
        this.error = error;
        console.log(error);
      })
      .then(_ => this.loading = false);
  }
}
