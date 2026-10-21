require "./spec_helper"

describe Slugify do
  it "transliterates Russian titles" do
    Slugify.call("Ночная смена").should eq "nochnaya-smena"
  end

  it "removes unsafe characters" do
    Slugify.call("Hello, World! 2026").should eq "hello-world-2026"
  end

  it "falls back when nothing is left" do
    Slugify.call("!!!").should eq "project"
  end
end
