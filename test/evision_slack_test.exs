defmodule EvisionSlack.ImageCellTest do
  use ExUnit.Case

  import Kino.Test

  alias EvisionSlack.ImageCell

  setup :configure_livebook_bridge

  test "when required fields are filled in, generates source code" do
    {kino, _source} = start_smart_cell!(ImageCell, %{})

    push_event(kino, "update_token_secret_name", "SLACK_TOKEN")
    push_event(kino, "update_channel", "slack-channel")
    push_event(kino, "update_message", "slack message")
    push_event(kino, "update_variable", "image_variable")

    assert_smart_cell_update(
      kino,
      %{
        "token_secret_name" => "SLACK_TOKEN",
        "channel" => "slack-channel",
        "message" => "slack message",
        "variable" => "image_variable"
      },
      generated_code
    )

    expected_code = ~S"""
    boundary = "evision_slack_msg"
    channel = String.trim("#" <> "slack-channel")
    initial_comment = String.trim("slack message")
    file_data = Evision.imencode(".png", image_variable)
    filename = "attached#{System.monotonic_time()}.png"
    form_data = "--#{boundary}
    Content-Disposition: form-data; name=\"channels\"

    #{channel}
    --#{boundary}
    Content-Disposition: form-data; name=\"initial_comment\"

    #{initial_comment}
    --#{boundary}
    Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"
    Content-Type: image/png
    Content-Transfer-Encoding: binary

    #{file_data}
    --#{boundary}
    Content-Disposition: form-data; name=\"filetype\"

    png
    --#{boundary}-
    "

    req =
      Req.new(
        base_url: "https://slack.com/api",
        auth: {:bearer, System.fetch_env!("LB_SLACK_TOKEN")}
      )
      |> Req.Request.put_header("Content-Type", "multipart/form-data; boundary=#{boundary}")

    response = Req.post!(req, url: "/files.upload", body: form_data)

    case response.body do
      %{"ok" => true} -> :ok
      %{"ok" => false, "error" => error} -> {:error, error}
    end
    """

    expected_code = String.trim(expected_code)

    assert generated_code == expected_code
  end

  test "generates source code from stored attributes" do
    stored_attrs = %{
      "token_secret_name" => "SLACK_TOKEN",
      "channel" => "slack-channel",
      "message" => "slack message",
      "variable" => "image_variable"
    }

    {_kino, source} = start_smart_cell!(ImageCell, stored_attrs)

    expected_source = ~S"""
    boundary = "evision_slack_msg"
    channel = String.trim("#" <> "slack-channel")
    initial_comment = String.trim("slack message")
    file_data = Evision.imencode(".png", image_variable)
    filename = "attached#{System.monotonic_time()}.png"
    form_data = "--#{boundary}
    Content-Disposition: form-data; name=\"channels\"

    #{channel}
    --#{boundary}
    Content-Disposition: form-data; name=\"initial_comment\"

    #{initial_comment}
    --#{boundary}
    Content-Disposition: form-data; name=\"file\"; filename=\"#{filename}\"
    Content-Type: image/png
    Content-Transfer-Encoding: binary

    #{file_data}
    --#{boundary}
    Content-Disposition: form-data; name=\"filetype\"

    png
    --#{boundary}-
    "

    req =
      Req.new(
        base_url: "https://slack.com/api",
        auth: {:bearer, System.fetch_env!("LB_SLACK_TOKEN")}
      )
      |> Req.Request.put_header("Content-Type", "multipart/form-data; boundary=#{boundary}")

    response = Req.post!(req, url: "/files.upload", body: form_data)

    case response.body do
      %{"ok" => true} -> :ok
      %{"ok" => false, "error" => error} -> {:error, error}
    end
    """

    expected_source = String.trim(expected_source)

    assert source == expected_source
  end

  test "when any required field is empty, returns empty source code" do
    required_attrs = %{
      "token_secret_name" => "SLACK_TOKEN",
      "channel" => "#slack-channel",
      "message" => "slack message",
      "variable" => "image_variable"
    }

    attrs_missing_required = put_in(required_attrs["token_secret_name"], "")
    assert ImageCell.to_source(attrs_missing_required) == ""

    attrs_missing_required = put_in(required_attrs["channel"], "")
    assert ImageCell.to_source(attrs_missing_required) == ""

    attrs_missing_required = put_in(required_attrs["message"], "")
    assert ImageCell.to_source(attrs_missing_required) == ""

    attrs_missing_required = put_in(required_attrs["variable"], "")
    assert ImageCell.to_source(attrs_missing_required) == ""
  end

  test "when slack token secret field changes, broadcasts secret name back to client" do
    {kino, _source} = start_smart_cell!(ImageCell, %{})

    push_event(kino, "update_token_secret_name", "SLACK_TOKEN")

    assert_broadcast_event(kino, "update_token_secret_name", "SLACK_TOKEN")
  end
end
