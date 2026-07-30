Rails.application.config.to_prepare do
  Rails.application.config.x.quickbooks.sandbox_connection_store =
    Quickbooks::SandboxConnectionStore.new
end
