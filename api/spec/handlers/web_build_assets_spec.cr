require "../spec_helper"
require "file_utils"

private def assets_request(root : String, method : String, path : String, headers = HTTP::Headers.new)
  request = HTTP::Request.new(method, path, headers)
  output = IO::Memory.new
  response = HTTP::Server::Response.new(output)
  context = HTTP::Server::Context.new(request, response)

  reached_next = false
  handler = WebBuildAssetsHandler.new(root)
  handler.next = ->(_ctx : HTTP::Server::Context) { reached_next = true }
  handler.call(context)
  response.close

  # `output` holds the status line and headers too; the body starts after the
  # empty line that separates them.
  raw = output.to_s
  body = if index = raw.index("\r\n\r\n")
           raw[(index + 4)..].to_slice
         else
           Bytes.empty
         end

  {response, body, reached_next}
end

private def with_assets_root(&)
  root = File.tempname("webbuild", "")
  build = File.join(root, "abc", "Build")
  Dir.mkdir_p(build)
  File.write(File.join(build, "Spy.framework.js.br"), Bytes[0x1b, 0x2a, 0x00])
  File.write(File.join(build, "Spy.wasm.br"), Bytes[0x00, 0x61, 0x73, 0x6d])
  File.write(File.join(build, "Spy.data.br"), Bytes[0x01, 0x02])
  File.write(File.join(build, "Spy.symbols.json.gz"), Bytes[0x03])
  File.write(File.join(build, "Spy.loader.js"), "console.log('hi')")
  begin
    yield root
  ensure
    FileUtils.rm_rf(root)
  end
end

describe WebBuildAssetsHandler do
  it "serves a brotli script with the type of the uncompressed file" do
    with_assets_root do |root|
      response, body, reached_next = assets_request(
        root, "GET", "/media/web/abc/Build/Spy.framework.js.br",
      )

      reached_next.should be_false
      response.status_code.should eq 200
      response.headers["Content-Encoding"].should eq "br"
      response.headers["Content-Type"].should eq "text/javascript; charset=utf-8"
      response.headers["Accept-Ranges"].should eq "bytes"
      body.should eq Bytes[0x1b, 0x2a, 0x00]
    end
  end

  it "serves brotli wasm and data with their own types" do
    with_assets_root do |root|
      response, _, _ = assets_request(root, "GET", "/media/web/abc/Build/Spy.wasm.br")
      response.headers["Content-Encoding"].should eq "br"
      response.headers["Content-Type"].should eq "application/wasm"

      response, _, _ = assets_request(root, "GET", "/media/web/abc/Build/Spy.data.br")
      response.headers["Content-Encoding"].should eq "br"
      response.headers["Content-Type"].should eq "application/octet-stream"
    end
  end

  it "serves gzip with the same rules" do
    with_assets_root do |root|
      response, _, _ = assets_request(root, "GET", "/media/web/abc/Build/Spy.symbols.json.gz")

      response.headers["Content-Encoding"].should eq "gzip"
      response.headers["Content-Type"].should eq "application/json"
    end
  end

  it "leaves uncompressed files to the static handler" do
    with_assets_root do |root|
      _, _, reached_next = assets_request(root, "GET", "/media/web/abc/Build/Spy.loader.js")

      reached_next.should be_true
    end
  end

  it "ignores paths outside the web builds directory" do
    with_assets_root do |root|
      _, _, reached_next = assets_request(
        root, "GET", "/media/web/abc/Build/../../../../etc/passwd.br",
      )

      reached_next.should be_true
    end
  end

  it "answers a conditional request with 304" do
    with_assets_root do |root|
      response, _, _ = assets_request(root, "GET", "/media/web/abc/Build/Spy.framework.js.br")
      etag = response.headers["Etag"]

      headers = HTTP::Headers{"If-None-Match" => etag}
      not_modified, body, _ = assets_request(
        root, "GET", "/media/web/abc/Build/Spy.framework.js.br", headers,
      )

      not_modified.status_code.should eq 304
      body.empty?.should be_true
    end
  end

  it "supports byte ranges" do
    with_assets_root do |root|
      headers = HTTP::Headers{"Range" => "bytes=1-2"}
      response, body, _ = assets_request(
        root, "GET", "/media/web/abc/Build/Spy.framework.js.br", headers,
      )

      response.status_code.should eq 206
      response.headers["Content-Range"].should eq "bytes 1-2/3"
      body.should eq Bytes[0x2a, 0x00]
    end
  end

  it "rejects an unsatisfiable range" do
    with_assets_root do |root|
      headers = HTTP::Headers{"Range" => "bytes=99-"}
      response, _, _ = assets_request(
        root, "GET", "/media/web/abc/Build/Spy.framework.js.br", headers,
      )

      response.status_code.should eq 416
      response.headers["Content-Range"].should eq "bytes */3"
    end
  end

  it "sends no body for HEAD" do
    with_assets_root do |root|
      response, body, _ = assets_request(root, "HEAD", "/media/web/abc/Build/Spy.framework.js.br")

      response.headers["Content-Length"].should eq "3"
      body.empty?.should be_true
    end
  end

  it "leaves other media alone even when it ends with an encoding suffix" do
    with_assets_root do |root|
      _, _, reached_next = assets_request(root, "GET", "/media/screenshot/abc.jpg.br")

      reached_next.should be_true
    end
  end
end
