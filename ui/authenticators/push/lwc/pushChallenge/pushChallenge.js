import { LightningElement } from "lwc";
import { remote } from "c/fetch";

function poll(fn, exit, timeout, interval) {
  return new Promise((resolve, reject) => {
    // set timeout timer
    var timeoutTimer = setTimeout(function () {
      clearInterval(intervalTimer);
      reject("Past endTime; condition not satisfied");
    }, timeout);

    // set polling timer
    var intervalTimer = setInterval(function () {
      fn()
        .then((result) => {
            if (exit(result)) {
              clearTimeout(timeoutTimer);
              clearInterval(intervalTimer);
              resolve(result);
            }
          });
    }, interval);
  });
}

export default class PushChallenge extends LightningElement {
  loading = false;
  result;

  handleInitVerifyClick() {
    this.loading = true;
    this.result = null;
    remote("PushChallengeController.InitVerification", {})
      .then(({ auth_req_id }) => {
        this.auth_req_id = auth_req_id;
        return poll(
          remote.bind(undefined, "PushChallengeController.VerifyVerification", {
            auth_req_id,
          }),
          ({ message }) => message != "InProgress",
          30_000,
          3_000
        );
      })
      .then(result => {
        if (result.success) this.dispatchEvent(
          new CustomEvent("done", {
            detail: {...result, isValid: true},
          })
        );
        this.result = result
      })
      .catch(console.error)
      .then((_) => (this.loading = false));
  }
}
