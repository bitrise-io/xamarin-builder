require_relative './analyzer'

class Builder
  def initialize(path, configuration, platform)
    fail 'Empty path provided' if path.to_s == ''
    fail "File (#{path}) not exist" unless File.exist? path

    fail 'No configuration provided' if configuration.to_s == ''
    fail 'No platform provided' if platform.to_s == ''

    @path = path
    @configuration = configuration
    @platform = platform
  end

  def build
    analyzer = Analyzer.new()
    analyzer.analyze(@path)

    build_commands = analyzer.build_commands(@configuration, @platform)

    build_commands.each do |build_command|
      puts
      puts "\e[32m#{build_command}\e[0m"
      puts
      system(build_command)
    end

    @generated_files = analyzer.collect_generated_files(@configuration, @platform)
  end

  def generated_files
    @generated_files
  end
end
