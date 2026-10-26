# `status` is the publication state (draft/published); the catalogue needs a
# second axis for how far a project got. Genre only makes sense for games and
# moves out of the tag strip, which is then left for mood and technology.
class AddDevStatusAndGenreToProjects::V00000000000040 < Avram::Migrator::Migration::V1
  # Old tag slug => genre. Tag rows stay in the table: tools, assets and mood
  # tags keep using them. Only links from games are moved into the field.
  GENRE_TAGS = {
    "action"       => "action",
    "adventure"    => "adventure",
    "arcade"       => "arcade",
    "puzzle"       => "puzzle",
    "strategy"     => "strategy",
    "rpg"          => "rpg",
    "simulator"    => "simulator",
    "racing"       => "racing",
    "platformer"   => "platformer",
    "horror"       => "horror",
    "shooter"      => "shooter",
    "visual_novel" => "visual_novel",
    "novel"        => "visual_novel",
    "sport"        => "sport",
    "other"        => "other",
  }

  def migrate
    alter table_for(Project) do
      # Existing projects stay active: a neutral default beats guessing.
      add dev_status : String, default: "active"
      add genre : String?
      add_index :dev_status
      add_index :genre
    end

    # A game may carry several genre tags while the field stores one: the
    # first by the fixed order wins, and only links that map to the chosen
    # genre are dropped. Other genre tags stay visible instead of vanishing.
    execute <<-SQL
      WITH mapping(slug, genre, priority) AS (
        VALUES #{mapping_values}
      ), matched AS (
        SELECT DISTINCT ON (project_tags.project_id)
          project_tags.project_id,
          mapping.genre
        FROM project_tags
        JOIN tags ON tags.id = project_tags.tag_id
        JOIN mapping ON mapping.slug = tags.slug
        JOIN projects ON projects.id = project_tags.project_id
        WHERE projects.kind = 'game' AND projects.genre IS NULL
        ORDER BY project_tags.project_id, mapping.priority
      )
      UPDATE projects
      SET genre = matched.genre
      FROM matched
      WHERE projects.id = matched.project_id
    SQL

    execute <<-SQL
      WITH mapping(slug, genre, priority) AS (
        VALUES #{mapping_values}
      )
      DELETE FROM project_tags
      USING tags, projects, mapping
      WHERE project_tags.tag_id = tags.id
        AND projects.id = project_tags.project_id
        AND projects.kind = 'game'
        AND tags.slug = mapping.slug
        AND projects.genre = mapping.genre
    SQL
  end

  def rollback
    alter table_for(Project) do
      remove :genre
      remove :dev_status
    end
  end

  # Values are constants, so they can be inlined without parameters.
  private def mapping_values : String
    GENRE_TAGS.map_with_index do |(slug, genre), index|
      "('#{slug}', '#{genre}', #{index})"
    end.join(", ")
  end
end
