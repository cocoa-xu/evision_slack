defmodule EvisionSlack.ImageCell do
  @moduledoc false

  use Kino.JS, assets_path: "lib/assets"
  use Kino.JS.Live
  use Kino.SmartCell, name: "Evision Image to Slack"

  @impl true
  def init(attrs, ctx) do
    fields = %{
      "token_secret_name" => attrs["token_secret_name"] || "",
      "channel" => attrs["channel"] || "",
      "message" => attrs["message"] || "",
      "variable" => attrs["variable"] || ""
    }

    ctx = assign(ctx, fields: fields)
    {:ok, ctx}
  end

  @impl true
  def handle_connect(ctx) do
    {:ok, %{fields: ctx.assigns.fields}, ctx}
  end

  @impl true
  def handle_event("update_channel", value, ctx) do
    ctx = update(ctx, :fields, &Map.merge(&1, %{"channel" => value}))
    {:noreply, ctx}
  end

  @impl true
  def handle_event("update_message", value, ctx) do
    ctx = update(ctx, :fields, &Map.merge(&1, %{"message" => value}))
    {:noreply, ctx}
  end

  @impl true
  def handle_event("update_variable", value, ctx) do
    ctx = update(ctx, :fields, &Map.merge(&1, %{"variable" => value}))
    {:noreply, ctx}
  end

  @impl true
  def handle_event("update_token_secret_name", value, ctx) do
    broadcast_event(ctx, "update_token_secret_name", value)
    ctx = update(ctx, :fields, &Map.merge(&1, %{"token_secret_name" => value}))
    {:noreply, ctx}
  end

  @impl true
  def to_attrs(ctx) do
    ctx.assigns.fields
  end

  def quoted_var(nil), do: nil
  def quoted_var(string), do: {String.to_atom(string), [], nil}

  @impl true
  def to_source(attrs) do
    required_fields = ~w(token_secret_name channel message variable)

    if all_fields_filled?(attrs, required_fields) do
      quote do
        boundary = "evision_slack_msg"

        channel = String.trim("#" <> unquote(attrs["channel"]))
        initial_comment = String.trim(unquote(attrs["message"]))
        file_data = Evision.imencode(".png", unquote(quoted_var(attrs["variable"])))
        filename = "attached#{System.monotonic_time()}.png"

        form_data = """
        --#{boundary}
        Content-Disposition: form-data; name="channels"

        #{channel}
        --#{boundary}
        Content-Disposition: form-data; name="initial_comment"

        #{initial_comment}
        --#{boundary}
        Content-Disposition: form-data; name="file"; filename="#{filename}"
        Content-Type: image/png
        Content-Transfer-Encoding: binary

        #{file_data}
        --#{boundary}
        Content-Disposition: form-data; name="filetype"

        png
        --#{boundary}-
        """

        req =
          Req.new(
            base_url: "https://slack.com/api",
            auth: {:bearer, System.fetch_env!(unquote("LB_#{attrs["token_secret_name"]}"))}
          )
          |> Req.Request.put_header("Content-Type", "multipart/form-data; boundary=#{boundary}")

        response =
          Req.post!(req,
            url: "/files.upload",
            body: form_data
          )

        case response.body do
          %{"ok" => true} -> :ok
          %{"ok" => false, "error" => error} -> {:error, error}
        end
      end
      |> Kino.SmartCell.quoted_to_string()
    else
      ""
    end
  end

  def all_fields_filled?(attrs, keys) do
    Enum.all?(keys, fn key -> attrs[key] not in [nil, ""] end)
  end
end
