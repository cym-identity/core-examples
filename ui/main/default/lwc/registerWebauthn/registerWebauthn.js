import { LightningElement, api } from "lwc";
import base64url from "./base64url";
import initRegisterWebAuthn from "@salesforce/apex/ChallengeController.initRegisterWebAuthn";
import verifyRegisterWebAuthn from "@salesforce/apex/ChallengeController.verifyRegisterWebAuthn";

import MFA_STATIC_RESOURCE_URL from '@salesforce/resourceUrl/MFA';

export default class RegisterWebauthn extends LightningElement {
  @api credentials;
  @api authenticator;
  @api cta;
  @api basePath;
  @api startUrl;

  loading = false;

  registerAnimationUrl = MFA_STATIC_RESOURCE_URL + '/img/windows_register_animation.gif';

  handleRegisterWebAuthn() {
    this.loading = true;
    return initRegisterWebAuthn({
      authenticator: this.authenticator,
    })
      .then(({ transactionId, publicKey: result }) => {
        var publicKey = this.preformatMakeCredReq(result);
        return this.credentials
          .create({ publicKey })
          .then((response) => {
            var cred = {
              transactionId,
              id: response.id,
              rawId: base64url.encode(response.rawId),
              attestationObject: base64url.encode(
                response.response.attestationObject
              ),
              clientDataJSON: base64url.encode(
                response.response.clientDataJSON
              ),
              transports: response.response.getTransports
                ? JSON.stringify(response.response.getTransports())
                : "[]",
            };
            return fetch(this.basePath + '/browser_handle')
              .then(resp => resp.json())
              .then(resp => resp.handle)
              .then(handle => {
                return verifyRegisterWebAuthn({
                  authenticator: this.authenticator,
                  param: cred,
                  handle,
                })
              })
              .then(({id}) => {
                this.loading = false;
                if (id) {
                  this.dispatchEvent(new CustomEvent("done", { detail: id }));
                } else {

                }
              })
              .catch(({name, message}) => {
                this.loading = false;
                let location = 'verifyRegisterWebAuthn';
                console.error({location, name, message});
              });
          })
          .catch(({name, message}) => {
            let location = 'this.credentials.create';
            console.error({location, name, message});
            if (name === "InvalidStateError") {
              return this.dispatchEvent(new CustomEvent("error", { detail: {name, message} }));
            }
          });
      })
      .catch(console.error);
  }

  preformatMakeCredReq(makeCredReq) {
    makeCredReq.challenge = base64url.decode(makeCredReq.challenge);
    if (makeCredReq.user)
      makeCredReq.user.id = base64url.decode(makeCredReq.user.id);
    if (
      makeCredReq.excludeCredentials &&
      makeCredReq.excludeCredentials.length > 0
    ) {
      makeCredReq.excludeCredentials.forEach((cred) => {
        cred.id = base64url.decode(cred.id);
      });
    }
    return makeCredReq;
  }
}
