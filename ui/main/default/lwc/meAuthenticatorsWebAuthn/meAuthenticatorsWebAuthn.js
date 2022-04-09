import { LightningElement } from "lwc";
import { remote } from "c/fetch";

export default class MeAuthenticatorsWebAuthn extends LightningElement {
  loading = true;
  credentials = [];
  rename;

  connectedCallback() {
    remote("ProfileController.GetAllWebAuthnCredentials")
      .then(
        (credentials) =>
          (this.credentials = credentials.map((credential) => {
            return {
              ...credential,
              icon:
                credential.transports.indexOf("internal") > -1
                  ? "utility:touch_action"
                  : "utility:yubi_key",
              rename() {
                this.rename = {
                  id: credential.id,
                  name: credential.name,
                  handleChange: ((e) => {
                    this.rename.name = e.target.value;
                  }).bind(this),
                  continue: ((e) => {
                    e.preventDefault();
                    e.stopPropagation();
                    this.loading = true;
                    remote("ProfileController.RenameCredential", {
                      id: this.rename.id,
                      name: this.rename.name,
                      userId: this.userId,
                    })
                      .then((resp) => {
                        const { error } = resp;
                        console.log({ error });
                        this.rename = undefined;
                        this.connectedCallback();
                      })
                      .catch(console.error.bind(undefined))
                      .then((_) => (this.loading = false));
                  }).bind(this),
                };
              },
            };
          }))
      )
      .then((_) => (this.loading = false));
  }
}
