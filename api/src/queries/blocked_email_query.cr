class BlockedEmailQuery < BlockedEmail::BaseQuery
  def by_email(value : String)
    email(value.strip.downcase)
  end

  def newest_first
    created_at.desc_order
  end

  def search(term : String)
    pattern = "%#{term}%"

    email.ilike(pattern).or(&.username.ilike(pattern))
  end
end
