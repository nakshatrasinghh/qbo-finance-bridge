document.addEventListener("DOMContentLoaded", () => {
  const container = document.querySelector("[data-swagger-ui]")
  if (!container) return

  const localError = document.querySelector("[data-swagger-local-error]")
  const postWarning =
    "POST creates a real record in the connected QuickBooks sandbox.\n" +
    "Repeated executions may create duplicate records."

  const showLocalError = (message) => {
    localError.textContent = message
    localError.hidden = false
  }

  const clearLocalError = () => {
    localError.textContent = ""
    localError.hidden = true
  }

  const abortPost = (message) => {
    showLocalError(message)
    throw new Error(message)
  }

  if (typeof SwaggerUIBundle === "undefined") {
    container.textContent = "Swagger UI could not load. Use the raw OpenAPI YAML link above."
    container.setAttribute("role", "alert")
    return
  }

  SwaggerUIBundle({
    url: container.dataset.openapiUrl,
    dom_id: "#swagger-ui",
    deepLinking: true,
    displayRequestDuration: true,
    supportedSubmitMethods: ["get", "post"],
    requestInterceptor: (request) => {
      const method = String(request.method || "GET").toUpperCase()
      if (method !== "POST") return request

      clearLocalError()

      let target
      try {
        target = new URL(request.url, window.location.href)
      } catch {
        return abortPost("Swagger blocked this POST because its request URL is invalid.")
      }

      if (target.origin !== window.location.origin) {
        return abortPost("Swagger blocked this POST because it does not target this Rails application.")
      }

      const csrfToken = document.querySelector("meta[name='csrf-token']")?.content?.trim()
      if (!csrfToken) {
        return abortPost(
          "Swagger blocked this POST because the Rails CSRF token is missing. Reload the page before trying again."
        )
      }

      if (!window.confirm(postWarning)) {
        return abortPost("Swagger cancelled the POST before sending a network request.")
      }

      request.headers = { ...request.headers, "X-CSRF-Token": csrfToken }
      request.credentials = "same-origin"
      return request
    },
    presets: [SwaggerUIBundle.presets.apis],
    layout: "BaseLayout"
  })
})
