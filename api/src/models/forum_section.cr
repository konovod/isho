class ForumSection < BaseModel
  table do
    # Sections have at most two levels: a root section may contain
    # subsections. Child sections ignore group_title; the parent provides the
    # grouping and the breadcrumb.
    belongs_to parent : ForumSection?
    column title : String
    column slug : String
    column description : String?
    column group_title : String?
    column position : Int32
    # Moderators can turn AI answers off per section; "projects" is always off.
    column ai_answers_enabled : Bool
    has_many topics : ForumTopic
  end

  def root? : Bool
    parent_id.nil?
  end

  def child? : Bool
    !root?
  end
end
