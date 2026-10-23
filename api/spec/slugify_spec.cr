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

  it "adds a suffix when a section slug is already taken" do
    ForumSectionFactory.create &.slug("dzhemy")

    Slugify.unique_forum_section_slug("Джемы").should eq "dzhemy-2"
  end
end
