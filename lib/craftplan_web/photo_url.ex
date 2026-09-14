defmodule CraftplanWeb.PhotoUrl do
  alias ExAws.S3
  alias Waffle.Storage.S3, as: WaffleS3

  @doc """
  Builds a signed URL using a browser-reachable host, instead of
  Waffle's default which uses the container-internal S3 host.
  """
  def signed(definition, version, {file, scope}, opts \\ []) do
    bucket = System.get_env("AWS_S3_BUCKET")
    file_struct = %{file_name: file}
    key = WaffleS3.s3_key(definition, version, {file_struct, scope})

    config =
      ExAws.Config.new(:s3,
        scheme: System.get_env("AWS_S3_PUBLIC_SCHEME") || "http://",
        host: System.get_env("AWS_S3_PUBLIC_HOST") || "localhost",
        port: String.to_integer(System.get_env("AWS_S3_PUBLIC_PORT") || "9000")
      )

    expires_in = Keyword.get(opts, :expires_in, 300)

    {:ok, url} = S3.presigned_url(config, :get, bucket, key, expires_in: expires_in)
    url
  end
end
