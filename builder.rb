require_relative './analyzer'

class Builder
  def initialize(project_path, configuration, platform)
    fail 'Empty path provided' if project_path.to_s == ''
    fail "File (#{project_path}) not exist" unless File.exist? project_path

    fail 'No configuration provided' if configuration.to_s == ''
    fail 'No platform provided' if platform.to_s == ''

    @project_path = project_path
    @configuration = configuration
    @platform = platform
  end

  def build
    analyzer = Analyzer.new()
    analyzer.analyze(@project_path)

    command = analyzer.build_command(@configuration, @platform)

    puts
    puts command
    puts
    system(command)

    output_hash = analyzer.output_hash(@configuration, @platform)
    puts
    puts "output_hash: #{output_hash}"
  end
end