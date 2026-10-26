require "../spec_helper"

describe Import::UrlGuard do
  it "accepts a public https page" do
    uri = Import::UrlGuard.check("https://example.com/game")
    uri.host.should eq "example.com"
  end

  it "rejects other schemes" do
    expect_raises(Import::UrlGuard::Blocked) do
      Import::UrlGuard.check("ftp://example.com/game")
    end

    expect_raises(Import::UrlGuard::Blocked) do
      Import::UrlGuard.check("javascript:alert(1)")
    end
  end

  it "rejects a link with a login" do
    expect_raises(Import::UrlGuard::Blocked) do
      Import::UrlGuard.check("https://user:secret@example.com/game")
    end
  end

  it "rejects a port that is not a web port" do
    expect_raises(Import::UrlGuard::Blocked) do
      Import::UrlGuard.check("http://example.com:6379/")
    end
  end

  it "rejects hosts that resolve into the local network" do
    ["localhost", "10.0.0.5", "metadata"].each do |host|
      expect_raises(Import::UrlGuard::Blocked) do
        Import::UrlGuard.check("http://#{host}/")
      end
    end
  end

  it "knows the private IPv4 ranges" do
    %w[127.0.0.1 10.1.2.3 172.16.0.1 172.31.255.255 192.168.1.1 169.254.169.254 100.64.0.1 0.0.0.0 224.0.0.1].each do |address|
      Import::UrlGuard.internal?(Socket::IPAddress.new(address, 80)).should be_true
    end

    %w[8.8.8.8 93.184.216.34 172.32.0.1 169.253.0.1 100.63.0.1].each do |address|
      Import::UrlGuard.internal?(Socket::IPAddress.new(address, 80)).should be_false
    end
  end

  it "treats IPv4-mapped IPv6 like the IPv4 address" do
    Import::UrlGuard.internal?(Socket::IPAddress.new("::ffff:10.0.0.1", 80)).should be_true
    Import::UrlGuard.internal?(Socket::IPAddress.new("::1", 80)).should be_true
    Import::UrlGuard.internal?(Socket::IPAddress.new("::ffff:8.8.8.8", 80)).should be_false
  end

  it "refuses when the name does not resolve" do
    Import::UrlGuard.resolver = ->(host : String, port : Int32) { raise Socket::Error.new("no dns") }

    expect_raises(Import::UrlGuard::Blocked) do
      Import::UrlGuard.check("https://nowhere.example/")
    end
  end
end
