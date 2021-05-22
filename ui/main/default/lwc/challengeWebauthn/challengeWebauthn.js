import { LightningElement, api } from "lwc";
import base64url from "./base64url";
import initVerifyWebAuthn from "@salesforce/apex/ChallengeController.initVerifyWebAuthn";
import verifyVerifyWebAuthn from "@salesforce/apex/ChallengeController.verifyVerifyWebAuthn";

export default class ChallengeWebauthn extends LightningElement {
  @api credentials;
  @api authenticator;
  @api cta;
  @api mode;
  loading = false;

  connectedCallback() {
    if (this.mode === 'auto') this.handleVerifyWebAuthn();
  }

  handleVerifyWebAuthn() {
    this.loading = true;
    return initVerifyWebAuthn({
      authenticator: this.authenticator,
    })
      .then(({ transactionId, publicKey: result }) => {
        var publicKey = this.preformatMakeCredReq(result);
        return this.credentials
          .get({ publicKey })
          .then((response) => {
            return verifyVerifyWebAuthn({
              authenticator: this.authenticator,
              param: {
                transactionId,
                id: response.id,
                rawId: base64url.encode(response.rawId),
                authenticatorData: base64url.encode(
                  response.response.authenticatorData
                ),
                clientDataJSON: base64url.encode(
                  response.response.clientDataJSON
                ),
                signature: base64url.encode(response.response.signature),
              },
            })
              .then((isValid) => {
                if (isValid) {
                  this.dispatchEvent(
                    new CustomEvent("done", { detail: isValid })
                  );
                } else {
                  this.dispatchEvent(
                    new CustomEvent("error", {
                      detail: { name: "InvalidCredentialError", message: isValid },
                    })
                  );
                }
                this.loading = false;
              })
              .catch(({ name, message }) => {
                // Network Error or Server Throws during verification
                let location = "verifyVerifyWebAuthn";
                console.error({ location, name, message });
              });
          })
          .catch(({ name, message }) => {
            this.loading = false;
            // The authenticator throws during Assertion
            let location = "this.credentials.get";
            console.error({ location, name, message });
            if (name === "NotAllowedError") {
              return this.dispatchEvent(
                new CustomEvent("error", { detail: { name, message } })
              );
            }
          });
      })
      .catch(({ name, message }) => {
        this.loading = false;
        // Network Error or Server Throws during initiation
        let location = "initVerifyWebAuthn";
        console.error({ location, name, message });
      });
  }

  preformatMakeCredReq(makeCredReq) {
    makeCredReq.challenge = base64url.decode(makeCredReq.challenge);
    if (makeCredReq.user)
      makeCredReq.user.id = base64url.decode(makeCredReq.user.id);
    if (
      makeCredReq.allowCredentials &&
      makeCredReq.allowCredentials.length > 0
    ) {
      makeCredReq.allowCredentials.forEach((cred) => {
        cred.id = base64url.decode(cred.id);
      });
    }
    return makeCredReq;
  }
}
