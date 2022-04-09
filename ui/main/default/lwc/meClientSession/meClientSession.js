import { LightningElement } from "lwc";
import { remote } from "c/fetch";

export default class MeClientSession extends LightningElement {
  clientSessions = [];
  loading = true;

  get showEmpty() {
    return !this.loading && this.clientSessions.length === 0;
  }

  connectedCallback() {
    remote("ProfileController.GetAllClientSession")
      .then((sessions) => {
        this.clientSessions = sessions.map((session) => {
          return {
            ...session,
            revoke() {
              this.loading = true;
              remote("ProfileController.RevokeClientSession", {
                client: session.id,
              }).then(this.connectedCallback.bind(this));
            },
          };
        });
      })
      .then((_) => (this.loading = false));
  }
  revoke() {
    remote("ProfileController.RevokeClientSessions").then(
      this.connectedCallback.bind(this)
    );
  }
}
