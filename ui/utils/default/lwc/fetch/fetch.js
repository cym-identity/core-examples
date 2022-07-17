import STATIC_RESOURCE_URL from "@salesforce/resourceUrl/MFA";
const path =
  STATIC_RESOURCE_URL.split("/resource/")[0][0] === "/"
    ? window.location.protocol +
      "//" +
      window.location.host +
      STATIC_RESOURCE_URL.split("/resource/")[0]
    : STATIC_RESOURCE_URL.split("/resource/")[0] + "/remote";

const remote = async function(action, payload) {
  return fetch( path + '?action=' + encodeURIComponent(action), {
    method: 'POST',
    headers: {
      'Accept' : 'application/json'
    },
    body: new URLSearchParams({
      payload: JSON.stringify(payload || {})
    })
  })
  .then(resp => resp.json())
  .then((resp) => {
    const { error, response, redirect } = resp;
    if (redirect) return window.location.href = redirect;
    if (error) return Promise.reject(error);
    return response;
  });
}

export { remote };