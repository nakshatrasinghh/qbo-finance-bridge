class ApiDocsController < Quickbooks::BaseController
  OPENAPI_PATH = Rails.root.join("docs/openapi.yaml")

  def show
  end

  def openapi
    response.set_header("Cache-Control", "no-store")
    render plain: OPENAPI_PATH.read, content_type: "application/yaml"
  end
end
