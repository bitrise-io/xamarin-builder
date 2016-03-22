require_relative './analyzer'

class Builder
  def initialize(path, configuration, platform, project_type_filter=nil)
    fail 'Empty path provided' if path.to_s == ''
    fail "File (#{path}) not exist" unless File.exist? path

    fail 'No configuration provided' if configuration.to_s == ''
    fail 'No platform provided' if platform.to_s == ''

    @path = path
    @configuration = configuration
    @platform = platform
    @project_type_filter = project_type_filter || ['ios', 'android']
  end

  def build
    analyzer = Analyzer.new
    analyzer.analyze(@path)

    build_commands = analyzer.build_commands(@configuration, @platform, @project_type_filter)
    if build_commands.empty?
      # No iOS or Android application found to build
      # Switching to framework building
      build_commands << analyzer.build_solution_command(@configuration, @platform)
    end

    build_commands.each do |build_command|
      puts ""
      puts "\e[34m#{build_command}\e[0m"
      raise 'build command failed' unless system(build_command)
    end

    @generated_files = analyzer.collect_generated_files(@configuration, @platform, @project_type_filter)
  end

  def build_solution
    analyzer = Analyzer.new
    analyzer.analyze(@path)

    build_command = analyzer.build_solution_command(@configuration, @platform)

    puts
    puts "\e[34m#{build_command}\e[0m"
    puts

    raise 'build command failed' unless system(build_command)

    @generated_files = analyzer.collect_generated_files(@configuration, @platform, @project_type_filter)
  end

  def build_test
    analyzer = Analyzer.new
    analyzer.analyze(@path)

    test_commands = analyzer.build_test_commands(@configuration, @platform, @project_type_filter)

    test_commands.each do |test_command|
      puts
      puts "\e[34m#{test_command}\e[0m"
      puts
      raise 'Failed' unless system(test_command)
    end

    @generated_files = analyzer.collect_generated_files(@configuration, @platform, @project_type_filter)
  end

  def run_nunit_tests(options = nil)
    analyzer = Analyzer.new
    analyzer.analyze(@path)

    test_commands = analyzer.nunit_test_commands(@configuration, @platform, options)
    puts test_commands

    raise 'No projects found to test' if test_commands.empty?
    test_commands.each_with_index do |test_command, idx|
      puts
      puts "\e[34m#{test_command}\e[0m"
      raise 'Test failed' unless system(test_command)
    end
  end

  def generated_files
    @generated_files
  end
end
