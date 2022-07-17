import { LightningElement } from 'lwc';
// import list from '@salesforce/apex/ChallengeController.listAllTwilioPush';
// import init from '@salesforce/apex/ChallengeController.initTwilioPush';
// import verify from '@salesforce/apex/ChallengeController.verifyTwilioPush';

import MFA_STATIC_RESOURCE_URL from '@salesforce/resourceUrl/MFA';

export default class ChallengeTwilioPush extends LightningElement {
  factors = [];
  sid;
  pendingRequestImgUrl = MFA_STATIC_RESOURCE_URL + '/img/TwilioPushPendingRequest.jpg';

  connectedCallback() {
    // list().then(factors => {
    //   console.log(JSON.parse(JSON.stringify(factors)));
    //   this.factors = factors.map(factor => {
    //     factor.init = () => {
    //       init({sid : factor.sid}).then(challenge => {
    //         this.sid = challenge.sid;
    //       })
    //     }
    //     return factor;
    //   });
    // })
  }

  handleVerify() {
    // const interval = setInterval(() => {
      // verify({challenge : this.sid}).then(status => {
      //   if (status === 'approved') {
      //     // clearInterval(interval);
      //     this.dispatchEvent(new CustomEvent('done', {detail : status}));
      //     return;
      //   }
      //   if (status === 'denied') {
      //     // clearInterval(interval);
      //     return;
      //   };
      //   if (status === 'pending') return;
      // })
    // }, 5000);
  }
}
