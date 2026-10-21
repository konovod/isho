class Home::Index < ApiAction
  include Api::Auth::SkipRequireSession

  get "/" do
    json({name: "isho api", version: "0.1.0"})
  end
end
