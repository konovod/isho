module Slugify
  TRANSLITERATIONS = {
    'а' => "a", 'б' => "b", 'в' => "v", 'г' => "g", 'д' => "d", 'е' => "e",
    'ё' => "e", 'ж' => "zh", 'з' => "z", 'и' => "i", 'й' => "y", 'к' => "k",
    'л' => "l", 'м' => "m", 'н' => "n", 'о' => "o", 'п' => "p", 'р' => "r",
    'с' => "s", 'т' => "t", 'у' => "u", 'ф' => "f", 'х' => "kh", 'ц' => "ts",
    'ч' => "ch", 'ш' => "sh", 'щ' => "shch", 'ъ' => "", 'ы' => "y", 'ь' => "",
    'э' => "e", 'ю' => "yu", 'я' => "ya",
  }

  def self.call(value : String, fallback : String = "project") : String
    slug = String.build do |io|
      value.downcase.each_char do |char|
        if mapped = TRANSLITERATIONS[char]?
          io << mapped
        elsif ('a'..'z').includes?(char) || ('0'..'9').includes?(char)
          io << char
        else
          io << '-'
        end
      end
    end

    slug = slug.gsub(/-+/, "-").strip('-')
    slug = slug[0, 80].strip('-')
    slug.empty? ? fallback : slug
  end

  def self.unique_project_slug(title : String) : String
    base = call(title, "project")
    candidate = base
    suffix = 2

    while ProjectQuery.new.slug(candidate).first?
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    candidate
  end

  def self.unique_devlog_slug(project_id : Int64, title : String) : String
    base = call(title, "devlog")
    candidate = base
    suffix = 2

    while DevlogQuery.new.project_id(project_id).slug(candidate).first?
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    candidate
  end

  def self.unique_forum_section_slug(title : String) : String
    base = call(title, "section")
    candidate = base
    suffix = 2

    while ForumSectionQuery.new.by_slug(candidate).first?
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    candidate
  end

  def self.unique_forum_topic_slug(section_id : Int64, title : String) : String
    base = call(title, "topic")
    candidate = base
    suffix = 2

    while ForumTopicQuery.new.section_id(section_id).slug(candidate).first?
      candidate = "#{base}-#{suffix}"
      suffix += 1
    end

    candidate
  end
end
