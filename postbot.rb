Octokit.configure do |config|
  config.login = ENV['GITHUB_LOGIN']
  config.password = ENV['GITHUB_PASSWORD']
end

before do
  header_list = {
    'Access-Control-Allow-Origin' => '*',
    'Access-Control-Allow-Headers' => 'Accept, Content-Type',
    'Access-Control-Allow-Methods' => 'GET, POST, OPTIONS',
  }

  headers(header_list)
end

options '*' do
  response.headers["Allow"] = "HEAD, GET, PUT, POST, DELETE, OPTIONS"
  response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"
  200
end

post '/contents/:user/:name/:type' do
  configuration_path = '_config.yml'
  contents_response = Octokit.contents(params, :path => configuration_path)
  configuration = YAML.safe_load(Base64.decode64(contents_response.content))

  type = params.fetch('type')
  contents = configuration.fetch('contents')
  options = contents.fetch(type)

  template_path = options.fetch('template')
  template_file = Octokit.contents(params, :path => template_path)

  template = Liquid::Template.parse(Base64.decode64(template_file.content))

  data = params.fetch('data')
  content = template.render(params)

  placeholders = data
  placeholders['uuid'] = SecureRandom.uuid

  path = options.fetch('path').gsub(/:(\w+)/) do |match|
    placeholders[$1]
  end

  path.downcase!
  path.strip!
  path.gsub!(' ', '-')

  message = options.fetch('message', "Create #{path}")

  commit = options.fetch('commit')
  if commit
    create_response = Octokit.create_contents(params, path, message, content)
  else
    base_branch = "master"
    content_branch = "content/#{path}"

    base = Octokit.reference(params, "heads/#{base_branch}")
    reference = Octokit.create_reference(params, "heads/#{content_branch}", base.object.sha)

    contents = Octokit.create_content(params, path, message, content, {
      :branch => content_branch,
    })

    Octokit.create_pull_request(params, base_branch, content_branch, message)
  end

  if params.fetch('redirect')
    redirect params.fetch('redirect')
  else
    "done"
  end
end
