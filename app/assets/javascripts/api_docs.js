document.addEventListener("DOMContentLoaded", () => {
  const container = document.querySelector("[data-swagger-ui]")
  if (!container) return

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
    supportedSubmitMethods: ["get"],
    presets: [SwaggerUIBundle.presets.apis],
    layout: "BaseLayout"
  })
})
