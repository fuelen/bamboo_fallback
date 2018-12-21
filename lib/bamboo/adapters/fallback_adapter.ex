defmodule Bamboo.FallbackAdapter do
  @moduledoc """
  This adapter allows you to compose multiple adapters to increase the guarantee of delivering.
  It applies adapters one by one and fails only when all adapters fail.

  Config example:
    config :myapp, MyApp.Mailer,
      adapter:  Bamboo.FallbackAdapter,
      fallback_options: [
        {Bamboo.SendGridAdapter, api_key: "SENDGRID_API_KEY"},
        {Bamboo.MailgunAdapter, api_key: "MAILGUN_API_KEY", domain: "MAILGUN_DOMAIN"}
      ]
  """
  @behaviour Bamboo.Adapter
  require Logger

  def handle_config(config) do
    config
    |> Map.update!(:fallback_options, fn adapter_configs ->
      adapter_configs
      |> Enum.map(fn {adapter, config} ->
        {
          adapter,
          config |> Enum.into(%{}) |> adapter.handle_config()
        }
      end)
    end)
  end

  def deliver(email, %{fallback_options: adapter_configs}) do
    adapter_configs
    |> Enum.reduce_while(:no_result, fn {adapter, config}, _result ->
      try do
        {:halt, adapter.deliver(email, config)}
      rescue
        e in Bamboo.ApiError ->
          Logger.error(e.message)
          {:cont, :no_result}
      end
    end)
    |> case do
      :no_result -> Bamboo.ApiError.raise_api_error("None of given providers sent an email")
      result -> result
    end
  end
end
