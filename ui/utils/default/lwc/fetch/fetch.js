import STATIC_RESOURCE_URL from "@salesforce/resourceUrl/MFA";
const path = (
    // When using components on Experience builder, the STATIC_RESOURCE_URL looks like /resource/123456/MFA
    // When using compoennts on Lightning out, the STATIC_RESOURCE_URL looks like https://xxx.x/resource/123456/MFA
    STATIC_RESOURCE_URL.split("/resource/")[0][0] === "/"
    ? window.location.protocol +
      "//" +
      window.location.host
    : ""
  ) + STATIC_RESOURCE_URL.split("/resource/")[0] + "/remote";

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